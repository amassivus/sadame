#include "base.hpp"

namespace sadame {
namespace PackageManagers {

bool Base::installed(const std::string &package) { return shell_.run(query_command(package)).success(); }

void Base::install(const std::string &package, const Value &options) {
  shell_.run_checked(install_command(package, options));
}

void Base::remove(const std::string &package, const Value &options) {
  shell_.run_checked(remove_command(package, options));
}

std::string Base::extra_flags(const Value &options) {
  if (options.is_nil()) return "";
  if (options.is_array()) {
    std::string result;
    for (const Value &flag : options.items()) result += Shell::escape(flag.to_s()) + " ";
    return result;
  }
  return options.to_s() + " ";
}

}  // namespace PackageManagers
}  // namespace sadame
