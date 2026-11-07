#pragma once

#include "../resource.hpp"

namespace sadame {

// Manages a local user account on Linux.
//
//   (user "deploy" #:shell "/bin/bash" #:groups '("docker"))
//   (user "backup" #:system #t #:home "/var/lib/backup")
//   (user "olduser" #:state 'absent)
//
// #:groups lists groups the user must belong to; memberships not listed are
// left alone. The groups must already exist. New users get a home directory
// unless #:system #t.
class UserResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "user"; }
  std::vector<std::string> allowed_options() const override {
    return {"uid", "home", "shell", "groups", "system", "state"};
  }

  Value desired() override;
  Value current() override;
  void apply(const std::vector<Diff::Change> &changes) override;

 protected:
  void validate() override;

 private:
  std::vector<std::string> desired_groups() const;
  std::vector<std::string> memberships(const std::vector<std::string> &groups) const;
  std::vector<std::string> current_groups();
  std::string useradd_command() const;
  std::string usermod_command(const std::vector<Diff::Change> &changes) const;
  void require_linux();
  void require_shadow_tools();
};

}  // namespace sadame
