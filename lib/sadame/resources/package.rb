# frozen_string_literal: true

module Sadame
  # Installs or removes a system package with the host's package manager
  # (apt, dnf, apk or pacman, detected from /etc/os-release).
  #
  #   package "nginx"
  #   package "telnet", state: :absent
  #   package "base-devel", options: "--asdeps"
  class PackageResource < Resource
    STATES = %w[installed absent].freeze

    def self.type_name
      "package"
    end

    def self.allowed_options
      [:state, :options]
    end

    def desired
      { state: desired_state }
    end

    def current
      { state: manager.installed?(name) ? "installed" : "absent" }
    end

    def apply(_changes)
      if desired_state == "installed"
        manager.install(name, options[:options])
      else
        manager.remove(name, options[:options])
      end
    end

    private

    def validate
      validate_choice(:state, STATES)
      flags = options[:options]
      return if flags.nil? || flags.is_a?(String) || flags.is_a?(Array)

      raise ResourceError, "#{id}: options must be a String or an Array of flags"
    end

    def desired_state
      (options[:state] || :installed).to_s
    end

    def manager
      host.package_manager
    end
  end
end
