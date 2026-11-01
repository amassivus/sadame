# frozen_string_literal: true

module Sadame
  # Output of `sadame facts`: every fact of one host, as recipes see them.
  class FactsListing
    NAME_WIDTH = Facts::NAMES.map { |name| name.to_s.size }.max + 2

    def initialize(io, color: false)
      @io = io
      @color = color
    end

    def render(host)
      header = "sadame #{VERSION} facts on #{host.name} (#{host.platform.description})"
      line(@color ? "\e[1m#{header}\e[0m" : header)
      line
      host.facts.to_h.each { |name, value| line("#{name.to_s.ljust(NAME_WIDTH)}#{format_value(value)}".rstrip) }
    end

    def render_json(host)
      document = {
        format_version: Report::FORMAT_VERSION,
        sadame_version: VERSION,
        command: "facts",
        host: host.name,
        platform: host.platform.to_h,
        facts: host.facts.to_h
      }
      @io.write(JsonWriter.generate(document))
    end

    private

    def format_value(value)
      case value
      when nil then "(none)"
      when Array then value.empty? ? "(none)" : value.join(", ")
      else value.to_s
      end
    end

    def line(text = "")
      @io.write("#{text}\n")
    end
  end
end
