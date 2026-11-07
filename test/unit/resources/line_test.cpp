#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/line.hpp"

using namespace sadame;
using namespace test;

namespace {

const char *kPath = "/etc/ssh/sshd_config";

std::unique_ptr<LineResource> line_resource(Machine &machine, const std::string &name, const Value &extra,
                                            const std::string &content = "") {
  Value options = map({{"path", kPath}});
  for (std::size_t index = 0; index < extra.keys().size(); ++index) options.set(extra.keys()[index], extra.values()[index]);
  stub_stat(machine.shell, kPath, "640", "root", "ssh");
  machine.shell.files[kPath] = content;
  return build_resource<LineResource>(machine.host, name, options);
}

std::string edited(const std::string &content, const std::string &name, const Value &extra = Value::map()) {
  auto machine = linux_machine();
  auto line = line_resource(*machine, name, extra, content);
  auto changes = line->diff();
  return changes.empty() ? content : changes.front().to.to_s();
}

}  // namespace

TEST(LineResource, replaces_every_matching_line) {
  EXPECT_EQ(std::string("Port 22\nPermitRootLogin no\nUsePAM yes\nPermitRootLogin no\n"),
            edited("Port 22\n#PermitRootLogin yes\nUsePAM yes\n  PermitRootLogin prohibit-password\n", "PermitRootLogin no",
                   map({{"match", "^\\s*#?\\s*PermitRootLogin\\s"}})));
}

TEST(LineResource, appends_when_nothing_matches) {
  EXPECT_EQ(std::string("Port 22\nvm.swappiness = 10\n"), edited("Port 22\n", "vm.swappiness = 10"));
  EXPECT_EQ(std::string("Port 22\nvm.swappiness = 10\n"), edited("Port 22", "vm.swappiness = 10"));
  EXPECT_EQ(std::string("vm.swappiness = 10\n"), edited("", "vm.swappiness = 10"));
}

TEST(LineResource, an_existing_line_is_left_alone) {
  auto machine = linux_machine();
  auto line = line_resource(*machine, "Port 22", map(), "Port 22\nUsePAM yes\n");
  EXPECT_EMPTY(line->diff());
}

TEST(LineResource, removes_the_line_and_matching_lines) {
  EXPECT_EQ(std::string("UsePAM yes\n"),
            edited("Port 22\n#Port 2222\nUsePAM yes\n", "Port 22", map({{"state", sym("absent")}, {"match", "^#?Port "}})));
}

TEST(LineResource, line_option_sets_the_text) {
  EXPECT_EQ(std::string("a\n10.0.0.5 mirror.internal\n"),
            edited("a\n", "old mirror", map({{"line", "10.0.0.5 mirror.internal"}})));
}

TEST(LineResource, apply_keeps_mode_and_owner_and_verifies) {
  auto machine = linux_machine();
  auto line = line_resource(*machine, "Port 2222", map({{"match", "^Port "}, {"verify", "sshd -t -f %{path}"}}), "Port 22\n");
  auto changes = line->diff();
  EXPECT_EQ(std::string("update"), line->plan_action(changes));
  line->apply(changes);
  EXPECT_EQ((std::vector<std::string>{"write /etc/ssh/sshd_config.sadame-new", "chmod 0640 /etc/ssh/sshd_config.sadame-new",
                                      "chown root:ssh /etc/ssh/sshd_config.sadame-new",
                                      "sshd -t -f /etc/ssh/sshd_config.sadame-new",
                                      "mv -f /etc/ssh/sshd_config.sadame-new /etc/ssh/sshd_config"}),
            machine->shell.last(5));
  EXPECT_EQ(std::string("Port 2222\n"), machine->shell.files["/etc/ssh/sshd_config.sadame-new"]);
}

TEST(LineResource, a_missing_file_plans_the_line_and_fails_on_apply) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  auto line = build_resource<LineResource>(machine->host, "Port 22", map({{"path", kPath}}));
  auto changes = line->diff();
  EXPECT_EQ(Value("Port 22\n"), changes.front().to);
  EXPECT_CONTAINS(changes.front().reason.value(), "does not exist yet");
  EXPECT_THROWS(ResourceError, line->apply(changes), "line only edits existing files");

  auto absent = build_resource<LineResource>(machine->host, "Port 22", map({{"path", kPath}, {"state", sym("absent")}}));
  EXPECT_EMPTY(absent->diff());
}

TEST(LineResource, refuses_a_symbolic_link) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "777", "root", "root", "symbolic link");
  auto line = build_resource<LineResource>(machine->host, "Port 22", map({{"path", kPath}}));
  EXPECT_THROWS(ResourceError, line->diff(), "is a symbolic link, not a regular file");
}

TEST(LineResource, validation) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, build_resource<LineResource>(machine->host, "x", map()), "path must be the absolute path");
  EXPECT_THROWS(ResourceError, build_resource<LineResource>(machine->host, "a\nb", map({{"path", kPath}})), "single line");
  EXPECT_THROWS(ResourceError, build_resource<LineResource>(machine->host, "x", map({{"path", kPath}, {"match", "(unclosed"}})),
                "not a valid regular expression");
  EXPECT_THROWS(ResourceError, build_resource<LineResource>(machine->host, "x", map({{"path", kPath}, {"match", 5}})),
                "match must be a regular expression");
}
