# frozen_string_literal: true

module Sadame
  # `sadame validate`: evaluates a recipe once per host, with that host's
  # name, groups and vars, against a stand-in machine (see StandIn), and
  # checks what can be checked without the machine: Ruby errors, resource
  # names and options, notifications, include_recipe paths, and templates
  # and source files, which are found and rendered.
  class Validation
    Result = Struct.new(:name, :resources, :error)

    def initialize(recipe_path, platform:)
      @recipe_path = recipe_path
      @platform = platform
    end

    def check(name:, groups:, vars:)
      host = StandIn::Host.new(name: name, groups: groups, platform: @platform)
      resources = Recipe.load(@recipe_path, host: host, vars: vars)
      resources.each { |resource| resource.check_offline }
      Result.new(name, resources.size, nil)
    rescue Error => e
      Result.new(name, nil, e.message)
    rescue StandardError => e
      Result.new(name, nil, "#{e.class}: #{e.message}")
    end
  end

  # Output of `sadame validate`.
  class ValidationListing
    def initialize(io, color: false)
      @io = io
      @color = color
    end

    def render(recipe_path, platform, results)
      line(bold("sadame #{VERSION} validate #{recipe_path}, as on #{platform.description}"))
      line
      width = results.map { |result| result.name.size }.max + 2
      results.each do |result|
        if result.error
          first, *rest = result.error.split("\n")
          line("  #{result.name.ljust(width)}#{paint("error", 31)}  #{first}")
          rest.each { |text| line("  #{" " * (width + 7)}#{text}") }
        else
          noun = result.resources == 1 ? "resource" : "resources"
          line("  #{result.name.ljust(width)}#{paint("ok", 32)}     #{result.resources} #{noun}")
        end
      end
      errors = results.count { |result| result.error }
      noun = results.size == 1 ? "host" : "hosts"
      counts = ["#{results.size - errors} ok", errors > 0 ? "#{errors} error" : nil].compact.join(", ")
      line
      line("validate on #{results.size} #{noun}: #{counts}.")
    end

    def render_json(recipe_path, platform, results)
      document = {
        format_version: Report::FORMAT_VERSION,
        sadame_version: VERSION,
        command: "validate",
        recipe: recipe_path,
        platform: platform.to_h,
        hosts: results.map do |result|
          { name: result.name, status: result.error ? "error" : "ok", resources: result.resources, error: result.error }
        end,
        exit_status: Validation.exit_status(results)
      }
      @io.write(JsonWriter.generate(document))
    end

    private

    def paint(text, code)
      @color ? "\e[#{code}m#{text}\e[0m" : text
    end

    def bold(text)
      @color ? "\e[1m#{text}\e[0m" : text
    end

    def line(text = "")
      @io.write("#{text}\n")
    end
  end

  class Validation
    # 0 when every host's recipe is valid, 2 otherwise, like a recipe error.
    def self.exit_status(results)
      results.any? { |result| result.error } ? 2 : 0
    end
  end
end
