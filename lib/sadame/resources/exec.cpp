#include "exec.hpp"
#include <cctype>

namespace sadame {

namespace {

bool valid_variable_name(const std::string &name) {
  if (name.empty() || std::isdigit(static_cast<unsigned char>(name[0]))) return false;
  return name.find_first_not_of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_") == std::string::npos;
}

}  // namespace

std::string ExecResource::command() const { return given("command") ? opt("command").to_s() : name(); }

std::vector<Diff::Change> ExecResource::diff() {
  if (text_opt("action") == std::optional<std::string>("nothing")) return {};

  auto reason = pending_reason();
  if (!reason) return {};
  return {Diff::Change{"command", Value(), Value(command()), reason}};
}

std::string ExecResource::plan_action(const std::vector<Diff::Change> &changes) const {
  return changes.empty() ? "unchanged" : "run";
}

void ExecResource::apply(const std::vector<Diff::Change> &) { shell().run_checked(script(command())); }

void ExecResource::run_action(const std::string &action) {
  if (action != "run") throw ResourceError(id() + " does not support the " + action + " action");
  shell().run_checked(script(command()));
}

std::string ExecResource::script(const std::string &text) const {
  std::string result;
  const Value &env = opt("env");
  if (env.is_map()) {
    for (std::size_t index = 0; index < env.keys().size(); ++index) {
      result += "export " + env.keys()[index] + "=" + quote(env.values()[index].to_s()) + "\n";
    }
  }
  if (given("cwd")) {
    result += "cd " + quote(opt("cwd").to_s()) + " && {\n" + text + "\n}";
  } else {
    result += text;
  }
  return result;
}

void ExecResource::validate() {
  validate_choice("action", {"run", "nothing"});
  for (const char *key : {"command", "only_if", "not_if", "creates", "cwd"}) {
    const Value &value = opt(key);
    if (value.is_nil() || value.is_string()) continue;
    throw ResourceError(id() + ": " + key + " must be a string, got " + value.type_name());
  }
  validate_env();
}

void ExecResource::validate_env() const {
  const Value &env = opt("env");
  if (env.is_nil()) return;
  if (!env.is_map_like()) throw ResourceError(id() + ": env must be an association list");

  for (const std::string &key : env.keys()) {
    if (!valid_variable_name(key)) throw ResourceError(id() + ": env key \"" + key + "\" is not a valid variable name");
  }
}

// Why the command still has to run, or nothing when a guard says it is done.
std::optional<std::string> ExecResource::pending_reason() {
  std::vector<std::string> reasons;
  if (given("creates")) {
    if (guard_passes("test -e " + quote(opt("creates").to_s()))) return std::nullopt;
    reasons.push_back(opt("creates").to_s() + " does not exist");
  }
  if (given("not_if")) {
    if (guard_passes(opt("not_if").to_s())) return std::nullopt;
    reasons.push_back("not-if exited non-zero");
  }
  if (given("only_if")) {
    if (!guard_passes(opt("only_if").to_s())) return std::nullopt;
    reasons.push_back("only-if exited zero");
  }
  if (reasons.empty()) return std::string("no guard, runs on every apply");

  std::string joined;
  for (const std::string &reason : reasons) joined += (joined.empty() ? "" : ", ") + reason;
  return joined;
}

bool ExecResource::guard_passes(const std::string &guard) { return shell().run(script(guard)).success(); }

}  // namespace sadame
