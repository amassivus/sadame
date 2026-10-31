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

  # Finds "path:line" for an error raised while evaluating the file at path,
  # so recipe errors point at the line the user wrote.
  def self.error_location(error, path)
    prefix = "#{path}:"
    entry = (error.backtrace || []).find { |line| line.start_with?(prefix) }
    return path if entry.nil?

    line_number = entry[prefix.size..].split(":").first
    "#{path}:#{line_number}"
  end
end
