#pragma once

// A tiny test framework: TEST() cases, EXPECT_* checks, and the runner in
// test_main.cpp that executes them.

#include <exception>
#include <functional>
#include <optional>
#include <string>
#include <type_traits>
#include <vector>

#include "../../lib/sadame/value.hpp"

namespace test {

struct Failure : std::exception {
  explicit Failure(std::string text) : text(std::move(text)) {}
  const char *what() const noexcept override { return text.c_str(); }
  std::string text;
};

struct Case {
  std::string suite;
  std::string name;
  std::function<void()> body;
};

inline std::vector<Case> &registry() {
  static std::vector<Case> cases;
  return cases;
}

struct Registrar {
  Registrar(const char *suite, const char *name, std::function<void()> body) {
    registry().push_back({suite, name, std::move(body)});
  }
};

// How values appear in failure messages.
inline std::string show(const std::string &value) { return "\"" + value + "\""; }
inline std::string show(const char *value) { return show(std::string(value)); }
inline std::string show(bool value) { return value ? "true" : "false"; }
inline std::string show(const sadame::Value &value) { return value.inspect(); }
template <typename T, typename = std::enable_if_t<std::is_arithmetic<T>::value && !std::is_same<T, bool>::value>>
std::string show(T value) {
  return std::to_string(value);
}
template <typename T>
std::string show(const std::vector<T> &items) {
  std::string result = "[";
  for (std::size_t index = 0; index < items.size(); ++index) result += (index ? ", " : "") + show(items[index]);
  return result + "]";
}
template <typename T>
std::string show(const std::optional<T> &value) {
  return value ? show(*value) : "nullopt";
}

inline std::string where(const char *file, int line) { return std::string(file) + ":" + std::to_string(line) + ": "; }

template <typename A, typename B>
void expect_equal(const A &expected, const B &actual, const char *file, int line) {
  if (!(expected == actual)) {
    throw Failure(where(file, line) + "expected " + show(expected) + "\n  but got  " + show(actual));
  }
}

inline void expect_contains(const std::string &text, const std::string &part, const char *file, int line) {
  if (text.find(part) == std::string::npos) {
    throw Failure(where(file, line) + "expected " + show(text) + "\n  to include " + show(part));
  }
}

inline void expect_not_contains(const std::string &text, const std::string &part, const char *file, int line) {
  if (text.find(part) != std::string::npos) {
    throw Failure(where(file, line) + "expected " + show(text) + "\n  not to include " + show(part));
  }
}

}  // namespace test

#define TEST(suite, name)                                                                   \
  static void test_##suite##_##name();                                                      \
  static test::Registrar registrar_##suite##_##name(#suite, #name, test_##suite##_##name);  \
  static void test_##suite##_##name()

#define EXPECT_TRUE(condition)                                                                   \
  do {                                                                                           \
    if (!(condition)) throw test::Failure(test::where(__FILE__, __LINE__) + "expected " #condition); \
  } while (0)
#define EXPECT_FALSE(condition) EXPECT_TRUE(!(condition))
#define EXPECT_EQ(expected, actual) test::expect_equal((expected), (actual), __FILE__, __LINE__)
#define EXPECT_CONTAINS(text, part) test::expect_contains((text), (part), __FILE__, __LINE__)
#define EXPECT_NOT_CONTAINS(text, part) test::expect_not_contains((text), (part), __FILE__, __LINE__)
#define EXPECT_EMPTY(collection) EXPECT_TRUE((collection).empty())

// Passes when expression throws ErrorType with a message that includes part.
#define EXPECT_THROWS(ErrorType, expression, part)                                                        \
  do {                                                                                                    \
    bool thrown_ = false;                                                                                 \
    try {                                                                                                 \
      expression;                                                                                         \
    } catch (const ErrorType &error_) {                                                                   \
      thrown_ = true;                                                                                     \
      test::expect_contains(error_.what(), (part), __FILE__, __LINE__);                                   \
    }                                                                                                     \
    if (!thrown_) throw test::Failure(test::where(__FILE__, __LINE__) + "expected " #ErrorType " from " #expression); \
  } while (0)
