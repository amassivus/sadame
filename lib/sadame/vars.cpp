#include "vars.hpp"

#include <sys/stat.h>

#include "errors.hpp"
#include "scheme.hpp"
#include "shell.hpp"

namespace sadame {
namespace Vars {

Value load_file(const std::string &path) {
  struct stat info;
  if (::stat(path.c_str(), &info) != 0) return Value::map();

  Shell shell;
  std::string source = shell.read_file(path).value_or("");
  Value value = scheme::evaluate_file("vars", path, source);
  if (!value.is_map_like()) {
    throw RecipeError(path + " must evaluate to an association list, got " + value.type_name());
  }
  return normalize_keys(value);
}

bool is_integer(const std::string &value) {
  std::string digits = !value.empty() && value[0] == '-' ? value.substr(1) : value;
  if (digits.empty() || (digits.size() > 1 && digits[0] == '0')) return false;
  return digits.find_first_not_of("0123456789") == std::string::npos;
}

Value coerce(const std::string &value) {
  if (value == "true") return Value(true);
  if (value == "false") return Value(false);
  if (is_integer(value)) return Value(static_cast<long long>(std::stoll(value)));
  return Value(value);
}

std::pair<std::string, Value> parse_assignment(const std::string &text) {
  std::size_t equals = text.find('=');
  if (equals == std::string::npos || equals == 0) {
    throw UsageError("--var expects key=value, got \"" + text + "\"");
  }
  return {Value::normalize_key(text.substr(0, equals)), coerce(text.substr(equals + 1))};
}

Value normalize_keys(const Value &hash) {
  Value result = Value::map();
  for (std::size_t index = 0; index < hash.keys().size(); ++index) {
    result.set(Value::normalize_key(hash.keys()[index]), hash.values()[index]);
  }
  return result;
}

Value merge(const std::vector<Value> &layers) {
  Value result = Value::map();
  for (const Value &layer : layers) {
    Value normalized = normalize_keys(layer);
    for (std::size_t index = 0; index < normalized.keys().size(); ++index) {
      result.set(normalized.keys()[index], normalized.values()[index]);
    }
  }
  return result;
}

std::pair<Value, Value> layered(const std::vector<Layer> &layers) {
  Value vars = Value::map();
  Value sources = Value::map();
  for (const Layer &layer : layers) {
    Value normalized = normalize_keys(layer.values);
    for (std::size_t index = 0; index < normalized.keys().size(); ++index) {
      vars.set(normalized.keys()[index], normalized.values()[index]);
      sources.set(normalized.keys()[index], Value(layer.label));
    }
  }
  return {vars, sources};
}

}  // namespace Vars
}  // namespace sadame
