#include "json_writer.hpp"

#include <cstdio>
#include <cstdlib>

#include "errors.hpp"

namespace sadame {
namespace JsonWriter {

namespace {

const char *kIndent = "  ";

std::string indentation(int depth) {
  std::string result;
  for (int index = 0; index < depth; ++index) result += kIndent;
  return result;
}

std::string write(const Value &value, int depth);

std::string write_object(const Value &hash, int depth) {
  if (hash.empty()) return "{}";
  std::string inner = indentation(depth + 1);
  std::string result = "{\n";
  for (std::size_t index = 0; index < hash.keys().size(); ++index) {
    if (index > 0) result += ",\n";
    result += inner + write_string(hash.keys()[index]) + ": " + write(hash.values()[index], depth + 1);
  }
  return result + "\n" + indentation(depth) + "}";
}

std::string write_array(const Value &array, int depth) {
  if (array.items().empty()) return "[]";
  std::string inner = indentation(depth + 1);
  std::string result = "[\n";
  for (std::size_t index = 0; index < array.items().size(); ++index) {
    if (index > 0) result += ",\n";
    result += inner + write(array.items()[index], depth + 1);
  }
  return result + "\n" + indentation(depth) + "]";
}

std::string write(const Value &value, int depth) {
  switch (value.kind()) {
    case Value::Kind::Map: return write_object(value, depth);
    case Value::Kind::Array: return write_array(value, depth);
    case Value::Kind::String:
    case Value::Kind::Symbol: return write_string(value.text());
    case Value::Kind::Int:
    case Value::Kind::Float: return value.to_s();
    case Value::Kind::Bool: return value.boolean() ? "true" : "false";
    default: return "null";
  }
}

}  // namespace

std::string write_string(const std::string &text) {
  std::string result = "\"";
  for (char character : text) {
    switch (character) {
      case '"': result += "\\\""; break;
      case '\\': result += "\\\\"; break;
      case '\n': result += "\\n"; break;
      case '\r': result += "\\r"; break;
      case '\t': result += "\\t"; break;
      case '\b': result += "\\b"; break;
      case '\f': result += "\\f"; break;
      default:
        if (static_cast<unsigned char>(character) < 0x20) {
          char buffer[8];
          std::snprintf(buffer, sizeof buffer, "\\u%04x", static_cast<unsigned char>(character));
          result += buffer;
        } else {
          result += character;
        }
    }
  }
  return result + "\"";
}

std::string generate(const Value &value) { return write(value, 0) + "\n"; }

}  // namespace JsonWriter

namespace JsonParser {

namespace {

class Reader {
 public:
  explicit Reader(const std::string &text) : text_(text) {}

  Value document() {
    Value value = parse_value();
    skip_space();
    if (position_ < text_.size()) fail("unexpected text after the value");
    return value;
  }

 private:
  [[noreturn]] void fail(const std::string &what) const {
    throw Error("invalid JSON at character " + std::to_string(position_ + 1) + ": " + what);
  }

  void skip_space() {
    while (position_ < text_.size() &&
           (text_[position_] == ' ' || text_[position_] == '\n' || text_[position_] == '\t' || text_[position_] == '\r')) {
      ++position_;
    }
  }

  bool consume(const char *word) {
    std::size_t length = std::char_traits<char>::length(word);
    if (text_.compare(position_, length, word) != 0) return false;
    position_ += length;
    return true;
  }

  Value parse_value() {
    skip_space();
    if (position_ >= text_.size()) fail("unexpected end of text");
    char character = text_[position_];
    if (character == '{') return parse_object();
    if (character == '[') return parse_array();
    if (character == '"') return Value(parse_string());
    if (consume("true")) return Value(true);
    if (consume("false")) return Value(false);
    if (consume("null")) return Value();
    return parse_number();
  }

