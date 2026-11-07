#pragma once

#include "../resource.hpp"

namespace sadame {

// Manages a local group on Linux.
//
//   (group "deploy")
//   (group "app" #:gid 1500)
//   (group "backup" #:system #t)
//   (group "oldteam" #:state 'absent)
//
// Members are managed on the user side, with the user resource's #:groups.
// Uses groupadd, groupmod and groupdel; where those are missing, as on a
// fresh Alpine, BusyBox's addgroup and delgroup, which cannot change a gid.
class GroupResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "group"; }
  std::vector<std::string> allowed_options() const override { return {"gid", "system", "state"}; }

  Value desired() override;
  Value current() override;
  void apply(const std::vector<Diff::Change> &changes) override;

 protected:
  void validate() override;

 private:
  std::string groupadd_command() const;
  std::string addgroup_command() const;
  bool shadow_tools();
  void require_linux();
};

}  // namespace sadame
