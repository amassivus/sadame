#pragma once

#include <map>
#include <string>
#include <vector>

#include "host.hpp"
#include "resource_collection.hpp"
#include "value.hpp"

namespace sadame {

// Evaluates a recipe file. Every call a recipe can make (see recipe.scm)
// ends up in a method of this class:
//
//   (package "nginx")                       declare
//   (include-recipe "roles/web")            include_recipe
//   (platform 'family), (facts 'cpus)       host()
//
// `vars`, `platform`, `facts`, `host-name` and `host-groups` are available
// for decisions in plain Scheme.
class Recipe {
 public:
  using Sources = std::map<std::string, std::string>;

  // Loads the recipe at path and everything it includes. sources maps
  // expanded paths to text to use instead of the file's, such as an editor's
  // unsaved changes. The expanded path of every file evaluated is added to
  // loaded (when given), even when evaluation fails.
  static ResourceCollection load(const std::string &path, Host &host, const Value &vars,
                                 const Sources &sources = {}, std::vector<std::string> *loaded = nullptr);

  // The recipe being evaluated right now, for the Scheme primitives.
  static Recipe *&current();

  // tags are added to every resource this recipe declares (see
  // include-recipe).
  Recipe(std::string path, Host &host, const Value &vars, ResourceCollection &collection,
         std::vector<std::string> *loaded, std::vector<std::string> tags, const Sources &sources);

  void evaluate();

  void declare(const std::string &type, const std::string &name, Value options);

  // Evaluates another recipe, relative to this recipe's directory. The
  // ".scm" extension is optional. A recipe is only ever included once.
  void include_recipe(const std::string &name, const Value &options);

  Host &host() { return host_; }
  const Value &vars() const { return vars_; }

 private:
  std::string recipe_dir() const;

  std::string path_;
  Host &host_;
  Value vars_;
  ResourceCollection &collection_;
  std::vector<std::string> *loaded_;
  std::vector<std::string> tags_;
  const Sources &sources_;
};

// The directory part of a path, "." when it has none.
std::string dirname(const std::string &path);

}  // namespace sadame
