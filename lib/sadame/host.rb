# frozen_string_literal: true

module Sadame
  # The machine being configured: its shell plus facts read from it once
  # and then reused by every resource.
  class Host
    attr_reader :shell, :name

    def initialize(shell, name: "local")
      @shell = shell
      @name = name
      @platform = nil
      @package_manager = nil
      @systemd = nil
    end

    def platform
      @platform ||= Platform.detect(shell)
    end

    def package_manager
      @package_manager ||= PackageManagers.for(platform, shell)
    end

    def systemd?
      @systemd = shell.run("test -d /run/systemd/system").success? if @systemd.nil?
      @systemd
    end
  end
end
