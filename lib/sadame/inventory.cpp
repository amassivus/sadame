#include "inventory.hpp"

#include <algorithm>

#include "errors.hpp"
#include "glob.hpp"
#include "scheme.hpp"
#include "vars.hpp"

namespace sadame {

namespace {

bool contains(const std::vector<std::string> &list, const std::string &item) {
  return std::find(list.begin(), list.end(), item) != list.end();
}

std::string join(const std::vector<std::string> &items, const std::string &separator) {
  std::string result;
  for (std::size_t index = 0; index < items.size(); ++index) {
    if (index > 0) result += separator;
    result += items[index];
  }
  return result;
}

const std::vector<std::string> kHostOptions = {"address", "user", "port", "sudo", "ssh_opts", "vars"};
const std::vector<std::string> kConnectionOptions = {"address", "user", "port", "sudo", "ssh_opts"};

std::string keyword(const std::string &key) {
  std::string result = key;
  std::replace(result.begin(), result.end(), '_', '-');
  return result;
}

}  // namespace

Inventory Inventory::load(const std::string &path, Shell &shell) {
  Inventory inventory(path);
  auto source = Shell().read_file(path);
  if (!source) throw RecipeError("cannot read " + path);

  InventoryBuilder builder(inventory, shell);
  InventoryBuilder *previous = InventoryBuilder::current();
  InventoryBuilder::current() = &builder;
  try {
    scheme::evaluate_file("inventory", path, *source);
  } catch (...) {
    InventoryBuilder::current() = previous;
    throw;
  }
  InventoryBuilder::current() = previous;

  inventory.check_includes();
  return inventory;
}

std::vector<std::string> Inventory::host_names() const {
  std::vector<std::string> names;
  for (const HostEntry &entry : hosts_) names.push_back(entry.name);
  return names;
}

std::vector<std::string> Inventory::group_names() const {
  std::vector<std::string> names;
  for (const Group &group : groups_) names.push_back(group.name);
  return names;
}

Inventory::Group *Inventory::find_group(const std::string &name) {
  for (Group &group : groups_) {
    if (group.name == name) return &group;
  }
  return nullptr;
}

const Inventory::Group *Inventory::find_group(const std::string &name) const {
  for (const Group &group : groups_) {
    if (group.name == name) return &group;
  }
  return nullptr;
}

Inventory::HostEntry *Inventory::find_host(const std::string &name) {
  for (HostEntry &entry : hosts_) {
    if (entry.name == name) return &entry;
  }
  return nullptr;
}

const Inventory::HostEntry *Inventory::find_host(const std::string &name) const {
  for (const HostEntry &entry : hosts_) {
    if (entry.name == name) return &entry;
  }
  return nullptr;
}

Inventory::Group &Inventory::define_group(const std::string &name) {
  if (Group *existing = find_group(name)) return *existing;
  groups_.push_back(Group{name, {}, Value::map(), {}});
  return groups_.back();
}

void Inventory::define_host(const std::string &name, const Value &options, const std::optional<std::string> &group_name) {
  HostEntry *entry = find_host(name);
  if (!entry) {
    hosts_.push_back(HostEntry{name, Value::map(), Value::map()});
    entry = &hosts_.back();
  }
  for (const std::string &key : kConnectionOptions) {
    if (options.has(key)) merge_connection(*entry, key, options.get(key));
  }
  Value host_vars = Vars::normalize_keys(options.get("vars").is_map() ? options.get("vars") : Value::map());
  for (std::size_t index = 0; index < host_vars.keys().size(); ++index) {
    entry->vars.set(host_vars.keys()[index], host_vars.values()[index]);
  }

  if (!group_name) return;
  Group *group = find_group(*group_name);
  if (!contains(group->host_names, name)) group->host_names.push_back(name);
}

void Inventory::merge_connection(HostEntry &entry, const std::string &key, const Value &value) {
  if (entry.connection.has(key) && entry.connection.get(key) != value) {
    throw RecipeError(path_.value_or("") + ": host " + entry.name + " is declared with " + keyword(key) + " " +
                      entry.connection.get(key).inspect() + " and " + value.inspect());
  }
  entry.connection.set(key, value);
}

void Inventory::check_includes() const {
  for (const Group &group : groups_) {
    for (const std::string &included : group.includes) {
      if (find_group(included)) continue;
      throw RecipeError(path_.value_or("") + ": group " + group.name + " includes " + included + ", which is not defined");
    }
  }
  for (const Group &group : groups_) check_cycle(group.name, {});
}

void Inventory::check_cycle(const std::string &name, std::vector<std::string> chain) const {
  if (contains(chain, name)) {
    chain.push_back(name);
    throw RecipeError(path_.value_or("") + ": groups include each other: " + join(chain, " -> "));
  }

  chain.push_back(name);
  for (const std::string &included : find_group(name)->includes) check_cycle(included, chain);
}

std::vector<std::string> Inventory::included_closure(const std::string &name) const {
  std::vector<std::string> result;
  std::vector<std::string> pending = find_group(name)->includes;
  while (!pending.empty()) {
    std::string group = pending.front();
    pending.erase(pending.begin());
    if (contains(result, group)) continue;

    result.push_back(group);
    for (const std::string &included : find_group(group)->includes) pending.push_back(included);
  }
  return result;
}

std::vector<std::string> Inventory::hosts_in_group(const std::string &name) const {
  std::vector<std::string> names = included_closure(name);
  names.push_back(name);
  std::vector<std::string> result;
  for (const HostEntry &host : hosts_) {
    for (const std::string &group : names) {
      if (contains(find_group(group)->host_names, host.name)) {
        result.push_back(host.name);
        break;
      }
    }
  }
  return result;
}

std::vector<std::string> Inventory::groups_of(const std::string &host_name) const {
  std::vector<std::string> direct;
  for (const Group &group : groups_) {
    if (contains(group.host_names, host_name)) direct.push_back(group.name);
  }

  std::vector<std::string> member;
  for (const Group &group : groups_) {
    bool belongs = contains(direct, group.name);
    for (const std::string &included : included_closure(group.name)) belongs = belongs || contains(direct, included);
    if (belongs) member.push_back(group.name);
  }
  return order_by_includes(member);
}

std::vector<std::string> Inventory::order_by_includes(const std::vector<std::string> &names) const {
  std::vector<std::string> ordered;
  std::vector<std::string> remaining = names;
  while (!remaining.empty()) {
    auto ready = std::find_if(remaining.begin(), remaining.end(), [&](const std::string &name) {
      for (const std::string &included : included_closure(name)) {
        if (contains(names, included) && !contains(ordered, included)) return false;
      }
      return true;
    });
    ordered.push_back(*ready);
    remaining.erase(ready);
  }
  return ordered;
}

std::vector<Target> Inventory::select(const Selection &selection) const {
  std::vector<std::string> names;
  for (const std::string &group : selection.group_names) {
    if (!has_group(group)) throw UsageError("unknown group " + group + known_groups_hint());
    for (const std::string &host : hosts_in_group(group)) {
      if (!contains(names, host)) names.push_back(host);
    }
  }

  std::vector<std::pair<std::string, Target::Spec>> overrides;
  for (const std::string &text : selection.host_specs) {
    Target::Spec spec = Target::parse(text);
    overrides.push_back({spec.host, spec});
    if (!contains(names, spec.host)) names.push_back(spec.host);
  }

  if (selection.group_names.empty() && selection.host_specs.empty()) names = host_names();
  if (selection.limit) {
    std::vector<std::string> kept;
    for (const std::string &name : names) {
      if (Glob::match(*selection.limit, name)) kept.push_back(name);
    }
    names = kept;
  }
  if (names.empty()) throw UsageError("no hosts match" + selection_description(selection));

  std::vector<Target> targets;
  for (const std::string &name : names) {
    const Target::Spec *spec = nullptr;
    for (const auto &entry : overrides) {
      if (entry.first == name) spec = &entry.second;
    }
    targets.push_back(build_target(name, spec, selection));
  }
  return targets;
}

Target Inventory::build_target(const std::string &name, const Target::Spec *override_spec,
                               const Selection &selection) const {
  const HostEntry *entry = find_host(name);
  Value connection = entry ? entry->connection : Value::map();
  std::vector<std::string> groups = entry ? groups_of(name) : std::vector<std::string>();

  std::vector<Vars::Layer> layers;
  layers.push_back({"vars.scm", selection.base_vars});
  for (const std::string &group : groups) layers.push_back({"group " + group, find_group(group)->vars});
  if (entry) layers.push_back({"host", entry->vars});
  layers.push_back({"--var", selection.cli_vars});
  auto [vars, sources] = Vars::layered(layers);

  Target target;
  target.name = name;
  target.address = connection.has("address") ? connection.get("address").to_s() : name;
  if (override_spec && override_spec->user) {
    target.user = override_spec->user;
  } else if (connection.has("user")) {
    target.user = connection.get("user").to_s();
  }
  if (override_spec && override_spec->port) {
    target.port = override_spec->port;
  } else if (connection.has("port")) {
    target.port = static_cast<int>(connection.get("port").integer());
  }
  target.sudo = selection.sudo || connection.get("sudo").is_true();
  for (const Value &option : connection.get("ssh_opts").items()) target.ssh_opts.push_back(option.to_s());
  target.groups = groups;
  target.vars = vars;
  target.var_sources = sources;
  return target;
}

std::string Inventory::known_groups_hint() const {
  if (groups_.empty()) return " (no groups are defined)";
  return " (defined: " + join(group_names(), ", ") + ")";
}

std::string Inventory::selection_description(const Selection &selection) {
  std::string parts;
  if (!selection.host_specs.empty()) parts += " -h " + join(selection.host_specs, ",");
  if (!selection.group_names.empty()) parts += " -g " + join(selection.group_names, ",");
  if (selection.limit) parts += " --limit " + *selection.limit;
  if (parts.empty()) parts = " (the inventory is empty)";
  return parts;
}

// ---------------------------------------------------------------------------

InventoryBuilder *&InventoryBuilder::current() {
  static InventoryBuilder *current = nullptr;
  return current;
}

void InventoryBuilder::group_begin(const std::string &name, const Value &options) {
  if (group_) throw Error("groups cannot be nested; use #:include to combine groups");

  Inventory::Group &group = inventory_.define_group(name);
  Value includes = options.get("include");
  std::vector<Value> list = includes.is_array() ? includes.items() : std::vector<Value>();
  if (!includes.is_array() && !includes.is_nil()) list.push_back(includes);
  for (const Value &included : list) {
    if (!included.is_text()) throw Error("group " + name + ": #:include takes group names, got " + included.inspect());
    if (!contains(group.includes, included.text())) group.includes.push_back(included.text());
  }
  group_ = name;
}

void InventoryBuilder::host(const std::string &name, const Value &options) {
  if (name.empty()) throw Error("host name must not be empty");

  validate_host_options(name, options);
  inventory_.define_host(name, options, group_);
}

void InventoryBuilder::vars(const Value &values) {
  if (!group_) throw Error("vars must be inside a group; use (host ... #:vars '(...)) for one host");

  Value normalized = Vars::normalize_keys(values);
  Inventory::Group &group = inventory_.define_group(*group_);
  for (std::size_t index = 0; index < normalized.keys().size(); ++index) {
    group.vars.set(normalized.keys()[index], normalized.values()[index]);
  }
}

std::string InventoryBuilder::command_output(const std::string &command) {
  return shell_.run_checked(command).stdout_text;
}

void InventoryBuilder::validate_host_options(const std::string &name, const Value &options) const {
  for (std::size_t index = 0; index < options.keys().size(); ++index) {
    const std::string &key = options.keys()[index];
    const Value &value = options.values()[index];
    if (!contains(kHostOptions, key)) {
      std::vector<std::string> valid;
      for (const std::string &option : kHostOptions) valid.push_back(keyword(option));
      std::sort(valid.begin(), valid.end());
      throw Error("host " + name + ": unknown option #:" + keyword(key) + " (valid options: " + join(valid, ", ") + ")");
    }

    bool ok = false;
    std::string expected;
    if (key == "address" || key == "user") {
      ok = value.is_string() && !value.text().empty();
      expected = "a string";
    } else if (key == "port") {
      ok = value.is_int() && value.integer() >= 1 && value.integer() <= 65535;
      expected = "an integer from 1 to 65535";
    } else if (key == "sudo") {
      ok = value.is_bool();
      expected = "#t or #f";
    } else if (key == "ssh_opts") {
      ok = value.is_array() && std::all_of(value.items().begin(), value.items().end(),
                                           [](const Value &item) { return item.is_string(); });
      expected = "a list of strings";
    } else {
      ok = value.is_map_like();
      expected = "an association list";
    }
    if (!ok) throw Error("host " + name + ": " + keyword(key) + " must be " + expected + ", got " + value.inspect());
  }
}

}  // namespace sadame
