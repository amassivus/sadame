#pragma once

#include <optional>
#include <regex>

#include "../path_stat.hpp"
#include "../resource.hpp"

namespace sadame {

// Manages one line in a file that something else owns, such as a setting in
// a package's configuration file, and leaves the rest of the file alone.
//
//   (line "PermitRootLogin no" #:path "/etc/ssh/sshd_config"
//         #:match "^#?\\s*PermitRootLogin\\s")
//   (line "vm.swappiness = 10" #:path "/etc/sysctl.conf")
//   (line "old mirror" #:path "/etc/hosts" #:line "10.0.0.5 mirror.internal" #:state 'absent)
//
// The name is the line, unless #:line gives it. With #:match (a regular
// expression, as a string), every line that matches is replaced by the line;
// when none matches and the line is not in the file, it is appended. With
// #:state 'absent, the line and every line that matches #:match are removed.
//
// The file must exist by the time the change is applied. It keeps its mode
// and owner, and is replaced in one rename, as with the file resource;
// #:verify checks the new content first.
class LineResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "line"; }
  std::vector<std::string> allowed_options() const override {
    return {"path", "line", "match", "state", "verify", "sensitive"};
  }

  std::string text() const;
  std::string path() const { return opt("path").to_s(); }

  Value desired() override;
  Value current() override;
  // The whole file is compared, so plan shows the edit as a diff of the file.
  std::vector<Diff::Change> diff() override;
  void apply(const std::vector<Diff::Change> &changes) override;
  bool sensitive() const override { return opt("sensitive").is_true(); }
  std::string content_path() const override { return path(); }

 protected:
  void validate() override;

 private:
  std::optional<std::string> read_content();
  std::optional<PathStat> read_stat();
  std::string edit(const std::string &content) const;
  bool same(const std::string &line) const;
  bool matches(const std::string &line) const;

  std::optional<std::regex> pattern_;
};

}  // namespace sadame
