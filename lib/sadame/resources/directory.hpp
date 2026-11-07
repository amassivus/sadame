#pragma once

#include "../resource.hpp"

namespace sadame {

// Manages a directory, its permission bits and ownership.
//
//   (directory "/var/www/app" #:owner "www-data" #:mode "0755")
//   (directory "/opt/legacy" #:state 'absent #:recursive #t)
//
// Missing parent directories are created. Removing a non-empty directory
// requires #:recursive #t.
class DirectoryResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "directory"; }
  std::vector<std::string> allowed_options() const override { return {"mode", "owner", "group", "state", "recursive"}; }

  Value desired() override;
  Value current() override;
  void apply(const std::vector<Diff::Change> &changes) override;

 protected:
  void validate() override;

 private:
  void remove();
};

}  // namespace sadame
