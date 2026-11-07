#pragma once

#include <optional>
#include <string>
#include <vector>

#include "value.hpp"

namespace sadame {

// A machine to run on over SSH, with the connection options and vars that
// apply to it.
struct Target {
  std::string name;
  std::string address;
  std::optional<std::string> user;
  std::optional<int> port;
  bool sudo = false;
  std::vector<std::string> ssh_opts;
  std::vector<std::string> groups;
  Value vars = Value::map();
  Value var_sources = Value::map();

  struct Spec {
    std::optional<std::string> user;
    std::string host;
    std::optional<int> port;
  };

  // Parses "[user@]host[:port]". IPv6 addresses go in brackets:
  // "admin@[2001:db8::1]:2222".
  static Spec parse(const std::string &spec);

  Value to_h() const;
};

}  // namespace sadame
