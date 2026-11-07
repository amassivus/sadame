#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/package.hpp"

using namespace sadame;
using namespace test;

namespace {

const std::map<std::string, std::string> kQueries = {
    {"debian", "dpkg-query -W -f='${Status}' nginx"}, {"ubuntu", "dpkg-query -W -f='${Status}' nginx"},
    {"rocky", "rpm -q nginx"},                         {"alpine", "apk info -e nginx"},
    {"arch", "pacman -Q nginx"},                       {"omarchy", "pacman -Q nginx"}};

const std::map<std::string, std::string> kInstalls = {
    {"debian", "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx"},
    {"ubuntu", "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx"},
    {"rocky", "dnf install -y nginx"},
    {"alpine", "apk add nginx"},
    {"arch", "pacman -S --needed --noconfirm nginx"},
    {"omarchy", "pacman -S --needed --noconfirm nginx"}};

const std::map<std::string, std::string> kRemovals = {
    {"debian", "DEBIAN_FRONTEND=noninteractive apt-get remove -y nginx"},
    {"rocky", "dnf remove -y nginx"},
    {"alpine", "apk del nginx"},
    {"arch", "pacman -Rns --noconfirm nginx"}};

std::unique_ptr<Machine> missing_package(const std::string &distribution) {
  auto machine = linux_machine(distribution);
  machine->shell.on(kQueries.at(distribution), "", "", 1);
  return machine;
}

std::unique_ptr<Machine> installed_package(const std::string &distribution) {
  auto machine = linux_machine(distribution);
  bool apt = distribution == "debian" || distribution == "ubuntu";
  machine->shell.on(kQueries.at(distribution), apt ? "install ok installed" : "nginx 1.26.2-1\n");
  return machine;
}

}  // namespace

TEST(PackageResource, plans_and_installs_a_missing_package_on_every_manager) {
  for (const auto &[distribution, install_command] : kInstalls) {
    auto machine = missing_package(distribution);
    auto package = build_resource<PackageResource>(machine->host, "nginx");
    auto changes = package->diff();
    EXPECT_EQ(std::string("create"), package->plan_action(changes));
    EXPECT_EQ(Value("absent"), changes.front().from);
    EXPECT_EQ(Value("installed"), changes.front().to);

    package->apply(changes);
    EXPECT_EQ(install_command, machine->shell.commands.back());
  }
}

TEST(PackageResource, installed_package_has_no_changes) {
  for (const auto &[distribution, query] : kQueries) {
    auto machine = installed_package(distribution);
    auto package = build_resource<PackageResource>(machine->host, "nginx");
    EXPECT_EMPTY(package->diff());
  }
}

TEST(PackageResource, removes_an_installed_package_when_absent) {
  for (const auto &[distribution, remove_command] : kRemovals) {
    auto machine = installed_package(distribution);
    auto package = build_resource<PackageResource>(machine->host, "nginx", map({{"state", sym("absent")}}));
    auto changes = package->diff();
    EXPECT_EQ(std::string("remove"), package->plan_action(changes));
    package->apply(changes);
    EXPECT_EQ(remove_command, machine->shell.commands.back());
  }
}

TEST(PackageResource, pacman_exact_command_sequence) {
  auto machine = missing_package("arch");
  auto package = build_resource<PackageResource>(machine->host, "nginx", map({{"options", "--asdeps"}}));
  package->apply(package->diff());
  EXPECT_EQ((std::vector<std::string>{"uname -s", "pacman -Q nginx", "pacman -S --needed --noconfirm --asdeps nginx"}),
            machine->shell.commands);
}

TEST(PackageResource, option_lists_are_quoted_flag_by_flag) {
  auto machine = missing_package("arch");
  auto package = build_resource<PackageResource>(machine->host, "nginx", map({{"options", list({"--asdeps", "--needed x"})}}));
  package->apply(package->diff());
  EXPECT_EQ(std::string("pacman -S --needed --noconfirm --asdeps '--needed x' nginx"), machine->shell.commands.back());
}

TEST(PackageResource, apt_updates_the_index_once_before_installing) {
  auto machine = missing_package("debian");
  auto first = build_resource<PackageResource>(machine->host, "nginx");
  first->apply(first->diff());
  auto second = build_resource<PackageResource>(machine->host, "curl");
  machine->shell.on("dpkg-query -W -f='${Status}' curl", "", "", 1);
  second->apply(second->diff());

  int updates = 0;
  for (const std::string &command : machine->shell.commands) {
    if (command == "DEBIAN_FRONTEND=noninteractive apt-get update") ++updates;
  }
  EXPECT_EQ(1, updates);
}

TEST(PackageResource, rejects_unknown_state) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, build_resource<PackageResource>(machine->host, "nginx", map({{"state", sym("latest")}})),
                "state must be one of installed, absent");
}

TEST(PackageResource, rejects_unknown_options) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, build_resource<PackageResource>(machine->host, "nginx", map({{"version", "1.2"}})),
                "package[nginx]: unknown option #:version");
}

TEST(PackageResource, option_names_may_use_dashes_or_underscores) {
  EXPECT_EQ(std::string("not_if"), Value::normalize_key("not-if"));
  EXPECT_EQ(std::string("not_if"), Value::normalize_key("not_if"));
}

TEST(PackageResource, an_unsupported_system_has_no_package_manager) {
  auto machine = linux_machine("debian");
  machine->shell.files["/etc/os-release"] = "ID=plan9\nPRETTY_NAME=\"Plan 9\"\n";
  auto package = build_resource<PackageResource>(machine->host, "nginx");
  EXPECT_THROWS(ResourceError, package->diff(), "no supported package manager on Plan 9");
}
