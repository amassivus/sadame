#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/user.hpp"

using namespace sadame;
using namespace test;

namespace {

std::unique_ptr<UserResource> user_resource(Machine &machine, const Value &options = Value::map()) {
  return build_resource<UserResource>(machine.host, "deploy", options);
}

}  // namespace

TEST(UserResource, creates_a_missing_user) {
  auto machine = linux_machine();
  machine->shell.on("getent passwd deploy", "", "", 2);
  auto user = user_resource(*machine, map({{"shell", "/bin/bash"}, {"groups", list({"docker", "sudo"})}, {"uid", 1500}}));
  auto changes = user->diff();
  EXPECT_EQ(std::string("create"), user->plan_action(changes));

  user->apply(changes);
  EXPECT_EQ(std::string("useradd -m -u 1500 -s /bin/bash -G docker,sudo deploy"), machine->shell.commands.back());
}

TEST(UserResource, creates_a_system_user) {
  auto machine = linux_machine();
  machine->shell.on("getent passwd backup", "", "", 2);
  auto user = build_resource<UserResource>(machine->host, "backup", map({{"system", true}, {"home", "/var/lib/backup"}}));
  user->apply(user->diff());
  EXPECT_EQ(std::string("useradd -r -d /var/lib/backup backup"), machine->shell.commands.back());
}

TEST(UserResource, existing_user_without_differences) {
  auto machine = linux_machine();
  machine->shell.on("getent passwd deploy", "deploy:x:1001:1001::/home/deploy:/bin/bash\n");
  machine->shell.on("id -nG deploy", "deploy docker\n");
  EXPECT_EMPTY(user_resource(*machine, map({{"shell", "/bin/bash"}, {"home", "/home/deploy"}, {"groups", list({"docker"})}}))->diff());
}

TEST(UserResource, adds_missing_groups_and_changes_the_shell) {
  auto machine = linux_machine();
  machine->shell.on("getent passwd deploy", "deploy:x:1001:1001::/home/deploy:/bin/sh\n");
  machine->shell.on("id -nG deploy", "deploy\n");
  auto user = user_resource(*machine, map({{"shell", "/bin/bash"}, {"groups", list({"docker"})}}));
  auto changes = user->diff();
  EXPECT_EQ((std::vector<std::string>{"shell", "groups"}), change_attributes(changes));

  user->apply(changes);
  EXPECT_EQ(std::string("usermod -s /bin/bash -a -G docker deploy"), machine->shell.commands.back());
}

TEST(UserResource, removes_a_user) {
  auto machine = linux_machine();
  machine->shell.on("getent passwd deploy", "deploy:x:1001:1001::/home/deploy:/bin/sh\n");
  auto user = user_resource(*machine, map({{"state", sym("absent")}}));
  EXPECT_EQ(std::string("remove"), user->plan_action(user->diff()));
  user->apply(user->diff());
  EXPECT_EQ(std::string("userdel deploy"), machine->shell.commands.back());
}

TEST(UserResource, explains_missing_useradd) {
  auto machine = linux_machine("alpine");
  machine->shell.on("getent passwd deploy", "", "", 2);
  machine->shell.on("command -v useradd", "", "", 1);
  auto user = user_resource(*machine);
  EXPECT_THROWS(ResourceError, user->apply(user->diff()), "useradd is not installed");
}

TEST(UserResource, linux_only) {
  auto shell = std::make_unique<FakeShell>();
  shell->on("uname -s", "Darwin\n");
  Machine machine(std::move(shell));
  EXPECT_THROWS(ResourceError, user_resource(machine)->diff(), "the user resource only supports Linux");
}

TEST(UserResource, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, user_resource(*machine, map({{"uid", "1000"}})), "uid must be an integer");
  EXPECT_THROWS(ResourceError, user_resource(*machine, map({{"groups", "docker"}})), "groups must be a list of group names");
  EXPECT_THROWS(ResourceError, user_resource(*machine, map({{"system", "yes"}})), "system must be #t or #f");
}
