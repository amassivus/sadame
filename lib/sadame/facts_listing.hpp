#pragma once

#include <ostream>

#include "host.hpp"

namespace sadame {

// Output of `sadame facts`: every fact of one host, as recipes see them.
class FactsListing {
 public:
  FactsListing(std::ostream &io, bool color = false) : io_(io), color_(color) {}

  void render(Host &host);
  void render_json(Host &host);

 private:
  void line(const std::string &text = "") { io_ << text << "\n"; }

  std::ostream &io_;
  bool color_;
};

}  // namespace sadame
