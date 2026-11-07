#include "value.hpp"

#include <cmath>
#include <cstdio>

namespace sadame {

namespace {
const Value kNil;
}

Value Value::symbol(std::string name) {
  Value value;
  value.kind_ = Kind::Symbol;
  value.string_ = std::move(name);
  return value;
}

Value Value::array(std::vector<Value> items) {
  Value value;
  value.kind_ = Kind::Array;
  value.array_ = std::move(items);
  return value;
}

Value Value::map() {
  Value value;
  value.kind_ = Kind::Map;
  return value;
}

std::string Value::normalize_key(const std::string &key) {
  std::string result = key;
  for (char &character : result) {
    if (character == '-') character = '_';
  }
  return result;
}

bool Value::has(const std::string &key) const {
  for (const std::string &existing : keys_) {
    if (existing == key) return true;
  }
  return false;
}

const Value &Value::get(const std::string &key) const {
  for (std::size_t index = 0; index < keys_.size(); ++index) {
    if (keys_[index] == key) return values_[index];
  }
  return kNil;
}

Value &Value::set(const std::string &key, Value value) {
  kind_ = Kind::Map;
  for (std::size_t index = 0; index < keys_.size(); ++index) {
    if (keys_[index] == key) {
      values_[index] = std::move(value);
      return values_[index];
    }
  }
  keys_.push_back(key);
  values_.push_back(std::move(value));
  return values_.back();
}

void Value::erase(const std::string &key) {
  for (std::size_t index = 0; index < keys_.size(); ++index) {
    if (keys_[index] == key) {
      keys_.erase(keys_.begin() + static_cast<long>(index));
      values_.erase(values_.begin() + static_cast<long>(index));
      return;
    }
  }
}

std::size_t Value::size() const {
  if (kind_ == Kind::Map) return keys_.size();
  if (kind_ == Kind::Array) return array_.size();
  return 0;
}

std::string format_float(double value) {
  if (std::isnan(value)) return "NaN";
  if (std::isinf(value)) return value < 0 ? "-Infinity" : "Infinity";
  char buffer[64];
  for (int precision = 1; precision <= 17; ++precision) {
    std::snprintf(buffer, sizeof buffer, "%.*g", precision, value);
    if (std::strtod(buffer, nullptr) == value) break;
  }
  std::string text = buffer;
  if (text.find_first_of(".en") == std::string::npos) text += ".0";
  return text;
}

std::string Value::to_s() const {
  switch (kind_) {
    case Kind::Nil: return "";
    case Kind::Bool: return bool_ ? "true" : "false";
    case Kind::Int: return std::to_string(int_);
    case Kind::Float: return format_float(float_);
    case Kind::String:
    case Kind::Symbol: return string_;
    default: return inspect();
  }
}

namespace {
std::string quote(const std::string &text) {
  std::string result = "\"";
  for (char character : text) {
    if (character == '"' || character == '\\') result += '\\';
    if (character == '\n') {
      result += "\\n";
    } else {
      result += character;
    }
  }
  return result + "\"";
}
}  // namespace

std::string Value::inspect() const {
  switch (kind_) {
    case Kind::Nil: return "nil";
    case Kind::String: return quote(string_);
    case Kind::Symbol: return "'" + string_;
    case Kind::Array: {
      std::string result = "(";
      for (std::size_t index = 0; index < array_.size(); ++index) {
        if (index > 0) result += " ";
        result += array_[index].inspect();
      }
      return result + ")";
    }
    case Kind::Map: {
      std::string result = "(";
      for (std::size_t index = 0; index < keys_.size(); ++index) {
        if (index > 0) result += " ";
        result += "(" + keys_[index] + " . " + values_[index].inspect() + ")";
      }
      return result + ")";
    }
    default: return to_s();
  }
}

std::string Value::type_name() const {
  switch (kind_) {
    case Kind::Nil: return "nil";
    case Kind::Bool: return bool_ ? "true" : "false";
    case Kind::Int: return "an Integer";
    case Kind::Float: return "a Float";
    case Kind::String: return "a String";
    case Kind::Symbol: return "a Symbol";
    case Kind::Array: return "an Array";
    default: return "a Hash";
  }
}

bool Value::operator==(const Value &other) const {
  if (kind_ != other.kind_) {
    // Strings and symbols with the same text are different in Ruby; a
    // Scheme recipe cannot always choose, so only numbers mix.
    if (is_int() && other.is_float()) return static_cast<double>(int_) == other.float_;
    if (is_float() && other.is_int()) return float_ == static_cast<double>(other.int_);
    return false;
  }
  switch (kind_) {
    case Kind::Nil: return true;
    case Kind::Bool: return bool_ == other.bool_;
    case Kind::Int: return int_ == other.int_;
    case Kind::Float: return float_ == other.float_;
    case Kind::String:
    case Kind::Symbol: return string_ == other.string_;
    case Kind::Array: return array_ == other.array_;
    case Kind::Map: {
      if (keys_.size() != other.keys_.size()) return false;
      for (std::size_t index = 0; index < keys_.size(); ++index) {
        if (!other.has(keys_[index]) || other.get(keys_[index]) != values_[index]) return false;
      }
      return true;
    }
  }
  return false;
}

}  // namespace sadame
