#include <sstream>

#include "../support/test_helpers.hpp"

#include "../../lib/sadame/output.hpp"
#include "../../lib/sadame/resource_collection.hpp"
#include "../../lib/sadame/runner.hpp"

using namespace sadame;
using namespace test;

namespace {

struct Declaration {
  std::string type;
  std::string name;
  Value options;
};

ResourceCollection collection(Machine &machine, const std::vector<Declaration> &declarations) {
  ResourceCollection resources;
  for (const Declaration &declaration : declarations) {
    resources.add(make_resource(declaration.type, declaration.name, declaration.options, machine.host, ".", Value::map()));
  }
  return resources;
}

// A clock that advances 1.5 seconds per call.
Runner::Clock fixed_clock() {
  auto ticks = std::make_shared<double>(100.0);
  return [ticks]() {
    double now = *ticks;
    *ticks += 1.5;
    return now;
  };
}

std::vector<std::string> statuses(const Report &report) {
  std::vector<std::string> result;
  for (const auto &entry : report.entries()) result.push_back(entry.status);
  return result;
}

// The commands run, without the platform detection.
std::vector<std::string> last_commands(const FakeShell &shell, std::size_t count) {
  std::vector<std::string> all;
  for (const std::string &command : shell.commands) {
    if (command != "uname -s") all.push_back(command);
  }
  std::size_t from = all.size() > count ? all.size() - count : 0;
  return std::vector<std::string>(all.begin() + static_cast<long>(from), all.end());
}

bool ran(const FakeShell &shell, const std::string &command) {
  for (const std::string &candidate : shell.commands) {
    if (candidate == command) return true;
  }
  return false;
}

struct Fixture {
  Fixture() : machine(fresh_machine("debian")), output(sink) {}

  Runner runner(Selection selection = Selection()) { return Runner(machine->host, output, fixed_clock(), selection); }

  std::unique_ptr<Machine> machine;
  std::ostringstream sink;
  Output::Json output;
};

}  // namespace

TEST(Runner, plan_reads_state_without_changing_anything) {
  Fixture fixture;
  auto resources = collection(*fixture.machine, {{"package", "nginx", map()}, {"exec", "date", map()}});
  Report report = fixture.runner().plan(resources);
  EXPECT_EQ((std::vector<std::string>{"create", "run"}), statuses(report));
  EXPECT_FALSE(ran(fixture.machine->shell, "date"));
  EXPECT_FALSE(report.failed());
}

TEST(Runner, plan_marks_failing_resources_and_continues) {
  Fixture fixture;
  fixture.machine->shell.on("test -d /run/systemd/system", "", "", 1);
  auto resources = collection(*fixture.machine, {{"service", "nginx", map({{"state", sym("running")}})}, {"package", "git", map()}});
  Report report = fixture.runner().plan(resources);
  EXPECT_EQ((std::vector<std::string>{"failed", "create"}), statuses(report));
  EXPECT_CONTAINS(report.entries().front().error.value(), "no service manager is running");
  EXPECT_TRUE(report.failed());
  EXPECT_EQ(2, report.exit_status());
}

TEST(Runner, apply_runs_delayed_notifications_once_at_the_end) {
  Fixture fixture;
  auto resources = collection(*fixture.machine, {{"service", "nginx", map()},
                                                 {"exec", "write a", map({{"notifies", list({sym("reload"), "service[nginx]"})}})},
                                                 {"exec", "write b", map({{"notifies", list({sym("reload"), "service[nginx]"})}})},
                                                 {"exec", "last", map()}});
  Report report = fixture.runner().apply(resources);
  EXPECT_EQ((std::vector<std::string>{"unchanged", "changed", "changed", "changed"}), statuses(report));
  EXPECT_EQ((std::vector<std::string>{"write a", "write b", "last", "systemctl reload nginx"}),
            last_commands(fixture.machine->shell, 4));
  EXPECT_EQ(1, static_cast<int>(report.notification_runs().size()));
}

