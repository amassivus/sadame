# frozen_string_literal: true

module Sadame
  # Type, permission bits and ownership of a path, read with stat(1).
  class PathStat
    attr_reader :type, :mode, :owner, :group

    # Returns nil when the path does not exist.
    def self.read(shell, path, platform)
      result = shell.run(command_for(path, platform))
      return parse(result.stdout) if result.success?
      return nil if result.stderr.include?("No such file")

      raise CommandFailed.new(result)
    end

    def self.command_for(path, platform)
      if platform.darwin?
        "stat -f '%Lp %Su %Sg %HT' #{Shell.escape(path)}"
      else
        "stat -c '%a %U %G %F' #{Shell.escape(path)}"
      end
    end

    # Parses "644 root root regular file" (GNU and BusyBox) or
    # "644 root wheel Regular File" (BSD).
    def self.parse(line)
      mode, owner, group, type = line.strip.split(" ", 4)
      new(type: type_from(type.to_s.downcase), mode: normalize_mode(mode), owner: owner, group: group)
    end

    def self.type_from(description)
      return :file if description.start_with?("regular")
      return :directory if description == "directory"
      return :symlink if description == "symbolic link"

      :other
    end

    # Accepts "644" or "0644" and returns four octal digits, or nil when the
    # value is not a valid mode string.
    def self.normalize_mode(value)
      return nil unless value.is_a?(String)
      return nil unless value.size.between?(3, 4) && value.chars.all? { |char| "01234567".include?(char) }

      value.rjust(4, "0")
    end

    def initialize(type:, mode:, owner:, group:)
      @type = type
      @mode = mode
      @owner = owner
      @group = group
    end

    def file?
      type == :file
    end

    def directory?
      type == :directory
    end

    def type_label
      case type
      when :file then "regular file"
      when :directory then "directory"
      when :symlink then "symbolic link"
      else "special file"
      end
    end
  end
end
