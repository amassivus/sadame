# frozen_string_literal: true

module Sadame
  # Manages a symbolic link.
  #
  #   link "/etc/nginx/sites-enabled/app", to: "/etc/nginx/sites-available/app"
  #   link "/srv/app/current", to: "releases/42"
  #   link "/etc/nginx/sites-enabled/default", state: :absent
  #
  # to: is stored in the link as given, so a relative target is relative to
  # the link's directory. A link pointing elsewhere is changed. A regular
  # file in the way is an error unless force: true, which replaces it; a
  # directory in the way is always an error.
  class LinkResource < Resource
    STATES = %w[present absent].freeze

    def self.type_name
      "link"
    end

    def self.allowed_options
      [:to, :state, :force]
    end

    def path
      name
    end

    def desired
      return { state: "absent" } if absent?

      { state: "present", to: options[:to] }
    end

    def current
      stat = PathStat.read(shell, path, host.platform)
      return { state: "absent" } if stat.nil?
      return { state: "present", to: shell.run!("readlink #{quote(path)}").stdout.chomp } if stat.type == :symlink
      return { state: "regular file" } if stat.file? && options[:force] && !absent?

      hint = stat.file? && !absent? ? " (force: true replaces it)" : ""
      raise ResourceError, "#{id}: #{path} is a #{stat.type_label}, not a symbolic link#{hint}"
    end

    def apply(_changes)
      if absent?
        shell.run!("rm -f #{quote(path)}")
      else
        # -n replaces a link to a directory instead of creating a link inside it.
        shell.run!("ln -sfn #{quote(options[:to])} #{quote(path)}")
      end
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:force)
      target = options[:to]
      if absent?
        raise ResourceError, "#{id}: to: makes no sense with state: :absent" unless target.nil?
      elsif !(target.is_a?(String) && !target.empty?)
        raise ResourceError, "#{id}: to: must name the target of the link, such as to: \"/etc/nginx/sites-available/app\""
      end
    end

    def absent?
      options[:state].to_s == "absent"
    end
  end
end
