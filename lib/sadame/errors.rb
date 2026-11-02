# frozen_string_literal: true

module Sadame
  # Base class for errors that sadame reports to the user as a plain message.
  class Error < StandardError; end

  # The command line could not be understood.
  class UsageError < Error; end

  # A recipe, vars.rb or template could not be loaded or evaluated.
  class RecipeError < Error; end

  # A resource was declared with invalid options or cannot work on this host.
  class ResourceError < Error; end

  # A shell command exited with a non-zero status.
  class CommandFailed < Error
    attr_reader :result

    def initialize(result)
      @result = result
      super(CommandFailed.describe(result))
    end

    def self.describe(result)
      message = "command failed (exit #{result.exit_status}): #{result.command}"
      details = result.stderr.strip
      details = result.stdout.strip if details.empty?
      details.empty? ? message : "#{message}\n#{details}"
    end
  end

  UNKNOWN_OPTION = /unknown option :(\w+)/
  # How far from the reported line the misspelled option of the same call
  # can be.
  CALL_LINES = 20

  # The message for an error raised while evaluating the file at path,
  # starting with "path:line" so it points at the line the user wrote.
  # Syntax errors already name the file and line in both runtimes. source
  # is the file's text, when the caller has it (it may not be saved yet).
  def self.located_message(error, path, source = nil)
    return error.message if error.is_a?(SyntaxError)

    "#{error_location(error, path, source)}: #{error.message}"
  end

  # Finds "path:line" for an error raised while evaluating the file at path.
  def self.error_location(error, path, source = nil)
    prefix = "#{path}:"
    entry = (error.backtrace || []).find { |line| line.start_with?(prefix) }
    return path if entry.nil?

    line_number = entry[prefix.size..].split(":").first.to_i
    "#{path}:#{option_line(error.message, source, line_number)}"
  end

  # A misspelled option is reported on the line that names it. Runtimes
  # report a call that spans lines on its first line (CRuby) or its last
  # (mruby), so the reported line is only where to start looking: the
  # nearest line that names the option wins.
  def self.option_line(message, source, line_number)
    option = UNKNOWN_OPTION.match(message)
    return line_number if option.nil? || source.nil?

    lines = source.split("\n")
    reported = line_number - 1
    first = reported - CALL_LINES < 0 ? 0 : reported - CALL_LINES
    candidates = (first..(reported + CALL_LINES)).select { |index| lines[index].to_s.include?("#{option[1]}:") }
    best = candidates.min_by { |index| (index - reported).abs }
    best.nil? ? line_number : best + 1
  end
end
