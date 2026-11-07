#include "link.hpp"

#include "../path_stat.hpp"

namespace sadame {

Value LinkResource::desired() {
  Value result = Value::map();
  if (absent()) {
    result.set("state", "absent");
    return result;
  }
  result.set("state", "present");
  result.set("to", opt("to"));
  return result;
}

Value LinkResource::current() {
  Value result = Value::map();
  auto stat = PathStat::read(shell(), name(), host().platform());
  if (!stat) {
    result.set("state", "absent");
    return result;
  }
  if (stat->type() == PathStat::Type::Symlink) {
    result.set("state", "present");
    result.set("to", chomp(shell().run_checked("readlink " + quote(name())).stdout_text));
    return result;
  }
  if (stat->file() && opt("force").is_true() && !absent()) {
    result.set("state", "regular file");
    return result;
  }

  std::string hint = stat->file() && !absent() ? " (#:force #t replaces it)" : "";
  throw ResourceError(id() + ": " + name() + " is a " + stat->type_label() + ", not a symbolic link" + hint);
}

void LinkResource::apply(const std::vector<Diff::Change> &) {
  if (absent()) {
    shell().run_checked("rm -f " + quote(name()));
  } else {
    // -n replaces a link to a directory instead of creating a link inside it.
    shell().run_checked("ln -sfn " + quote(opt("to").to_s()) + " " + quote(name()));
  }
}

void LinkResource::validate() {
  validate_choice("state", {"present", "absent"});
  validate_boolean("force");
  const Value &target = opt("to");
  if (absent()) {
    if (!target.is_nil()) throw ResourceError(id() + ": #:to makes no sense with #:state 'absent");
  } else if (!(target.is_string() && !target.text().empty())) {
    throw ResourceError(id() + ": #:to must name the target of the link, such as #:to \"/etc/nginx/sites-available/app\"");
  }
}

}  // namespace sadame
