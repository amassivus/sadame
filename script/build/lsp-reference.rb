# frozen_string_literal: true

# Writes lib/sadame/lsp/reference.rb, what `sadame lsp` shows when it
# completes and describes resources, options, facts and recipe helpers,
# from the docs: each resource page's first paragraph and options table,
# the facts table, and the helpers table of recipe basics. The docs stay
# the one place these are written; a unit test fails when the generated
# file is out of date.
#
#   ruby script/build/lsp-reference.rb       (or rake lsp:reference)
#
# Development tooling: CRuby only.

module LspReference
  ROOT = File.expand_path("../..", __dir__)
  OUTPUT = File.join(ROOT, "lib", "sadame", "lsp", "reference.rb")
  SITE = "https://enderkus.github.io/sadame/"
  # In the order of the docs' navigation.
  RESOURCES = %w[package file line directory link service exec user group git].freeze

  module_function

  def generate
    resources = RESOURCES.map { |name| [name, resource(name)] }.to_h
    <<~RUBY
      # frozen_string_literal: true

      # Generated from docs/ by script/build/lsp-reference.rb (rake lsp:reference).
      # Do not edit: change the docs and generate it again.
      module Sadame
        module Lsp
          module Reference
            RESOURCES = #{literal(resources, 3)}.freeze

            FACTS = #{literal(facts, 3)}.freeze

            HELPERS = #{literal(helpers, 3)}.freeze
          end
        end
      end
    RUBY
  end

  def resource(name)
    page = "resources/#{name}.md"
    text = File.read(File.join(ROOT, "docs", page))
    options = {}
    table_rows(section(text, "## Options")).each do |option, type, default, description|
      key = option.delete("`")
      options[key] = {
        "type" => markdown(type, page), "default" => markdown(default, page),
        "description" => markdown(description, page), "values" => choices(type)
      }
    end
    { "summary" => markdown(first_paragraph(text), page), "url" => url(page), "options" => options }
  end

  # The Symbols an option takes, when its type is a choice between them,
  # such as "`:present` or `:absent`".
  def choices(type)
    return [] unless type.match?(/\A`:\w+`(?:(?:, | or |, or )`:\w+`)*\z/)

    type.scan(/`:(\w+)`/).flatten
  end

  def facts
    page = "recipes/facts.md"
    rows = table_rows(section(File.read(File.join(ROOT, "docs", page)), "## The facts"))
    rows.to_h do |fact, type, example, source|
      [fact.delete("`"), "#{markdown(type, page)}, such as #{markdown(example, page)}. Read from #{markdown(source, page)}."]
    end
  end

  # The helpers table of recipe basics: a row can name several helpers
  # (`host_name`, `host_groups`), and several rows one (platform).
  def helpers
    page = "recipes/basics.md"
    text = File.read(File.join(ROOT, "docs", page))
    table = text[/^Besides the resources, a recipe can use:\n\n(.*?)\n\n/m, 1]
    result = {}
    table_rows(table).each do |names, description|
      line = "- #{markdown(names, page)}: #{markdown(description, page)}"
      names.scan(/`(\w+)/).flatten.uniq.each { |name| result[name] = [result[name], line].compact.join("\n") }
    end
    result
  end

  def section(text, heading)
    text[/^#{Regexp.escape(heading)}\n(.*?)(?=^## |\z)/m, 1] or abort "no #{heading} section"
  end

  # Cells of every row after the header and separator lines.
  def table_rows(text)
    text.lines.map(&:strip).select { |line| line.start_with?("|") }.drop(2).map do |line|
      line.delete_prefix("|").delete_suffix("|").split(" | ").map(&:strip)
    end
  end

  def first_paragraph(text)
    text.split("\n\n").find { |block| !block.start_with?("#") }.gsub("\n", " ")
  end

  # Links relative to the page become links to the published site.
  def markdown(text, page)
    text.gsub(/\]\(([^)#]*\.md)(#[^)]*)?\)/) do
      target = File.expand_path(Regexp.last_match(1), File.join("/", File.dirname(page))).delete_prefix("/")
      "](#{url(target)}#{Regexp.last_match(2)})"
    end
  end

  def url(page)
    "#{SITE}#{page.delete_suffix(".md").delete_suffix("index")}/".sub(%r{//\z}, "/")
  end

  def literal(value, depth)
    indent = "  " * depth
    case value
    when Hash
      return "{}" if value.empty?

      entries = value.map { |key, item| "#{indent}  #{key.inspect} => #{literal(item, depth + 1)}" }
      "{\n#{entries.join(",\n")}\n#{indent}}"
    when Array then "[#{value.map(&:inspect).join(", ")}]"
    else value.inspect
    end
  end
end

if $PROGRAM_NAME == __FILE__
  File.write(LspReference::OUTPUT, LspReference.generate)
  puts LspReference::OUTPUT.delete_prefix("#{LspReference::ROOT}/")
end
