#pragma once

#include <string>
#include <vector>

namespace sadame {

class Resource;

// Which resources a run works on, from --tags and --skip-tags:
//
//   sadame apply site.scm --tags nginx    only resources tagged nginx
//   sadame apply site.scm --skip-tags slow  everything not tagged slow
//
// Resources outside the selection are not read or changed and are left out
// of the report, but notifications can still act on them.
class Selection {
 public:
  Selection() = default;
  Selection(std::vector<std::string> tags, std::vector<std::string> skip_tags)
      : tags_(std::move(tags)), skip_tags_(std::move(skip_tags)) {}

  const std::vector<std::string> &tags() const { return tags_; }
  const std::vector<std::string> &skip_tags() const { return skip_tags_; }

  bool all() const { return tags_.empty() && skip_tags_.empty(); }
  bool includes(const Resource &resource) const;

  // "Only resources tagged nginx: 3 of 12."
  std::string description(std::size_t selected, std::size_t total) const;

 private:
  std::vector<std::string> tags_;
  std::vector<std::string> skip_tags_;
};

}  // namespace sadame