TEST(Runner, unchanged_resources_do_not_notify) {
  Fixture fixture;
  fixture.machine->shell.on("test -e /done");
  auto resources = collection(*fixture.machine,
                              {{"service", "nginx", map()},
                               {"exec", "work", map({{"creates", "/done"}, {"notifies", list({sym("restart"), "service[nginx]"})}})}});
  Report report = fixture.runner().apply(resources);
  EXPECT_EMPTY(report.notification_runs());
  EXPECT_FALSE(ran(fixture.machine->shell, "systemctl restart nginx"));
}

TEST(Runner, apply_stops_at_the_first_failure) {
  Fixture fixture;
  fixture.machine->shell.on("broken", "", "nope\n", 1);
  auto resources = collection(*fixture.machine,
                              {{"service", "nginx", map()},
                               {"exec", "broken", map({{"notifies", list({sym("reload"), "service[nginx]"})}})},
                               {"exec", "after", map({{"notifies", list({sym("reload"), "service[nginx]"})}})}});
  Report report = fixture.runner().apply(resources);
  EXPECT_EQ((std::vector<std::string>{"unchanged", "failed", "skipped"}), statuses(report));
  EXPECT_CONTAINS(report.entries()[1].error.value(), "nope");
  EXPECT_FALSE(ran(fixture.machine->shell, "after"));
  EXPECT_FALSE(ran(fixture.machine->shell, "systemctl reload nginx"));
  EXPECT_TRUE(report.failed());
}

TEST(Runner, failed_notification_fails_the_run) {
  Fixture fixture;
  fixture.machine->shell.on("systemctl reload nginx", "", "Job failed\n", 1);
  auto resources = collection(*fixture.machine, {{"service", "nginx", map()},
                                                 {"exec", "work", map({{"notifies", list({sym("reload"), "service[nginx]"})}})}});
  Report report = fixture.runner().apply(resources);
  EXPECT_TRUE(report.notification_runs().front().failed());
  EXPECT_TRUE(report.failed());
}

TEST(Runner, immediate_notifications_run_right_after_the_resource) {
  Fixture fixture;
  Value notifies = list({list({sym("run"), "exec[systemctl daemon-reload]", sym("immediately")}),
                         list({sym("restart"), "service[app]"})});
  auto resources = collection(*fixture.machine,
                              {{"exec", "systemctl daemon-reload", map({{"action", sym("nothing")}})},
                               {"service", "app", map()},
                               {"exec", "write unit", map({{"notifies", notifies}})},
                               {"exec", "next step", map()}});
  Report report = fixture.runner().apply(resources);
  EXPECT_EQ((std::vector<std::string>{"write unit", "systemctl daemon-reload", "next step", "systemctl restart app"}),
            last_commands(fixture.machine->shell, 4));
  EXPECT_EQ(std::string("immediately"), report.notification_runs()[0].notification.timing);
  EXPECT_EQ(std::string("delayed"), report.notification_runs()[1].notification.timing);
}

TEST(Runner, failed_immediate_notification_stops_the_run) {
  Fixture fixture;
  fixture.machine->shell.on("systemctl daemon-reload", "", "Access denied\n", 1);
  Value notifies = list({list({sym("run"), "exec[systemctl daemon-reload]", sym("immediately")}),
                         list({sym("restart"), "service[app]"})});
  auto resources = collection(*fixture.machine,
                              {{"exec", "systemctl daemon-reload", map({{"action", sym("nothing")}})},
                               {"service", "app", map()},
                               {"exec", "write unit", map({{"notifies", notifies}})},
                               {"exec", "next step", map()}});
  Report report = fixture.runner().apply(resources);
  EXPECT_EQ((std::vector<std::string>{"unchanged", "unchanged", "changed", "skipped"}), statuses(report));
  EXPECT_FALSE(ran(fixture.machine->shell, "next step"));
  EXPECT_FALSE(ran(fixture.machine->shell, "systemctl restart app"));
  EXPECT_EQ(1, report.exit_status());
}

