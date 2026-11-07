#include "dnf.hpp"

namespace sadame {
namespace PackageManagers {

std::string Dnf::query_command(const std::string &package) const { return "rpm -q " + Shell::escape(package); }

std::string Dnf::install_command(const std::string &package, const Value &options) const {
  return "dnf install -y " + extra_flags(options) + Shell::escape(package);
}

std::string Dnf::remove_command(const std::string &package, const Value &options) const {
  return "dnf remove -y " + extra_flags(options) + Shell::escape(package);
}

}  // namespace PackageManagers
}  // namespace sadame
