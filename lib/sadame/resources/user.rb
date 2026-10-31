# frozen_string_literal: true

module Sadame
  # Manages a local user account on Linux.
  #
  #   user "deploy", shell: "/bin/bash", groups: ["docker"]
  #   user "backup", system: true, home: "/var/lib/backup"
  #   user "olduser", state: :absent
  #
  # groups: lists groups the user must belong to; memberships not listed
  # are left alone. The groups must already exist. New users get a home
  # directory unless system: true.
  class UserResource < Resource
    STATES = %w[present absent].freeze

    def self.type_name
      "user"
    end

    def self.allowed_options
      [:uid, :home, :shell, :groups, :system, :state]
    end

    def desired
      return { state: "absent" } if absent?

      attributes = { state: "present" }
      attributes[:uid] = options[:uid] if options[:uid]
      attributes[:home] = options[:home] if options[:home]
      attributes[:shell] = options[:shell] if options[:shell]
      attributes[:groups] = desired_groups unless desired_groups.empty?
      attributes
    end

    def current
      require_linux
      result = shell.run("getent passwd #{quote(name)}")
      return { state: "absent" } unless result.success?

      fields = result.stdout.strip.split(":", -1)
      {
        state: "present",
        uid: fields[2].to_i,
        home: fields[5],
        shell: fields[6],
        groups: memberships(current_groups)
      }
    end

    def apply(changes)
      if absent?
        shell.run!("userdel #{quote(name)}")
      elsif changed?(changes, :state)
        require_shadow_tools
        shell.run!(useradd_command)
      else
        require_shadow_tools
        shell.run!(usermod_command(changes))
      end
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:system)
      if options[:uid] && !options[:uid].is_a?(Integer)
        raise ResourceError, "#{id}: uid must be an Integer"
      end
      groups = options[:groups]
      return if groups.nil? || (groups.is_a?(Array) && groups.all? { |group| group.is_a?(String) })

      raise ResourceError, "#{id}: groups must be an Array of group names"
    end

    def absent?
      options[:state].to_s == "absent"
    end

    def desired_groups
      options[:groups] || []
    end

    # The desired groups the user already belongs to, in desired order, so
    # the result equals desired_groups exactly when nothing is missing.
    def memberships(groups)
      desired_groups.select { |group| groups.include?(group) }
    end

    def current_groups
      result = shell.run("id -nG #{quote(name)}")
      result.success? ? result.stdout.strip.split(" ") : []
    end

    def useradd_command
      flags = []
      flags << (options[:system] ? "-r" : "-m")
      flags << "-u #{options[:uid]}" if options[:uid]
      flags << "-d #{quote(options[:home])}" if options[:home]
      flags << "-s #{quote(options[:shell])}" if options[:shell]
      flags << "-G #{quote(desired_groups.join(","))}" unless desired_groups.empty?
      "useradd #{flags.join(" ")} #{quote(name)}"
    end

    def usermod_command(changes)
      flags = []
      flags << "-u #{options[:uid]}" if changed?(changes, :uid)
      flags << "-d #{quote(options[:home])}" if changed?(changes, :home)
      flags << "-s #{quote(options[:shell])}" if changed?(changes, :shell)
      flags << "-a -G #{quote(desired_groups.join(","))}" if changed?(changes, :groups)
      "usermod #{flags.join(" ")} #{quote(name)}"
    end

    def require_linux
      return if host.platform.linux?

      raise ResourceError, "#{id}: the user resource only supports Linux"
    end

    def require_shadow_tools
      return if shell.run("command -v useradd").success?

      raise ResourceError, "#{id}: useradd is not installed " \
                           "(on Alpine, declare package \"shadow\" before user resources)"
    end
  end
end
