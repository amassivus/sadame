#include "directory.hpp"

#include "../path_stat.hpp"

namespace sadame {

Value DirectoryResource::desired() {
  Value result = Value::map();
  if (absent()) {
    result.set("state", "absent");
    return result;
  }
  result.set("state", "present");
  if (given("mode")) result.set("mode", PathStat::normalize_mode(opt("mode").text()).value_or(""));
  if (given("owner")) result.set("owner", opt("owner").to_s());
  if (given("group")) result.set("group", opt("group").to_s());
  return result;
}

Value DirectoryResource::current() {
  Value result = Value::map();
  auto stat = PathStat::read(shell(), name(), host().platform());
  if (!stat) {
    result.set("state", "absent");
    return result;
  }
  if (!stat->directory()) throw ResourceError(id() + ": " + name() + " is a " + stat->type_label() + ", not a directory");

  result.set("state", "present");
  result.set("mode", stat->mode());
  result.set("owner", stat->owner());
  result.set("group", stat->group());
  return result;
}

void DirectoryResource::apply(const std::vector<Diff::Change> &changes) {
  if (absent()) {
    remove();
    return;
  }

  if (changed(changes, "state")) shell().run_checked("mkdir -p " + quote(name()));
  if (changed(changes, "mode")) shell().run_checked("chmod " + desired().get("mode").to_s() + " " + quote(name()));
  if (changed(changes, "owner") || changed(changes, "group")) {
    shell().run_checked("chown " + ownership(text_opt("owner"), text_opt("group")) + " " + quote(name()));
  }
}

void DirectoryResource::validate() {
  validate_choice("state", {"present", "absent"});
  validate_boolean("recursive");
  validate_mode();
}

void DirectoryResource::remove() {
  if (opt("recursive").is_true()) {
    shell().run_checked("rm -rf " + quote(name()));
  } else {
    shell().run_checked("rmdir " + quote(name()));
  }
}

}  // namespace sadame