  Value parse_object() {
    ++position_;
    Value result = Value::map();
    skip_space();
    if (position_ < text_.size() && text_[position_] == '}') {
      ++position_;
      return result;
    }
    while (true) {
      skip_space();
      if (position_ >= text_.size() || text_[position_] != '"') fail("expected a string key");
      std::string key = parse_string();
      skip_space();
      if (position_ >= text_.size() || text_[position_] != ':') fail("expected ':'");
      ++position_;
      result.set(key, parse_value());
      skip_space();
      if (position_ < text_.size() && text_[position_] == ',') {
        ++position_;
        continue;
      }
      if (position_ < text_.size() && text_[position_] == '}') {
        ++position_;
        return result;
      }
      fail("expected ',' or '}'");
    }
  }

  Value parse_array() {
    ++position_;
    Value result = Value::array();
    skip_space();
    if (position_ < text_.size() && text_[position_] == ']') {
      ++position_;
      return result;
    }
    while (true) {
      result.push(parse_value());
      skip_space();
      if (position_ < text_.size() && text_[position_] == ',') {
        ++position_;
        continue;
      }
      if (position_ < text_.size() && text_[position_] == ']') {
        ++position_;
        return result;
      }
      fail("expected ',' or ']'");
    }
  }

  static void append_utf8(std::string &out, unsigned code) {
    if (code < 0x80) {
      out += static_cast<char>(code);
    } else if (code < 0x800) {
      out += static_cast<char>(0xC0 | (code >> 6));
      out += static_cast<char>(0x80 | (code & 0x3F));
    } else if (code < 0x10000) {
      out += static_cast<char>(0xE0 | (code >> 12));
      out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
      out += static_cast<char>(0x80 | (code & 0x3F));
    } else {
      out += static_cast<char>(0xF0 | (code >> 18));
      out += static_cast<char>(0x80 | ((code >> 12) & 0x3F));
      out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
      out += static_cast<char>(0x80 | (code & 0x3F));
    }
  }

  unsigned parse_hex4() {
    if (position_ + 4 > text_.size()) fail("short \\u escape");
    unsigned code = 0;
    for (int index = 0; index < 4; ++index) {
      char digit = text_[position_++];
      code <<= 4;
      if (digit >= '0' && digit <= '9') code |= static_cast<unsigned>(digit - '0');
      else if (digit >= 'a' && digit <= 'f') code |= static_cast<unsigned>(digit - 'a' + 10);
      else if (digit >= 'A' && digit <= 'F') code |= static_cast<unsigned>(digit - 'A' + 10);
      else fail("bad \\u escape");
    }
    return code;
  }

  std::string parse_string() {
    ++position_;
    std::string result;
    while (position_ < text_.size()) {
      char character = text_[position_++];
      if (character == '"') return result;
      if (character != '\\') {
        result += character;
        continue;
      }
      if (position_ >= text_.size()) break;
      char escape = text_[position_++];
      switch (escape) {
        case 'n': result += '\n'; break;
        case 't': result += '\t'; break;
        case 'r': result += '\r'; break;
        case 'b': result += '\b'; break;
        case 'f': result += '\f'; break;
        case 'u': {
          unsigned code = parse_hex4();
          if (code >= 0xD800 && code < 0xDC00 && text_.compare(position_, 2, "\\u") == 0) {
            position_ += 2;
            unsigned low = parse_hex4();
            code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
          }
          append_utf8(result, code);
          break;
        }
        default: result += escape;
      }
    }
    fail("unterminated string");
  }

  Value parse_number() {
    std::size_t start = position_;
    if (position_ < text_.size() && text_[position_] == '-') ++position_;
    bool is_float = false;
    while (position_ < text_.size()) {
      char character = text_[position_];
      if (character >= '0' && character <= '9') {
        ++position_;
      } else if (character == '.' || character == 'e' || character == 'E' || character == '+' || character == '-') {
        is_float = true;
        ++position_;
      } else {
        break;
      }
    }
    std::string number = text_.substr(start, position_ - start);
    if (number.empty() || number == "-") fail("unexpected character");
    if (is_float) return Value(std::strtod(number.c_str(), nullptr));
    return Value(static_cast<long long>(std::strtoll(number.c_str(), nullptr, 10)));
  }

  const std::string &text_;
  std::size_t position_ = 0;
};

}  // namespace

Value parse(const std::string &text) { return Reader(text).document(); }

}  // namespace JsonParser
}  // namespace sadame
