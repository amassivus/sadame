// The cron resource built step by step in docs/contributing/architecture.md.
// The page embeds the sections between the --8<-- markers, so the tutorial's
// code is compiled and tested like the real resources. It lives here, not in
// lib/, because sadame does not ship a cron resource.
#include <sstream>

#include "../support/test_helpers.hpp"

#include "../../lib/sadame/path_stat.hpp"

using namespace sadame;
using namespace test;

namespace tutorial {

// --8<-- [start:resource]
// Manages one cron job as a file in /etc/cron.d.
//
//   (cron "backup" #:schedule "0 3 * * *" #:command "/usr/local/bin/backup")
class CronResource : public sadame::Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "cron"; }
  std::vector<std::string> allowed_options() const override { return {"schedule", "command", "user", "state"}; }

  std::string path() const { return "/etc/cron.d/" + name(); }

  Value desired() override {
    Value result = Value::map();
    if (absent()) {
      result.set("state", "absent");
      return result;
    }
    result.set("state", "present");
    result.set("content", opt("schedule").to_s() + " " + user() + " " + opt("command").to_s() + "\n");
    return result;
  }

  Value current() override {
    Value result = Value::map();
    auto content = shell().read_file(path());
    if (!content) {
      result.set("state", "absent");
      return result;
    }
    result.set("state", "present");
    result.set("content", *content);
    return result;
  }

  void apply(const std::vector<Diff::Change> &) override {
    if (absent()) {
      shell().run_checked("rm -f " + quote(path()));
    } else {
      shell().write_file(path(), desired().get("content").to_s());
      shell().run_checked("chmod 0644 " + quote(path()));
    }
  }

 protected:
  void validate() override {
    validate_choice("state", {"present", "absent"});
    if (name().find_first_not_of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_") != std::string::npos) {
      throw ResourceError(id() + ": cron.d file names may only use letters, digits, - and _");
    }
    if (absent()) return;

    for (const char *key : {"schedule", "command"}) {
      if (!opt(key).is_string()) throw ResourceError(id() + ": " + key + " is required");
    }
    std::istringstream fields(opt("schedule").text());
    std::string field;
    int count = 0;
    while (fields >> field) ++count;
    if (count != 5) throw ResourceError(id() + ": schedule needs five fields, such as \"0 3 * * *\"");
  }

 private:
  std::string user() const { return given("user") ? opt("user").to_s() : "root"; }
};
// --8<-- [end:resource]

}  // namespace tutorial

// --8<-- [start:tests]
namespace {

std::unique_ptr<tutorial::CronResource> cron(Machine &machine, const Value &options) {
  return build_resource<tutorial::CronResource>(machine.host, "backup", options);
}

}  // namespace

TEST(TutorialCron, creates_a_missing_job) {
  auto machine = linux_machine();
  auto job = cron(*machine, map({{"schedule", "0 3 * * *"}, {"command", "/usr/local/bin/backup"}}));
  auto changes = job->diff();
  EXPECT_EQ(std::string("create"), job->plan_action(changes));

  job->apply(changes);
  EXPECT_EQ(std::string("0 3 * * * root /usr/local/bin/backup\n"), machine->shell.files["/etc/cron.d/backup"]);
  EXPECT_EQ(std::string("chmod 0644 /etc/cron.d/backup"), machine->shell.commands.back());
}

TEST(TutorialCron, matching_job_has_no_changes) {
  auto machine = linux_machine();
  machine->shell.files["/etc/cron.d/backup"] = "0 3 * * * root /usr/local/bin/backup\n";
  EXPECT_EMPTY(cron(*machine, map({{"schedule", "0 3 * * *"}, {"command", "/usr/local/bin/backup"}}))->diff());
}

TEST(TutorialCron, changed_schedule_is_an_update) {
  auto machine = linux_machine();
  machine->shell.files["/etc/cron.d/backup"] = "0 3 * * * root /usr/local/bin/backup\n";
  auto job = cron(*machine, map({{"schedule", "30 4 * * *"}, {"command", "/usr/local/bin/backup"}}));
  auto changes = job->diff();
  EXPECT_EQ(std::string("update"), job->plan_action(changes));
  EXPECT_EQ((std::vector<std::string>{"content"}), change_attributes(changes));
}

TEST(TutorialCron, removes_a_job) {
  auto machine = linux_machine();
  machine->shell.files["/etc/cron.d/backup"] = "0 3 * * * root /usr/local/bin/backup\n";
  auto job = cron(*machine, map({{"state", sym("absent")}}));
  job->apply(job->diff());
  EXPECT_EQ(std::string("rm -f /etc/cron.d/backup"), machine->shell.commands.back());
}

TEST(TutorialCron, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, cron(*machine, map({{"schedule", "daily"}, {"command", "x"}})), "schedule needs five fields");
  EXPECT_THROWS(ResourceError, cron(*machine, map({{"schedule", "0 3 * * *"}})), "command is required");
  EXPECT_THROWS(ResourceError, build_resource<tutorial::CronResource>(machine->host, "bad name", map()),
                "file names may only use letters");
}
// --8<-- [end:tests]
