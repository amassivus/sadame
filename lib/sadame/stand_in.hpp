#pragma once

#include <string>

#include "facts.hpp"
#include "host.hpp"
#include "platform.hpp"
#include "shell.hpp"

namespace sadame {

// A machine that is not there, for `sadame validate`: recipes are evaluated
// against it to find their mistakes without connecting to anything. Its
// platform is one of the names in platform_names(), its facts are made up,
// and it refuses to run commands.
namespace StandIn {

// The systems --platform can name, in the order they are listed in messages.
const std::vector<std::string> &platform_names();

Platform platform(const std::string &name);

// Refuses every command: a recipe that runs one while it is evaluated, or a
// check that would need the machine, says so instead.
class RefusingShell : public Shell {
 public:
  CommandResult run(const std::string &command) override;
  int stream(const std::string &command, const std::function<void(const std::string &)> &on_line) override;
  std::optional<std::string> read_file(const std::string &path) override;
  void write_file(const std::string &path, const std::string &content) override;
};

// Plausible values for a small virtual server, so that recipes that compute
// with facts can be evaluated. The addresses are from the ranges set aside
// for documentation.
class MadeUpFacts : public Facts {
 public:
  using Facts::Facts;

 protected:
  Value read(const std::string &name) override;
};

namespace detail {
struct ShellHolder {
  RefusingShell shell;
};
}  // namespace detail

class StandInHost : private detail::ShellHolder, public Host {
 public:
  StandInHost(std::string name, std::vector<std::string> groups, Platform platform);

  const Platform &platform() override { return *platform_; }
  Facts &facts() override;
  std::string init_system() override;

 private:
  MadeUpFacts made_up_facts_;
};

}  // namespace StandIn
}  // namespace sadame
