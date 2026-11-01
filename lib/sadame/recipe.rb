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
  #   include_recipe "roles/web"
  #
  # `vars`, `platform`, `host_name` and `host_groups` are available for
  # decisions in plain Ruby.
  class Recipe
    attr_reader :vars

    # Loads the recipe at path and everything it includes.
    def self.load(path, host:, vars:)
      collection = ResourceCollection.new
      new(path, host: host, vars: vars, collection: collection, loaded: []).evaluate
      collection.link_notifications
      collection
    end

    def initialize(path, host:, vars:, collection:, loaded:)
      @path = path
      @host = host
      @vars = vars
      @collection = collection
      @loaded = loaded
    end

    def evaluate
      @loaded << File.expand_path(@path)
      instance_eval(File.read(@path), @path, 1)
      self
    rescue RecipeError => e
      raise e
    rescue ScriptError, StandardError => e
      raise RecipeError, Sadame.located_message(e, @path)
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

    # Evaluates another recipe, relative to this recipe's directory. The
    # ".rb" extension is optional. A recipe is only ever included once.
    def include_recipe(name)
      file_name = name.to_s.end_with?(".rb") ? name.to_s : "#{name}.rb"
      path = recipe_dir == "." ? file_name : File.join(recipe_dir, file_name)
      raise Error, "include_recipe cannot find #{path}" unless File.file?(path)
      return if @loaded.include?(File.expand_path(path))

      Recipe.new(path, host: @host, vars: @vars, collection: @collection, loaded: @loaded).evaluate
      nil
    end

    def platform
      @host.platform
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
      resource = resource_class.new(name, options, host: @host, source_dir: recipe_dir, vars: @vars)
      @collection.add(resource)
      resource
    end
  end
end
