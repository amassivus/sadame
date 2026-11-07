#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/link.hpp"

using namespace sadame;
using namespace test;

namespace {

const char *kPath = "/etc/nginx/sites-enabled/app";

std::unique_ptr<LinkResource> link_resource(Machine &machine, const Value &options) {
  return build_resource<LinkResource>(machine.host, kPath, options);
}

}  // namespace

TEST(LinkResource, creates_a_missing_link) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  auto link = link_resource(*machine, map({{"to", "/etc/nginx/sites-available/app"}}));
  auto changes = link->diff();
  EXPECT_EQ(std::string("create"), link->plan_action(changes));
  link->apply(changes);
  EXPECT_EQ(std::string("ln -sfn /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app"), machine->shell.commands.back());
}

TEST(LinkResource, a_link_to_the_target_is_unchanged) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "777", "root", "root", "symbolic link");
  machine->shell.on("readlink /etc/nginx/sites-enabled/app", "/etc/nginx/sites-available/app\n");
  EXPECT_EMPTY(link_resource(*machine, map({{"to", "/etc/nginx/sites-available/app"}}))->diff());
}

TEST(LinkResource, repoints_a_link) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "777", "root", "root", "symbolic link");
  machine->shell.on("readlink /etc/nginx/sites-enabled/app", "/old\n");
  auto link = link_resource(*machine, map({{"to", "/new"}}));
  auto changes = link->diff();
  EXPECT_EQ(std::string("update"), link->plan_action(changes));
  EXPECT_EQ(Value("/old"), changes.front().from);
  link->apply(changes);
  EXPECT_EQ(std::string("ln -sfn /new /etc/nginx/sites-enabled/app"), machine->shell.commands.back());
}

TEST(LinkResource, relative_targets_are_compared_as_written) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "777", "root", "root", "symbolic link");
  machine->shell.on("readlink /etc/nginx/sites-enabled/app", "../sites-available/app\n");
  EXPECT_EMPTY(link_resource(*machine, map({{"to", "../sites-available/app"}}))->diff());
}

TEST(LinkResource, removes_a_link) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "777", "root", "root", "symbolic link");
  machine->shell.on("readlink /etc/nginx/sites-enabled/app", "/x\n");
  auto link = link_resource(*machine, map({{"state", sym("absent")}}));
  EXPECT_EQ(std::string("remove"), link->plan_action(link->diff()));
  link->apply(link->diff());
  EXPECT_EQ(std::string("rm -f /etc/nginx/sites-enabled/app"), machine->shell.commands.back());
}

TEST(LinkResource, a_regular_file_in_the_way) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath);
  EXPECT_THROWS(ResourceError, link_resource(*machine, map({{"to", "/x"}}))->diff(), "#:force #t replaces it");

  auto forced = linux_machine();
  stub_stat(forced->shell, kPath);
  auto link = link_resource(*forced, map({{"to", "/x"}, {"force", true}}));
  auto changes = link->diff();
  EXPECT_EQ(Value("regular file"), changes.front().from);
  link->apply(changes);
  EXPECT_EQ(std::string("ln -sfn /x /etc/nginx/sites-enabled/app"), forced->shell.commands.back());
}

TEST(LinkResource, a_directory_in_the_way_is_always_an_error) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "755", "root", "root", "directory");
  auto link = link_resource(*machine, map({{"to", "/x"}, {"force", true}}));
  EXPECT_THROWS(ResourceError, link->diff(), "is a directory, not a symbolic link");
}

TEST(LinkResource, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, link_resource(*machine, map()), "#:to must name the target of the link");
  EXPECT_THROWS(ResourceError, link_resource(*machine, map({{"to", "/x"}, {"state", sym("absent")}})), "#:to makes no sense");
}
