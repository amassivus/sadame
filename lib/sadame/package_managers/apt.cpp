#include "apt.hpp"

#include "../errors.hpp"

namespace sadame {
namespace PackageManagers {

bool Apt::installed(const std::string &package) {
  CommandResult result = shell_.run(query_command(package));
  if (!result.success()) return false;
  std::string text = strip(result.stdout_text);
  std::size_t space = text.rfind(' ');
  return (space == std::string::npos ? text : text.substr(space + 1)) == "installed";
}

void Apt::install(const std::string &package, const Value &options) {
  update_index();
  Base::install(package, options);
}

std::string Apt::query_command(const std::string &package) const {
  return "dpkg-query -W -f='${Status}' " + Shell::escape(package);
}

std::string Apt::install_command(const std::string &package, const Value &options) const {
  return "DEBIAN_FRONTEND=noninteractive apt-get install -y " + extra_flags(options) + Shell::escape(package);
}

std::string Apt::remove_command(const std::string &package, const Value &options) const {
  return "DEBIAN_FRONTEND=noninteractive apt-get remove -y " + extra_flags(options) + Shell::escape(package);
}

std::string Apt::update_command() const { return "DEBIAN_FRONTEND=noninteractive apt-get update"; }

void Apt::update_index() {
  if (index_updated_) return;
  shell_.run_checked(update_command());
  index_updated_ = true;
}

}  // namespace PackageManagers
}  // namespace sadame
