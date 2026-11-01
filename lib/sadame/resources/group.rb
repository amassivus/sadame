# frozen_string_literal: true

module Sadame
  # Manages a local group on Linux.
  #
  #   group "deploy"
  #   group "app", gid: 1500
  #   group "backup", system: true
  #   group "oldteam", state: :absent
  #
  # Members are managed on the user side, with the user resource's groups:.
  # Uses groupadd, groupmod and groupdel; where those are missing, as on a
  # fresh Alpine, BusyBox's addgroup and delgroup, which cannot change a
  # gid.
  class GroupResource < Resource
    STATES = %w[present absent].freeze

    def self.type_name
      "group"
    end

    def self.allowed_options
      [:gid, :system, :state]
    end

    def desired
      return { state: "absent" } if absent?

      attributes = { state: "present" }
      attributes[:gid] = options[:gid] if options[:gid]
      attributes
    end

    def current
      require_linux
      result = shell.run("getent group #{quote(name)}")
      return { state: "absent" } unless result.success?

      { state: "present", gid: result.stdout.strip.split(":", -1)[2].to_i }
    end

    def apply(changes)
      shadow = shadow_tools?
      if absent?
        shell.run!("#{shadow ? "groupdel" : "delgroup"} #{quote(name)}")
      elsif changed?(changes, :state)
        shell.run!(shadow ? groupadd_command : addgroup_command)
      else
        unless shadow
          raise ResourceError, "#{id}: changing a gid needs groupmod (on Alpine, declare package \"shadow\" first)"
        end

        shell.run!("groupmod -g #{options[:gid]} #{quote(name)}")
      end
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:system)
      gid = options[:gid]
      return if gid.nil? || (gid.is_a?(Integer) && gid >= 0)

      raise ResourceError, "#{id}: gid must be a non-negative Integer"
    end

    def absent?
      options[:state].to_s == "absent"
    end

    def groupadd_command
      flags = []
      flags << "-r" if options[:system]
      flags << "-g #{options[:gid]}" if options[:gid]
      (["groupadd"] + flags + [quote(name)]).join(" ")
    end

    # BusyBox: addgroup [-g GID] [-S] GROUP
    def addgroup_command
      flags = []
      flags << "-g #{options[:gid]}" if options[:gid]
      flags << "-S" if options[:system]
      (["addgroup"] + flags + [quote(name)]).join(" ")
    end

    def shadow_tools?
      shell.run("command -v groupadd").success?
    end

    def require_linux
      return if host.platform.linux?

      raise ResourceError, "#{id}: the group resource only supports Linux"
    end
  end
end
