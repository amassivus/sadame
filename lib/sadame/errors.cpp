#include "errors.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <sstream>
#include <vector>

namespace sadame {

// How far from the reported line the misspelled option of the same call
// can be.
constexpr int kCallLines = 20;

std::string strip(const std::string &text) {
  std::size_t first = 0;
  std::size_t last = text.size();
  while (first < last && std::isspace(static_cast<unsigned char>(text[first]))) ++first;
  while (last > first && std::isspace(static_cast<unsigned char>(text[last - 1]))) --last;
  return text.substr(first, last - first);
}

std::string chomp(const std::string &text) {
  if (!text.empty() && text.back() == '\n') {
    std::string result = text.substr(0, text.size() - 1);
    if (!result.empty() && result.back() == '\r') result.pop_back();
    return result;
  }
  return text;
}

std::string CommandFailed::describe(const CommandResult &result) {
  std::string message = "command failed (exit " + std::to_string(result.exit_status) + "): " + result.command;
  std::string details = strip(result.stderr_text);
  if (details.empty()) details = strip(result.stdout_text);
  return details.empty() ? message : message + "\n" + details;
}

std::string error_class_name(const std::exception &error) {
  if (dynamic_cast<const CommandFailed *>(&error)) return "CommandFailed";
  if (dynamic_cast<const ResourceError *>(&error)) return "ResourceError";
  if (dynamic_cast<const RecipeError *>(&error)) return "RecipeError";
  if (dynamic_cast<const UsageError *>(&error)) return "UsageError";
  if (dynamic_cast<const Error *>(&error)) return "Error";
  return "StandardError";
}

std::string located_message(const std::string &message, const std::string &path, int line) {
  if (line <= 0) return path + ": " + message;
  return path + ":" + std::to_string(line) + ": " + message;
}

int option_line(const std::string &message, const std::string &source, int line) {
  const std::string marker = "unknown option #:";
  std::size_t at = message.find(marker);
  if (at == std::string::npos || source.empty()) return line;

  std::size_t end = at + marker.size();
  while (end < message.size() && (std::isalnum(static_cast<unsigned char>(message[end])) || message[end] == '_' ||
                                  message[end] == '-')) {
    ++end;
  }
  std::string needle = "#:" + message.substr(at + marker.size(), end - at - marker.size());
  std::string dashed = needle;
  std::string underscored = needle;
  std::replace(dashed.begin(), dashed.end(), '_', '-');
  std::replace(underscored.begin(), underscored.end(), '-', '_');

  std::vector<std::string> lines;
  std::istringstream stream(source);
  std::string text;
  while (std::getline(stream, text)) lines.push_back(text);

  int reported = line - 1;
  int first = std::max(0, reported - kCallLines);
  int last = std::min(static_cast<int>(lines.size()) - 1, reported + kCallLines);
  int best = -1;
  for (int index = first; index <= last; ++index) {
    const std::string &candidate = lines[static_cast<std::size_t>(index)];
    if (candidate.find(dashed) == std::string::npos && candidate.find(underscored) == std::string::npos) continue;
    if (best < 0 || std::abs(index - reported) < std::abs(best - reported)) best = index;
  }
  return best < 0 ? line : best + 1;
}

}  // namespace sadame
