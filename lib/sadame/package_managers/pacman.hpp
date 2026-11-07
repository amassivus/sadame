#pragma once

#include "base.hpp"

namespace sadame {
namespace PackageManagers {

class Pacman : public Base {
 public:
  using Base::Base;

  std::string name() const override { return "pacman"; }
  std::string query_command(const std::string &package) const override;
  std::string install_command(const std::string &package, const Value &options = Value()) const override;
  std::string remove_command(const std::string &package, const Value &options = Value()) const override;
};

}  // namespace PackageManagers
}  // namespace sadame
