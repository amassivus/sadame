# frozen_string_literal: true

# Real-VM smoke tests. Local only: never wired to CI, because the VMs and
# the details to reach them belong to the maintainer, in hosts.local.rb
# (git ignores it; hosts.example.rb shows the shape).
#
#   rake "vm:reset[ubuntu]"    revert the ubuntu VM to its clean snapshot
#   rake "vm:test[ubuntu]"     push every example that applies to it, each on
#                              a freshly reverted VM, and check that drift
#                              exits 0 after each
#   rake vm:test:all           every VM in hosts.local.rb
#
# Each example is applied with push mode, through the inventory, from this
# machine; the binaries come from dist/ (SADAME_BINARY_DIR). The VMs are
# x86_64, so dist/sadame-linux-amd64 must exist.
#
# Development tooling: CRuby only.

require "json"
require "open3"
require "shellwords"
require_relative "../../../lib/sadame"
require_relative "../../support/example_matrix"

module VMTests
  ROOT = File.expand_path("../../..", __dir__)
  INVENTORY = File.join(__dir__, "hosts.local.rb")
  EXAMPLE_INVENTORY = File.join(__dir__, "hosts.example.rb")
  DISTRIBUTIONS = %w[ubuntu debian rocky arch omarchy].freeze
  PEBBLE_VERSION = "v2.10.1"

  # On the Omarchy VM only the workstation examples run; example 12 runs
  # nowhere else among the VMs.
  OMARCHY_EXAMPLES = ["examples/01-hello", "examples/12-omarchy-workstation"].freeze
  # 07 moves SSH to port 2222.
  HARDENING = "examples/07-hardening-baseline"

  Result = Struct.new(:example, :status, :detail)

  def self.missing_inventory?
    return false if File.exist?(INVENTORY)

    puts <<~TEXT
      The VM tests need #{INVENTORY.delete_prefix("#{ROOT}/")}, which is not there.
      Copy #{EXAMPLE_INVENTORY.delete_prefix("#{ROOT}/")} to that name and fill in:
        - one group per distribution (#{DISTRIBUTIONS.join(", ")}), each with one host:
          address, user (passwordless sudo), port, ssh_opts, and vars libvirt_domain:
          (the libvirt domain) and snapshot: (the clean snapshot to revert to);
        - a hypervisor group with the libvirt host's SSH details and vars libvirt_uri:.
      Git ignores hosts.local.rb. Nothing was run.
    TEXT
    true
  end

  def self.inventory
    @inventory ||= Sadame::Inventory.load(INVENTORY, shell: Sadame::Shell.new)
  end

  def self.target(group)
    inventory.select(group_names: [group]).first
  end

  def self.distributions
    DISTRIBUTIONS.select { |name| inventory.group?(name) }
  end

  class Runner
    def initialize(distribution)
      @distribution = distribution
      @target = VMTests.target(distribution)
      @hypervisor = VMTests.target("hypervisor")
    end

    def reset
      domain = @target.vars.fetch(:libvirt_domain)
      snapshot = @target.vars.fetch(:snapshot)
      puts "== #{@distribution}: reverting #{domain} to snapshot #{snapshot}"
      virsh("snapshot-revert", domain, snapshot, "--running", "--force")
      add_forwards(domain)
      wait_for_ssh(@target.port)
      set_clock
    end

    # Each example starts from the clean snapshot, as each starts in a
    # fresh container in the Docker tests: examples conflict with each
    # other (04 installs docker-ce, another example docker.io).
    def test
      results = examples.map do |example|
        reset
        exercise(example)
      end
      report(results)
    end

    private

    def examples
      matrix_distro = @distribution == "omarchy" ? "arch" : @distribution
      selected = ExampleMatrix::EXAMPLES.select do |example|
        if @distribution == "omarchy"
          OMARCHY_EXAMPLES.include?(example[:path])
        else
          example[:distros].include?(matrix_distro) && example[:path] != "examples/12-omarchy-workstation"
        end
      end
      selected
    end

    def exercise(example)
      path = ExampleMatrix.recipe_path(example)
      print "#{example[:path]} ... "
      prepare_pebble if example[:pebble]
      failure = nil
      ExampleMatrix.vm_runs(example).each do |arguments|
        arguments = pebble_arguments(arguments) if example[:pebble]
        failure ||= expect(["apply", path, "-g", @distribution] + arguments, 0)
        failure ||= expect(["drift", path] + drift_target(example) + arguments, 0)
      end
      failure ||= drift_demo(path) if example[:drift_demo]
      puts failure ? "FAIL" : "ok"
      Result.new(example, failure ? :fail : :pass, failure)
    end

    # After 07, SSH listens on 2222 inside the VM: drift connects there, or
    # to the hypervisor port forwarded to it.
    def drift_target(example)
      return ["-g", @distribution] unless example[:path] == HARDENING

      ["-h", "#{@target.name}:#{@target.vars.fetch(:ssh_port_after_07, 2222)}"]
    end

    # On user-mode networking (GNOME Boxes, plain QEMU) the VM is reached
    # through ports QEMU forwards. Forwards added at run time do not survive
    # a restart of the VM, so the ones in vars hostfwd: are added again
    # after every revert; QEMU refuses a rule that already exists, which is
    # harmless.
    def add_forwards(domain)
      Array(@target.vars[:hostfwd]).each do |rule|
        virsh("qemu-monitor-command", domain, "--hmp", "hostfwd_add #{rule}")
      end
    end

    # Retried when ssh itself fails (exit status 255), as on a flaky home
    # network; reverting and adding forwards can safely run twice.
    # A snapshot taken while the VM ran (needed where the disk is
    # encrypted, as on Omarchy, so the VM comes back unlocked) resumes with
    # the time it was taken; package signatures and TLS need the real time.
    def set_clock
      run!(ssh(@target, "sudo -n date -u -s @#{Time.now.to_i} >/dev/null"), retries: 3)
    end

    def virsh(*arguments)
      uri = @hypervisor.vars.fetch(:libvirt_uri, "qemu:///system")
      run!(ssh(@hypervisor, Shellwords.join(["virsh", "-c", uri] + arguments)), retries: 3)
    end

    def drift_demo(path)
      script = File.join(File.dirname(path), "break-things.sh")
      run!("#{ssh(@target, "sudo sh -s")} < #{script}")
      expect(["drift", path, "-g", @distribution], 1) ||
        expect(["apply", path, "-g", @distribution], 0) ||
        expect(["drift", path, "-g", @distribution], 0)
    end

    # Pebble, Let's Encrypt's test server, runs on the VM itself and
    # accepts every challenge, so certbot can get a certificate without a
    # public domain.
    def prepare_pebble
      base = "https://github.com/letsencrypt/pebble"
      raw = "https://raw.githubusercontent.com/letsencrypt/pebble/#{PEBBLE_VERSION}"
      script = <<~SCRIPT
        set -e
        mkdir -p /opt/pebble/test/certs/localhost /opt/pebble/test/config && cd /opt/pebble
        curl -fsSL #{base}/releases/download/#{PEBBLE_VERSION}/pebble-linux-amd64.tar.gz |
          tar -xzf - --strip-components=3 --no-same-owner
        chmod 0755 pebble
        curl -fsSL -o test/certs/localhost/cert.pem #{raw}/test/certs/localhost/cert.pem
        curl -fsSL -o test/certs/localhost/key.pem #{raw}/test/certs/localhost/key.pem
        curl -fsSL -o test/config/pebble-config.json #{raw}/test/config/pebble-config.json
        PEBBLE_VA_ALWAYS_VALID=1 PEBBLE_WFE_NONCEREJECT=0 nohup ./pebble -config test/config/pebble-config.json \
          < /dev/null > pebble.log 2>&1 &
        for i in 1 2 3 4 5 6 7 8 9 10; do
          curl -fsk https://localhost:14000/dir > /dev/null && exit 0
          sleep 1
        done
        cat pebble.log
        exit 1
      SCRIPT
      run!("#{ssh(@target, "sudo sh -s")} <<'SCRIPT'\n#{script}SCRIPT")
    end

    def pebble_arguments(arguments)
      arguments.map { |argument| argument.sub("https://pebble:14000", "https://localhost:14000") }
    end

    def expect(arguments, wanted)
      command = [sadame] + arguments + ["--inventory", INVENTORY]
      output, status = Open3.capture2e({ "SADAME_BINARY_DIR" => File.join(ROOT, "dist") }, *command, chdir: ROOT)
      return nil if status.exitstatus == wanted

      "sadame #{arguments.join(" ")} exited #{status.exitstatus}, expected #{wanted}:\n#{output.lines.last(40).join}"
    end

    # The binary for this machine when it was built, else sadame from source.
    def sadame
      machine = `uname -sm`.strip
      name = { "Darwin arm64" => "sadame-darwin-arm64", "Darwin x86_64" => "sadame-darwin-amd64",
               "Linux x86_64" => "sadame-linux-amd64", "Linux aarch64" => "sadame-linux-arm64" }[machine]
      binary = name && File.join(ROOT, "dist", name)
      binary && File.exist?(binary) ? binary : File.join(ROOT, "bin", "sadame")
    end

    def ssh(target, command)
      Sadame::Push::SSH.new(target).ssh(command)
    end

    def wait_for_ssh(port)
      target = @target.with(port: port || @target.port)
      deadline = Time.now + 300
      until system(ssh(target, "true"), out: File::NULL, err: File::NULL)
        abort "#{@target.name} did not come back over SSH" if Time.now > deadline
        sleep 3
      end
    end

    def run!(command, retries: 0)
      output, status = Open3.capture2e(command)
      if status.exitstatus == 255 && retries.positive?
        sleep 5
        return run!(command, retries: retries - 1)
      end
      raise "#{command} failed:\n#{output}" unless status.success?

      output
    end

    def report(results)
      puts
      results.each do |result|
        puts "  #{result.status == :pass ? "pass" : "FAIL"}  #{result.example[:path]}"
      end
      results.select { |result| result.status == :fail }.each do |result|
        puts "\n--- #{result.example[:path]} on #{@distribution}\n#{result.detail}"
      end
      failed = results.count { |result| result.status == :fail }
      puts "\n#{@distribution} VM: #{results.size - failed} pass, #{failed} fail"
      failed == 0
    end
  end

  def self.main(command, distribution)
    return if missing_inventory?

    distributions = distribution.nil? || distribution == "all" ? self.distributions : [distribution]
    unknown = distributions - self.distributions
    abort "no #{unknown.join(", ")} group in #{INVENTORY}" unless unknown.empty?
    abort "unknown command #{command}" unless %w[reset test].include?(command)

    passed = distributions.map do |name|
      runner = Runner.new(name)
      command == "reset" ? (runner.reset || true) : runner.test
    end
    exit(passed.all? ? 0 : 1)
  end
end

VMTests.main(ARGV[0], ARGV[1]) if $PROGRAM_NAME == __FILE__
