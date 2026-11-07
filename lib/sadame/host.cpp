#include "host.hpp"

#include "facts.hpp"

namespace sadame {

Host::Host(Shell &shell, std::string name, std::vector<std::string> groups)
    : shell_(shell), name_(std::move(name)), groups_(std::move(groups)) {}

Host::~Host() = default;

const Platform &Host::platform() {
  if (!platform_) platform_ = Platform::detect(shell_);
  return *platform_;
}

PackageManagers::Base &Host::package_manager() {
  if (!package_manager_) package_manager_ = PackageManagers::for_platform(platform(), shell_);
  return *package_manager_;
}

Facts &Host::facts() {
  if (!facts_) facts_ = std::make_unique<Facts>(*this);
  return *facts_;
}

std::string Host::init_system() {
  if (!init_system_) {
    if (shell_.run("test -d /run/systemd/system").success()) {
      init_system_ = "systemd";
    } else if (shell_.run("test -e /run/openrc/softlevel").success()) {
      init_system_ = "openrc";
    } else {
      init_system_ = "";
    }
  }
  return *init_system_;
}

}  // namespace sadame
