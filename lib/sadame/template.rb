# frozen_string_literal: true

module Sadame
  # A small ERB-compatible template engine, since mruby has no ERB.
  #
  # Supported tags:
  #   <%= expression %>  inserts the value of expression
  #   <% code %>         runs Ruby code (loops, conditionals)
  #   <%# comment %>     is dropped
  #   <%%                is a literal "<%"
  #   -%>                at the end of a tag removes the newline that follows it
  #   <%-                at the start of a tag removes indentation before it
  #
  # Templates see `vars` (the run's vars) and `locals` (the file resource's
  # locals: option), both plain hashes, and `facts` (see Facts).
  class Template
    attr_reader :path

    def initialize(source, path)
      @source = source
      @path = path
    end

    def render(vars: {}, locals: {}, facts: nil)
      literals, code = compile
      Scope.new(vars, locals, facts, literals).evaluate(code, path)
    rescue RecipeError => e
      raise e
    rescue ScriptError, StandardError => e
      raise RecipeError, Sadame.located_message(e, path)
    end

    # Turns the template into Ruby code that appends to _sadame_out. Literal
    # text is kept in a separate array and referenced by index, so it never
    # has to be escaped into a Ruby string literal. The generated code keeps
    # the template's line breaks, so error line numbers match the template.
    def compile
      literals = []
      code = String.new("_sadame_out = String.new;")
      position = 0

      while (tag_start = @source.index("<%", position))
        text = @source[position...tag_start]

        if @source[tag_start + 2] == "%"
          append_literal(code, literals, "#{text}<%")
          position = tag_start + 3
          next
        end

        tag_end = @source.index("%>", tag_start + 2)
        raise RecipeError, "#{path}:#{line_of(tag_start)}: unclosed <% tag" if tag_end.nil?

        tag = @source[(tag_start + 2)...tag_end]
        if tag.start_with?("-")
          text = strip_indentation(text)
          tag = tag[1..]
        end
        trim_newline = tag.end_with?("-")
        tag = tag[0...-1] if trim_newline

        append_literal(code, literals, text)
        append_tag(code, tag)

        position = tag_end + 2
        if trim_newline && newline_at?(position)
          position = skip_newline(position)
          code << "\n"
        end
      end

      append_literal(code, literals, @source[position..] || "")
      code << "\n_sadame_out\n"
      [literals, code]
    end

    private

    def append_literal(code, literals, text)
      return if text.empty?

      code << "_sadame_out << @_sadame_literals[#{literals.size}];" << ("\n" * text.count("\n"))
      literals << text
    end

    def append_tag(code, tag)
      if tag.start_with?("=")
        code << "_sadame_out << (#{tag[1..]}).to_s;"
      elsif tag.start_with?("#")
        code << ("\n" * tag.count("\n"))
      else
        code << "#{tag};"
      end
    end

    # Removes spaces and tabs between the last newline and a <%- tag.
    def strip_indentation(text)
      index = text.size
      index -= 1 while index > 0 && [" ", "\t"].include?(text[index - 1])
      return text if index > 0 && text[index - 1] != "\n"

      text[0...index]
    end

    def newline_at?(position)
      @source[position] == "\n" || @source[position, 2] == "\r\n"
    end

    def skip_newline(position)
      @source[position] == "\n" ? position + 1 : position + 2
    end

    def line_of(index)
      @source[0...index].count("\n") + 1
    end

    # The object a template is evaluated in. Its only public names are
    # vars, locals and facts.
    class Scope
      attr_reader :vars, :locals

      def initialize(vars, locals, facts, literals)
        @vars = vars
        @locals = locals
        @_sadame_facts = facts
        @_sadame_literals = literals
      end

      def facts
        raise RecipeError, "facts are not available here" if @_sadame_facts.nil?

        @_sadame_facts
      end

      def evaluate(code, path)
        instance_eval(code, path, 1)
      end

      # Older Rubies put inspect into NameError messages; keep those short.
      def inspect
        "#<Sadame::Template::Scope>"
      end
    end
  end
end
