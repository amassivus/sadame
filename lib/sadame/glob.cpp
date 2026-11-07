#include "glob.hpp"

namespace sadame {
namespace Glob {

namespace {

// Backtracks on "*": tries to let it match zero characters first, then one
// more each time.
bool match_from(const std::string &pattern, std::size_t pattern_index, const std::string &text, std::size_t text_index) {
  while (pattern_index < pattern.size()) {
    char character = pattern[pattern_index];
    if (character == '*') {
      for (std::size_t start = text_index; start <= text.size(); ++start) {
        if (match_from(pattern, pattern_index + 1, text, start)) return true;
      }
      return false;
    }
    if (text_index >= text.size()) return false;
    if (character != '?' && character != text[text_index]) return false;
    ++pattern_index;
    ++text_index;
  }
  return text_index == text.size();
}

}  // namespace

bool match(const std::string &pattern, const std::string &text) { return match_from(pattern, 0, text, 0); }

}  // namespace Glob
}  // namespace sadame
