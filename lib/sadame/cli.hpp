#pragma once

#include <istream>
#include <map>
#include <optional>
#include <ostream>
#include <string>
#include <vector>

#include "inventory.hpp"
#include "shell.hpp"
#include "target.hpp"
#include "value.hpp"

namespace sadame {

// Command-line interface: parses arguments, loads the recipe, vars and
// inventory, runs the command, and returns the process exit status.
//
// Exit status (see Report::exit_status):
//   0 success
//   1 apply failed, or drift found differences
//   2 usage or recipe error, a state that could not be read, or a target
//     that could not be reached
class CLI {
 public:
  static constexpr const char *kDefaultRecipe = "recipe.scm";
  static constexpr const char *kDefaultInventory = "hosts.scm";

  static const char *usage();

  struct Environment {
    std::map<std::string, std::string> variables;
    // Whether stdout is a terminal, which turns colors on.
    bool stdout_tty = false;
  };

  CLI(std::vector<std::string> argv, std::ostream &out, std::ostream &err, Shell &shell, Environment environment);
  CLI(std::vector<std::string> argv, std::ostream &out, std::ostream &err, Shell &shell);

  int run();

 private:
  struct Options {
    Value vars = Value::map();
    std::vector<std::string> hosts, groups;
    std::optional<std::string> limit, inventory;
    bool sudo = false, json = false;
    std::optional<bool> color;
    std::optional<std::string> vars_file, host_name;
    std::vector<std::string> host_groups;
    std::optional<int> forks;
    std::optional<std::string> serial;
    std::vector<std::string> tags, skip_tags;
    std::optional<std::string> platform, format, ci;
    bool help = false, version = false;
    std::string command;
    std::optional<std::string> recipe;
  };

  int execute(const Options &options);
  void check_local_options(const Options &options) const;
  void check_remote_options(const Options &options) const;
  int run_local(const Options &options, const std::string &recipe_path, const Value &base_vars);
  int init_project(const Options &options);
  int validate(const Options &options);
  int list_hosts(const Options &options);
  int show_facts(const Options &options);
  int not_ported(const std::string &what);
  Inventory load_inventory(const Options &options, const std::string &base_dir) const;
  std::vector<Target> select_targets(const Inventory &inventory, const Options &options, const Value &base_vars) const;

  Options parse(const std::vector<std::string> &argv) const;
  Options assign_positional(Options options, std::vector<std::string> positional) const;

  std::string resolve_recipe(const std::optional<std::string> &argument) const;
  std::string recipe_directory(const std::optional<std::string> &argument) const;
  Value load_vars_file(const std::string &path) const;
  bool is_remote(const Options &options) const;
  bool use_color(const Options &options) const;

  std::vector<std::string> argv_;
  std::ostream &out_;
  std::ostream &err_;
  Shell &shell_;
  Environment environment_;
};

}  // namespace sadame
