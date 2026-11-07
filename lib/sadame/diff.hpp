#pragma once

#include <optional>
#include <string>
#include <vector>

#include "value.hpp"

namespace sadame {

// Differences between the desired and the current state of a resource.
namespace Diff {

// One attribute that differs. For content changes, from and to hold the
// full text; output turns them into a unified diff.
struct Change {
  std::string attribute;
  Value from;
  Value to;
  std::optional<std::string> reason;

  bool content() const { return attribute == "content"; }
};

// Compares the attributes present in desired with the same keys in current.
std::vector<Change> changes(const Value &desired, const Value &current);

// Returns a unified diff between two texts, or "" when they are equal.
std::string unified(const std::string &old_text, const std::string &new_text, const std::string &old_label,
                    const std::string &new_label, int context = 3);

// Splits text into lines that keep their trailing newline, so a missing
// newline at the end of a file shows up as a difference.
std::vector<std::string> split_lines(const std::string &text);

}  // namespace Diff
}  // namespace sadame
