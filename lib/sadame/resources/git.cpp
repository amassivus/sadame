#include "git.hpp"

#include <sstream>

#include "../path_stat.hpp"

namespace sadame {

std::string GitResource::revision() const { return given("revision") ? opt("revision").to_s() : "HEAD"; }

Value GitResource::desired() {
  Value result = Value::map();
  if (absent()) {
    result.set("state", "absent");
    return result;
  }
  auto commit = remote_commit();
  result.set("state", "present");
  result.set("repository", opt("repository"));
  result.set("revision", commit ? *commit : revision());
  return result;
}

Value GitResource::current() {
  Value result = Value::map();
  if (!checkout_exists()) {
    result.set("state", "absent");
    return result;
  }
  result.set("state", "present");
  if (absent()) return result;

  result.set("repository", strip(git("-C " + quote(name()) + " config --get remote.origin.url").stdout_text));
  result.set("revision", strip(git("-C " + quote(name()) + " rev-parse HEAD").stdout_text));
  return result;
}

void GitResource::apply(const std::vector<Diff::Change> &changes) {
  if (absent()) {
    shell().run_checked("rm -rf " + quote(name()));
    return;
  }

  require_git();
  if (changed(changes, "state")) {
    git_checked("clone --quiet --no-checkout " + quote(opt("repository").to_s()) + " " + quote(name()));
  } else {
    if (changed(changes, "repository")) {
      git_checked("-C " + quote(name()) + " remote set-url origin " + quote(opt("repository").to_s()));
    }
    git_checked("-C " + quote(name()) + " fetch --quiet --tags origin");
  }

  for (const Diff::Change &change : changes) {
    if (change.attribute == "revision") {
      git_checked("-C " + quote(name()) + " checkout --quiet --force --detach " + quote(change.to.to_s()));
      break;
    }
  }
}

void GitResource::validate() {
  validate_choice("state", {"present", "absent"});
  for (const char *key : {"repository", "revision", "user"}) {
    const Value &value = opt(key);
    if (value.is_nil() || (value.is_string() && !value.text().empty())) continue;
    throw ResourceError(id() + ": " + key + " must be a non-empty string");
  }
  if (absent() || given("repository")) return;
  throw ResourceError(id() + ": #:repository is required, such as #:repository \"https://github.com/example/app.git\"");
}

// A directory with a .git directory is a checkout; a missing path or an
// empty directory is where one can be cloned; anything else is an error.
bool GitResource::checkout_exists() {
  auto stat = PathStat::read(shell(), name(), host().platform());
  if (!stat) return false;
  if (!stat->directory()) throw ResourceError(id() + ": " + name() + " is a " + stat->type_label() + ", not a git checkout");
  if (shell().run("test -d " + quote(name() + "/.git")).success()) return true;
  if (strip(shell().run_checked("ls -A " + quote(name())).stdout_text).empty()) return false;
  throw ResourceError(id() + ": " + name() + " is a directory with files in it, but not a git checkout");
}

// The commit revision names on the remote, or nothing when git is not
// installed yet: a plan on a fresh machine then shows the revision as
// written, and apply, which runs after the package is installed, resolves
// it.
std::optional<std::string> GitResource::remote_commit() {
  if (is_commit(revision())) return revision();
  if (!shell().run("command -v git").success()) return std::nullopt;

  auto refs = remote_refs();
  for (const std::string &ref : ref_candidates()) {
    auto found = refs.find(ref);
    if (found != refs.end()) return found->second;
  }
  throw ResourceError(id() + ": " + opt("repository").to_s() + " has no branch or tag named " + revision());
}

// Tags first, peeled to their commit, then branches, as git itself
// resolves a name.
std::vector<std::string> GitResource::ref_candidates() const {
  if (revision() == "HEAD") return {"HEAD"};
  return {"refs/tags/" + revision() + "^{}", "refs/tags/" + revision(), "refs/heads/" + revision()};
}

std::map<std::string, std::string> GitResource::remote_refs() {
  std::string patterns;
  for (const std::string &ref : ref_candidates()) patterns += (patterns.empty() ? "" : " ") + quote(ref);
  CommandResult result = git("ls-remote " + quote(opt("repository").to_s()) + " " + patterns);
  if (!result.success()) {
    throw ResourceError(id() + ": cannot read " + opt("repository").to_s() + ": " + CommandFailed::describe(result));
  }

  std::map<std::string, std::string> refs;
  std::istringstream lines(result.stdout_text);
  std::string entry;
  while (std::getline(lines, entry)) {
    std::size_t tab = entry.find('\t');
    if (tab != std::string::npos) refs[strip(entry.substr(tab + 1))] = entry.substr(0, tab);
  }
  return refs;
}

void GitResource::require_git() {
  if (shell().run("command -v git").success()) return;
  throw ResourceError(id() + ": git is not installed (declare (package \"git\") before this resource)");
}

bool GitResource::is_commit(const std::string &text) {
  return text.size() == 40 && text.find_first_not_of("0123456789abcdef") == std::string::npos;
}

CommandResult GitResource::git(const std::string &arguments) { return shell().run(command_line(arguments)); }

CommandResult GitResource::git_checked(const std::string &arguments) { return shell().run_checked(command_line(arguments)); }

// Never prompts for credentials: there is nobody to answer. As root, a
// checkout that belongs to another user is still trusted.
std::string GitResource::command_line(const std::string &arguments) const {
  if (given("user")) {
    std::string inner = "cd / && GIT_TERMINAL_PROMPT=0 git " + arguments;
    return "su -s /bin/sh " + quote(opt("user").to_s()) + " -c " + quote(inner);
  }
  return "GIT_TERMINAL_PROMPT=0 git -c safe.directory=" + quote(name()) + " " + arguments;
}

}  // namespace sadame
