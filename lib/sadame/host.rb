# frozen_string_literal: true

module Sadame
  # The machine being configured: its shell plus what is read from it once
  # and then reused by every resource, including the facts recipes see.
  class Host
    attr_reader :shell, :name, :groups

    # name and groups are what recipes see as host_name and host_groups.
    def initialize(shell, name: "local", groups: [])
      @shell = shell
      @name = name
      @groups = groups
      @platform = nil
      @package_manager = nil
      @init_system = nil
    end

    def platform
      @platform ||= Platform.detect(shell)
    end

    def package_manager
      @package_manager ||= PackageManagers.for(platform, shell)
    end

    def facts
      @facts ||= Facts.new(self)
    end

    # The service manager running on the host: :systemd, :openrc (Alpine),
    # or nil when neither runs, as in most containers.
    def init_system
      @init_system ||= detect_init_system
      @init_system == :none ? nil : @init_system
    end

    def systemd?
      init_system == :systemd
    end

    private

    def detect_init_system
      return :systemd if shell.run("test -d /run/systemd/system").success?
      return :openrc if shell.run("test -e /run/openrc/softlevel").success?

      :none
    end
  end
end
