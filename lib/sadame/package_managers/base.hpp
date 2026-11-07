#pragma once

#include <memory>
#include <string>

#include "../shell.hpp"
#include "../value.hpp"

namespace sadame {

class Platform;

namespace PackageManagers {

// Common behaviour of the package managers. A subclass provides the three
// command lines; everything else is shared.
class Base {
 public:
  explicit Base(Shell &shell) : shell_(shell) {}
  virtual ~Base() = default;

  virtual std::string name() const = 0;
  virtual bool installed(const std::string &package);
  virtual void install(const std::string &package, const Value &options = Value());
  void remove(const std::string &package, const Value &options = Value());

  virtual std::string query_command(const std::string &package) const = 0;
  virtual std::string install_command(const std::string &package, const Value &options = Value()) const = 0;
  virtual std::string remove_command(const std::string &package, const Value &options = Value()) const = 0;

 protected:
  // Extra flags from the package resource's options: argument, given as a
  // string (used as is) or an array (each element quoted).
  static std::string extra_flags(const Value &options);

  Shell &shell_;
};

}  // namespace PackageManagers
}  // namespace sadame
