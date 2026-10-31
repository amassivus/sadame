# frozen_string_literal: true

module Sadame
  # Manages a directory, its permission bits and ownership.
  #
  #   directory "/var/www/app", owner: "www-data", mode: "0755"
  #   directory "/opt/legacy", state: :absent, recursive: true
  #
  # Missing parent directories are created. Removing a non-empty directory
  # requires recursive: true.
  class DirectoryResource < Resource
    STATES = %w[present absent].freeze

    def self.type_name
      "directory"
    end

    def self.allowed_options
      [:mode, :owner, :group, :state, :recursive]
    end

    def path
      name
    end

    def desired
      return { state: "absent" } if absent?

      attributes = { state: "present" }
      attributes[:mode] = PathStat.normalize_mode(options[:mode]) if options[:mode]
      attributes[:owner] = options[:owner].to_s if options[:owner]
      attributes[:group] = options[:group].to_s if options[:group]
      attributes
    end

    def current
      stat = PathStat.read(shell, path, host.platform)
      return { state: "absent" } if stat.nil?
      unless stat.directory?
        raise ResourceError, "#{id}: #{path} is a #{stat.type_label}, not a directory"
      end

      { state: "present", mode: stat.mode, owner: stat.owner, group: stat.group }
    end

    def apply(changes)
      if absent?
        remove
        return
      end

      shell.run!("mkdir -p #{quote(path)}") if changed?(changes, :state)
      shell.run!("chmod #{desired[:mode]} #{quote(path)}") if changed?(changes, :mode)
      if changed?(changes, :owner) || changed?(changes, :group)
        shell.run!("chown #{ownership(options[:owner], options[:group])} #{quote(path)}")
      end
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:recursive)
      validate_mode
    end

    def absent?
      options[:state].to_s == "absent"
    end

    def remove
      if options[:recursive]
        shell.run!("rm -rf #{quote(path)}")
      else
        shell.run!("rmdir #{quote(path)}")
      end
    end
  end
end
