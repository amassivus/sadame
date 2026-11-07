#include "package_managers.hpp"

#include "errors.hpp"
#include "package_managers/apk.hpp"
#include "package_managers/apt.hpp"
#include "package_managers/dnf.hpp"
#include "package_managers/pacman.hpp"

namespace sadame {
namespace PackageManagers {

const std::vector<std::string> &all() {
  static const std::vector<std::string> names = {"apt", "dnf", "apk", "pacman"};
  return names;
}

std::unique_ptr<Base> for_platform(const Platform &platform, Shell &shell) {
  auto name = platform.package_manager();
  if (name == "apt") return std::make_unique<Apt>(shell);
  if (name == "dnf") return std::make_unique<Dnf>(shell);
  if (name == "apk") return std::make_unique<Apk>(shell);
  if (name == "pacman") return std::make_unique<Pacman>(shell);

  std::string supported;
  for (const std::string &manager : all()) supported += (supported.empty() ? "" : ", ") + manager;
  throw ResourceError("no supported package manager on " + platform.description() + " (supported: " + supported + ")");
}

}  // namespace PackageManagers
}  // namespace sadame
