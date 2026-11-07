#pragma once

#include <string>
#include <utility>
#include <vector>

#include "shell.hpp"

namespace sadame {

// `sadame init`: the files a new project starts from, and optionally a CI job
// that checks the servers for drift every day. Nothing that exists is
// overwritten: when any of the files is already there, nothing is written.
class Scaffold {
 public:
  static const std::vector<std::string> &ci_systems();

  static std::string github_job(const std::string &recipe);
  static std::string gitlab_job(const std::string &recipe);

  // directory is where the project goes; ci is empty, "github" or "gitlab".
  // CI files go in the current directory, the repository's root.
  Scaffold(Shell &shell, std::string directory, std::string ci = "")
      : shell_(shell), directory_(std::move(directory)), ci_(std::move(ci)) {}

  // The paths and content of the files to write.
  std::vector<std::pair<std::string, std::string>> files() const;

  // Returns the paths written.
  std::vector<std::string> write();

 private:
  std::string in_directory(const std::string &name) const;

  Shell &shell_;
  std::string directory_;
  std::string ci_;
};

}  // namespace sadame
