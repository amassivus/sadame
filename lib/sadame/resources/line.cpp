#include "line.hpp"

namespace sadame {

std::string LineResource::text() const { return has("line") ? opt("line").to_s() : name(); }

Value LineResource::desired() {
  Value result = Value::map();
  result.set("content", edit(read_content().value_or("")));
  return result;
}

Value LineResource::current() {
  Value result = Value::map();
  auto content = read_content();
  result.set("content", content ? Value(*content) : Value());
  return result;
}

std::vector<Diff::Change> LineResource::diff() {
  auto content = read_content();
  if (!content) {
    if (absent()) return {};
    return {Diff::Change{"content", Value(), Value(edit("")), path() + " does not exist yet"}};
  }
  std::string edited = edit(*content);
  if (edited == *content) return {};
  return {Diff::Change{"content", Value(*content), Value(edited), std::nullopt}};
}

void LineResource::apply(const std::vector<Diff::Change> &changes) {
  auto stat = read_stat();
  if (!stat) {
    throw ResourceError(id() + ": " + path() + " does not exist; line only edits existing files " +
                        "(create it with a file resource, or install the package that ships it, first)");
  }

  replace_file(path(), changes.front().to.to_s(), stat->mode(), stat->owner(), stat->group(),
               given("verify") ? text_opt("verify") : std::nullopt);
}

void LineResource::validate() {
  validate_choice("state", {"present", "absent"});
  validate_boolean("sensitive");
  validate_verify();

  const Value &file = opt("path");
  if (!(file.is_string() && file.text().rfind("/", 0) == 0)) {
    throw ResourceError(id() + ": path must be the absolute path of the file to edit, " +
                        "such as #:path \"/etc/ssh/sshd_config\"");
  }

  const Value &value = has("line") ? opt("line") : Value(name());
  if (!(value.is_string() && !value.text().empty())) throw ResourceError(id() + ": line must be a non-empty string");
  if (value.text().find('\n') != std::string::npos) throw ResourceError(id() + ": line must be a single line, without \"\\n\"");

  const Value &pattern = opt("match");
  if (pattern.is_nil()) return;
  if (!pattern.is_string()) {
    throw ResourceError(id() + ": match must be a regular expression given as a string, such as \"^#?Port \"");
  }
  try {
    pattern_ = std::regex(pattern.text(), std::regex::ECMAScript);
  } catch (const std::regex_error &error) {
    throw ResourceError(id() + ": match is not a valid regular expression: " + error.what());
  }
}

// The file's content, or nothing when it does not exist.
std::optional<std::string> LineResource::read_content() {
  if (!read_stat()) return std::nullopt;
  return shell().read_file(path());
}

std::optional<PathStat> LineResource::read_stat() {
  auto stat = PathStat::read(shell(), path(), host().platform());
  if (!stat || stat->file()) return stat;
  throw ResourceError(id() + ": " + path() + " is a " + stat->type_label() + ", not a regular file");
}

bool LineResource::same(const std::string &line) const { return chomp(line) == text(); }

bool LineResource::matches(const std::string &line) const {
  return pattern_ && std::regex_search(chomp(line), *pattern_);
}

// The content with this resource's edit made.
std::string LineResource::edit(const std::string &content) const {
  std::vector<std::string> lines = Diff::split_lines(content);
  std::string result;

  if (absent()) {
    for (const std::string &line : lines) {
      if (!same(line) && !matches(line)) result += line;
    }
    return result;
  }

  bool replaced = false;
  bool present = false;
  for (const std::string &line : lines) {
    if (!matches(line)) {
      result += line;
      present = present || same(line);
      continue;
    }
    replaced = true;
    result += !line.empty() && line.back() == '\n' ? text() + "\n" : text();
  }
  if (replaced || present) return result;

  if (content.empty() || content.back() == '\n') return content + text() + "\n";
  return content + "\n" + text() + "\n";
}

}  // namespace sadame
