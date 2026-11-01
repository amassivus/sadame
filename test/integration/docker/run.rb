# frozen_string_literal: true

# Docker integration tests: every example of test/support/example_matrix.rb
# runs in a fresh container of each distribution it supports, with the
# static binary for the container's architecture. Each run must apply with
# exit status 0 and then report no drift (exit status 0).
#
#   rake "test:docker[debian,amd64]"   one distribution and architecture
#   rake "test:docker[all,arm64]"      every distribution, arm64
#   rake test:docker                   every distribution, this machine's architecture
#   SADAME_IT_ONLY=03-nginx rake ...   only examples whose path contains the text
#
# Containers boot systemd (privileged, with the host's cgroups) so service
# resources run for real; Alpine uses OpenRC and only runs the examples
# without services. The other architecture runs under QEMU; register it
# with: docker run --privileged --rm tonistiigi/binfmt --install all
#
# Development tooling: CRuby only.

require "open3"
require_relative "../../support/example_matrix"

module DockerIntegration
  ROOT = File.expand_path("../../..", __dir__)
  PREFIX = "sadame-it"
  JOBS = Integer(ENV.fetch("SADAME_IT_JOBS", "4"))
  ONLY = ENV.fetch("SADAME_IT_ONLY", "")
  PEBBLE_IMAGE = "ghcr.io/letsencrypt/pebble:latest"

  # distro => [Dockerfile, base image per architecture (for build args), boots systemd]
  DISTROS = {
    "ubuntu" => ["ubuntu", {}, true],
    "debian" => ["debian", {}, true],
    "rocky" => ["rocky", {}, true],
    "alpine" => ["alpine", {}, false],
    "arch" => ["arch", { "amd64" => "archlinux:latest", "arm64" => "menci/archlinuxarm:latest" }, true]
  }.freeze

  Result = Struct.new(:example, :status, :detail, :seconds)

  class Runner
    def initialize(distro, arch, emulated:)
      @distro = distro
      @arch = arch
      @emulated = emulated
      @platform = "linux/#{arch}"
      @image = "#{PREFIX}-#{distro}-#{arch}"
      @dockerfile, @bases, @systemd = DISTROS.fetch(distro)
    end

    def run
      check_binary
      puts "== #{@distro} (#{@platform}#{@emulated ? ", emulated" : ""}): building #{@image}"
      build_image
      results = Queue.new
      runnable = []
      ExampleMatrix::EXAMPLES.each do |example|
        next unless example[:path].include?(ONLY)

        reason = skip_reason(example)
        reason ? results << Result.new(example, :skip, reason, 0) : runnable << example
      end

      pending = Queue.new
      runnable.each_with_index { |example, i| pending << [example, i] }
      workers = Array.new(JOBS) do
        Thread.new do
          loop do
            example, index = pending.pop(true)
            results << run_example(example, index)
          rescue ThreadError
            break
          end
        end
      end
      workers.each(&:join)
      report(Array.new(results.size) { results.pop })
    end

    private

    def skip_reason(example)
      return ExampleMatrix.skip_reason(example, @distro) unless example[:distros].include?(@distro)

      @emulated ? example[:emulated] : nil
    end

    def check_binary
      binary = File.join(ROOT, "dist", "sadame-linux-#{@arch}")
      return if File.exist?(binary)

      abort "#{binary} is missing; build it with rake build:linux-#{@arch}"
    end

    def build_image
      command = ["docker", "buildx", "build", "--quiet", "--load", "--platform", @platform, "--tag", @image,
                 "--file", File.join(__dir__, "images", "#{@dockerfile}.Dockerfile")]
      base = @bases[@arch]
      command += ["--build-arg", "BASE=#{base}"] if base
      sh(*command, File.join(__dir__, "images"))
    end

    def run_example(example, index)
      started = Time.now
      name = "#{PREFIX}-#{@distro}-#{@arch}-#{index}"
      network = example[:pebble] ? "#{name}-net" : nil
      start(example, name, network)
      detail = exercise(example, name)
      Result.new(example, detail ? :fail : :pass, detail, Time.now - started)
    rescue StandardError => e
      Result.new(example, :fail, "#{e.class}: #{e.message}", Time.now - started)
    ensure
      cleanup(name, network)
    end

    def start(example, name, network)
      command = ["docker", "run", "--detach", "--name", name, "--platform", @platform,
                 "--volume", "#{ROOT}:/sadame:ro"]
      if network
        sh("docker", "network", "create", network)
        sh("docker", "run", "--detach", "--name", "#{name}-pebble", "--network", network,
           "--platform", @platform, "--env", "PEBBLE_VA_ALWAYS_VALID=1", "--env", "PEBBLE_WFE_NONCEREJECT=0",
           PEBBLE_IMAGE)
        # Through /etc/hosts rather than Docker's DNS: some distributions
        # resolve through systemd-resolved, which ignores single-label names.
        address = sh("docker", "inspect", "--format", "{{(index .NetworkSettings.Networks \"#{network}\").IPAddress}}",
                     "#{name}-pebble").strip
        command += ["--network", network, "--add-host", "pebble:#{address}"]
      end
      if @systemd
        command += ["--privileged", "--cgroupns=host", "--volume", "/sys/fs/cgroup:/sys/fs/cgroup:rw"]
      end
      sh(*command, @image)
      wait_for_systemd(name) if @systemd
      exec_in(name, "ln -s /sadame/dist/sadame-linux-#{@arch} /usr/local/bin/sadame")
      (example[:setup] || []).each { |command_line| exec_in(name, command_line) }
    end

    # Returns nil when every check passed, or what went wrong.
    def exercise(example, name)
      path = File.join("/sadame", ExampleMatrix.recipe_path(example))
      ExampleMatrix.runs(example).each do |arguments|
        extra = arguments.map { |argument| shell_quote(argument) }.join(" ")
        failure = expect(name, "sadame apply #{path} #{extra}", 0) ||
                  expect(name, "sadame drift #{path} #{extra}", 0)
        return failure if failure
      end
      return nil unless example[:drift_demo]

      script = File.join(File.dirname(path), "break-things.sh")
      expect(name, "sh #{script}", 0) ||
        expect(name, "sadame drift #{path}", 1) ||
        expect(name, "sadame apply #{path}", 0) ||
        expect(name, "sadame drift #{path}", 0)
    end

    def expect(name, command, wanted)
      output, status = Open3.capture2e("docker", "exec", name, "sh", "-c", command)
      return nil if status.exitstatus == wanted

      "#{command} exited #{status.exitstatus}, expected #{wanted}:\n#{output.lines.last(40).join}"
    end

    def wait_for_systemd(name)
      deadline = Time.now + 180
      loop do
        output, = Open3.capture2e("docker", "exec", name, "systemctl", "is-system-running", "--wait")
        return if output.include?("running") || output.include?("degraded")
        raise "systemd did not start in #{name}: #{output.strip}" if Time.now > deadline

        sleep 2
      end
    end

    def exec_in(name, command)
      output, status = Open3.capture2e("docker", "exec", name, "sh", "-c", command)
      raise "#{command} failed in #{name}:\n#{output}" unless status.success?
    end

    def cleanup(name, network)
      quiet("docker", "rm", "--force", name, "#{name}-pebble")
      quiet("docker", "network", "rm", network) if network
    end

    def report(results)
      order = ExampleMatrix::EXAMPLES
      results.sort_by! { |result| order.index(result.example) }
      width = results.map { |result| result.example[:path].size }.max
      puts
      results.each do |result|
        label = { pass: "pass", fail: "FAIL", skip: "skip" }[result.status]
        time = result.status == :skip ? "" : format("%5.0fs  ", result.seconds)
        reason = result.status == :skip ? result.detail : ""
        puts "  #{label}  #{result.example[:path].ljust(width)}  #{time}#{reason}"
      end
      failures = results.select { |result| result.status == :fail }
      failures.each { |result| puts "\n--- #{result.example[:path]} on #{@distro} (#{@arch})\n#{result.detail}" }
      counts = %i[pass fail skip].map { |status| "#{results.count { |result| result.status == status }} #{status}" }
      puts "\n#{@distro} (#{@platform}): #{counts.join(", ")}"
      failures.empty?
    end

    def shell_quote(text)
      return text if text.match?(%r{\A[A-Za-z0-9_./:=,@+-]+\z})

      "'#{text.gsub("'", "'\\\\''")}'"
    end

    def sh(*command)
      output, status = Open3.capture2e(*command)
      raise "#{command.join(" ")} failed:\n#{output}" unless status.success?

      output
    end

    def quiet(*command)
      Open3.capture2e(*command)
    end
  end

  def self.native_arch
    machine, = Open3.capture2("docker", "info", "--format", "{{.Architecture}}")
    %w[aarch64 arm64].include?(machine.strip) ? "arm64" : "amd64"
  end

  def self.main(distro_argument, arch_argument)
    distros = distro_argument.nil? || distro_argument == "all" ? DISTROS.keys : distro_argument.split(",")
    arch = arch_argument || native_arch
    unknown = distros - DISTROS.keys
    abort "unknown distribution: #{unknown.join(", ")} (known: #{DISTROS.keys.join(", ")})" unless unknown.empty?

    emulated = arch != native_arch
    passed = distros.map { |distro| Runner.new(distro, arch, emulated: emulated).run }
    exit(passed.all? ? 0 : 1)
  end
end

DockerIntegration.main(ARGV[0], ARGV[1]) if $PROGRAM_NAME == __FILE__
