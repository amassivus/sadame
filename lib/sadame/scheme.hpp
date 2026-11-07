#pragma once

#include <functional>
#include <string>
#include <utility>
#include <vector>

#include "value.hpp"

namespace sadame {

// The bridge to Guile Scheme. Recipes, hosts.scm, vars.scm and template
// expressions are Scheme; everything they call lives in C++.
namespace scheme {

// Runs body in Guile mode, which every other function here needs: Guile
// must know the thread it is used from. Starts the bridge on first use.
int with_guile(const std::function<int()> &body);

// Evaluates the text of a Scheme file as one of the languages "recipe",
// "inventory" or "vars" and returns the value of its last form. Throws
// RecipeError, with the file and line, when it fails.
Value evaluate_file(const std::string &kind, const std::string &path, const std::string &source);

struct ExpressionResult {
  bool ok = false;
  Value value;
  std::string kind;
  std::string message;
};

// Evaluates one template expression. bindings are the variables of the
// enclosing ~(each) loops.
ExpressionResult evaluate_expression(const std::string &expression,
                                     const std::vector<std::pair<std::string, Value>> &bindings);

}  // namespace scheme
}  // namespace sadame
