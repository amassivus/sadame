#pragma once

#include <string>
#include <utility>
#include <vector>

#include "value.hpp"

namespace sadame {

// Loads and merges the `vars` map that recipes and templates see. Keys are
// always normalized (see Value::normalize_key).
namespace Vars {

// vars.scm is plain Scheme whose last expression is an association list:
//
//   '((server-name . "example.com") (workers . 4))
//
// A missing file gives no vars.
Value load_file(const std::string &path);

// Parses one --var argument of the form key=value. Values stay strings,
// except "true", "false" and integers without leading zeros (so "0644"
// stays a string), which are converted.
std::pair<std::string, Value> parse_assignment(const std::string &text);

Value coerce(const std::string &value);
bool is_integer(const std::string &value);

// Merges layers given from lowest to highest precedence.
Value merge(const std::vector<Value> &layers);

// A layer of vars and the label shown for it by `sadame hosts`.
struct Layer {
  std::string label;
  Value values;
};

// Merges layers given from lowest to highest precedence. Returns the vars
// and, for each key, the label of the layer it came from.
std::pair<Value, Value> layered(const std::vector<Layer> &layers);

Value normalize_keys(const Value &hash);

}  // namespace Vars
}  // namespace sadame
