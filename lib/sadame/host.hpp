#pragma once

#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "package_managers.hpp"
#include "platform.hpp"
#include "shell.hpp"
#include "value.hpp"

namespace sadame {

class Facts;

// The machine being configured: its shell plus what is read from it once
// and then reused by every resource, including the facts recipes see.
class Host {
 public:
  // name and groups are what recipes see as (host-name) and (host-groups).
  explicit Host(Shell &shell, std::string name = "local", std::vector<std::string> groups = {});
  virtual ~Host();

  Shell &shell() { return shell_; }
  const std::string &name() const { return name_; }
  const std::vector<std::string> &groups() const { return groups_; }

  virtual const Platform &platform();
  PackageManagers::Base &package_manager();
  virtual Facts &facts();

  // The service manager running on the host: "systemd", "openrc" (Alpine),
  // or "" when neither runs, as in most containers.
  virtual std::string init_system();
  bool systemd() { return init_system() == "systemd"; }

 protected:
  Shell &shell_;
  std::string name_;
  std::vector<std::string> groups_;
  std::optional<Platform> platform_;
  std::unique_ptr<PackageManagers::Base> package_manager_;
  std::unique_ptr<Facts> facts_;
  std::optional<std::string> init_system_;
};

}  // namespace sadame
