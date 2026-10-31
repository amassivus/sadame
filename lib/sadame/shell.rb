# frozen_string_literal: true

module Sadame
  # Outcome of one shell command.
  class CommandResult
    attr_reader :command, :stdout, :stderr, :exit_status

    def initialize(command, stdout:, stderr:, exit_status:)
      @command = command
      @stdout = stdout
      @stderr = stderr
      @exit_status = exit_status
    end

    def success?
      exit_status == 0
    end
  end

  # The single gateway between sadame and the system it manages. Resources
  # read state and make changes only through this class, which lets tests
  # swap in a fake shell and lets us log every command in one place.
  class Shell
    SAFE_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_./:=@%+,"

    # Quotes a value for /bin/sh. Plain words are left as they are so that
    # command lines stay readable in output and tests.
    def self.escape(value)
      text = value.to_s
      return "''" if text.empty?
      return text if text.chars.all? { |char| SAFE_CHARACTERS.include?(char) }

      "'#{text.split("'", -1).join("'\\''")}'"
    end

    def initialize
      @counter = 0
    end

    # Runs a command with /bin/sh, stdin closed, and captures its output.
    def run(command)
      stderr_path = next_stderr_path
      wrapped = "(\n#{command}\n) </dev/null 2>#{Shell.escape(stderr_path)}"
      stdout = IO.popen(wrapped, "r") { |io| io.read }
      exit_status = exit_status_from($?)
      CommandResult.new(command, stdout: stdout, stderr: take_file(stderr_path), exit_status: exit_status)
    end

    # Like run, but raises CommandFailed when the command exits non-zero.
    def run!(command)
      result = run(command)
      raise CommandFailed.new(result) unless result.success?

      result
    end

    # Returns the file content, or nil when the file does not exist.
    def read_file(path)
      return nil unless File.exist?(path)

      File.read(path)
    end

    def write_file(path, content)
      File.open(path, "w") { |file| file.write(content) }
    end

    private

    def next_stderr_path
      @counter += 1
      directory = ENV["TMPDIR"] || "/tmp"
      File.join(directory, "sadame-#{Process.pid}-#{@counter}.stderr")
    end

    def take_file(path)
      return "" unless File.exist?(path)

      content = File.read(path)
      File.delete(path)
      content
    end

    # mruby-io sets $? to a Process::Status when mruby-process is present
    # and to a plain exit code otherwise; CRuby always uses Process::Status.
    def exit_status_from(status)
      return status if status.is_a?(Integer)
      return status.exitstatus if status.exitstatus

      128 + status.termsig.to_i
    end
  end
end
