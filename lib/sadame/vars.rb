# frozen_string_literal: true

module Sadame
  # Loads and merges the `vars` hash that recipes and templates see.
  # Keys are always symbols.
  module Vars
    # vars.rb is plain Ruby whose last expression is a Hash:
    #
    #   { server_name: "example.com", workers: 4 }
    def self.load_file(path)
      return {} unless File.exist?(path)

      value = Evaluator.new.evaluate(File.read(path), path)
      raise RecipeError, "#{path} must evaluate to a Hash, got #{value.class}" unless value.is_a?(Hash)

      symbolize_keys(value)
    rescue RecipeError => e
      raise e
    rescue ScriptError, StandardError => e
      raise RecipeError, Sadame.located_message(e, path)
    end

    # Parses one --var argument of the form key=value. Values stay strings,
    # except "true", "false" and integers without leading zeros (so "0644"
    # stays a string), which are converted.
    def self.parse_assignment(text)
      key, value = text.to_s.split("=", 2)
      raise UsageError, "--var expects key=value, got #{text.inspect}" if key.nil? || key.empty? || value.nil?

      [key.to_sym, coerce(value)]
    end

    def self.coerce(value)
      return true if value == "true"
      return false if value == "false"
      return value.to_i if integer?(value)

      value
    end

    def self.integer?(value)
      digits = value.start_with?("-") ? value[1..] : value
      return false if digits.empty? || (digits.size > 1 && digits.start_with?("0"))

      digits.chars.all? { |char| "0123456789".include?(char) }
    end

    # Merges layers given from lowest to highest precedence.
    def self.merge(*layers)
      result = {}
      layers.each { |layer| result = result.merge(symbolize_keys(layer)) }
      result
    end

    # Merges [label, hash] layers given from lowest to highest precedence.
    # Returns the vars and, for each key, the label of the layer it came
    # from, which `sadame hosts` shows.
    def self.layered(layers)
      vars = {}
      sources = {}
      layers.each do |label, values|
        symbolize_keys(values).each do |key, value|
          vars[key] = value
          sources[key] = label
        end
      end
      [vars, sources]
    end

    def self.symbolize_keys(hash)
      result = {}
      hash.each { |key, value| result[key.to_sym] = value }
      result
    end

    # Evaluates vars.rb in an empty object, so the file cannot reach into
    # sadame's internals by accident.
    class Evaluator
      def evaluate(code, path)
        instance_eval(code, path, 1)
      end
    end
  end
end
