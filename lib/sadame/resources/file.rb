# frozen_string_literal: true

module Sadame
  # Manages a regular file: its content, permission bits and ownership.
  #
  #   file "/etc/motd", content: "Welcome\n"
  #   file "/etc/nginx/nginx.conf", template: "nginx.conf.erb", mode: "0644"
  #   file "/usr/local/bin/backup", source: "backup.sh", mode: "0755"
  #   file "/etc/old.conf", state: :absent
  #
  # New content is written to a temporary file next to the target, given
  # its final mode and owner, then renamed over the target, so readers never
  # see a half-written file. With verify:, a command checks the temporary
  # file first and a failure leaves the target untouched:
  #
  #   file "/etc/sudoers.d/deploy", content: "...", verify: "visudo -cf %{path}"
  class FileResource < Resource
    STATES = %w[present absent].freeze
    CONTENT_OPTIONS = [:content, :template, :source].freeze

    attr_reader :local_file

    def self.type_name
      "file"
    end

    def self.allowed_options
      [:content, :template, :source, :locals, :mode, :owner, :group, :state, :sensitive, :verify]
    end

    def path
      name
    end

    def desired
      return { state: "absent" } if absent?

      attributes = { state: "present" }
      attributes[:mode] = desired_mode if options[:mode]
      attributes[:owner] = options[:owner].to_s if options[:owner]
      attributes[:group] = options[:group].to_s if options[:group]
      attributes[:content] = desired_content if content_managed?
      attributes
    end

    def current
      stat = read_stat
      return { state: "absent" } if stat.nil?

      attributes = { state: "present", mode: stat.mode, owner: stat.owner, group: stat.group }
      attributes[:content] = shell.read_file(path) if content_managed?
      attributes
    end

    def apply(changes)
      if absent?
        shell.run!("rm -f #{quote(path)}")
      elsif changed?(changes, :state) || changed?(changes, :content)
        replace_content
      else
        shell.run!("chmod #{desired_mode} #{quote(path)}") if changed?(changes, :mode)
        if changed?(changes, :owner) || changed?(changes, :group)
          shell.run!("chown #{ownership(options[:owner], options[:group])} #{quote(path)}")
        end
      end
    end

    def sensitive?
      options[:sensitive] == true
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:sensitive)
      validate_mode
      validate_content_options
      validate_verify
      @local_file = resolve_local_file
    end

    def validate_content_options
      given = CONTENT_OPTIONS.select { |key| options.key?(key) }
      if given.size > 1
        raise ResourceError, "#{id}: use only one of content:, template: and source: (got #{given.join(", ")})"
      end
      if options.key?(:locals) && !options.key?(:template)
        raise ResourceError, "#{id}: locals: only applies to template:"
      end
      return unless absent? && !given.empty?

      raise ResourceError, "#{id}: #{given.first}: makes no sense with state: :absent"
    end

    # Finds template: or source: relative to the recipe's directory, then in
    # its templates/ or files/ subdirectory.
    def resolve_local_file
      if options[:template]
        find_local_file(options[:template].to_s, "templates")
      elsif options[:source]
        find_local_file(options[:source].to_s, "files")
      end
    end

    def find_local_file(relative, subdirectory)
      candidates = if relative.start_with?("/")
                     [relative]
                   else
                     [in_source_dir(relative), in_source_dir(File.join(subdirectory, relative))]
                   end
      found = candidates.find { |candidate| File.file?(candidate) }
      return found if found

      raise ResourceError, "#{id}: cannot find #{relative} (looked in #{candidates.join(", ")})"
    end

    def in_source_dir(relative)
      source_dir == "." ? relative : File.join(source_dir, relative)
    end

    def absent?
      options[:state].to_s == "absent"
    end

    def content_managed?
      CONTENT_OPTIONS.any? { |key| options.key?(key) }
    end

    def desired_mode
      PathStat.normalize_mode(options[:mode])
    end

    def desired_content
      @desired_content ||= render_content
    end

    def render_content
      if options.key?(:content)
        options[:content].to_s
      elsif options[:template]
        Template.new(File.read(local_file), local_file).render(vars: vars, locals: options[:locals] || {})
      else
        File.read(local_file)
      end
    end

    def read_stat
      stat = PathStat.read(shell, path, host.platform)
      return nil if stat.nil?
      return stat if stat.file?

      raise ResourceError, "#{id}: #{path} is a #{stat.type_label}, not a regular file"
    end

    def replace_content
      existing = read_stat
      replace_file(path, content_managed? ? desired_content : "",
                   mode: desired_mode || existing&.mode, owner: options[:owner] || existing&.owner,
                   group: options[:group] || existing&.group, verify: options[:verify])
    end
  end
end
