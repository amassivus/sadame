# frozen_string_literal: true

module Sadame
  # Evaluates a recipe file. Every public method of this class is part of
  # the recipe language:
  #
  #   package "nginx"
  #   directory "/var/www/app", owner: "www-data", mode: "0755"
  #   file "/etc/nginx/nginx.conf", template: "nginx.conf.erb", notifies: [:reload, "service[nginx]"]
  #   service "nginx", enable: true, state: :running
  #   exec "certbot --nginx -d example.com", not_if: "test -f /etc/letsencrypt/live/example.com/fullchain.pem"
  #   user "deploy", shell: "/bin/bash", groups: ["docker"]
  #   group "app", gid: 1500
  #   link "/etc/nginx/sites-enabled/app", to: "/etc/nginx/sites-available/app"
  #   line "PermitRootLogin no", path: "/etc/ssh/sshd_config", match: /^#?\s*PermitRootLogin\s/
  #   git "/srv/app", repository: "https://github.com/example/app.git", revision: "v1.4.2"
  #   include_recipe "roles/web", tags: [:web]
  #
  # `vars`, `platform`, `facts`, `host_name` and `host_groups` are
  # available for decisions in plain Ruby.
  class Recipe
    attr_reader :vars

    # Loads the recipe at path and everything it includes. sources maps
    # expanded paths to text to use instead of the file's, such as an
    # editor's unsaved changes. The expanded path of every file evaluated
    # is added to loaded, even when evaluation fails.
    def self.load(path, host:, vars:, sources: {}, loaded: [])
      collection = ResourceCollection.new
      new(path, host: host, vars: vars, collection: collection, loaded: loaded, sources: sources).evaluate
      collection.link_notifications
      collection
    end

    # tags are added to every resource this recipe declares (see
    # include_recipe).
    def initialize(path, host:, vars:, collection:, loaded:, tags: [], sources: {})
      @path = path
      @host = host
      @vars = vars
      @collection = collection
      @loaded = loaded
      @tags = tags
      @sources = sources
    end

    def evaluate
      expanded = File.expand_path(@path)
      @loaded << expanded
      source = @sources[expanded] || File.read(@path)
      instance_eval(source, @path, 1)
      self
    rescue RecipeError => e
      raise e
    rescue ScriptError, StandardError => e
      raise RecipeError, Sadame.located_message(e, @path, source)
    end

    def package(name, options = {})
      declare(PackageResource, name, options)
    end

    def file(path, options = {})
      declare(FileResource, path, options)
    end

    def directory(path, options = {})
      declare(DirectoryResource, path, options)
    end

    def service(name, options = {})
      declare(ServiceResource, name, options)
    end

    def exec(command, options = {})
      declare(ExecResource, command, options)
    end

    def user(name, options = {})
      declare(UserResource, name, options)
    end

    def group(name, options = {})
      declare(GroupResource, name, options)
    end

    def link(path, options = {})
      declare(LinkResource, path, options)
    end

    def line(name, options = {})
      declare(LineResource, name, options)
    end

    def git(path, options = {})
      declare(GitResource, path, options)
    end

    # Evaluates another recipe, relative to this recipe's directory. The
    # ".rb" extension is optional. A recipe is only ever included once.
    # With tags:, every resource it declares (and the recipes it includes)
    # gets those tags.
    def include_recipe(name, options = {})
      unknown = options.keys - [:tags]
      raise Error, "include_recipe takes only tags:, got #{unknown.first.inspect}" unless unknown.empty?

      tags = @tags + Resource.tag_list(options[:tags], "include_recipe #{name}")
      file_name = name.to_s.end_with?(".rb") ? name.to_s : "#{name}.rb"
      path = recipe_dir == "." ? file_name : File.join(recipe_dir, file_name)
      raise Error, "include_recipe cannot find #{path}" unless File.file?(path)
      return if @loaded.include?(File.expand_path(path))

      Recipe.new(path, host: @host, vars: @vars, collection: @collection, loaded: @loaded, tags: tags,
                       sources: @sources).evaluate
      nil
    end

    def platform
      @host.platform
    end

    # What the machine has: CPUs, memory, addresses and more, read from it
    # when first asked for. See Facts.
    #
    #   workers = facts[:cpus] * 2
    def facts
      @host.facts
    end

    # The name of the host being configured: its name in hosts.rb or -h, or
    # "local" (see --host-name).
    def host_name
      @host.name
    end

    # The groups the host belongs to in hosts.rb, as symbols, including
    # groups that include them. Empty for local runs (see --host-groups).
    #
    #   include_recipe "roles/web" if host_groups.include?(:web)
    def host_groups
      @host.groups
    end

    private

    def recipe_dir
      File.dirname(@path)
    end

    def declare(resource_class, name, options)
      if options.is_a?(Hash) && !@tags.empty?
        own = options[:tags]
        options = options.merge(tags: @tags + (own.is_a?(Array) ? own : [own].compact))
      end
      resource = resource_class.new(name, options, host: @host, source_dir: recipe_dir, vars: @vars)
      @collection.add(resource)
      resource
    end
  end
end
