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
  #   include_recipe "roles/web"
  #
  # `vars` and `platform` are available for decisions in plain Ruby.
  class Recipe
    attr_reader :vars

    # Loads the recipe at path and everything it includes.
    def self.load(path, host:, vars:)
      collection = ResourceCollection.new
      new(path, host: host, vars: vars, collection: collection, loaded: []).evaluate
      collection.validate_notifications
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
      raise RecipeError, "#{Sadame.error_location(e, @path)}: #{e.message}"
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

    # Evaluates another recipe, relative to this recipe's directory. The
    # ".rb" extension is optional. A recipe is only ever included once.
    def include_recipe(name)
      path = File.join(recipe_dir, name.to_s.end_with?(".rb") ? name.to_s : "#{name}.rb")
      raise Error, "include_recipe cannot find #{path}" unless File.file?(path)
      return if @loaded.include?(File.expand_path(path))

      Recipe.new(path, host: @host, vars: @vars, collection: @collection, loaded: @loaded).evaluate
      nil
    end

    def platform
      @host.platform
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
