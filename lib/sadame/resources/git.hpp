#pragma once

#include <map>

#include "../resource.hpp"

namespace sadame {

// Keeps a git checkout at a revision: a branch, a tag or a commit.
//
//   (git "/srv/app" #:repository "https://github.com/example/app.git" #:revision "v1.4.2")
//   (git "/srv/app" #:repository "git@github.com:example/app.git" #:revision "main" #:user "deploy")
//
// The checkout is a clone of #:repository with the commit that #:revision
// names checked out (a detached HEAD). For a branch, that is the branch's
// latest commit on the remote, so every plan asks the remote (git
// ls-remote) and apply moves the checkout when the branch has moved.
// Without #:revision, the remote's default branch is used. Local changes to
// tracked files are discarded when the checkout moves.
//
// With #:user, every git command runs as that user (through su), so the
// files belong to them and their SSH keys and git configuration apply. git
// must be installed; declare (package "git") before.
class GitResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "git"; }
  std::vector<std::string> allowed_options() const override { return {"repository", "revision", "user", "state"}; }

  std::string revision() const;

  Value desired() override;
  Value current() override;
  // The changes come from a diff made right before, with git installed, so a
  // revision change names a commit.
  void apply(const std::vector<Diff::Change> &changes) override;

 protected:
  void validate() override;

 private:
  bool checkout_exists();
  std::optional<std::string> remote_commit();
  std::vector<std::string> ref_candidates() const;
  std::map<std::string, std::string> remote_refs();
  void require_git();
  static bool is_commit(const std::string &text);
  CommandResult git(const std::string &arguments);
  CommandResult git_checked(const std::string &arguments);
  std::string command_line(const std::string &arguments) const;
};

}  // namespace sadame
