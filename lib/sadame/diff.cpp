#include "diff.hpp"

#include <algorithm>

namespace sadame {
namespace Diff {

namespace {

enum class Type { Equal, Delete, Insert };

struct Operation {
  Type type;
  std::string line;
  int old_position = 0;
  int new_position = 0;
};

using Frontier = std::vector<int>;

// Myers' O(ND) diff algorithm.
int next_x(const Frontier &frontier, int k, int distance, int offset) {
  if (k == -distance || (k != distance && frontier[k - 1 + offset] < frontier[k + 1 + offset])) {
    return frontier[k + 1 + offset];
  }
  return frontier[k - 1 + offset] + 1;
}

std::vector<Frontier> shortest_edit_trace(const std::vector<std::string> &old_lines,
                                          const std::vector<std::string> &new_lines) {
  int old_size = static_cast<int>(old_lines.size());
  int new_size = static_cast<int>(new_lines.size());
  int max = old_size + new_size;
  int offset = max;
  Frontier frontier(static_cast<std::size_t>(2 * max + 2), 0);
  std::vector<Frontier> trace;

  for (int distance = 0; distance <= max; ++distance) {
    trace.push_back(frontier);
    for (int k = -distance; k <= distance; k += 2) {
      int x = next_x(frontier, k, distance, offset);
      int y = x - k;
      while (x < old_size && y < new_size && old_lines[static_cast<std::size_t>(x)] == new_lines[static_cast<std::size_t>(y)]) {
        ++x;
        ++y;
      }
      frontier[static_cast<std::size_t>(k + offset)] = x;
      if (x >= old_size && y >= new_size) return trace;
    }
  }
  return trace;
}

std::vector<Operation> backtrack(const std::vector<Frontier> &trace, const std::vector<std::string> &old_lines,
                                 const std::vector<std::string> &new_lines) {
  int offset = static_cast<int>(old_lines.size() + new_lines.size());
  int x = static_cast<int>(old_lines.size());
  int y = static_cast<int>(new_lines.size());
  std::vector<Operation> reversed;

  for (int distance = static_cast<int>(trace.size()) - 1; distance >= 0; --distance) {
    const Frontier &frontier = trace[static_cast<std::size_t>(distance)];
    int k = x - y;
    int previous_k;
    if (k == -distance || (k != distance && frontier[static_cast<std::size_t>(k - 1 + offset)] <
                                                frontier[static_cast<std::size_t>(k + 1 + offset)])) {
      previous_k = k + 1;
    } else {
      previous_k = k - 1;
    }
    int previous_x = frontier[static_cast<std::size_t>(previous_k + offset)];
    int previous_y = previous_x - previous_k;

    while (x > previous_x && y > previous_y) {
      reversed.push_back({Type::Equal, old_lines[static_cast<std::size_t>(x - 1)]});
      --x;
      --y;
    }
    if (distance == 0) continue;

    if (x == previous_x) {
      reversed.push_back({Type::Insert, new_lines[static_cast<std::size_t>(y - 1)]});
    } else {
      reversed.push_back({Type::Delete, old_lines[static_cast<std::size_t>(x - 1)]});
    }
    x = previous_x;
    y = previous_y;
  }
  std::reverse(reversed.begin(), reversed.end());
  return reversed;
}

std::vector<Operation> edit_script(const std::vector<std::string> &old_lines, const std::vector<std::string> &new_lines) {
  std::vector<Operation> operations = backtrack(shortest_edit_trace(old_lines, new_lines), old_lines, new_lines);
  int old_position = 0;
  int new_position = 0;
  for (Operation &operation : operations) {
    operation.old_position = old_position;
    operation.new_position = new_position;
    if (operation.type != Type::Insert) ++old_position;
    if (operation.type != Type::Delete) ++new_position;
  }
  return operations;
}

// Groups changed operations into hunks of [first_index, last_index], each
// padded with context lines and merged when they overlap.
std::vector<std::pair<int, int>> group_hunks(const std::vector<Operation> &operations, int context) {
  std::vector<std::pair<int, int>> hunks;
  int size = static_cast<int>(operations.size());
  for (int index = 0; index < size; ++index) {
    if (operations[static_cast<std::size_t>(index)].type == Type::Equal) continue;
    int first = std::max(index - context, 0);
    int last = std::min(index + context, size - 1);
    if (hunks.empty() || first > hunks.back().second + 1) {
      hunks.push_back({first, last});
    } else {
      hunks.back().second = last;
    }
  }
  return hunks;
}

std::string hunk_range(int start, int count) {
  return count == 1 ? std::to_string(start) : std::to_string(start) + "," + std::to_string(count);
}

std::string format_hunk(const std::vector<Operation> &operations, const std::pair<int, int> &hunk) {
  int old_count = 0;
  int new_count = 0;
  for (int index = hunk.first; index <= hunk.second; ++index) {
    Type type = operations[static_cast<std::size_t>(index)].type;
    if (type != Type::Insert) ++old_count;
    if (type != Type::Delete) ++new_count;
  }
  const Operation &first = operations[static_cast<std::size_t>(hunk.first)];
  int old_start = first.old_position + (old_count == 0 ? 0 : 1);
  int new_start = first.new_position + (new_count == 0 ? 0 : 1);

  std::string output = "@@ -" + hunk_range(old_start, old_count) + " +" + hunk_range(new_start, new_count) + " @@\n";
  for (int index = hunk.first; index <= hunk.second; ++index) {
    const Operation &operation = operations[static_cast<std::size_t>(index)];
    output += operation.type == Type::Delete ? "-" : operation.type == Type::Insert ? "+" : " ";
    output += operation.line;
    if (operation.line.empty() || operation.line.back() != '\n') output += "\n\\ No newline at end of file\n";
  }
  return output;
}

}  // namespace

std::vector<Change> changes(const Value &desired, const Value &current) {
  std::vector<Change> result;
  for (std::size_t index = 0; index < desired.keys().size(); ++index) {
    const std::string &attribute = desired.keys()[index];
    const Value &value = desired.values()[index];
    if (value != current.get(attribute)) result.push_back({attribute, current.get(attribute), value, std::nullopt});
  }
  return result;
}

std::vector<std::string> split_lines(const std::string &text) {
  std::vector<std::string> lines;
  std::size_t start = 0;
  std::size_t index;
  while ((index = text.find('\n', start)) != std::string::npos) {
    lines.push_back(text.substr(start, index - start + 1));
    start = index + 1;
  }
  if (start < text.size()) lines.push_back(text.substr(start));
  return lines;
}

std::string unified(const std::string &old_text, const std::string &new_text, const std::string &old_label,
                    const std::string &new_label, int context) {
  std::vector<Operation> operations = edit_script(split_lines(old_text), split_lines(new_text));
  auto hunks = group_hunks(operations, context);
  if (hunks.empty()) return "";

  std::string output = "--- " + old_label + "\n+++ " + new_label + "\n";
  for (const auto &hunk : hunks) output += format_hunk(operations, hunk);
  return output;
}

}  // namespace Diff
}  // namespace sadame
