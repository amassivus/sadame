#pragma once

#include <optional>
#include <string>
#include <vector>

#include "shell.hpp"
#include "target.hpp"
#include "value.hpp"

namespace sadame {

// The machines a recipe can run on, read from hosts.scm:
//
//   (group 'web
//     (host "web1.example.com")
//     (host "web2.example.com" #:vars '((workers . 8)))
//     (vars #:workers 4 #:tls #t))
//
//   (group 'db
//     (host "db1.example.com" #:user "admin" #:port 2222 #:sudo #t))
//
//   (group 'all #:include '(web db)
//     (vars #:env "production"))
//
// Vars precedence, highest first: --var, host vars, group vars (a group
// overrides the groups it includes), vars.scm.
class Inventory {
 public:
  // A named set of hosts, with vars and other groups it includes.
  struct Group {
    std::string name;
    std::vector<std::string> includes;
    Value vars = Value::map();
    std::vector<std::string> host_names;
  };

  // A host as declared in hosts.scm, possibly in several groups.
  struct HostEntry {
    std::string name;
    Value connection = Value::map();
    Value vars = Value::map();
  };

  static Inventory load(const std::string &path, Shell &shell);
  static Inventory empty() { return Inventory(std::nullopt); }

  explicit Inventory(std::optional<std::string> path) : path_(std::move(path)) {}

  const std::optional<std::string> &path() const { return path_; }
  bool is_empty() const { return hosts_.empty(); }
  std::vector<std::string> host_names() const;
  std::vector<std::string> group_names() const;
  bool has_host(const std::string &name) const { return find_host(name) != nullptr; }
  bool has_group(const std::string &name) const { return find_group(name) != nullptr; }

  // Used by the hosts.scm language.
  Group &define_group(const std::string &name);
  void define_host(const std::string &name, const Value &options, const std::optional<std::string> &group_name);

  void check_includes() const;

  // Hosts of a group and of the groups it includes, in the order they were
  // declared.
  std::vector<std::string> hosts_in_group(const std::string &name) const;

  // Groups a host belongs to, directly or through #:include, ordered so that
  // a group comes after every group it includes. Unrelated groups keep the
  // order they were declared in.
  std::vector<std::string> groups_of(const std::string &host_name) const;

  struct Selection {
    std::vector<std::string> host_specs;   // "[user@]host[:port]" strings from -h
    std::vector<std::string> group_names;  // names from -g
    std::optional<std::string> limit;      // a glob matched against host names
    Value base_vars = Value::map();        // vars from vars.scm (lowest precedence)
    Value cli_vars = Value::map();         // vars from --var (highest precedence)
    bool sudo = false;                     // true for --sudo, which applies to every target
  };

  // Resolves -h, -g and --limit to targets with their final vars.
  std::vector<Target> select(const Selection &selection) const;

 private:
  Group *find_group(const std::string &name);
  const Group *find_group(const std::string &name) const;
  HostEntry *find_host(const std::string &name);
  const HostEntry *find_host(const std::string &name) const;

  void merge_connection(HostEntry &entry, const std::string &key, const Value &value);
  void check_cycle(const std::string &name, std::vector<std::string> chain) const;
  // Every group reachable through #:include, without the group itself.
  std::vector<std::string> included_closure(const std::string &name) const;
  std::vector<std::string> order_by_includes(const std::vector<std::string> &names) const;
  Target build_target(const std::string &name, const Target::Spec *override_spec, const Selection &selection) const;
  std::string known_groups_hint() const;
  static std::string selection_description(const Selection &selection);

  std::optional<std::string> path_;
  std::vector<Group> groups_;
  std::vector<HostEntry> hosts_;
};

// The hosts.scm language. Its methods are what hosts.scm can call.
class InventoryBuilder {
 public:
  InventoryBuilder(Inventory &inventory, Shell &shell) : inventory_(inventory), shell_(shell) {}

  // The builder of the hosts.scm being evaluated, for the Scheme primitives.
  static InventoryBuilder *&current();

  // Declares a group, or adds to one declared earlier. group_end closes it.
  void group_begin(const std::string &name, const Value &options);
  void group_end() { group_.reset(); }

  // Declares a host, in the current group if inside one.
  void host(const std::string &name, const Value &options);

  // Sets vars for the current group.
  void vars(const Value &values);

  // Runs a command on the machine running sadame and returns what it
  // printed; fails when the command does.
  std::string command_output(const std::string &command);

 private:
  void validate_host_options(const std::string &name, const Value &options) const;

  Inventory &inventory_;
  Shell &shell_;
  std::optional<std::string> group_;
};

}  // namespace sadame
