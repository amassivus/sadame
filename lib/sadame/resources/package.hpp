#pragma once

#include "../resource.hpp"

namespace sadame {

// Installs or removes a system package with the host's package manager
// (apt, dnf, apk or pacman, detected from /etc/os-release).
//
//   (package "nginx")
//   (package "telnet" #:state 'absent)
//   (package "base-devel" #:options "--asdeps")
class PackageResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "package"; }
  std::vector<std::string> allowed_options() const override { return {"state", "options"}; }

  Value desired() override;
  Value current() override;
  void apply(const std::vector<Diff::Change> &changes) override;

 protected:
  void validate() override;

 private:
  std::string desired_state() const;
};

}  // namespace sadame
