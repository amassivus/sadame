#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/directory.hpp"

using namespace sadame;
using namespace test;

namespace {
const char *kPath = "/var/www/app";

std::unique_ptr<DirectoryResource> directory_resource(Machine &machine, const Value &options) {
  return build_resource<DirectoryResource>(machine.host, kPath, options);
}
}  // namespace

TEST(DirectoryResource, creates_a_missing_directory_with_mode_and_owner) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  auto directory = directory_resource(*machine, map({{"mode", "0755"}, {"owner", "www-data"}, {"group", "www-data"}}));
  auto changes = directory->diff();
  EXPECT_EQ(std::string("create"), directory->plan_action(changes));

  directory->apply(changes);
  EXPECT_EQ((std::vector<std::string>{"mkdir -p /var/www/app", "chmod 0755 /var/www/app",
                                      "chown www-data:www-data /var/www/app"}),
            machine->shell.last(3));
}

TEST(DirectoryResource, existing_directory_without_differences) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "755", "root", "root", "directory");
  EXPECT_EMPTY(directory_resource(*machine, map({{"mode", "0755"}, {"owner", "root"}}))->diff());
}

TEST(DirectoryResource, fixes_mode_only) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "700", "root", "root", "directory");
  auto directory = directory_resource(*machine, map({{"mode", "0755"}}));
  directory->apply(directory->diff());
  EXPECT_EQ(std::string("chmod 0755 /var/www/app"), machine->shell.commands.back());
}

TEST(DirectoryResource, removal) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "644", "root", "root", "directory");
  auto directory = directory_resource(*machine, map({{"state", sym("absent")}}));
  directory->apply(directory->diff());
  EXPECT_EQ(std::string("rmdir /var/www/app"), machine->shell.commands.back());

  auto second = linux_machine();
  stub_stat(second->shell, kPath, "644", "root", "root", "directory");
  auto recursive = directory_resource(*second, map({{"state", sym("absent")}, {"recursive", true}}));
  recursive->apply(recursive->diff());
  EXPECT_EQ(std::string("rm -rf /var/www/app"), second->shell.commands.back());
}

TEST(DirectoryResource, refuses_a_regular_file) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "644", "root", "root", "regular empty file");
  EXPECT_THROWS(ResourceError, directory_resource(*machine, map())->diff(), "is a regular file, not a directory");
}

TEST(DirectoryResource, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, directory_resource(*machine, map({{"mode", "rwx"}})), "mode must be a string");
  EXPECT_THROWS(ResourceError, directory_resource(*machine, map({{"recursive", "yes"}})), "recursive must be #t or #f");
  EXPECT_THROWS(ResourceError, directory_resource(*machine, map({{"state", sym("gone")}})), "state must be one of");
}
