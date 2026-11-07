#include "user.hpp"

#include <algorithm>
#include <sstream>

namespace sadame {

namespace {

// "a:b::c" split on ":" keeping empty fields, like Ruby's split(":", -1).
std::vector<std::string> split_fields(const std::string &text) {
  std::vector<std::string> fields;
  std::string field;
  for (char character : text) {
    if (character == ':') {
      fields.push_back(field);
      field.clear();
    } else {
      field += character;
    }
  }
  fields.push_back(field);
  return fields;
}

std::string join(const std::vector<std::string> &items, const std::string &separator) {
  std::string result;
  for (std::size_t index = 0; index < items.size(); ++index) {
    if (index > 0) result += separator;
    result += items[index];
  }
  return result;
}

Value string_array(const std::vector<std::string> &items) {
  Value result = Value::array();
  for (const std::string &item : items) result.push(Value(item));
  return result;
}

}  // namespace

std::vector<std::string> UserResource::desired_groups() const {
  std::vector<std::string> result;
  if (opt("groups").is_array()) {
    for (const Value &group : opt("groups").items()) result.push_back(group.to_s());
  }
  return result;
}

Value UserResource::desired() {
  Value result = Value::map();
  if (absent()) {
    result.set("state", "absent");
    return result;
  }
  result.set("state", "present");
  if (given("uid")) result.set("uid", opt("uid"));
  if (given("home")) result.set("home", opt("home"));
  if (given("shell")) result.set("shell", opt("shell"));
  if (!desired_groups().empty()) result.set("groups", string_array(desired_groups()));
  return result;
}

Value UserResource::current() {
  require_linux();
  Value result = Value::map();
  CommandResult found = shell().run("getent passwd " + quote(name()));
  if (!found.success()) {
    result.set("state", "absent");
    return result;
  }

  std::vector<std::string> fields = split_fields(strip(found.stdout_text));
  auto field = [&](std::size_t index) { return index < fields.size() ? fields[index] : std::string(); };
  result.set("state", "present");
  result.set("uid", static_cast<long long>(std::atoll(field(2).c_str())));
  result.set("home", field(5));
  result.set("shell", field(6));
  result.set("groups", string_array(memberships(current_groups())));
  return result;
}

void UserResource::apply(const std::vector<Diff::Change> &changes) {
  if (absent()) {
    shell().run_checked("userdel " + quote(name()));
  } else if (changed(changes, "state")) {
    require_shadow_tools();
    shell().run_checked(useradd_command());
  } else {
    require_shadow_tools();
    shell().run_checked(usermod_command(changes));
  }
}

void UserResource::validate() {
  validate_choice("state", {"present", "absent"});
  validate_boolean("system");
  if (given("uid") && !opt("uid").is_int()) throw ResourceError(id() + ": uid must be an integer");

  const Value &groups = opt("groups");
  if (groups.is_nil()) return;
  bool valid = groups.is_array() && std::all_of(groups.items().begin(), groups.items().end(),
                                                [](const Value &group) { return group.is_string(); });
  if (!valid) throw ResourceError(id() + ": groups must be a list of group names");
}

// The desired groups the user already belongs to, in desired order, so the
// result equals desired_groups exactly when nothing is missing.
std::vector<std::string> UserResource::memberships(const std::vector<std::string> &groups) const {
  std::vector<std::string> result;
  for (const std::string &group : desired_groups()) {
    if (std::find(groups.begin(), groups.end(), group) != groups.end()) result.push_back(group);
  }
  return result;
}

std::vector<std::string> UserResource::current_groups() {
  CommandResult result = shell().run("id -nG " + quote(name()));
  std::vector<std::string> groups;
  if (!result.success()) return groups;
  std::istringstream words(result.stdout_text);
  std::string group;
  while (words >> group) groups.push_back(group);
  return groups;
}

std::string UserResource::useradd_command() const {
  std::vector<std::string> flags;
  flags.push_back(opt("system").is_true() ? "-r" : "-m");
  if (given("uid")) flags.push_back("-u " + opt("uid").to_s());
  if (given("home")) flags.push_back("-d " + quote(opt("home").to_s()));
  if (given("shell")) flags.push_back("-s " + quote(opt("shell").to_s()));
  if (!desired_groups().empty()) flags.push_back("-G " + quote(join(desired_groups(), ",")));
  return "useradd " + join(flags, " ") + " " + quote(name());
}

std::string UserResource::usermod_command(const std::vector<Diff::Change> &changes) const {
  std::vector<std::string> flags;
  if (changed(changes, "uid")) flags.push_back("-u " + opt("uid").to_s());
  if (changed(changes, "home")) flags.push_back("-d " + quote(opt("home").to_s()));
  if (changed(changes, "shell")) flags.push_back("-s " + quote(opt("shell").to_s()));
  if (changed(changes, "groups")) flags.push_back("-a -G " + quote(join(desired_groups(), ",")));
  return "usermod " + join(flags, " ") + " " + quote(name());
}

void UserResource::require_linux() {
  if (host().platform().linux_kernel()) return;
  throw ResourceError(id() + ": the user resource only supports Linux");
}

void UserResource::require_shadow_tools() {
  if (shell().run("command -v useradd").success()) return;
  throw ResourceError(id() + ": useradd is not installed " +
                      "(on Alpine, declare (package \"shadow\") before user resources)");
}

}  // namespace sadame
