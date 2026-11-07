#include "selection.hpp"

#include <algorithm>

#include "resource.hpp"

namespace sadame {

namespace {

bool intersects(const std::vector<std::string> &left, const std::vector<std::string> &right) {
  for (const std::string &item : left) {
    if (std::find(right.begin(), right.end(), item) != right.end()) return true;
  }
  return false;
}

std::string join(const std::vector<std::string> &items, const std::string &separator) {
  std::string result;
  for (std::size_t index = 0; index < items.size(); ++index) {
    if (index > 0) result += separator;
    result += items[index];
  }
  return result;
}

}  // namespace

bool Selection::includes(const Resource &resource) const {
  if (intersects(resource.tags(), skip_tags_)) return false;
  return tags_.empty() || intersects(resource.tags(), tags_);
}

std::string Selection::description(std::size_t selected, std::size_t total) const {
  std::vector<std::string> parts;
  if (!tags_.empty()) parts.push_back("tagged " + join(tags_, ", "));
  if (!skip_tags_.empty()) parts.push_back("not tagged " + join(skip_tags_, ", "));
  return "Only resources " + join(parts, " and ") + ": " + std::to_string(selected) + " of " + std::to_string(total) + ".";
}

}  // namespace sadame
