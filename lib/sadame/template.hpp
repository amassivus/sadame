#pragma once

#include <string>
#include <vector>

#include "value.hpp"

namespace sadame {

class Facts;

// What the Scheme expressions of a template can reach: the run's vars, the
// file resource's locals and the machine's facts.
struct TemplateContext {
  const Value *vars = nullptr;
  const Value *locals = nullptr;
  Facts *facts = nullptr;

  // The template being rendered right now, for the Scheme primitives.
  static TemplateContext *&current();
};

// The template engine. Templates are text with Scheme in it:
//
//   ~{expression}      inserts the value of a Scheme expression
//   ~(if expression)   inserts what follows up to ~(else) or ~(end) when the
//                      expression is not #f
//   ~(else)
//   ~(each name list)  inserts what follows up to ~(end) once for each item
//                      of the list, with name bound to the item
//   ~(end)
//   ~;                 a comment: dropped, with the rest of its line
//   ~~                 a literal "~"
//
// A line that holds nothing but ~(if), ~(else), ~(each), ~(end) or a comment
// is dropped with its line break, so the tags leave no blank lines behind.
// A "~" followed by anything else is an ordinary character.
//
// Expressions see (vars 'name), (locals 'name) and (facts 'name), and
// (ref alist 'key) for the items of a loop. Values are inserted as text: an
// #f or a missing value is empty, #t is "true".
class Template {
 public:
  Template(std::string source, std::string path) : source_(std::move(source)), path_(std::move(path)) {}

  const std::string &path() const { return path_; }

  // facts may be null, for templates that never ask for them.
  std::string render(const Value &vars, const Value &locals, Facts *facts) const;

 private:
  struct Node {
    enum class Type { Text, Expression, If, Each } type = Type::Text;
    std::string text;        // Text: the text; others: the expression
    std::string variable;    // Each: the loop variable
    int line = 1;
    std::vector<Node> body;
    std::vector<Node> otherwise;
  };

  struct Parser;

  std::vector<Node> parse() const;
  void render_nodes(const std::vector<Node> &nodes, std::string &out,
                    std::vector<std::pair<std::string, Value>> &bindings) const;
  Value evaluate(const Node &node, const std::vector<std::pair<std::string, Value>> &bindings) const;

  std::string source_;
  std::string path_;
};

}  // namespace sadame