TEST(Runner, subscribers_are_notified) {
  Fixture fixture;
  auto resources = collection(*fixture.machine,
                              {{"exec", "write config", map()},
                               {"service", "nginx", map({{"subscribes", list({sym("restart"), "exec[write config]"})}})}});
  Report report = fixture.runner().apply(resources);
  EXPECT_EQ(std::string("exec[write config]"), report.notification_runs().front().notification.source_id);
  EXPECT_EQ((std::vector<std::string>{"systemctl restart nginx"}), last_commands(fixture.machine->shell, 1));
}

TEST(Runner, drift_exits_one_when_something_differs) {
  Fixture fixture;
  auto resources = collection(*fixture.machine, {{"package", "nginx", map()}});
  EXPECT_EQ(1, fixture.runner().drift(resources).exit_status());
  EXPECT_EQ(0, fixture.runner().plan(resources).exit_status());
}

TEST(Runner, drift_with_nothing_to_do_exits_zero) {
  Fixture fixture;
  fixture.machine->shell.on("dpkg-query -W -f='${Status}' nginx", "install ok installed");
  auto resources = collection(*fixture.machine, {{"package", "nginx", map()}});
  EXPECT_EQ(0, fixture.runner().drift(resources).exit_status());
}

TEST(Runner, the_report_records_the_duration_from_the_clock) {
  Fixture fixture;
  auto resources = collection(*fixture.machine, {{"package", "nginx", map()}});
  Report report = fixture.runner().plan(resources);
  EXPECT_EQ(1.5, report.duration.value());
}

TEST(Runner, selection_limits_what_is_read_but_notifications_still_reach_everything) {
  Fixture fixture;
  auto resources = collection(*fixture.machine,
                              {{"service", "nginx", map()},
                               {"exec", "work", map({{"tags", list({sym("config")})}, {"notifies", list({sym("reload"), "service[nginx]"})}})},
                               {"exec", "other", map()}});
  Report report = fixture.runner(Selection({"config"}, {})).apply(resources);
  EXPECT_EQ((std::vector<std::string>{"changed"}), statuses(report));
  EXPECT_EQ((std::vector<std::string>{"systemctl reload nginx"}), last_commands(fixture.machine->shell, 1));
  EXPECT_FALSE(ran(fixture.machine->shell, "other"));
}

TEST(Runner, human_output_shows_the_plan_and_a_summary) {
  auto machine = fresh_machine("debian");
  std::ostringstream out;
  Output::Human human(out, false);
  Runner runner(machine->host, human, fixed_clock());
  auto resources = collection(*machine, {{"package", "nginx", map()}, {"exec", "date", map()}});
  runner.plan(resources);
  EXPECT_CONTAINS(out.str(), "sadame 0.5.1 plan on local (Debian GNU/Linux 12 (bookworm))");
  EXPECT_CONTAINS(out.str(), "+ package[nginx]\n    state: absent -> installed\n");
  EXPECT_CONTAINS(out.str(), "! exec[date]\n    command: date\n    (no guard, runs on every apply)\n");
  EXPECT_CONTAINS(out.str(), "Plan: 1 to create, 0 to update, 0 to remove, 1 to run, 0 unchanged.\n");

  std::ostringstream applied;
  Output::Human second(applied, false);
  Runner apply_runner(machine->host, second, fixed_clock());
  apply_runner.apply(resources);
  EXPECT_CONTAINS(applied.str(), "changed    package[nginx]\n");
  EXPECT_CONTAINS(applied.str(), "Summary\n  changed      2  package[nginx]\n                  exec[date]\n  unchanged    0\n");
  EXPECT_CONTAINS(applied.str(), "Finished in 1.50s.\n");
}
