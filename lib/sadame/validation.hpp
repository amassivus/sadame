#pragma once

#include <optional>
#include <ostream>
#include <string>
#include <vector>

#include "platform.hpp"
#include "recipe.hpp"
#include "value.hpp"

namespace sadame {

// `sadame validate`: evaluates a recipe once per host, with that host's
// name, groups and vars, against a stand-in machine (see StandIn), and
// checks what can be checked without the machine: Scheme errors, resource
// names and options, notifications, include-recipe paths, and templates and
// source files, which are found and rendered.
class Validation {
 public:
  // files: the expanded paths of the recipe files evaluated.
  struct Result {
    std::string name;
    std::optional<std::size_t> resources;
    std::optional<std::string> error;
    std::vector<std::string> files;
  };

  Validation(std::string recipe_path, Platform platform)
      : recipe_path_(std::move(recipe_path)), platform_(std::move(platform)) {}

  // sources: see Recipe::load.
  Result check(const std::string &name, const std::vector<std::string> &groups, const Value &vars,
               const Recipe::Sources &sources = {});

  // 0 when every host's recipe is valid, 2 otherwise, like a recipe error.
  static int exit_status(const std::vector<Result> &results);

 private:
  std::string recipe_path_;
  Platform platform_;
};

// Output of `sadame validate`.
class ValidationListing {
 public:
  ValidationListing(std::ostream &io, bool color = false) : io_(io), color_(color) {}

  void render(const std::string &recipe_path, const Platform &platform, const std::vector<Validation::Result> &results);
  void render_json(const std::string &recipe_path, const Platform &platform,
                   const std::vector<Validation::Result> &results);

 private:
  std::string paint(const std::string &text, int code) const;
  void line(const std::string &text = "") { io_ << text << "\n"; }

  std::ostream &io_;
  bool color_;
};

}  // namespace sadame
