#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/group.hpp"

using namespace sadame;
using namespace test;

namespace {

std::unique_ptr<GroupResource> group_resource(Machine &machine, const Value &options = Value::map()) {
  return build_resource<GroupResource>(machine.host, "app", options);
}

}  // namespace

TEST(GroupResource, creates_a_group) {
  auto machine = linux_machine();
  machine->shell.on("getent group app", "", "", 2);
  auto group = group_resource(*machine, map({{"gid", 1500}, {"system", true}}));
  group->apply(group->diff());
  EXPECT_EQ(std::string("groupadd -r -g 1500 app"), machine->shell.commands.back());
}

TEST(GroupResource, an_existing_group_is_unchanged) {
  auto machine = linux_machine();
  machine->shell.on("getent group app", "app:x:1500:alice,bob\n");
  EXPECT_EMPTY(group_resource(*machine, map({{"gid", 1500}}))->diff());
}

TEST(GroupResource, changes_the_gid) {
  auto machine = linux_machine();
  machine->shell.on("getent group app", "app:x:1500:\n");
  auto group = group_resource(*machine, map({{"gid", 1600}}));
  auto changes = group->diff();
  EXPECT_EQ((std::vector<std::string>{"gid"}), change_attributes(changes));
  group->apply(changes);
  EXPECT_EQ(std::string("groupmod -g 1600 app"), machine->shell.commands.back());
}

TEST(GroupResource, removes_a_group) {
  auto machine = linux_machine();
  machine->shell.on("getent group app", "app:x:1500:\n");
  auto group = group_resource(*machine, map({{"state", sym("absent")}}));
  group->apply(group->diff());
  EXPECT_EQ(std::string("groupdel app"), machine->shell.commands.back());
}

TEST(GroupResource, busybox_tools_on_a_fresh_alpine) {
  auto machine = linux_machine("alpine");
  machine->shell.on("getent group app", "", "", 2);
  machine->shell.on("command -v groupadd", "", "", 1);
  auto group = group_resource(*machine, map({{"gid", 1500}, {"system", true}}));
  group->apply(group->diff());
  EXPECT_EQ(std::string("addgroup -g 1500 -S app"), machine->shell.commands.back());

  auto changing = linux_machine("alpine");
  changing->shell.on("getent group app", "app:x:1400:\n");
  changing->shell.on("command -v groupadd", "", "", 1);
  auto other = group_resource(*changing, map({{"gid", 1500}}));
  EXPECT_THROWS(ResourceError, other->apply(other->diff()), "changing a gid needs groupmod");
}

TEST(GroupResource, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, group_resource(*machine, map({{"gid", -1}})), "gid must be a non-negative integer");
  EXPECT_THROWS(ResourceError, group_resource(*machine, map({{"gid", "15"}})), "gid must be a non-negative integer");
}
