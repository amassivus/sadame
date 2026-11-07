#include "service.hpp"

#include <algorithm>
#include <sstream>

namespace sadame {

Value ServiceResource::desired() {
  Value result = Value::map();
  if (has("enable")) result.set("enabled", opt("enable"));
  if (given("state")) result.set("state", opt("state").to_s());
  return result;
}

Value ServiceResource::current() {
  require_service_manager();
  Value result = Value::map();
  if (has("enable")) result.set("enabled", enabled());
  if (given("state")) result.set("state", active() ? "running" : "stopped");
  return result;
}

void ServiceResource::apply(const std::vector<Diff::Change> &changes) {
  if (changed(changes, "enabled")) {
    if (given("enable")) {
      enable();
    } else {
      disable();
    }
  }
  if (!changed(changes, "state")) return;
  control(opt("state").to_s() == "running" ? "start" : "stop");
}

void ServiceResource::run_action(const std::string &action) {
  auto supported = actions();
  if (std::find(supported.begin(), supported.end(), action) == supported.end()) {
    throw ResourceError(id() + " does not support the " + action + " action");
  }

  require_service_manager();
  if (action == "enable") {
    enable();
  } else if (action == "disable") {
    disable();
  } else {
    control(action);
  }
}

void ServiceResource::validate() {
  validate_choice("state", {"running", "stopped"});
  validate_boolean("enable");
  const Value &user = opt("user");
  if (user.is_nil() || (user.is_string() && !user.text().empty())) return;
  throw ResourceError(id() + ": user must be a user name");
}

void ServiceResource::require_service_manager() {
  std::string manager = host().init_system();
  if (manager == "systemd") return;
  if (manager == "openrc") {
    if (given("user")) throw ResourceError(id() + ": #:user needs systemd; this host runs OpenRC");
    return;
  }
  throw ResourceError(id() + ": no service manager is running on this host " +
                      "(the service resource needs systemd, or OpenRC as on Alpine)");
}

bool ServiceResource::enabled() {
  if (openrc()) return !runlevels().empty();
  return strip(shell().run(systemctl_command() + " is-enabled " + quote(name())).stdout_text) == "enabled";
}

bool ServiceResource::active() {
  if (openrc()) return shell().run("rc-service " + quote(name()) + " status").success();
  return strip(shell().run(systemctl_command() + " is-active " + quote(name())).stdout_text) == "active";
}

void ServiceResource::enable() {
  if (openrc()) {
    shell().run_checked("rc-update add " + quote(name()) + " default");
    return;
  }
  systemctl("enable");
}

void ServiceResource::disable() {
  if (!openrc()) {
    systemctl("disable");
    return;
  }

  std::vector<std::string> levels = runlevels();
  if (levels.empty()) return;
  std::string command;
  for (const std::string &level : levels) {
    if (!command.empty()) command += " && ";
    command += "rc-update del " + quote(name()) + " " + quote(level);
  }
  shell().run_checked(command);
}

// start, stop, restart or reload.
void ServiceResource::control(const std::string &verb) {
  if (openrc()) {
    shell().run_checked("rc-service " + quote(name()) + " " + verb);
    return;
  }
  systemctl(verb);
}

// The OpenRC runlevels the service is in, from lines of `rc-update show`
// such as "  nginx |      default".
std::vector<std::string> ServiceResource::runlevels() {
  std::istringstream lines(shell().run_checked("rc-update show").stdout_text);
  std::string entry;
  while (std::getline(lines, entry)) {
    std::size_t bar = entry.find('|');
    std::string service = strip(entry.substr(0, bar));
    if (service != name()) continue;

    std::vector<std::string> levels;
    if (bar != std::string::npos) {
      std::istringstream words(entry.substr(bar + 1));
      std::string level;
      while (words >> level) levels.push_back(level);
    }
    return levels;
  }
  return {};
}

void ServiceResource::systemctl(const std::string &verb) {
  shell().run_checked(systemctl_command() + " " + verb + " " + quote(name()));
}

std::string ServiceResource::systemctl_command() const {
  if (!given("user")) return "systemctl";
  return "systemctl --user -M " + quote(opt("user").to_s() + "@");
}

}  // namespace sadame
