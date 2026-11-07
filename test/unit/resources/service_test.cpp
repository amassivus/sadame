#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/service.hpp"

using namespace sadame;
using namespace test;

namespace {

std::unique_ptr<Machine> systemd_machine(const std::string &enabled = "disabled", const std::string &active = "inactive") {
  auto machine = linux_machine();
  machine->shell.on("test -d /run/systemd/system");
  machine->shell.on("systemctl is-enabled nginx", enabled + "\n", "", enabled == "enabled" ? 0 : 1);
  machine->shell.on("systemctl is-active nginx", active + "\n", "", active == "active" ? 0 : 3);
  return machine;
}

std::unique_ptr<Machine> openrc_machine(bool in_default_runlevel, bool running) {
  auto machine = linux_machine("alpine");
  machine->shell.on("test -d /run/systemd/system", "", "", 1);
  machine->shell.on("test -e /run/openrc/softlevel");
  machine->shell.on("rc-update show", in_default_runlevel ? "  nginx |      default\n  sshd  | default boot\n" : "  sshd | default\n");
  machine->shell.on("rc-service nginx status", "", "", running ? 0 : 3);
  return machine;
}

std::unique_ptr<ServiceResource> service_resource(Machine &machine, const Value &options) {
  return build_resource<ServiceResource>(machine.host, "nginx", options);
}

}  // namespace

TEST(ServiceResource, enables_and_starts_a_stopped_service) {
  auto machine = systemd_machine();
  auto service = service_resource(*machine, map({{"enable", true}, {"state", sym("running")}}));
  auto changes = service->diff();
  EXPECT_EQ(std::string("update"), service->plan_action(changes));
  EXPECT_EQ((std::vector<std::string>{"enabled", "state"}), change_attributes(changes));

  service->apply(changes);
  EXPECT_EQ((std::vector<std::string>{"systemctl enable nginx", "systemctl start nginx"}), machine->shell.last(2));
}

TEST(ServiceResource, running_and_enabled_service_has_no_changes) {
  auto machine = systemd_machine("enabled", "active");
  EXPECT_EMPTY(service_resource(*machine, map({{"enable", true}, {"state", sym("running")}}))->diff());
}

TEST(ServiceResource, disables_and_stops) {
  auto machine = systemd_machine("enabled", "active");
  auto service = service_resource(*machine, map({{"enable", false}, {"state", sym("stopped")}}));
  service->apply(service->diff());
  EXPECT_EQ((std::vector<std::string>{"systemctl disable nginx", "systemctl stop nginx"}), machine->shell.last(2));
}

TEST(ServiceResource, only_manages_the_attributes_given) {
  auto machine = systemd_machine("disabled", "active");
  EXPECT_EMPTY(service_resource(*machine, map({{"state", sym("running")}}))->diff());
  for (const std::string &command : machine->shell.commands) EXPECT_TRUE(command != "systemctl is-enabled nginx");
}

TEST(ServiceResource, notification_actions) {
  auto machine = systemd_machine();
  auto service = service_resource(*machine, map());
  service->run_action("reload");
  EXPECT_EQ(std::string("systemctl reload nginx"), machine->shell.commands.back());
  EXPECT_EQ((std::vector<std::string>{"start", "stop", "restart", "reload", "enable", "disable"}), service->actions());
  EXPECT_THROWS(ResourceError, service->run_action("explode"), "does not support the explode action");
}

TEST(ServiceResource, user_units_use_the_users_systemd_instance) {
  auto machine = linux_machine();
  machine->shell.on("test -d /run/systemd/system");
  machine->shell.on("systemctl --user -M alice@ is-enabled backup.timer", "disabled\n", "", 1);
  auto service = build_resource<ServiceResource>(machine->host, "backup.timer", map({{"user", "alice"}, {"enable", true}}));
  service->apply(service->diff());
  EXPECT_EQ(std::string("systemctl --user -M alice@ enable backup.timer"), machine->shell.commands.back());
}

TEST(ServiceResource, requires_a_service_manager) {
  auto machine = linux_machine();
  machine->shell.on("test -d /run/systemd/system", "", "", 1).on("test -e /run/openrc/softlevel", "", "", 1);
  EXPECT_THROWS(ResourceError, service_resource(*machine, map({{"state", sym("running")}}))->diff(),
                "no service manager is running on this host");
}

TEST(ServiceResource, openrc_enables_and_starts) {
  auto machine = openrc_machine(false, false);
  auto service = service_resource(*machine, map({{"enable", true}, {"state", sym("running")}}));
  service->apply(service->diff());
  EXPECT_EQ((std::vector<std::string>{"rc-update add nginx default", "rc-service nginx start"}), machine->shell.last(2));
}

TEST(ServiceResource, openrc_running_and_enabled_service_has_no_changes) {
  auto machine = openrc_machine(true, true);
  EXPECT_EMPTY(service_resource(*machine, map({{"enable", true}, {"state", sym("running")}}))->diff());
}

TEST(ServiceResource, openrc_disable_removes_the_service_from_every_runlevel) {
  auto machine = linux_machine("alpine");
  machine->shell.on("test -d /run/systemd/system", "", "", 1).on("test -e /run/openrc/softlevel");
  machine->shell.on("rc-update show", "  nginx | default boot\n");
  auto service = service_resource(*machine, map({{"enable", false}}));
  service->apply(service->diff());
  EXPECT_EQ(std::string("rc-update del nginx default && rc-update del nginx boot"), machine->shell.commands.back());
}

TEST(ServiceResource, openrc_notification_actions) {
  auto machine = openrc_machine(true, true);
  service_resource(*machine, map())->run_action("restart");
  EXPECT_EQ(std::string("rc-service nginx restart"), machine->shell.commands.back());
}

TEST(ServiceResource, openrc_has_no_user_services) {
  auto machine = openrc_machine(true, true);
  auto service = build_resource<ServiceResource>(machine->host, "nginx", map({{"user", "alice"}, {"enable", true}}));
  EXPECT_THROWS(ResourceError, service->diff(), "#:user needs systemd; this host runs OpenRC");
}

TEST(ServiceResource, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, service_resource(*machine, map({{"state", sym("paused")}})), "state must be one of running, stopped");
  EXPECT_THROWS(ResourceError, service_resource(*machine, map({{"enable", "yes"}})), "enable must be #t or #f");
  EXPECT_THROWS(ResourceError, service_resource(*machine, map({{"user", ""}})), "user must be a user name");
}
