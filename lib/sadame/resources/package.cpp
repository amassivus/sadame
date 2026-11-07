#include "package.hpp"

namespace sadame {

Value PackageResource::desired() {
  Value result = Value::map();
  result.set("state", desired_state());
  return result;
}

Value PackageResource::current() {
  Value result = Value::map();
  result.set("state", host().package_manager().installed(name()) ? "installed" : "absent");
  return result;
}

void PackageResource::apply(const std::vector<Diff::Change> &) {
  if (desired_state() == "installed") {
    host().package_manager().install(name(), opt("options"));
  } else {
    host().package_manager().remove(name(), opt("options"));
  }
}

void PackageResource::validate() {
  validate_choice("state", {"installed", "absent"});
  const Value &flags = opt("options");
  if (flags.is_nil() || flags.is_string() || flags.is_array()) return;
  throw ResourceError(id() + ": options must be a string or a list of flags");
}

std::string PackageResource::desired_state() const { return text_opt("state").value_or("installed"); }

}  // namespace sadame
