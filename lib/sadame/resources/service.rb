# frozen_string_literal: true

module Sadame
  # Manages a service: whether it starts at boot and whether it is running
  # now, with systemd, or with OpenRC on Alpine.
  #
  #   service "nginx", enable: true, state: :running
  #   service "cups", enable: false, state: :stopped
  #
  # Other resources can ask it to start, stop, restart or reload through
  # notifies:.
  #
  # With OpenRC, enable: true adds the service to the default runlevel and
  # enable: false removes it from every runlevel it is in.
  #
  # With user: (systemd only), the unit belongs to that user's systemd
  # instance (systemctl --user -M USER@), such as a timer in
  # ~/.config/systemd/user. The user's instance must be running: the user
  # is logged in, or has lingering enabled (loginctl enable-linger USER).
  class ServiceResource < Resource
    STATES = %w[running stopped].freeze
    ACTIONS = [:start, :stop, :restart, :reload, :enable, :disable].freeze
    OPENRC_RUNLEVEL = "default"

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
      require_service_manager
      attributes = {}
      attributes[:enabled] = enabled? if options.key?(:enable)
      attributes[:state] = active? ? "running" : "stopped" if options[:state]
      attributes
    end

    def apply(changes)
      if changed?(changes, :enabled)
        options[:enable] ? enable : disable
      end
      return unless changed?(changes, :state)

      control(options[:state].to_s == "running" ? "start" : "stop")
    end

    def run_action(action)
      raise ResourceError, "#{id} does not support the #{action} action" unless ACTIONS.include?(action)

      require_service_manager
      case action
      when :enable then enable
      when :disable then disable
      else control(action.to_s)
      end
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:enable)
      user = options[:user]
      return if user.nil? || (user.is_a?(String) && !user.empty?)

      raise ResourceError, "#{id}: user must be a user name"
    end

    def require_service_manager
      case host.init_system
      when :systemd then nil
      when :openrc
        raise ResourceError, "#{id}: user: needs systemd; this host runs OpenRC" if options[:user]
      else
        raise ResourceError, "#{id}: no service manager is running on this host " \
                             "(the service resource needs systemd, or OpenRC as on Alpine)"
      end
    end

    def openrc?
      host.init_system == :openrc
    end

    def enabled?
      return !runlevels.empty? if openrc?

      shell.run("#{systemctl_command} is-enabled #{quote(name)}").stdout.strip == "enabled"
    end

    def active?
      return shell.run("rc-service #{quote(name)} status").success? if openrc?

      shell.run("#{systemctl_command} is-active #{quote(name)}").stdout.strip == "active"
    end

    def enable
      return shell.run!("rc-update add #{quote(name)} #{OPENRC_RUNLEVEL}") if openrc?

      systemctl("enable")
    end

    def disable
      return systemctl("disable") unless openrc?

      levels = runlevels
      return if levels.empty?

      shell.run!(levels.map { |level| "rc-update del #{quote(name)} #{quote(level)}" }.join(" && "))
    end

    # start, stop, restart or reload.
    def control(verb)
      return shell.run!("rc-service #{quote(name)} #{verb}") if openrc?

      systemctl(verb)
    end

    # The OpenRC runlevels the service is in, from lines of `rc-update
    # show` such as "  nginx |      default".
    def runlevels
      shell.run!("rc-update show").stdout.split("\n").each do |entry|
        service, levels = entry.split("|", 2)
        return levels.to_s.split(" ") if service.strip == name
      end
      []
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
