# frozen_string_literal: true

module Sadame
  # Command-line interface: parses arguments, loads the recipe, vars and
  # inventory, runs the command locally or on remote targets, and returns
  # the process exit status.
  #
  # Exit status (see Report#exit_status and Push::Run):
  #   0 success
  #   1 apply failed, or drift found differences
  #   2 usage or recipe error, a state that could not be read, or a target
  #     that could not be reached
  class CLI
    COMMANDS = %w[plan apply drift validate hosts facts].freeze
    DEFAULT_RECIPE = "recipe.rb"
    DEFAULT_INVENTORY = "hosts.rb"

    USAGE = <<~TEXT
      Usage: sadame COMMAND [RECIPE] [options]

      Commands:
        plan     Show what apply would change, as a diff. Changes nothing.
        apply    Make the hosts match the recipe.
        drift    Like plan, but exit 1 when a host differs from the recipe.
        validate Check the recipe for every selected host without connecting.
        hosts    Show the selected hosts with their connection options and vars.
        facts    Show the facts recipes see on each host: CPUs, memory, addresses.

      RECIPE is a recipe file or a directory containing recipe.rb
      (default: ./recipe.rb). vars.rb and hosts.rb next to it are loaded if
      present; hosts and facts only use those. Without -h, -g or --limit,
      sadame runs on this machine.

      Targets:
        -h, --host [USER@]HOST[:PORT],...   Run on these hosts over SSH
        -g, --group GROUP,...               Run on the hosts of these groups
        --limit GLOB                        Only hosts whose name matches, e.g. "web*"
        --inventory PATH                    Use this inventory instead of ./hosts.rb
        --sudo                              Run sadame with sudo on every target
        --forks N                           Work on at most N hosts at once (default: all)
        --serial N|N%                       Run in batches of N hosts (or N% of them), one
                                            batch after another; stop when a batch fails

      Options:
        --platform NAME     validate as on debian, ubuntu, rocky, alpine or arch
                            (default: debian)
        --tags T,...        Only resources with one of these tags (plan, apply, drift)
        --skip-tags T,...   Leave out resources with one of these tags
        --var KEY=VALUE     Set vars[:KEY]; repeatable, overrides everything else
        --vars-file PATH    Load more vars from a Ruby file (local runs)
        --json              Print a JSON report instead of text
        --color             Always use colors
        --no-color          Never use colors (also: NO_COLOR environment variable)
        --host-name NAME    host_name in recipes and reports for local runs (default: local)
        --host-groups G,... host_groups in recipes for local runs
        --version           Print the version
        --help              Print this help

      Exit status:
        0  success; for drift, every host matches the recipe
        1  apply failed, or drift found differences
        2  usage or recipe error, the state of a resource could not be read,
           or a host could not be reached
    TEXT

    def initialize(argv, stdout: $stdout, stderr: $stderr, shell: nil, environment: ENV, forking: true)
      @argv = argv
      @stdout = stdout
      @stderr = stderr
      @shell = shell || Shell.new
      @environment = environment
      @forking = forking
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

    RECIPE_COMMANDS = %w[plan apply drift].freeze

    def execute(options)
      unless RECIPE_COMMANDS.include?(options[:command])
        [["--tags", :tags], ["--skip-tags", :skip_tags]].each do |flag, key|
          raise UsageError, "#{flag} only applies to plan, apply and drift" unless options[key].empty?
        end
      end
      if options[:platform] && options[:command] != "validate"
        raise UsageError, "--platform only applies to validate"
      end
      return list_hosts(options) if options[:command] == "hosts"
      return show_facts(options) if options[:command] == "facts"
      return validate(options) if options[:command] == "validate"

      recipe_path = resolve_recipe(options[:recipe])
      base_dir = File.dirname(recipe_path)
      base_vars = Vars.load_file(File.join(base_dir, "vars.rb"))
      return run_remote(options, recipe_path, base_dir, base_vars) if remote?(options)

      run_local(options, recipe_path, base_vars)
    end

    def check_local_options(options)
      raise UsageError, "--sudo only applies to -h, -g and --limit; run `sudo sadame` here instead" if options[:sudo]
      [["--forks", :forks], ["--serial", :serial]].each do |flag, key|
        raise UsageError, "#{flag} only applies to -h, -g and --limit" if options[key]
      end
    end

    def local_host(options)
      Host.new(@shell, name: options[:host_name] || "local", groups: options[:host_groups].map { |group| group.to_sym })
    end

    def run_local(options, recipe_path, base_vars)
      check_local_options(options)
      file_vars = options[:vars_file] ? load_vars_file(options[:vars_file]) : {}
      vars = Vars.merge(base_vars, file_vars, options[:vars])
      host = local_host(options)
      resources = Recipe.load(recipe_path, host: host, vars: vars)
      runner = Runner.new(host: host, output: build_output(options), selection: selection(options))
      report = case options[:command]
               when "plan" then runner.plan(resources)
               when "drift" then runner.drift(resources)
               else runner.apply(resources)
               end
      report.exit_status
    end

    def check_remote_options(options)
      raise UsageError, "--vars-file is for local runs; put the vars in hosts.rb or vars.rb" if options[:vars_file]
      return unless options[:host_name] || !options[:host_groups].empty?

      raise UsageError, "--host-name and --host-groups are for local runs; targets get them from hosts.rb"
    end

    # The recipe for each selected host, or for this machine, against a
    # stand-in machine: nothing is connected to.
    def validate(options)
      recipe_path = resolve_recipe(options[:recipe])
      base_dir = File.dirname(recipe_path)
      base_vars = Vars.load_file(File.join(base_dir, "vars.rb"))
      platform = StandIn.platform(options[:platform] || "debian")
      checks = if remote?(options)
                 check_remote_options(options)
                 select_targets(load_inventory(options, base_dir), options, base_vars).map do |target|
                   [target.name, target.groups, target.vars]
                 end
               else
                 check_local_options(options)
                 file_vars = options[:vars_file] ? load_vars_file(options[:vars_file]) : {}
                 [[options[:host_name] || "local", options[:host_groups].map { |group| group.to_sym },
                   Vars.merge(base_vars, file_vars, options[:vars])]]
               end
      validation = Validation.new(recipe_path, platform: platform)
      results = checks.map { |name, groups, vars| validation.check(name: name, groups: groups, vars: vars) }
      listing = ValidationListing.new(@stdout, color: color?(options))
      options[:json] ? listing.render_json(recipe_path, platform, results) : listing.render(recipe_path, platform, results)
      Validation.exit_status(results)
    end

    # recipe_path is nil for facts, which runs no recipe.
    def run_remote(options, recipe_path, base_dir, base_vars)
      check_remote_options(options)

      inventory = load_inventory(options, base_dir)
      targets = select_targets(inventory, options, base_vars)
      color = color?(options)
      Push::Run.new(
        targets: targets, command: options[:command], recipe_path: recipe_path, shell: @shell, stdout: @stdout,
        binary_store: Push::BinaryStore.new(@shell, environment: @environment),
        parallel: Push::Parallel.new(@stdout, color: color, forking: @forking),
        json: options[:json], color: color, forks: options[:forks], serial: options[:serial],
        arguments: selection_arguments(options)
      ).call
    end

    def selection(options)
      Selection.new(tags: options[:tags], skip_tags: options[:skip_tags])
    end

    # --tags and --skip-tags for the sadame that runs on each target.
    def selection_arguments(options)
      arguments = []
      arguments += ["--tags", options[:tags].join(",")] unless options[:tags].empty?
      arguments += ["--skip-tags", options[:skip_tags].join(",")] unless options[:skip_tags].empty?
      arguments
    end

    # Facts of this machine, or of the selected hosts, where sadame runs
    # `sadame facts` over SSH as for plan.
    def show_facts(options)
      base_dir = recipe_directory(options[:recipe])
      if remote?(options)
        return run_remote(options, nil, base_dir, Vars.load_file(in_directory(base_dir, "vars.rb")))
      end

      check_local_options(options)
      listing = FactsListing.new(@stdout, color: color?(options))
      options[:json] ? listing.render_json(local_host(options)) : listing.render(local_host(options))
      0
    end

    def list_hosts(options)
      base_dir = recipe_directory(options[:recipe])
      base_vars = Vars.load_file(in_directory(base_dir, "vars.rb"))
      inventory = load_inventory(options, base_dir)
      if inventory.empty? && options[:hosts].empty?
        raise UsageError, "no hosts: #{in_directory(base_dir, DEFAULT_INVENTORY)} not found; use --inventory or -h"
      end

      targets = select_targets(inventory, options, base_vars)
      listing = HostsListing.new(@stdout, color: color?(options))
      options[:json] ? listing.render_json(targets) : listing.render(targets, inventory.path)
      0
    end

    def select_targets(inventory, options, base_vars)
      inventory.select(host_specs: options[:hosts], group_names: options[:groups], limit: options[:limit],
                       base_vars: base_vars, cli_vars: options[:vars], sudo: options[:sudo])
    end

    def remote?(options)
      !options[:hosts].empty? || !options[:groups].empty? || !options[:limit].nil?
    end

    def load_inventory(options, base_dir)
      path = options[:inventory] || in_directory(base_dir, DEFAULT_INVENTORY)
      return Inventory.load(path, shell: @shell) if File.file?(path)
      raise UsageError, "inventory not found: #{path}" if options[:inventory]

      Inventory.empty
    end

    def load_vars_file(path)
      raise UsageError, "vars file not found: #{path}" unless File.file?(path)

      Vars.load_file(path)
    end

    def parse(argv)
      options = { vars: {}, hosts: [], groups: [], limit: nil, inventory: nil, sudo: false, json: false,
                  color: nil, vars_file: nil, host_name: nil, host_groups: [], forks: nil, serial: nil,
                  tags: [], skip_tags: [], platform: nil,
                  help: false, version: false }
      positional = []
      arguments = argv.dup

      until arguments.empty?
        argument = arguments.shift
        name, inline_value = split_option(argument)
        case name
        when "--help" then options[:help] = true
        when "--version" then options[:version] = true
        when "--json" then options[:json] = true
        when "--sudo" then options[:sudo] = true
        when "--color" then options[:color] = true
        when "--no-color" then options[:color] = false
        when "--var" then add_var(options, inline_value || arguments.shift)
        when "-h", "--host" then options[:hosts].concat(list_value(name, inline_value || arguments.shift))
        when "-g", "--group" then options[:groups].concat(list_value(name, inline_value || arguments.shift))
        when "--limit" then options[:limit] = value(name, inline_value || arguments.shift)
        when "--inventory" then options[:inventory] = value(name, inline_value || arguments.shift)
        when "--platform" then options[:platform] = value(name, inline_value || arguments.shift)
        when "--tags" then options[:tags].concat(list_value(name, inline_value || arguments.shift))
        when "--skip-tags" then options[:skip_tags].concat(list_value(name, inline_value || arguments.shift))
        when "--forks" then options[:forks] = positive_integer(name, inline_value || arguments.shift)
        when "--serial" then options[:serial] = batch_size(name, inline_value || arguments.shift)
        when "--vars-file" then options[:vars_file] = value(name, inline_value || arguments.shift)
        when "--host-name" then options[:host_name] = value(name, inline_value || arguments.shift)
        when "--host-groups" then options[:host_groups].concat(list_value(name, inline_value || arguments.shift))
        else
          raise UsageError, "unknown option #{argument}" if argument.start_with?("-")

          positional << argument
        end
      end
      return options if options[:help] || options[:version]

      assign_positional(options, positional)
    end

    # "--limit=web*" is the same as "--limit web*".
    def split_option(argument)
      return [argument, nil] unless argument.start_with?("--") && argument.include?("=")

      argument.split("=", 2)
    end

    def value(name, text)
      raise UsageError, "#{name} needs a value" if text.nil? || text.empty?

      text
    end

    def positive_integer(name, text)
      text = value(name, text)
      return text.to_i if digits?(text) && text.to_i > 0

      raise UsageError, "#{name} needs a whole number of hosts, at least 1 (got #{text})"
    end

    # A number of hosts, or a percentage of them: "2" or "25%".
    def batch_size(name, text)
      text = value(name, text)
      return positive_integer(name, text) unless text.end_with?("%")

      percent = text.chomp("%")
      return text if digits?(percent) && percent.to_i.between?(1, 100)

      raise UsageError, "#{name} needs a number of hosts or a percentage from 1% to 100% (got #{text})"
    end

    def digits?(text)
      !text.empty? && text.chars.all? { |char| "0123456789".include?(char) }
    end

    def list_value(name, text)
      value(name, text).split(",").map { |item| item.strip }.reject { |item| item.empty? }
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

    def in_directory(directory, name)
      directory == "." ? name : File.join(directory, name)
    end

    # For `hosts`, RECIPE only says where hosts.rb and vars.rb are.
    def recipe_directory(argument)
      return "." if argument.nil?
      return argument if File.directory?(argument)

      File.dirname(argument)
    end

    def build_output(options)
      return Output::Json.new(@stdout) if options[:json]

      Output::Human.new(@stdout, color: color?(options))
    end

    def color?(options)
      return options[:color] unless options[:color].nil?
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
