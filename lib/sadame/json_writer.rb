# frozen_string_literal: true

module Sadame
  # Writes the --json output. Using our own small generator keeps the output
  # identical under CRuby and mruby, including key order and indentation.
  module JsonWriter
    ESCAPES = {
      '"' => '\\"',
      "\\" => "\\\\",
      "\n" => "\\n",
      "\r" => "\\r",
      "\t" => "\\t",
      "\b" => "\\b",
      "\f" => "\\f"
    }.freeze

    INDENT = "  "

    # JSON text inserted as it is, such as a report sadame produced on
    # another machine. It is re-indented to fit where it is placed.
    class Raw
      attr_reader :text

      def initialize(text)
        @text = text.strip
      end
    end

    def self.generate(value)
      "#{write(value, 0)}\n"
    end

    def self.write(value, depth)
      case value
      when Raw then indent_raw(value.text, depth)
      when Hash then write_object(value, depth)
      when Array then write_array(value, depth)
      when String then write_string(value)
      when Symbol then write_string(value.to_s)
      when Integer, Float then value.to_s
      when true then "true"
      when false then "false"
      when nil then "null"
      else write_string(value.to_s)
      end
    end

    def self.write_object(hash, depth)
      return "{}" if hash.empty?

      inner = INDENT * (depth + 1)
      members = hash.map { |key, member| "#{inner}#{write_string(key.to_s)}: #{write(member, depth + 1)}" }
      "{\n#{members.join(",\n")}\n#{INDENT * depth}}"
    end

    def self.write_array(array, depth)
      return "[]" if array.empty?

      inner = INDENT * (depth + 1)
      items = array.map { |item| "#{inner}#{write(item, depth + 1)}" }
      "[\n#{items.join(",\n")}\n#{INDENT * depth}]"
    end

    def self.indent_raw(text, depth)
      lines = text.split("\n")
      return text if lines.size < 2

      ([lines.first] + lines[1..].map { |line| "#{INDENT * depth}#{line}" }).join("\n")
    end

    def self.write_string(string)
      escaped = String.new
      string.each_char do |char|
        escaped << (ESCAPES[char] || escape_control(char))
      end
      "\"#{escaped}\""
    end

    def self.escape_control(char)
      code = char.ord
      code < 0x20 ? format("\\u%04x", code) : char
    end
  end
end
