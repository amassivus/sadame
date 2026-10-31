# frozen_string_literal: true

module Sadame
  # Writes values as Ruby source on a single line, so they can be sent to
  # another process or machine and read back with eval exactly as they were:
  # symbols stay symbols, integers stay integers. Push mode uses it for the
  # vars it sends to each target.
  module RubyLiteral
    ESCAPES = {
      "\\" => "\\\\",
      '"' => '\\"',
      "#" => "\\#",
      "\n" => "\\n",
      "\r" => "\\r",
      "\t" => "\\t"
    }.freeze

    def self.dump(value)
      case value
      when Hash then dump_hash(value)
      when Array then "[#{value.map { |item| dump(item) }.join(", ")}]"
      when String then dump_string(value)
      when Symbol then dump_symbol(value.to_s)
      when Integer, Float then value.to_s
      when true then "true"
      when false then "false"
      when nil then "nil"
      else
        raise Error, "cannot send a #{value.class} to a target; use strings, numbers, booleans, arrays and hashes"
      end
    end

    IDENTIFIER_START = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"
    IDENTIFIER_CHARACTERS = "#{IDENTIFIER_START}0123456789".freeze

    # :name for plain names, :"..." for anything else.
    def self.dump_symbol(name)
      plain = !name.empty? && IDENTIFIER_START.include?(name[0]) &&
              name.chars.all? { |char| IDENTIFIER_CHARACTERS.include?(char) }
      plain ? ":#{name}" : ":#{dump_string(name)}"
    end

    def self.dump_hash(hash)
      return "{}" if hash.empty?

      "{ #{hash.map { |key, value| "#{dump(key)} => #{dump(value)}" }.join(", ")} }"
    end

    def self.dump_string(string)
      escaped = String.new
      string.each_char do |char|
        escaped << (ESCAPES[char] || escape_control(char))
      end
      "\"#{escaped}\""
    end

    def self.escape_control(char)
      code = char.ord
      code < 0x20 || code == 0x7f ? format("\\x%02X", code) : char
    end
  end
end
