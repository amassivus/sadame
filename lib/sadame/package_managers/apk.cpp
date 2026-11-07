#include "apk.hpp"

namespace sadame {
namespace PackageManagers {

std::string Apk::query_command(const std::string &package) const { return "apk info -e " + Shell::escape(package); }

std::string Apk::install_command(const std::string &package, const Value &options) const {
  return "apk add " + extra_flags(options) + Shell::escape(package);
}

std::string Apk::remove_command(const std::string &package, const Value &options) const {
  return "apk del " + extra_flags(options) + Shell::escape(package);
}

}  // namespace PackageManagers
}  // namespace sadame
