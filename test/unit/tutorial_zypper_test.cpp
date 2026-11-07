// The zypper package manager built step by step in
// docs/contributing/architecture.md. The page embeds the sections between the
// --8<-- markers, so the tutorial's code is compiled and tested like the real
// package managers. It lives here, not in lib/, because sadame does not ship
// zypper support.
#include "../support/test_helpers.hpp"

#include "../../lib/sadame/package_managers/base.hpp"
#include "../../lib/sadame/platform.hpp"

using namespace sadame;
using namespace test;

namespace tutorial {

// --8<-- [start:manager]
class Zypper : public sadame::PackageManagers::Base {
 public:
  using Base::Base;

  std::string name() const override { return "zypper"; }

  std::string query_command(const std::string &package) const override { return "rpm -q " + Shell::escape(package); }

  std::string install_command(const std::string &package, const Value &options = Value()) const override {
    return "zypper --non-interactive install " + extra_flags(options) + Shell::escape(package);
  }

  std::string remove_command(const std::string &package, const Value &options = Value()) const override {
    return "zypper --non-interactive remove " + extra_flags(options) + Shell::escape(package);
  }
};
// --8<-- [end:manager]

}  // namespace tutorial

// --8<-- [start:tests]
TEST(TutorialZypper, command_lines) {
  FakeShell shell;
  tutorial::Zypper zypper(shell);
  EXPECT_EQ(std::string("rpm -q nginx"), zypper.query_command("nginx"));
  EXPECT_EQ(std::string("zypper --non-interactive install nginx"), zypper.install_command("nginx"));
  EXPECT_EQ(std::string("zypper --non-interactive install --no-recommends nginx"),
            zypper.install_command("nginx", Value("--no-recommends")));
  EXPECT_EQ(std::string("zypper --non-interactive remove nginx"), zypper.remove_command("nginx"));
}

TEST(TutorialZypper, install_runs_the_command_and_failures_raise) {
  FakeShell shell;
  tutorial::Zypper zypper(shell);
  zypper.install("nginx");
  EXPECT_EQ(std::string("zypper --non-interactive install nginx"), shell.commands.back());

  shell.on("zypper --non-interactive install broken", "", "No provider of 'broken' found.\n", 104);
  EXPECT_THROWS(CommandFailed, zypper.install("broken"), "No provider of 'broken' found.");
}

TEST(TutorialZypper, installed_follows_the_query_status) {
  FakeShell shell;
  tutorial::Zypper zypper(shell);
  EXPECT_TRUE(zypper.installed("nginx"));
  shell.on("rpm -q missing", "", "", 1);
  EXPECT_FALSE(zypper.installed("missing"));
}
// --8<-- [end:tests]
