# frozen_string_literal: true

require "open3"

# A small network of SSH targets for testing push mode for real, used by
# `rake test:push` (test/integration/push/run.rb) and by the docs
# transcripts. Development tooling: CRuby only.
#
#   network sadame-lab           controller, web1/web2.example.com (port 22),
#                                db1.example.com (port 2222), bastion.example.com
#   network sadame-lab-private   bastion.example.com, app1.internal
#
# The targets boot systemd and run sshd; user "deploy" has passwordless
# sudo. The controller has only the OpenSSH client, its own key and
# ~/.ssh/config, and the static sadame binary from dist/.
module Lab
  ROOT = File.expand_path("../../..", __dir__)
  PREFIX = "sadame-lab"
  NETWORK = "#{PREFIX}"
  PRIVATE_NETWORK = "#{PREFIX}-private"

  # name => [network aliases, sshd port, networks]
  TARGETS = {
    "web1" => [["web1.example.com"], 22, [NETWORK]],
    "web2" => [["web2.example.com"], 22, [NETWORK]],
    "db1" => [["db1.example.com"], 2222, [NETWORK]],
    "bastion" => [["bastion.example.com"], 22, [NETWORK, PRIVATE_NETWORK]],
    "app1" => [["app1.internal"], 22, [PRIVATE_NETWORK]]
  }.freeze

  SSH_CONFIG = <<~CONFIG
    Host *
      StrictHostKeyChecking accept-new
  CONFIG

  class Environment
    def up
      check_binary
      down
      build_images
      sh("docker", "network", "create", NETWORK)
      sh("docker", "network", "create", "--internal", PRIVATE_NETWORK)
      TARGETS.each_key { |name| start_target(name) }
      start_controller
      install_keys
      wait_for_sshd
    end

    def down
      names = (TARGETS.keys + ["controller"]).map { |name| "#{PREFIX}-#{name}" }
      quiet("docker", "rm", "--force", *names)
      quiet("docker", "network", "rm", NETWORK, PRIVATE_NETWORK)
    end

    # Runs a shell command in the controller; returns [exit status, output].
    def controller(command, dir: "/sadame", env: {})
      arguments = ["docker", "exec", "--workdir", dir]
      env.each { |key, value| arguments += ["--env", "#{key}=#{value}"] }
      output, status = Open3.capture2e(*arguments, "#{PREFIX}-controller", "sh", "-c", command)
      [status.exitstatus, output]
    end

    # Runs commands in the controller like a terminal session (see
    # script/transcripts/session.sh); returns the transcript.
    def controller_session(commands, dir:)
      output, = Open3.capture2e("docker", "exec", "--interactive", "--workdir", dir, "#{PREFIX}-controller",
                                "sh", "/sadame/script/transcripts/session.sh", stdin_data: "#{commands.join("\n")}\n")
      output
    end

    # Runs a shell command on a target as root; returns its output.
    def target(name, command)
      output, = Open3.capture2e("docker", "exec", "#{PREFIX}-#{name}", "sh", "-c", command)
      output
    end

    def binary
      "sadame-linux-#{architecture}"
    end

    private

    def architecture
      machine, = Open3.capture2("docker", "info", "--format", "{{.Architecture}}")
      machine.strip == "aarch64" || machine.strip == "arm64" ? "arm64" : "amd64"
    end

    def check_binary
      path = File.join(ROOT, "dist", binary)
      return if File.exist?(path)

      abort "#{path} is missing; build it first with rake build:linux-#{architecture}"
    end

    def build_images
      %w[target controller].each do |image|
        sh("docker", "build", "--quiet", "--tag", "#{PREFIX}-#{image}", "--file", File.join(__dir__, "#{image}.Dockerfile"),
           __dir__)
      end
    end

    def start_target(name)
      aliases, _port, networks = TARGETS.fetch(name)
      arguments = ["docker", "run", "--detach", "--name", "#{PREFIX}-#{name}", "--hostname", name,
                   "--privileged", "--cgroupns=host", "--volume", "/sys/fs/cgroup:/sys/fs/cgroup:rw",
                   "--network", networks.first]
      aliases.each { |name_alias| arguments += ["--network-alias", name_alias] }
      sh(*arguments, "#{PREFIX}-target")
      networks.drop(1).each do |network|
        sh("docker", "network", "connect", *aliases.flat_map { |name_alias| ["--alias", name_alias] }, network,
           "#{PREFIX}-#{name}")
      end
    end

    def start_controller
      sh("docker", "run", "--detach", "--name", "#{PREFIX}-controller", "--network", NETWORK,
         "--volume", "#{ROOT}:/sadame:ro", "#{PREFIX}-controller", "sleep", "infinity")
      setup = <<~SCRIPT
        mkdir -p /root/.ssh && chmod 0700 /root/.ssh
        ssh-keygen -q -t ed25519 -N '' -f /root/.ssh/id_ed25519
        printf '#{SSH_CONFIG.gsub("\n", "\\n")}' > /root/.ssh/config
        chmod 0600 /root/.ssh/config
        ln -s /sadame/dist/#{binary} /usr/local/bin/sadame
      SCRIPT
      status, output = controller(setup, dir: "/")
      abort "controller setup failed:\n#{output}" unless status == 0
    end

    def install_keys
      _status, key = controller("cat /root/.ssh/id_ed25519.pub", dir: "/")
      TARGETS.each do |name, (_aliases, port, _networks)|
        script = %w[deploy ops].map do |user|
          "install -d -m 0700 -o #{user} -g #{user} /home/#{user}/.ssh && " \
            "echo '#{key.strip}' > /home/#{user}/.ssh/authorized_keys && " \
            "chown #{user}:#{user} /home/#{user}/.ssh/authorized_keys && chmod 0600 /home/#{user}/.ssh/authorized_keys"
        end.join(" && ")
        script += " && echo 'Port #{port}' > /etc/ssh/sshd_config.d/port.conf && systemctl restart ssh" if port != 22
        wait_until("systemd on #{name}") { target(name, "systemctl is-system-running --wait").match?(/running|degraded/) }
        target(name, script)
      end
    end

    def wait_for_sshd
      checks = {
        "web1.example.com" => "ssh deploy@web1.example.com true",
        "web2.example.com" => "ssh deploy@web2.example.com true",
        "db1.example.com" => "ssh -p 2222 deploy@db1.example.com true",
        "app1.internal" => "ssh -F /sadame/test/integration/push/ssh_config app1.internal true"
      }
      checks.each do |name, command|
        wait_until("sshd on #{name}") { controller(command, dir: "/").first == 0 }
      end
    end

    def wait_until(what, seconds: 90)
      deadline = Time.now + seconds
      until yield
        abort "timed out waiting for #{what}" if Time.now > deadline
        sleep 1
      end
    end

    def sh(*command)
      output, status = Open3.capture2e(*command)
      abort "#{command.join(" ")} failed:\n#{output}" unless status.success?

      output
    end

    def quiet(*command)
      Open3.capture2e(*command)
    end
  end
end
