#pragma once

#include "../resource.hpp"

namespace sadame {

// Manages a symbolic link.
//
//   (link "/etc/nginx/sites-enabled/app" #:to "/etc/nginx/sites-available/app")
//   (link "/srv/app/current" #:to "releases/42")
//   (link "/etc/nginx/sites-enabled/default" #:state 'absent)
//
// #:to is stored in the link as given, so a relative target is relative to
// the link's directory. A link pointing elsewhere is changed. A regular file
// in the way is an error unless #:force #t, which replaces it; a directory
// in the way is always an error.
class LinkResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "link"; }
  std::vector<std::string> allowed_options() const override { return {"to", "state", "force"}; }

  Value desired() override;
  Value current() override;
  void apply(const std::vector<Diff::Change> &changes) override;

 protected:
  void validate() override;
};

}  // namespace sadame
