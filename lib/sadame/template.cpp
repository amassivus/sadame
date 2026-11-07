#include "template.hpp"

#include "errors.hpp"
#include "scheme.hpp"

namespace sadame {

TemplateContext *&TemplateContext::current() {
  static TemplateContext *current = nullptr;
  return current;
}

namespace {

bool blank(char character) { return character == ' ' || character == '\t'; }

}  // namespace

struct Template::Parser {
  enum class Stop { Eof, Else, End };

  Parser(const std::string &source, const std::string &path) : source(source), path(path) {}

  [[noreturn]] void fail(std::size_t at, const std::string &message) const {
    throw RecipeError(path + ":" + std::to_string(line_of(at)) + ": " + message);
  }

  int line_of(std::size_t index) const {
    int line = 1;
    for (std::size_t position = 0; position < index && position < source.size(); ++position) {
      if (source[position] == '\n') ++line;
    }
    return line;
  }

  // The index of the closing bracket that matches the opening one at
  // `open`, skipping over Scheme strings, or npos.
  std::size_t matching(std::size_t open, char opener, char closer) const {
    int depth = 0;
    for (std::size_t index = open; index < source.size(); ++index) {
      char character = source[index];
      if (character == '"') {
        for (++index; index < source.size() && source[index] != '"'; ++index) {
          if (source[index] == '\\') ++index;
        }
      } else if (character == '#' && index + 1 < source.size() && source[index + 1] == '\\') {
        index += 2;  // a character literal such as #\) is not a bracket
      } else if (character == opener) {
        ++depth;
      } else if (character == closer && --depth == 0) {
        return index;
      }
    }
    return std::string::npos;
  }

  // True when only blanks stand between the start of the line and `at`.
  bool starts_line(std::size_t at) const {
    while (at > 0 && blank(source[at - 1])) --at;
    return at == 0 || source[at - 1] == '\n';
  }

  // The index after the blanks and the line break that follow `from`, when
  // nothing else is on the rest of the line; otherwise `from`.
  std::size_t rest_of_line(std::size_t from) const {
    std::size_t index = from;
    while (index < source.size() && blank(source[index])) ++index;
    if (index >= source.size()) return index;
    if (source[index] == '\n') return index + 1;
    if (source[index] == '\r' && index + 1 < source.size() && source[index + 1] == '\n') return index + 2;
    return from;
  }

  static void trim_blanks(std::string &text) {
    while (!text.empty() && blank(text.back())) text.pop_back();
  }

  static std::string trimmed(const std::string &text) { return strip(text); }

  void flush(std::vector<Node> &nodes, std::string &text, std::size_t text_start) const {
    if (text.empty()) return;
    Node node;
    node.type = Node::Type::Text;
    node.text = text;
    node.line = line_of(text_start);
    nodes.push_back(node);
    text.clear();
  }

  std::vector<Node> block(Stop &stop, const std::string &opener, std::size_t opened_at) {
    std::vector<Node> nodes;
    std::string text;
    std::size_t text_start = pos;

    while (pos < source.size()) {
      char character = source[pos];
      if (character != '~' || pos + 1 >= source.size()) {
        if (text.empty()) text_start = pos;
        text += character;
        ++pos;
        continue;
      }

      char next = source[pos + 1];
      if (next == '~') {
        if (text.empty()) text_start = pos;
        text += '~';
        pos += 2;
      } else if (next == '{') {
        std::size_t close = matching(pos + 1, '{', '}');
        if (close == std::string::npos) fail(pos, "unclosed ~{ tag");
        flush(nodes, text, text_start);
        Node node;
        node.type = Node::Type::Expression;
        node.text = source.substr(pos + 2, close - pos - 2);
        node.line = line_of(pos);
        nodes.push_back(node);
        pos = close + 1;
      } else if (next == ';') {
        bool alone = starts_line(pos);
        std::size_t end = source.find('\n', pos);
        if (end == std::string::npos) end = source.size();
        if (alone) {
          trim_blanks(text);
          pos = end < source.size() ? end + 1 : end;
        } else {
          pos = end;
        }
      } else if (next == '(') {
        std::size_t close = matching(pos + 1, '(', ')');
        if (close == std::string::npos) fail(pos, "unclosed ~( tag");
        std::string inner = trimmed(source.substr(pos + 2, close - pos - 2));
        std::size_t space = inner.find_first_of(" \t\n");
        std::string word = inner.substr(0, space);
        std::string rest = space == std::string::npos ? "" : trimmed(inner.substr(space));
        std::size_t directive = pos;

        if (word != "if" && word != "else" && word != "end" && word != "each") {
          fail(pos, "unknown tag ~(" + word + "); use ~{...} to insert a value");
        }
        if (starts_line(pos)) {
          std::size_t after = rest_of_line(close + 1);
          if (after != close + 1) {
            trim_blanks(text);
            pos = after;
          } else {
            pos = close + 1;
          }
        } else {
          pos = close + 1;
        }
        flush(nodes, text, text_start);

        if (word == "else" || word == "end") {
          if (opener.empty()) fail(directive, "~(" + word + ") without ~(if) or ~(each)");
          stop = word == "else" ? Stop::Else : Stop::End;
          return nodes;
        }
        nodes.push_back(open_block(word, rest, directive));
      } else {
        if (text.empty()) text_start = pos;
        text += '~';
        ++pos;
      }
    }

    flush(nodes, text, text_start);
    if (!opener.empty()) fail(opened_at, "~(" + opener + ") is never closed with ~(end)");
    stop = Stop::Eof;
    return nodes;
  }

