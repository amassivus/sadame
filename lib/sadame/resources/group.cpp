#include "group.hpp"

namespace sadame {

Value GroupResource::desired() {
  Value result = Value::map();
  if (absent()) {
    result.set("state", "absent");
    return result;
  }
  result.set("state", "present");
  if (given("gid")) result.set("gid", opt("gid"));
  return result;
}

Value GroupResource::current() {
  require_linux();
  Value result = Value::map();
  CommandResult found = shell().run("getent group " + quote(name()));
  if (!found.success()) {
    result.set("state", "absent");
    return result;
  }

  // The gid is the third field of "name:x:gid:members".
  std::string line = strip(found.stdout_text);
  std::size_t first = line.find(':');
  std::size_t second = first == std::string::npos ? first : line.find(':', first + 1);
  long long gid = second == std::string::npos ? 0 : std::atoll(line.c_str() + second + 1);
  result.set("state", "present");
  result.set("gid", gid);
  return result;
}

void GroupResource::apply(const std::vector<Diff::Change> &changes) {
  bool shadow = shadow_tools();
  if (absent()) {
    shell().run_checked(std::string(shadow ? "groupdel" : "delgroup") + " " + quote(name()));
  } else if (changed(changes, "state")) {
    shell().run_checked(shadow ? groupadd_command() : addgroup_command());
  } else {
    if (!shadow) {
      throw ResourceError(id() + ": changing a gid needs groupmod (on Alpine, declare (package \"shadow\") first)");
    }
    shell().run_checked("groupmod -g " + opt("gid").to_s() + " " + quote(name()));
  }
}

void GroupResource::validate() {
  validate_choice("state", {"present", "absent"});
  validate_boolean("system");
  const Value &gid = opt("gid");
  if (gid.is_nil() || (gid.is_int() && gid.integer() >= 0)) return;
  throw ResourceError(id() + ": gid must be a non-negative integer");
}

std::string GroupResource::groupadd_command() const {
  std::string command = "groupadd";
  if (opt("system").is_true()) command += " -r";
  if (given("gid")) command += " -g " + opt("gid").to_s();
  return command + " " + quote(name());
}

// BusyBox: addgroup [-g GID] [-S] GROUP
std::string GroupResource::addgroup_command() const {
  std::string command = "addgroup";
  if (given("gid")) command += " -g " + opt("gid").to_s();
  if (opt("system").is_true()) command += " -S";
  return command + " " + quote(name());
}

bool GroupResource::shadow_tools() { return shell().run("command -v groupadd").success(); }

void GroupResource::require_linux() {
  if (host().platform().linux_kernel()) return;
  throw ResourceError(id() + ": the group resource only supports Linux");
}

}  // namespace sadame
