# frozen_string_literal: true

module Sadame
  # Manages a systemd service: whether it starts at boot and whether it is
  # running now.
  #
  #   service "nginx", enable: true, state: :running
  #   service "cups", enable: false, state: :stopped
  #
  # Other resources can ask it to start, stop, restart or reload through
  # notifies:.
  #
  # With user:, the unit belongs to that user's systemd instance
  # (systemctl --user -M USER@), such as a timer in ~/.config/systemd/user.
  # The user's instance must be running: the user is logged in, or has
  # lingering enabled (loginctl enable-linger USER).
  class ServiceResource < Resource
    STATES = %w[running stopped].freeze
    ACTIONS = [:start, :stop, :restart, :reload, :enable, :disable].freeze

    def self.type_name
      "service"
    end

    def self.allowed_options
      [:enable, :state, :user]
    end

    def self.actions
      ACTIONS
    end

    def desired
      attributes = {}
      attributes[:enabled] = options[:enable] if options.key?(:enable)
      attributes[:state] = options[:state].to_s if options[:state]
      attributes
    end

    def current
      require_systemd
      attributes = {}
      attributes[:enabled] = enabled? if options.key?(:enable)
      attributes[:state] = active? ? "running" : "stopped" if options[:state]
      attributes
    end

    def apply(changes)
      if changed?(changes, :enabled)
        systemctl(options[:enable] ? "enable" : "disable")
      end
      return unless changed?(changes, :state)

      systemctl(options[:state].to_s == "running" ? "start" : "stop")
    end

    def run_action(action)
      raise ResourceError, "#{id} does not support the #{action} action" unless ACTIONS.include?(action)

      require_systemd
      systemctl(action.to_s)
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:enable)
      user = options[:user]
      return if user.nil? || (user.is_a?(String) && !user.empty?)

      raise ResourceError, "#{id}: user must be a user name"
    end

    def require_systemd
      return if host.systemd?

      raise ResourceError, "#{id}: systemd is not running on this host (the service resource needs systemd)"
    end

    def enabled?
      shell.run("#{systemctl_command} is-enabled #{quote(name)}").stdout.strip == "enabled"
    end

    def active?
      shell.run("#{systemctl_command} is-active #{quote(name)}").stdout.strip == "active"
    end

    def systemctl(verb)
      shell.run!("#{systemctl_command} #{verb} #{quote(name)}")
    end

    def systemctl_command
      return "systemctl" if options[:user].nil?

      "systemctl --user -M #{quote("#{options[:user]}@")}"
    end
  end
end
