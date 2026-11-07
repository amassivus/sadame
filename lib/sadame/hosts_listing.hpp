#pragma once

#include <optional>
#include <ostream>
#include <string>
#include <vector>

#include "target.hpp"

namespace sadame {

// Output of `sadame hosts`: each selected target with the connection options
// and vars it would get, and where each var came from.
class HostsListing {
 public:
  HostsListing(std::ostream &io, bool color = false) : io_(io), color_(color) {}

  void render(const std::vector<Target> &targets, const std::optional<std::string> &inventory_path);
  void render_json(const std::vector<Target> &targets);

 private:
  void print_target(const Target &target);
  void print_vars(const Target &target);
  void field(const std::string &label, const std::string &value);
  std::string bold(const std::string &text) const;
  void line(const std::string &text = "");

  std::ostream &io_;
  bool color_;
};

}  // namespace sadame
