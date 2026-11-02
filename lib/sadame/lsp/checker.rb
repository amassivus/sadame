# frozen_string_literal: true

module Sadame
  module Lsp
    # Finds what is wrong in a file while it is edited, as `sadame validate`
    # does: a recipe is evaluated for every host of the nearest hosts.rb,
    # with the nearest vars.rb, against a stand-in machine; vars.rb and
    # hosts.rb files are loaded. Problems come back by file, because a
    # recipe's error can be in a template or a recipe it includes.
    #
    # A file that a recipe of the project includes, such as roles/web.rb,
    # is checked through that recipe, for the hosts it is included on: a
    # role guarded by `if host_groups.include?(:web)` is not checked with a
    # database server's vars. The project's recipes are the .rb files next
    # to its vars.rb or hosts.rb. A file no recipe includes is evaluated as
    # a recipe of its own. Ruby files outside a sadame project (no
    # recipe.rb, site.rb, vars.rb or hosts.rb in their directory or above)
    # are left alone.
    class Checker
      MARKERS = ["recipe.rb", "site.rb", "vars.rb", "hosts.rb"].freeze
      LOCATED = /\A(.+?):(\d+):(?:\d+:)? ?(.*)\z/m
      RESOURCE_ID = /([a-z_]+)\[([^\]]+)\]/

      # root is the editor's workspace: the search for vars.rb and hosts.rb
      # stops there.
      def initialize(shell, root:, platform:)
        @shell = shell
        @root = root && File.expand_path(root)
        @platform = platform
        @inventories = {}
      end

      # hosts.rb and vars.rb changed: read them again next time.
      def forget
        @inventories = {}
      end

      # { path => [[line, message], ...] }, for the files with problems.
      def check(path, text)
        name = File.basename(path)
        return check_load(path) { Vars.load_file(path) } if name == "vars.rb"
        return check_load(path) { Inventory.load(path, shell: @shell) } if name.start_with?("hosts") && name.end_with?(".rb")
        return {} unless name.end_with?(".rb") && project?(path)

        check_recipe(path, text)
      end

      private

      def check_load(path)
        yield
        {}
      rescue Error => e
        problems_from([[e.message, nil]], path, File.read(path))
      end

      def check_recipe(path, text)
        expanded = File.expand_path(path)
        vars_path = nearest(path, "vars.rb")
        base_vars = vars_path ? Vars.load_file(vars_path) : {}
        hosts = targets(nearest(path, "hosts.rb"), base_vars)
        hosts = [["local", [], base_vars]] if hosts.empty?
        sources = { expanded => text }
        entries = entry_recipes(path) - [expanded]
        failures, including = through_entries(entries, hosts, expanded, sources)
        if including == 0
          failures = hosts.map { |host| [evaluate(expanded, host, sources).error, host[0]] }
          including = hosts.size
        end
        problems_from(group_by_message(failures.select { |error, _name| error }, including), path, text)
      rescue Error => e
        problems_from([[e.message, nil]], path, text)
      end

      # Evaluates the project's recipes for every host and keeps the
      # results of those that include path. Returns the failures and how
      # many hosts include it.
      def through_entries(entries, hosts, path, sources)
        failures = []
        including = 0
        hosts.each do |host|
          results = entries.map { |entry| evaluate(entry, host, sources) }.select { |result| result.files.include?(path) }
          next if results.empty?

          including += 1
          results.each { |result| failures << [result.error, host[0]] if result.error }
        end
        [failures.uniq, including]
      end

      def evaluate(recipe, host, sources)
        name, groups, vars = host
        Validation.new(recipe, platform: @platform).check(name: name, groups: groups, vars: vars, sources: sources)
      end

      # The .rb files next to the project's vars.rb or hosts.rb, which are
      # where recipes start.
      def entry_recipes(path)
        marker = nearest(path, "vars.rb") || nearest(path, "hosts.rb")
        return [] if marker.nil?

        directory = File.dirname(marker)
        Dir.entries(directory).sort.select do |name|
          name.end_with?(".rb") && name != "vars.rb" && !name.start_with?("hosts") &&
            File.file?(File.join(directory, name))
        end.map { |name| File.expand_path(File.join(directory, name)) }
      end

      # One entry per message, naming the hosts it happened on unless it
      # happened on all of them.
      def group_by_message(failures, host_count)
        grouped = {}
        failures.each { |error, name| (grouped[error] ||= []) << name }
        grouped.map do |error, names|
          names.size == host_count || host_count == 1 ? [error, nil] : [error, names]
        end
      end

      def problems_from(errors, path, text)
        problems = {}
        errors.each do |error, names|
          file, line, message = locate(error, path, text)
          message = "#{message} (on #{names.join(", ")})" if names
          (problems[file] ||= []) << [line, message]
        end
        problems
      end

      # "path:line: message", or a message that names a resource such as
      # "file[/etc/motd] notifies service[nginx], which is not declared",
      # placed on the line that declares that resource.
      def locate(error, path, text)
        match = LOCATED.match(error)
        # The file being edited may not be saved yet.
        if match && (File.file?(match[1]) || File.expand_path(match[1]) == File.expand_path(path))
          file = File.expand_path(match[1])
          # The line is already the one the user wrote, misspelled options
          # included (see Sadame.located_message).
          return [file, match[2].to_i - 1, match[3].strip]
        end

        [File.expand_path(path), declaration_line(error, text), error]
      end

      def declaration_line(error, text)
        id = RESOURCE_ID.match(error)
        return 0 unless id

        lines = text.split("\n")
        index = lines.index do |line|
          line.include?("#{id[1]} \"#{id[2]}\"") || line.include?("#{id[1]} '#{id[2]}'") ||
            line.include?("#{id[1]}(\"#{id[2]}\"")
        end
        index || 0
      end

      # Every host of the inventory, with its vars, evaluated once until
      # forget.
      def targets(hosts_path, base_vars)
        return [] if hosts_path.nil?

        @inventories[hosts_path] ||= begin
          inventory = Inventory.load(hosts_path, shell: @shell)
          if inventory.empty?
            []
          else
            inventory.select(host_specs: [], group_names: [], limit: nil, base_vars: base_vars, cli_vars: {},
                             sudo: false).map { |target| [target.name, target.groups, target.vars] }
          end
        rescue Error
          []
        end
      end

      def project?(path)
        directories(path).any? { |directory| MARKERS.any? { |marker| File.file?(File.join(directory, marker)) } }
      end

      def nearest(path, name)
        directories(path).map { |directory| File.join(directory, name) }.find { |candidate| File.file?(candidate) }
      end

      # The file's directory and its parents, up to the workspace root.
      def directories(path)
        result = []
        directory = File.dirname(File.expand_path(path))
        loop do
          result << directory
          break if directory == @root || directory == "/" || File.dirname(directory) == directory

          directory = File.dirname(directory)
        end
        result
      end
    end
  end
end
