#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/file.hpp"

using namespace sadame;
using namespace test;

namespace {

const char *kPath = "/etc/motd";
const char *kSourceDir = "test/fixtures/recipes/templates_and_files";

std::unique_ptr<FileResource> file_resource(Machine &machine, const Value &options, const Value &vars = Value::map()) {
  return build_resource<FileResource>(machine.host, kPath, options, vars, kSourceDir);
}

}  // namespace

TEST(FileResource, creates_a_missing_file_with_mode) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  auto file = file_resource(*machine, map({{"content", "hello\n"}, {"mode", "0640"}}));
  auto changes = file->diff();
  EXPECT_EQ(std::string("create"), file->plan_action(changes));
  EXPECT_EQ((std::vector<std::string>{"state", "mode", "content"}), change_attributes(changes));

  file->apply(changes);
  EXPECT_EQ(std::string("hello\n"), machine->shell.files["/etc/motd.sadame-new"]);
  EXPECT_EQ((std::vector<std::string>{"write /etc/motd.sadame-new", "chmod 0640 /etc/motd.sadame-new",
                                      "mv -f /etc/motd.sadame-new /etc/motd"}),
            machine->shell.last(3));
}

TEST(FileResource, matching_file_has_no_changes) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "644");
  machine->shell.files[kPath] = "hello\n";
  EXPECT_EMPTY(file_resource(*machine, map({{"content", "hello\n"}, {"mode", "0644"}, {"owner", "root"}, {"group", "root"}}))->diff());
}

TEST(FileResource, content_change_keeps_existing_mode_and_owner) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "600", "app", "staff");
  machine->shell.files[kPath] = "old\n";
  auto file = file_resource(*machine, map({{"content", "new\n"}}));
  auto changes = file->diff();
  EXPECT_EQ((std::vector<std::string>{"content"}), change_attributes(changes));
  EXPECT_EQ(Value("old\n"), changes.front().from);

  file->apply(changes);
  EXPECT_EQ((std::vector<std::string>{"write /etc/motd.sadame-new", "chmod 0600 /etc/motd.sadame-new",
                                      "chown app:staff /etc/motd.sadame-new", "mv -f /etc/motd.sadame-new /etc/motd"}),
            machine->shell.last(4));
}

TEST(FileResource, mode_and_owner_changes_do_not_rewrite_content) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "600");
  machine->shell.files[kPath] = "same\n";
  auto file = file_resource(*machine, map({{"content", "same\n"}, {"mode", "0644"}, {"owner", "www-data"}}));
  auto changes = file->diff();
  EXPECT_EQ((std::vector<std::string>{"mode", "owner"}), change_attributes(changes));

  file->apply(changes);
  EXPECT_EQ((std::vector<std::string>{"chmod 0644 /etc/motd", "chown www-data /etc/motd"}), machine->shell.last(2));
}

TEST(FileResource, group_only_change) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath);
  auto file = file_resource(*machine, map({{"group", "adm"}}));
  file->apply(file->diff());
  EXPECT_EQ(std::string("chown :adm /etc/motd"), machine->shell.commands.back());
}

TEST(FileResource, file_without_content_options_only_manages_metadata) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "644");
  machine->shell.files[kPath] = "anything\n";
  EXPECT_EMPTY(file_resource(*machine, map({{"mode", "0644"}}))->diff());
}

TEST(FileResource, missing_file_without_content_is_created_empty) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  auto file = file_resource(*machine, map());
  file->apply(file->diff());
  EXPECT_EQ(std::string(""), machine->shell.files["/etc/motd.sadame-new"]);
}

TEST(FileResource, removes_a_file) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath);
  auto file = file_resource(*machine, map({{"state", sym("absent")}}));
  auto changes = file->diff();
  EXPECT_EQ(std::string("remove"), file->plan_action(changes));
  file->apply(changes);
  EXPECT_EQ(std::string("rm -f /etc/motd"), machine->shell.commands.back());
}

TEST(FileResource, absent_file_that_is_already_gone) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  EXPECT_EMPTY(file_resource(*machine, map({{"state", sym("absent")}}))->diff());
}

TEST(FileResource, refuses_to_replace_a_directory_or_symlink) {
  auto machine = linux_machine();
  stub_stat(machine->shell, kPath, "644", "root", "root", "directory");
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"content", "x"}}))->diff(),
                "/etc/motd is a directory, not a regular file");

  auto other = linux_machine();
  stub_stat(other->shell, kPath, "644", "root", "root", "symbolic link");
  EXPECT_THROWS(ResourceError, file_resource(*other, map({{"content", "x"}}))->diff(), "is a symbolic link");
}

