#pragma once

#include <string>
#include <utility>
#include <vector>

namespace sadame {

// The dynamic value recipes, vars, facts and reports are made of. Maps keep
// the order their keys were added in, which decides the order of output.
// Keys are plain strings: Scheme symbols and keywords arrive with their
// dashes turned into underscores (see Value::normalize_key).
class Value {
 public:
  enum class Kind { Nil, Bool, Int, Float, String, Symbol, Array, Map };

  Value() = default;
  Value(bool value) : kind_(Kind::Bool), bool_(value) {}
  Value(int value) : kind_(Kind::Int), int_(value) {}
  Value(long long value) : kind_(Kind::Int), int_(value) {}
  Value(std::size_t value) : kind_(Kind::Int), int_(static_cast<long long>(value)) {}
  Value(double value) : kind_(Kind::Float), float_(value) {}
  Value(const char *value) : kind_(Kind::String), string_(value) {}
  Value(std::string value) : kind_(Kind::String), string_(std::move(value)) {}

  static Value symbol(std::string name);
  static Value array(std::vector<Value> items = {});
  static Value map();

  // "not-if" and "not_if" are the same key.
  static std::string normalize_key(const std::string &key);

  Kind kind() const { return kind_; }
  bool is_nil() const { return kind_ == Kind::Nil; }
  bool is_bool() const { return kind_ == Kind::Bool; }
  bool is_int() const { return kind_ == Kind::Int; }
  bool is_float() const { return kind_ == Kind::Float; }
  bool is_string() const { return kind_ == Kind::String; }
  bool is_symbol() const { return kind_ == Kind::Symbol; }
  bool is_array() const { return kind_ == Kind::Array; }
  bool is_map() const { return kind_ == Kind::Map; }
  // A String or a Symbol: the two ways a recipe names things.
  bool is_text() const { return is_string() || is_symbol(); }
  // Scheme cannot tell an empty list from an empty map.
  bool is_map_like() const { return is_map() || (is_array() && array_.empty()); }
  bool is_true() const { return kind_ == Kind::Bool && bool_; }
  bool is_false() const { return kind_ == Kind::Bool && !bool_; }

  bool boolean() const { return bool_; }
  long long integer() const { return int_; }
  double real() const { return float_; }
  const std::string &text() const { return string_; }
  const std::vector<Value> &items() const { return array_; }
  std::vector<Value> &items() { return array_; }

  // Map access. get returns nil for a missing key.
  bool has(const std::string &key) const;
  const Value &get(const std::string &key) const;
  Value &set(const std::string &key, Value value);
  void erase(const std::string &key);
  const std::vector<std::string> &keys() const { return keys_; }
  const std::vector<Value> &values() const { return values_; }
  std::size_t size() const;
  bool empty() const { return size() == 0; }

  void push(Value item) { array_.push_back(std::move(item)); }

  // Ruby's to_s: nil is "", symbols and strings are their text.
  std::string to_s() const;
  // A short name for error messages: "a String", "an Integer", ...
  std::string type_name() const;
  // The value as Scheme would write it, for messages.
  std::string inspect() const;

  bool operator==(const Value &other) const;
  bool operator!=(const Value &other) const { return !(*this == other); }

 private:
  Kind kind_ = Kind::Nil;
  bool bool_ = false;
  long long int_ = 0;
  double float_ = 0.0;
  std::string string_;
  std::vector<Value> array_;
  std::vector<std::string> keys_;
  std::vector<Value> values_;
};

using Map = Value;

std::string format_float(double value);

}  // namespace sadame
