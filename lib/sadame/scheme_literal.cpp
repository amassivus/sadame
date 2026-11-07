#include "scheme_literal.hpp"

#include <cstdio>

namespace sadame {
namespace SchemeLiteral {

namespace {

std::string dump_string(const std::string &text) {
  std::string result = "\"";
  for (char character : text) {
    unsigned char code = static_cast<unsigned char>(character);
    switch (character) {
      case '\\': result += "\\\\"; break;
      case '"': result += "\\\""; break;
      case '\n': result += "\\n"; break;
      case '\r': result += "\\r"; break;
      case '\t': result += "\\t"; break;
      default:
        if (code < 0x20 || code == 0x7f) {
          char buffer[8];
          std::snprintf(buffer, sizeof buffer, "\\x%02x;", code);
          result += buffer;
        } else {
          result += character;
        }
    }
  }
  return result + "\"";
}

std::string dump_symbol(const std::string &name) {
  if (!name.empty() &&
      name.find_first_of(" \t\n()\"';`,|#") == std::string::npos) {
    return name;
  }
  return "|" + name + "|";
}

// quoted is true inside a quoted list, where symbols and lists need no
// quote of their own.
std::string write(const Value &value, bool quoted) {
  switch (value.kind()) {
    case Value::Kind::Map: {
      if (value.empty()) return quoted ? "()" : "'()";
      std::string result = quoted ? "(" : "'(";
      for (std::size_t index = 0; index < value.keys().size(); ++index) {
        if (index > 0) result += " ";
        result += "(" + dump_symbol(value.keys()[index]) + " . " + write(value.values()[index], true) + ")";
      }
      return result + ")";
    }
    case Value::Kind::Array: {
      if (value.items().empty()) return quoted ? "()" : "'()";
      std::string result = quoted ? "(" : "'(";
      for (std::size_t index = 0; index < value.items().size(); ++index) {
        if (index > 0) result += " ";
        result += write(value.items()[index], true);
      }
      return result + ")";
    }
    case Value::Kind::String: return dump_string(value.text());
    case Value::Kind::Symbol: return (quoted ? "" : "'") + dump_symbol(value.text());
    case Value::Kind::Int:
    case Value::Kind::Float: return value.to_s();
    case Value::Kind::Bool: return value.boolean() ? "#t" : "#f";
    default: return "#f";
  }
}

}  // namespace

std::string dump(const Value &value) { return write(value, false); }

}  // namespace SchemeLiteral
}  // namespace sadame
