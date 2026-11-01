# frozen_string_literal: true

module Sadame
  module Lsp
    # What the editor shows while a recipe is written: completions, hover
    # text and the outline. It reads the text around the cursor, not the
    # evaluated recipe, so it works on half-written code.
    class Editing
      RESOURCES = Reference::RESOURCES
      # The first word of a statement, and a resource with its name.
      STATEMENT = /\A\s*([a-z_]+)[\s(]/
      DECLARATION = /\A\s*([a-z_]+)\s*\(?\s*(["'])(.*?)\2/
      KIND_FUNCTION = 3
      KIND_VARIABLE = 6
      KIND_PROPERTY = 10
      KIND_ENUM_MEMBER = 20
      KIND_FIELD = 5
      SYMBOL_FUNCTION = 12
      SYMBOL_MODULE = 2

      def initialize(text)
        @lines = text.split("\n", -1)
      end

      def completion(line_number, column)
        prefix = (@lines[line_number] || "").byteslice(0, column).to_s
        return fact_items if /facts\[:\w*\z/.match(prefix)

        value = /(\w+):\s*:\w*\z/.match(prefix)
        if value
          resource = resource_at(line_number, prefix.sub(/\w+:\s*:\w*\z/, ""))
          return resource ? value_items(resource, value[1]) : []
        end

        resource = resource_at(line_number, prefix)
        return option_items(resource) if resource
        return statement_items if /\A\s*\w*\z/.match(prefix)

        []
      end

      # Markdown about the word at the cursor, and the word's byte range,
      # or nil.
      def hover(line_number, column)
        line = @lines[line_number] || ""
        start, stop = word_bounds(line, column)
        return nil if start == stop

        word = line.byteslice(start, stop - start)
        before = line.byteslice(0, start).to_s
        text = hover_text(line_number, word, before, line.byteslice(stop, 1).to_s)
        text ? [text, start, stop] : nil
      end

      # Resources and included recipes, in order, as [name, kind, line].
      def symbols
        result = []
        @lines.each_with_index do |line, index|
          match = DECLARATION.match(line)
          next unless match

          if RESOURCES.key?(match[1])
            result << ["#{match[1]}[#{match[3]}]", SYMBOL_FUNCTION, index]
          elsif match[1] == "include_recipe"
            result << ["include_recipe #{match[3]}", SYMBOL_MODULE, index]
          end
        end
        result
      end

      private

      # The resource whose arguments the cursor is in: on the line that
      # declares it, after the first argument, or on a following line while
      # the lines before end with a comma.
      def resource_at(line_number, prefix)
        same_line = /\A\s*([a-z_]+)[\s(].*,\s*\w*\z/.match(prefix)
        return same_line[1] if same_line && RESOURCES.key?(same_line[1])
        return nil unless /\A\s*\w*\z/.match(prefix) || /,\s*\w*\z/.match(prefix)

        index = line_number - 1
        while index >= 0
          text = @lines[index].to_s.rstrip
          break unless text.end_with?(",")

          start = STATEMENT.match(text)
          return start[1] if start && RESOURCES.key?(start[1])

          index -= 1
        end
        nil
      end

      def statement_items
        resources = RESOURCES.map do |name, resource|
          item(name, KIND_FUNCTION, "resource", "#{resource["summary"]}\n\n[#{name}](#{resource["url"]})")
        end
        helpers = Reference::HELPERS.map do |name, text|
          item(name, name == "include_recipe" ? KIND_FUNCTION : KIND_VARIABLE, "recipe helper", text)
        end
        resources + helpers
      end

      def option_items(resource)
        RESOURCES[resource]["options"].map do |name, option|
          item("#{name}:", KIND_PROPERTY, option["type"], option_text(resource, name, option), insert: "#{name}: ")
        end
      end

      def value_items(resource, option)
        details = RESOURCES[resource]["options"][option]
        return [] unless details

        details["values"].map { |value| item(value, KIND_ENUM_MEMBER, ":#{value}", option_text(resource, option, details)) }
      end

      def fact_items
        Reference::FACTS.map { |name, text| item(name, KIND_FIELD, "fact", text) }
      end

      def item(label, kind, detail, documentation, insert: nil)
        result = { label: label, kind: kind, detail: detail, documentation: { kind: "markdown", value: documentation } }
        result[:insertText] = insert if insert
        result
      end

      def option_text(resource, name, option)
        "**#{name}** (#{resource})\n\n#{option["description"]}\n\nType: #{option["type"]}. Default: #{option["default"]}."
      end

      def hover_text(line_number, word, before, after)
        return fact_hover(word) if before.end_with?("facts[:")

        if after == ":"
          resource = resource_at(line_number, before)
          option = resource && RESOURCES[resource]["options"][word]
          return option_text(resource, word, option) if option
        end
        if before.strip.empty? && RESOURCES.key?(word)
          resource = RESOURCES[word]
          return "**#{word}**\n\n#{resource["summary"]}\n\n[Documentation](#{resource["url"]})"
        end
        return "**#{word}**\n\n#{Reference::HELPERS[word]}" if Reference::HELPERS.key?(word)

        nil
      end

      def fact_hover(word)
        text = Reference::FACTS[word]
        text ? "**facts[:#{word}]**\n\n#{text}" : nil
      end

      def word_bounds(line, column)
        start = column
        start -= 1 while start > 0 && word_byte?(line.getbyte(start - 1))
        stop = column
        stop += 1 while stop < line.bytesize && word_byte?(line.getbyte(stop))
        [start, stop]
      end

      def word_byte?(byte)
        return false if byte.nil?

        (byte >= 97 && byte <= 122) || (byte >= 65 && byte <= 90) || (byte >= 48 && byte <= 57) || byte == 95
      end
    end
  end
end