TEST(FileResource, renders_templates_with_vars_and_locals) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  auto file = file_resource(*machine, map({{"template", "motd.tmpl"}, {"locals", map({{"greeting", "Welcome"}})}}),
                            map({{"host", "web1"}}));
  EXPECT_EQ(Value("Welcome to web1\n"), file->diff().back().to);
  EXPECT_EQ(std::string("test/fixtures/recipes/templates_and_files/templates/motd.tmpl"), file->local_file());
}

TEST(FileResource, copies_source_files) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  auto file = file_resource(*machine, map({{"source", "banner.txt"}}));
  EXPECT_EQ(Value("static banner\n"), file->diff().back().to);
  EXPECT_EQ(std::string("test/fixtures/recipes/templates_and_files/files/banner.txt"), file->local_file());
}

TEST(FileResource, missing_template_is_reported_when_declared) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"template", "nope.tmpl"}})), "cannot find nope.tmpl");
}

TEST(FileResource, validation_errors) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"content", "a"}, {"source", "banner.txt"}})),
                "use only one of #:content, #:template and #:source");
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"mode", 644}})), "mode must be a string of octal digits");
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"mode", "0999"}})), "mode must be a string");
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"content", "a"}, {"locals", map({{"a", 1}})}})),
                "#:locals only applies to #:template");
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"content", "a"}, {"state", sym("absent")}})),
                "makes no sense with #:state 'absent");
}

TEST(FileResource, sensitive_files) {
  auto machine = linux_machine();
  EXPECT_TRUE(file_resource(*machine, map({{"content", "secret"}, {"sensitive", true}}))->sensitive());
  EXPECT_FALSE(file_resource(*machine, map({{"content", "public"}}))->sensitive());
}

TEST(FileResource, failed_write_removes_the_temporary_file) {
  auto machine = linux_machine();
  stub_missing(machine->shell, kPath);
  machine->shell.on("mv -f /etc/motd.sadame-new /etc/motd", "", "mv: permission denied\n", 1);
  auto file = file_resource(*machine, map({{"content", "x"}}));
  EXPECT_THROWS(CommandFailed, file->apply(file->diff()), "permission denied");
  EXPECT_EQ(std::string("rm -f /etc/motd.sadame-new"), machine->shell.commands.back());
}

TEST(FileResource, verify_checks_the_new_content_before_it_replaces_the_file) {
  auto machine = linux_machine();
  stub_missing(machine->shell, "/etc/sudoers.d/deploy");
  auto file = build_resource<FileResource>(
      machine->host, "/etc/sudoers.d/deploy",
      map({{"content", "deploy ALL=(ALL) NOPASSWD: ALL\n"}, {"mode", "0440"}, {"verify", "visudo -cf %{path}"}}));
  file->apply(file->diff());
  EXPECT_EQ((std::vector<std::string>{"visudo -cf /etc/sudoers.d/deploy.sadame-new",
                                      "mv -f /etc/sudoers.d/deploy.sadame-new /etc/sudoers.d/deploy"}),
            machine->shell.last(2));

  auto failing = linux_machine();
  stub_missing(failing->shell, "/etc/sudoers.d/deploy");
  failing->shell.on("visudo -cf /etc/sudoers.d/deploy.sadame-new", "", "syntax error near line 1\n", 1);
  auto bad = build_resource<FileResource>(failing->host, "/etc/sudoers.d/deploy",
                                          map({{"content", "nonsense"}, {"verify", "visudo -cf %{path}"}}));
  EXPECT_THROWS(ResourceError, bad->apply(bad->diff()), "verify failed, /etc/sudoers.d/deploy was not changed");
  EXPECT_THROWS(ResourceError, bad->apply(bad->diff()), "syntax error near line 1");
  EXPECT_EQ(std::string("rm -f /etc/sudoers.d/deploy.sadame-new"), failing->shell.commands.back());
}

TEST(FileResource, verify_needs_the_path_placeholder) {
  auto machine = linux_machine();
  EXPECT_THROWS(ResourceError, file_resource(*machine, map({{"content", "x"}, {"verify", "visudo -c"}})),
                "verify must be a command containing %{path}");
}

TEST(FileResource, uses_bsd_stat_on_macos) {
  auto shell = std::make_unique<FakeShell>();
  shell->on("uname -s", "Darwin\n");
  shell->on("stat -f '%Lp %Su %Sg %HT' /etc/motd", "644 root wheel Regular File\n");
  shell->files[kPath] = "x";
  Machine machine(std::move(shell));
  EXPECT_EMPTY(file_resource(machine, map({{"content", "x"}, {"mode", "0644"}, {"group", "wheel"}}))->diff());
}
