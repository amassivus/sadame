# frozen_string_literal: true

module Sadame
  # The machines a recipe can run on, read from hosts.rb:
  #
  #   group :web do
  #     host "web1.example.com"
  #     host "web2.example.com", vars: { workers: 8 }
  #     vars workers: 4, tls: true
  #   end
  #
  #   group :db do
  #     host "db1.example.com", user: "admin", port: 2222, sudo: true
  #   end
  #
  #   group :all, include: [:web, :db] do
  #     vars env: "production"
  #   end
  #
  # Vars precedence, highest first: --var, host vars, group vars (a group
  # overrides the groups it includes), vars.rb.
  class Inventory
    HOST_OPTIONS = [:address, :user, :port, :sudo, :ssh_opts, :vars].freeze
    CONNECTION_OPTIONS = [:address, :user, :port, :sudo, :ssh_opts].freeze
    GROUP_OPTIONS = [:include].freeze

    # A named set of hosts, with vars and other groups it includes.
    class Group
      attr_reader :name, :includes, :vars, :host_names

      def initialize(name)
        @name = name
        @includes = []
        @vars = {}
        @host_names = []
      end
    end

    # A host as declared in hosts.rb, possibly in several groups.
    class HostEntry
      attr_reader :name, :connection, :vars

      def initialize(name)
        @name = name
        @connection = {}
        @vars = {}
      end
    end

    attr_reader :path

    def self.load(path, shell:)
      inventory = new(path)
      Builder.new(inventory, shell).evaluate(File.read(path), path)
      inventory.check_includes
      inventory
    rescue RecipeError, UsageError => e
      raise e
    rescue ScriptError, StandardError => e
      raise RecipeError, Sadame.located_message(e, path)
    end

    def self.empty
      new(nil)
    end

    def initialize(path)
      @path = path
      @groups = {}
      @hosts = {}
    end

    def empty?
      @hosts.empty?
    end

    def host_names
      @hosts.keys
    end

    def group_names
      @groups.keys
    end

    def host?(name)
      @hosts.key?(name)
    end

    def group?(name)
      @groups.key?(name.to_sym)
    end

    # Used by the hosts.rb DSL.
    def define_group(name)
      @groups[name] ||= Group.new(name)
    end

    def define_host(name, options, group_name)
      entry = (@hosts[name] ||= HostEntry.new(name))
      CONNECTION_OPTIONS.each do |key|
        next unless options.key?(key)

        merge_connection(entry, key, options[key])
      end
      entry.vars.merge!(Vars.symbolize_keys(options[:vars] || {}))
      return if group_name.nil?

      group = @groups.fetch(group_name)
      group.host_names << name unless group.host_names.include?(name)
    end

    def check_includes
      @groups.each_value do |group|
        group.includes.each do |included|
          next if @groups.key?(included)

          raise RecipeError, "#{path}: group #{group.name} includes #{included}, which is not defined"
        end
      end
      @groups.each_key { |name| check_cycle(name, []) }
    end

    # Hosts of a group and of the groups it includes, in the order they were
    # declared.
    def hosts_in_group(name)
      names = included_closure(name.to_sym) + [name.to_sym]
      host_names.select do |host|
        names.any? { |group| @groups[group].host_names.include?(host) }
      end
    end

    # Groups a host belongs to, directly or through include:, ordered so
    # that a group comes after every group it includes. Unrelated groups
    # keep the order they were declared in.
    def groups_of(host_name)
      direct = @groups.keys.select { |name| @groups[name].host_names.include?(host_name) }
      member = @groups.keys.select do |name|
        direct.include?(name) || included_closure(name).any? { |included| direct.include?(included) }
      end
      order_by_includes(member)
    end

    # Resolves -h, -g and --limit to targets with their final vars.
    #
    #   host_specs  "[user@]host[:port]" strings from -h
    #   group_names names from -g
    #   limit       a glob matched against host names
    #   base_vars   vars from vars.rb (lowest precedence)
    #   cli_vars    vars from --var (highest precedence)
    #   sudo        true for --sudo, which applies to every target
    def select(host_specs: [], group_names: [], limit: nil, base_vars: {}, cli_vars: {}, sudo: false)
      names = []
      group_names.each do |group|
        raise UsageError, "unknown group #{group}#{known_groups_hint}" unless group?(group)

        hosts_in_group(group).each { |host| names << host unless names.include?(host) }
      end

      overrides = {}
      host_specs.each do |spec|
        user, host, port = Target.parse(spec)
        overrides[host] = { user: user, port: port }
        names << host unless names.include?(host)
      end

      names = host_names if group_names.empty? && host_specs.empty?
      names = names.select { |name| Glob.match?(limit, name) } if limit
      raise UsageError, "no hosts match#{selection_description(host_specs, group_names, limit)}" if names.empty?

      names.map { |name| build_target(name, overrides[name] || {}, base_vars, cli_vars, sudo) }
    end

    private

    def merge_connection(entry, key, value)
      if entry.connection.key?(key) && entry.connection[key] != value
        raise RecipeError, "#{path}: host #{entry.name} is declared with #{key} " \
                           "#{entry.connection[key].inspect} and #{value.inspect}"
      end
      entry.connection[key] = value
    end

    def check_cycle(name, chain)
      if chain.include?(name)
        raise RecipeError, "#{path}: groups include each other: #{(chain + [name]).join(" -> ")}"
      end

      @groups[name].includes.each { |included| check_cycle(included, chain + [name]) }
    end

    # Every group reachable through include:, without the group itself.
    def included_closure(name)
      result = []
      pending = @groups[name].includes.dup
      until pending.empty?
        group = pending.shift
        next if result.include?(group)

        result << group
        pending.concat(@groups[group].includes)
      end
      result
    end

    def order_by_includes(names)
      ordered = []
      remaining = names.dup
      until remaining.empty?
        ready = remaining.find do |name|
          (included_closure(name) & names).all? { |included| ordered.include?(included) }
        end
        ordered << ready
        remaining.delete(ready)
      end
      ordered
    end

    def build_target(name, override, base_vars, cli_vars, sudo)
      entry = @hosts[name]
      connection = entry ? entry.connection : {}
      groups = entry ? groups_of(name) : []

      layers = [["vars.rb", base_vars]]
      groups.each { |group| layers << ["group #{group}", @groups[group].vars] }
      layers << ["host", entry.vars] if entry
      layers << ["--var", cli_vars]
      vars, sources = Vars.layered(layers)

      Target.new(
        name,
        address: connection[:address],
        user: override[:user] || connection[:user],
        port: override[:port] || connection[:port],
        sudo: sudo || connection[:sudo] == true,
        ssh_opts: connection[:ssh_opts] || [],
        groups: groups,
        vars: vars,
        var_sources: sources
      )
    end

    def known_groups_hint
      return " (no groups are defined)" if @groups.empty?

      " (defined: #{@groups.keys.join(", ")})"
    end

    def selection_description(host_specs, group_names, limit)
      parts = []
      parts << " -h #{host_specs.join(",")}" unless host_specs.empty?
      parts << " -g #{group_names.join(",")}" unless group_names.empty?
      parts << " --limit #{limit}" if limit
      parts << " (the inventory is empty)" if parts.empty?
      parts.join
    end

    # The hosts.rb language. Its public methods are what hosts.rb can call.
    class Builder
      def initialize(inventory, shell)
        @inventory = inventory
        @shell = shell
        @group = nil
      end

      def evaluate(code, path)
        instance_eval(code, path, 1)
      end

      # Declares a group, or adds to one declared earlier.
      #
      #   group :web do ... end
      #   group :all, include: [:web, :db]
      def group(name, options = {}, &block)
        raise Error, "groups cannot be nested; use include: to combine groups" if @group
        unless options.is_a?(Hash) && options.keys.all? { |key| GROUP_OPTIONS.include?(key) }
          raise Error, "group #{name}: the only option is include: [:group, ...]"
        end

        group = @inventory.define_group(name.to_sym)
        includes = options[:include] || []
        includes = [includes] unless includes.is_a?(Array)
        includes.each do |included|
          group.includes << included.to_sym unless group.includes.include?(included.to_sym)
        end
        return group.name if block.nil?

        @group = group.name
        begin
          instance_eval(&block)
        ensure
          @group = nil
        end
        group.name
      end

      # Declares a host, in the current group if inside one.
      #
      #   host "db1.example.com", user: "admin", port: 2222, sudo: true,
      #        ssh_opts: ["-i", "~/.ssh/db"], vars: { role: "primary" }
      def host(name, options = {})
        name = name.to_s
        raise Error, "host name must not be empty" if name.empty?

        validate_host_options(name, options)
        @inventory.define_host(name, options, @group)
        name
      end

      # Sets vars for the current group.
      def vars(values)
        raise Error, "vars must be inside a group; use host ..., vars: { ... } for one host" if @group.nil?
        raise Error, "vars expects a Hash, such as vars workers: 4" unless values.is_a?(Hash)

        @inventory.define_group(@group).vars.merge!(Vars.symbolize_keys(values))
      end

      # Runs a command on the machine running sadame and returns what it
      # printed; fails when the command does. For dynamic inventories:
      #
      #   servers = JSON.parse(command_output("hcloud server list -o json"))
      def command_output(command)
        @shell.run!(command).stdout
      end

      private

      def validate_host_options(name, options)
        raise Error, "host #{name}: options must be a Hash" unless options.is_a?(Hash)

        options.each do |key, value|
          unless HOST_OPTIONS.include?(key)
            raise Error, "host #{name}: unknown option #{key.inspect} " \
                         "(valid options: #{HOST_OPTIONS.map { |option| option.to_s }.sort.join(", ")})"
          end
          validate_host_option(name, key, value)
        end
      end

      def validate_host_option(name, key, value)
        valid = case key
                when :address, :user then value.is_a?(String) && !value.empty?
                when :port then value.is_a?(Integer) && value.between?(1, 65_535)
                when :sudo then value == true || value == false
                when :ssh_opts then value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
                else value.is_a?(Hash)
                end
        return if valid

        expected = { address: "a String", user: "a String", port: "an Integer from 1 to 65535",
                     sudo: "true or false", ssh_opts: "an Array of Strings", vars: "a Hash" }
        raise Error, "host #{name}: #{key} must be #{expected[key]}, got #{value.inspect}"
      end
    end
  end
end