  Node open_block(const std::string &word, const std::string &rest, std::size_t at) {
    Node node;
    node.line = line_of(at);
    if (word == "if") {
      if (rest.empty()) fail(at, "~(if) needs an expression");
      node.type = Node::Type::If;
      node.text = rest;
    } else {
      std::size_t space = rest.find_first_of(" \t\n");
      std::string expression = space == std::string::npos ? "" : trimmed(rest.substr(space));
      if (rest.empty() || expression.empty()) fail(at, "~(each) needs a name and a list, as in ~(each item (vars 'items))");
      node.type = Node::Type::Each;
      node.variable = rest.substr(0, space);
      node.text = expression;
    }

    Stop stop = Stop::Eof;
    node.body = block(stop, word, at);
    if (stop == Stop::Else) {
      if (word == "each") fail(at, "~(else) does not belong to ~(each)");
      node.otherwise = block(stop, word, at);
      if (stop == Stop::Else) fail(at, "~(if) has two ~(else) tags");
    }
    return node;
  }

  const std::string &source;
  const std::string &path;
  std::size_t pos = 0;
};

std::vector<Template::Node> Template::parse() const {
  Parser parser(source_, path_);
  Parser::Stop stop = Parser::Stop::Eof;
  return parser.block(stop, "", 0);
}

Value Template::evaluate(const Node &node, const std::vector<std::pair<std::string, Value>> &bindings) const {
  scheme::ExpressionResult result = scheme::evaluate_expression(node.text, bindings);
  if (!result.ok) throw RecipeError(path_ + ":" + std::to_string(node.line) + ": " + result.message);
  return result.value;
}

void Template::render_nodes(const std::vector<Node> &nodes, std::string &out,
                            std::vector<std::pair<std::string, Value>> &bindings) const {
  for (const Node &node : nodes) {
    switch (node.type) {
      case Node::Type::Text: out += node.text; break;
      case Node::Type::Expression: {
        Value value = evaluate(node, bindings);
        if (!value.is_false()) out += value.to_s();
        break;
      }
      case Node::Type::If: {
        Value condition = evaluate(node, bindings);
        bool truthy = !condition.is_nil() && !condition.is_false();
        render_nodes(truthy ? node.body : node.otherwise, out, bindings);
        break;
      }
      case Node::Type::Each: {
        Value list = evaluate(node, bindings);
        std::vector<Value> items;
        if (list.is_array()) {
          items = list.items();
        } else if (list.is_map()) {
          for (std::size_t index = 0; index < list.keys().size(); ++index) {
            items.push_back(Value::array({Value::symbol(list.keys()[index]), list.values()[index]}));
          }
        } else if (!list.is_nil() && !list.is_false()) {
          throw RecipeError(path_ + ":" + std::to_string(node.line) + ": ~(each) needs a list, got " + list.type_name());
        }
        for (const Value &item : items) {
          bindings.push_back({node.variable, item});
          render_nodes(node.body, out, bindings);
          bindings.pop_back();
        }
        break;
      }
    }
  }
}

std::string Template::render(const Value &vars, const Value &locals, Facts *facts) const {
  std::vector<Node> nodes = parse();

  TemplateContext context;
  context.vars = &vars;
  context.locals = &locals;
  context.facts = facts;
  TemplateContext *previous = TemplateContext::current();
  TemplateContext::current() = &context;

  std::string out;
  std::vector<std::pair<std::string, Value>> bindings;
  try {
    render_nodes(nodes, out, bindings);
  } catch (...) {
    TemplateContext::current() = previous;
    throw;
  }
  TemplateContext::current() = previous;
  return out;
}

}  // namespace sadame
