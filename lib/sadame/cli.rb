# frozen_string_literal: true

module Sadame
  # Command-line interface: parses arguments, loads the recipe and vars,
  # runs the command and returns the process exit status.
  #
  # Exit status: 0 success, 1 a resource or notification failed,
  # 2 usage, recipe or configuration error.
  class CLI
    COMMANDS = %w[plan apply].freeze
    DEFAULT_RECIPE = "recipe.rb"

    USAGE = <<~TEXT
      Usage: sadame COMMAND [RECIPE] [options]

      Commands:
        plan     Show what apply would change, as a diff. Changes nothing.
        apply    Make the host match the recipe.

      RECIPE is a recipe file or a directory containing recipe.rb
      (default: ./recipe.rb). vars.rb next to the recipe is loaded if present.

      Options:
        --var KEY=VALUE   Set vars[:KEY]; repeatable, overrides vars.rb
        --json            Print a JSON report instead of text
        --no-color        Disable colors (also: NO_COLOR environment variable)
        --version         Print the version
        --help            Print this help
    TEXT

    def initialize(argv, stdout: $stdout, stderr: $stderr, shell: nil, environment: ENV)
      @argv = argv
      @stdout = stdout
      @stderr = stderr
      @shell = shell
      @environment = environment
    end

    def run
      options = parse(@argv)
      return print_text(USAGE) if options[:help]
      return print_text("sadame #{VERSION}\n") if options[:version]

      execute(options)
    rescue UsageError => e
      @stderr.write("sadame: #{e.message}\nRun 'sadame --help' for usage.\n")
      2
    rescue Error => e
      @stderr.write("sadame: #{e.message}\n")
      2
    end

    private

    def execute(options)
      recipe_path = resolve_recipe(options[:recipe])
      vars = Vars.merge(Vars.load_file(File.join(File.dirname(recipe_path), "vars.rb")), options[:vars])
      host = Host.new(@shell || Shell.new)
      resources = Recipe.load(recipe_path, host: host, vars: vars)
      runner = Runner.new(host: host, output: build_output(options))
      report = options[:command] == "plan" ? runner.plan(resources) : runner.apply(resources)
      report.failed? ? 1 : 0
    end

    def parse(argv)
      options = { vars: {}, json: false, color: true, help: false, version: false }
      positional = []
      arguments = argv.dup

      until arguments.empty?
        argument = arguments.shift
        case argument
        when "--help" then options[:help] = true
        when "--version" then options[:version] = true
        when "--json" then options[:json] = true
        when "--no-color" then options[:color] = false
        when "--var" then add_var(options, arguments.shift)
        else
          if argument.start_with?("--var=")
            add_var(options, argument["--var=".size..])
          elsif argument.start_with?("-")
            raise UsageError, "unknown option #{argument}"
          else
            positional << argument
          end
        end
      end
      return options if options[:help] || options[:version]

      assign_positional(options, positional)
    end

    def assign_positional(options, positional)
      command = positional.shift
      raise UsageError, "missing command" if command.nil?
      raise UsageError, "unknown command #{command}" unless COMMANDS.include?(command)
      raise UsageError, "too many arguments: #{positional.join(" ")}" if positional.size > 1

      options[:command] = command
      options[:recipe] = positional.first
      options
    end

    def add_var(options, assignment)
      raise UsageError, "--var expects key=value" if assignment.nil?

      key, value = Vars.parse_assignment(assignment)
      options[:vars][key] = value
    end

    def resolve_recipe(argument)
      path = argument || DEFAULT_RECIPE
      path = File.join(path, DEFAULT_RECIPE) if File.directory?(path)
      raise UsageError, "recipe not found: #{path}" unless File.file?(path)

      path
    end

    def build_output(options)
      return Output::Json.new(@stdout) if options[:json]

      Output::Human.new(@stdout, color: color?(options))
    end

    def color?(options)
      return false unless options[:color]
      return false if @environment["NO_COLOR"] && !@environment["NO_COLOR"].empty?

      @stdout.respond_to?(:tty?) && @stdout.tty?
    end

    def print_text(text)
      @stdout.write(text)
      0
    end
  end

  def self.main(argv)
    CLI.new(argv).run
  end
end
