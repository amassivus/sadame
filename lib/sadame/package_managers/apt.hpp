#pragma once

#include "base.hpp"

namespace sadame {
namespace PackageManagers {

class Apt : public Base {
 public:
  using Base::Base;

  std::string name() const override { return "apt"; }
  bool installed(const std::string &package) override;
  void install(const std::string &package, const Value &options = Value()) override;
  std::string query_command(const std::string &package) const override;
  std::string install_command(const std::string &package, const Value &options = Value()) const override;
  std::string remove_command(const std::string &package, const Value &options = Value()) const override;
  std::string update_command() const;

 private:
  void update_index();

  bool index_updated_ = false;
};

}  // namespace PackageManagers
}  // namespace sadame
