# frozen_string_literal: true

module Sadame
  # A machine that is not there, for `sadame validate`: recipes are
  # evaluated against it to find their mistakes without connecting to
  # anything. Its platform is one of PLATFORMS, its facts are made up, and
  # it refuses to run commands.
  module StandIn
    # os-release of the systems --platform can name.
    PLATFORMS = {
      "debian" => "ID=debian\nVERSION_ID=\"12\"\nVERSION_CODENAME=bookworm\nPRETTY_NAME=\"Debian GNU/Linux 12 (bookworm)\"\n",
      "ubuntu" => "ID=ubuntu\nID_LIKE=debian\nVERSION_ID=\"24.04\"\nVERSION_CODENAME=noble\nPRETTY_NAME=\"Ubuntu 24.04 LTS\"\n",
      "rocky" => "ID=\"rocky\"\nID_LIKE=\"rhel centos fedora\"\nVERSION_ID=\"9.4\"\nPRETTY_NAME=\"Rocky Linux 9.4 (Blue Onyx)\"\n",
      "alpine" => "ID=alpine\nVERSION_ID=3.20.3\nPRETTY_NAME=\"Alpine Linux v3.20\"\n",
      "arch" => "ID=arch\nPRETTY_NAME=\"Arch Linux\"\n"
    }.freeze

    def self.platform(name)
      text = PLATFORMS[name]
      unless text
        raise UsageError, "unknown platform #{name} for --platform (known: #{PLATFORMS.keys.join(", ")})"
      end

      Platform.from_os_release(text)
    end

    # Refuses every command: a recipe that runs one while it is evaluated,
    # or a check that would need the machine, says so instead.
    class Shell < Sadame::Shell
      def run(command)
        raise Error, "validate runs no commands, and something asked for: #{command}"
      end

      def stream(command)
        run(command)
      end

      def read_file(path)
        raise Error, "validate reads no files on the machine, and something asked for #{path}"
      end

      def write_file(path, _content)
        raise Error, "validate writes no files, and something asked to write #{path}"
      end
    end

    class Host < Sadame::Host
      def initialize(name:, groups:, platform:)
        super(Shell.new, name: name, groups: groups)
        @platform = platform
        @init_system = platform.family == "alpine" ? :openrc : :systemd
      end

      def facts
        @facts ||= Facts.new(self)
      end
    end

    # Plausible values for a small virtual server, so that recipes that
    # compute with facts can be evaluated. The addresses are from the
    # ranges set aside for documentation.
    class Facts < Sadame::Facts
      private

      def read(name)
        case name
        when :hostname then @host.name.split(".").first
        when :fqdn then @host.name
        when :arch then "x86_64"
        when :kernel then "6.1.0"
        when :cpus then 2
        when :memory_mb then 2048
        when :swap_mb then 0
        when :root_disk_gb then 20
        when :ipv4 then "192.0.2.10"
        when :default_interface then "eth0"
        when :ipv4_addresses then ["192.0.2.10"]
        when :ipv6_addresses then ["2001:db8::10"]
        when :virtualization then "kvm"
        when :container then false
        when :service_manager then @host.init_system.to_s
        when :machine_id then "0123456789abcdef0123456789abcdef"
        end
      end
    end
  end
end
