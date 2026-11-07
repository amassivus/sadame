#include "pacman.hpp"

namespace sadame {
namespace PackageManagers {

std::string Pacman::query_command(const std::string &package) const { return "pacman -Q " + Shell::escape(package); }

std::string Pacman::install_command(const std::string &package, const Value &options) const {
  return "pacman -S --needed --noconfirm " + extra_flags(options) + Shell::escape(package);
}

std::string Pacman::remove_command(const std::string &package, const Value &options) const {
  return "pacman -Rns --noconfirm " + extra_flags(options) + Shell::escape(package);
}

}  // namespace PackageManagers
}  // namespace sadame
