#pragma once

#include <optional>

#include "../path_stat.hpp"
#include "../resource.hpp"

namespace sadame {

// Manages a regular file: its content, permission bits and ownership.
//
//   (file "/etc/motd" #:content "Welcome\n")
//   (file "/etc/nginx/nginx.conf" #:template "nginx.conf.tmpl" #:mode "0644")
//   (file "/usr/local/bin/backup" #:source "backup.sh" #:mode "0755")
//   (file "/etc/old.conf" #:state 'absent)
//
// New content is written to a temporary file next to the target, given its
// final mode and owner, then renamed over the target, so readers never see a
// half-written file. With #:verify, a command checks the temporary file first
// and a failure leaves the target untouched:
//
//   (file "/etc/sudoers.d/deploy" #:content "..." #:verify "visudo -cf %{path}")
class FileResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "file"; }
  std::vector<std::string> allowed_options() const override {
    return {"content", "template", "source", "locals", "mode", "owner", "group", "state", "sensitive", "verify"};
  }

  const std::string &local_file() const { return local_file_; }

  Value desired() override;
  Value current() override;
  void apply(const std::vector<Diff::Change> &changes) override;
  bool sensitive() const override { return opt("sensitive").is_true(); }

  // Renders the template, or reads the source file, so their errors show up
  // without a machine.
  void check_offline() override;

 protected:
  void validate() override;

 private:
  void validate_content_options() const;
  std::string find_local_file(const std::string &relative, const std::string &subdirectory) const;
  std::string in_source_dir(const std::string &relative) const;
  bool content_managed() const;
  std::optional<std::string> desired_mode() const;
  const std::string &desired_content();
  std::string render_content();
  std::optional<PathStat> read_stat();
  void replace_content();

  std::string local_file_;
  std::optional<std::string> desired_content_;
};

}  // namespace sadame
