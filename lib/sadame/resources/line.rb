# frozen_string_literal: true

module Sadame
  # Manages one line in a file that something else owns, such as a setting
  # in a package's configuration file, and leaves the rest of the file
  # alone.
  #
  #   line "PermitRootLogin no", path: "/etc/ssh/sshd_config", match: /^#?\s*PermitRootLogin\s/
  #   line "vm.swappiness = 10", path: "/etc/sysctl.conf"
  #   line "old mirror", path: "/etc/hosts", line: "10.0.0.5 mirror.internal", state: :absent
  #
  # The name is the line, unless line: gives it. With match: (a regular
  # expression), every line that matches is replaced by the line; when none
  # matches and the line is not in the file, it is appended. With state:
  # :absent, the line and every line that matches match: are removed.
  #
  # The file must exist by the time the change is applied. It keeps its
  # mode and owner, and is replaced in one rename, as with the file
  # resource; verify: checks the new content first.
  class LineResource < Resource
    STATES = %w[present absent].freeze

    def self.type_name
      "line"
    end

    def self.allowed_options
      [:path, :line, :match, :state, :verify, :sensitive]
    end

    def text
      (options[:line] || name).to_s
    end

    def path
      options[:path].to_s
    end

    def desired
      { content: edit(read_content.to_s) }
    end

    def current
      { content: read_content }
    end

    # The whole file is compared, so plan shows the edit as a diff of the
    # file.
    def diff
      content = read_content
      if content.nil?
        return [] if absent?

        return [Diff::Change.new(:content, nil, edit(""), reason: "#{path} does not exist yet")]
      end
      edited = edit(content)
      edited == content ? [] : [Diff::Change.new(:content, content, edited)]
    end

    def apply(changes)
      stat = read_stat
      if stat.nil?
        raise ResourceError, "#{id}: #{path} does not exist; line only edits existing files " \
                             "(create it with a file resource, or install the package that ships it, first)"
      end

      replace_file(path, changes.first.to, mode: stat.mode, owner: stat.owner, group: stat.group,
                                           verify: options[:verify])
    end

    def sensitive?
      options[:sensitive] == true
    end

    private

    def validate
      validate_choice(:state, STATES)
      validate_boolean(:sensitive)
      validate_verify
      validate_path
      validate_text
      @pattern = build_pattern
    end

    def validate_path
      value = options[:path]
      return if value.is_a?(String) && value.start_with?("/")

      raise ResourceError, "#{id}: path must be the absolute path of the file to edit, " \
                           "such as path: \"/etc/ssh/sshd_config\""
    end

    def validate_text
      value = options.key?(:line) ? options[:line] : name
      unless value.is_a?(String) && !value.empty?
        raise ResourceError, "#{id}: line must be a non-empty String"
      end
      return unless value.include?("\n")

      raise ResourceError, "#{id}: line must be a single line, without \"\\n\""
    end

    def build_pattern
      value = options[:match]
      return nil if value.nil?
      return value if value.is_a?(Regexp)
      raise ResourceError, "#{id}: match must be a regular expression, such as /^#?Port /" unless value.is_a?(String)

      begin
        Regexp.new(value)
      rescue StandardError => e
        raise ResourceError, "#{id}: match is not a valid regular expression: #{e.message}"
      end
    end

    def absent?
      options[:state].to_s == "absent"
    end

    # The file's content, or nil when it does not exist.
    def read_content
      read_stat.nil? ? nil : shell.read_file(path)
    end

    def read_stat
      stat = PathStat.read(shell, path, host.platform)
      return nil if stat.nil?
      return stat if stat.file?

      raise ResourceError, "#{id}: #{path} is a #{stat.type_label}, not a regular file"
    end

    # The content with this resource's edit made.
    def edit(content)
      lines = Diff.split_lines(content)
      return lines.reject { |line| same?(line) || matches?(line) }.join if absent?

      replaced = false
      edited = lines.map do |line|
        next line unless matches?(line)

        replaced = true
        line.end_with?("\n") ? "#{text}\n" : text
      end
      return edited.join if replaced || lines.any? { |line| same?(line) }

      content.empty? || content.end_with?("\n") ? "#{content}#{text}\n" : "#{content}\n#{text}\n"
    end

    def same?(line)
      line.chomp == text
    end

    def matches?(line)
      !@pattern.nil? && !@pattern.match(line.chomp).nil?
    end
  end
end
