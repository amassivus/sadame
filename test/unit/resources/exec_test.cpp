#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/exec.hpp"

using namespace sadame;
using namespace test;

namespace {

std::unique_ptr<ExecResource> exec_resource(Machine &machine, const std::string &command, const Value &options = Value::map()) {
  return build_resource<ExecResource>(machine.host, command, options);
}

}  // namespace

TEST(ExecResource, not_if_success_skips_the_command) {
  auto machine = linux_machine();
  auto exec = exec_resource(*machine, "make install", map({{"not_if", "test -f /usr/bin/app"}}));
  EXPECT_EMPTY(exec->diff());
}

TEST(ExecResource, not_if_failure_runs_the_command) {
  auto machine = linux_machine();
  machine->shell.on("test -f /usr/bin/app", "", "", 1);
  auto exec = exec_resource(*machine, "make install", map({{"not_if", "test -f /usr/bin/app"}}));
  auto changes = exec->diff();
  EXPECT_EQ(std::string("run"), exec->plan_action(changes));
  EXPECT_EQ(std::string("command"), changes.front().attribute);
  EXPECT_EQ(std::string("not-if exited non-zero"), changes.front().reason.value());

  exec->apply(changes);
  EXPECT_EQ(std::string("make install"), machine->shell.commands.back());
}

TEST(ExecResource, only_if) {
  auto machine = linux_machine();
  machine->shell.on("test -f /etc/app.conf", "", "", 1);
  EXPECT_EMPTY(exec_resource(*machine, "reload", map({{"only_if", "test -f /etc/app.conf"}}))->diff());

  auto other = linux_machine();
  auto exec = exec_resource(*other, "reload", map({{"only_if", "test -f /etc/app.conf"}}));
  EXPECT_EQ(std::string("only-if exited zero"), exec->diff().front().reason.value());
}

TEST(ExecResource, creates) {
  auto machine = linux_machine();
  machine->shell.on("test -e /usr/local/bin/app", "", "", 1);
  auto exec = exec_resource(*machine, "make install", map({{"creates", "/usr/local/bin/app"}}));
  EXPECT_EQ(std::string("/usr/local/bin/app does not exist"), exec->diff().front().reason.value());

  auto done = linux_machine();
  EXPECT_EMPTY(exec_resource(*done, "make install", map({{"creates", "/usr/local/bin/app"}}))->diff());
}

TEST(ExecResource, without_guards_it_always_runs) {
  auto machine = linux_machine();
  auto exec = exec_resource(*machine, "date");
  EXPECT_EQ(std::string("no guard, runs on every apply"), exec->diff().front().reason.value());
}

TEST(ExecResource, cwd_and_env_wrap_the_command_and_guards) {
  auto machine = linux_machine();
  machine->shell.on("export MODE=fast\ncd /opt/app && {\ntest -f built\n}", "", "", 1);
  auto exec = exec_resource(*machine, "make", map({{"cwd", "/opt/app"}, {"env", map({{"MODE", "fast"}})}, {"not_if", "test -f built"}}));
  auto changes = exec->diff();
  EXPECT_EQ(1, static_cast<int>(changes.size()));

  exec->apply(changes);
  EXPECT_EQ(std::string("export MODE=fast\ncd /opt/app && {\nmake\n}"), machine->shell.commands.back());
}

TEST(ExecResource, command_option_overrides_the_name) {
  auto machine = linux_machine();
  auto exec = exec_resource(*machine, "reload daemons", map({{"command", "systemctl daemon-reload"}}));
  exec->apply(exec->diff());
  EXPECT_EQ(std::string("systemctl daemon-reload"), machine->shell.commands.back());
  EXPECT_EQ(std::string("exec[reload daemons]"), exec->id());
}

TEST(ExecResource, failure_raises_with_output) {
  auto machine = linux_machine();
  machine->shell.on("false", "", "it broke\n", 1);
  auto exec = exec_resource(*machine, "false");
  EXPECT_THROWS(CommandFailed, exec->apply(exec->diff()), "command failed (exit 1): false\nit broke");
}

TEST(ExecResource, action_nothing_has_no_changes_but_runs_when_notified) {
  auto machine = linux_machine();
  auto exec = exec_resource(*machine, "systemctl daemon-reload", map({{"action", sym("nothing")}}));
  EXPECT_EMPTY(exec->diff());
  exec->run_action("run");
  EXPECT_EQ(std::string("systemctl daemon-reload"), machine->shell.commands.back());
  EXPECT_THROWS(ResourceError, exec->run_action("restart"), "does not support the restart action");
}

TEST(ExecResource, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, exec_resource(*machine, "x", map({{"action", sym("later")}})), "action must be one of run, nothing");
  EXPECT_THROWS(ResourceError, exec_resource(*machine, "x", map({{"cwd", 5}})), "cwd must be a string");
  EXPECT_THROWS(ResourceError, exec_resource(*machine, "x", map({{"env", "A=1"}})), "env must be an association list");
  EXPECT_THROWS(ResourceError, exec_resource(*machine, "x", map({{"env", map({{"1BAD", "x"}})}})), "not a valid variable name");
}
