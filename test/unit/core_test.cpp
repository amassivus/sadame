#include <unistd.h>

#include "../support/test_helpers.hpp"

#include "../../lib/sadame/diff.hpp"
#include "../../lib/sadame/glob.hpp"
#include "../../lib/sadame/json_writer.hpp"
#include "../../lib/sadame/platform.hpp"
#include "../../lib/sadame/scheme_literal.hpp"
#include "../../lib/sadame/shell.hpp"
#include "../../lib/sadame/target.hpp"
#include "../../lib/sadame/vars.hpp"

using namespace sadame;
using namespace test;

// ---------------------------------------------------------------- diff

TEST(Diff, equal_texts_have_no_diff) { EXPECT_EQ(std::string(""), Diff::unified("a\nb\n", "a\nb\n", "old", "new")); }

TEST(Diff, a_changed_line) {
  EXPECT_EQ(std::string("--- old\n+++ new\n@@ -1,3 +1,3 @@\n a\n-b\n+B\n c\n"),
            Diff::unified("a\nb\nc\n", "a\nB\nc\n", "old", "new"));
}

TEST(Diff, a_new_file_is_all_additions) {
  EXPECT_EQ(std::string("--- /dev/null\n+++ f\n@@ -0,0 +1,2 @@\n+x\n+y\n"), Diff::unified("", "x\ny\n", "/dev/null", "f"));
}

TEST(Diff, a_missing_final_newline_shows_up) {
  EXPECT_EQ(std::string("--- a\n+++ b\n@@ -1 +1 @@\n-x\n\\ No newline at end of file\n+x\n"), Diff::unified("x", "x\n", "a", "b"));
}

TEST(Diff, distant_changes_make_separate_hunks) {
  std::string old_text, new_text;
  for (int index = 1; index <= 20; ++index) {
    old_text += std::to_string(index) + "\n";
    new_text += (index == 2 || index == 19 ? "x" : std::to_string(index)) + "\n";
  }
  std::string diff = Diff::unified(old_text, new_text, "a", "b");
  EXPECT_CONTAINS(diff, "@@ -1,5 +1,5 @@");
  EXPECT_CONTAINS(diff, "@@ -16,5 +16,5 @@");
}

TEST(Diff, changes_compare_only_the_desired_attributes) {
  Value desired = map({{"state", "present"}, {"mode", "0644"}});
  Value current = map({{"state", "present"}, {"mode", "0600"}, {"owner", "root"}});
  auto changes = Diff::changes(desired, current);
  EXPECT_EQ(1, static_cast<int>(changes.size()));
  EXPECT_EQ(std::string("mode"), changes.front().attribute);
  EXPECT_EQ(Value("0600"), changes.front().from);
}

TEST(Diff, split_lines_keeps_line_breaks) {
  EXPECT_EQ((std::vector<std::string>{"a\n", "b"}), Diff::split_lines("a\nb"));
  EXPECT_EMPTY(Diff::split_lines(""));
}

// ------------------------------------------------------------ platform

TEST(Platform, maps_distributions_to_families_and_package_managers) {
  struct Expectation {
    const char *name, *family, *manager;
  };
  for (const Expectation &expected : {Expectation{"debian", "debian", "apt"}, Expectation{"ubuntu", "debian", "apt"},
                                      Expectation{"rocky", "rhel", "dnf"}, Expectation{"alpine", "alpine", "apk"},
                                      Expectation{"arch", "arch", "pacman"}, Expectation{"omarchy", "arch", "pacman"}}) {
    Platform platform = Platform::from_os_release(os_release(expected.name));
    EXPECT_EQ(std::optional<std::string>(expected.family), platform.family());
    EXPECT_EQ(std::optional<std::string>(expected.manager), platform.package_manager());
  }
}

TEST(Platform, reads_names_versions_and_codenames) {
  Platform platform = Platform::from_os_release(os_release("ubuntu"));
  EXPECT_EQ(std::optional<std::string>("ubuntu"), platform.id());
  EXPECT_TRUE(platform.version().has_value());
  EXPECT_TRUE(platform.codename().has_value());
  EXPECT_EQ(platform.name().value(), platform.description());
}

TEST(Platform, an_unknown_system_has_no_family) {
  Platform platform = Platform::from_os_release("ID=plan9\n");
  EXPECT_FALSE(platform.family().has_value());
  EXPECT_FALSE(platform.package_manager().has_value());
  EXPECT_EQ(std::string("Linux"), platform.description());
  EXPECT_EQ(std::string("macOS"), Platform::from_os_release("", "Darwin").description());
}

TEST(Platform, quotes_and_comments_in_os_release) {
  auto fields = Platform::parse_os_release("# comment\nID=\"rocky\"\nNAME='Rocky Linux'\nEMPTY=\n");
  EXPECT_EQ(std::string("rocky"), fields["ID"]);
  EXPECT_EQ(std::string("Rocky Linux"), fields["NAME"]);
  EXPECT_EQ(std::string(""), fields["EMPTY"]);
}

// ---------------------------------------------------------------- glob

TEST(Glob, star_and_question_mark) {
  EXPECT_TRUE(Glob::match("web*", "web1.example.com"));
  EXPECT_TRUE(Glob::match("*.example.com", "web1.example.com"));
  EXPECT_TRUE(Glob::match("web?", "web1"));
  EXPECT_FALSE(Glob::match("web?", "web12"));
  EXPECT_TRUE(Glob::match("*", ""));
  EXPECT_TRUE(Glob::match("a*b*c", "aXXbYYc"));
  EXPECT_FALSE(Glob::match("web", "web1"));
}

// -------------------------------------------------------------- target

TEST(Target, parses_user_host_and_port) {
  auto spec = Target::parse("admin@web1.example.com:2222");
  EXPECT_EQ(std::optional<std::string>("admin"), spec.user);
  EXPECT_EQ(std::string("web1.example.com"), spec.host);
  EXPECT_EQ(std::optional<int>(2222), spec.port);

  auto plain = Target::parse("web1");
  EXPECT_FALSE(plain.user.has_value());
  EXPECT_FALSE(plain.port.has_value());
}

TEST(Target, ipv6_addresses_go_in_brackets) {
  auto spec = Target::parse("admin@[2001:db8::1]:2222");
  EXPECT_EQ(std::string("2001:db8::1"), spec.host);
  EXPECT_EQ(std::optional<int>(2222), spec.port);
  EXPECT_EQ(std::string("2001:db8::1"), Target::parse("[2001:db8::1]").host);
  EXPECT_THROWS(UsageError, Target::parse("2001:db8::1"), "put IPv6 addresses in brackets");
}

TEST(Target, rejects_bad_specs) {
  EXPECT_THROWS(UsageError, Target::parse("@host"), "missing user name before @");
  EXPECT_THROWS(UsageError, Target::parse("host:99999"), "invalid port");
  EXPECT_THROWS(UsageError, Target::parse("host:abc"), "invalid port");
  EXPECT_THROWS(UsageError, Target::parse("user@"), "missing host name");
  EXPECT_THROWS(UsageError, Target::parse("[::1"), "missing ]");
}

// ---------------------------------------------------------------- vars

TEST(Vars, assignments_coerce_booleans_and_integers) {
  EXPECT_EQ(Value(true), Vars::parse_assignment("a=true").second);
  EXPECT_EQ(Value(false), Vars::parse_assignment("a=false").second);
  EXPECT_EQ(Value(42), Vars::parse_assignment("a=42").second);
  EXPECT_EQ(Value(-3), Vars::parse_assignment("a=-3").second);
  EXPECT_EQ(Value("0644"), Vars::parse_assignment("a=0644").second);
  EXPECT_EQ(Value("1.5"), Vars::parse_assignment("a=1.5").second);
  EXPECT_EQ(Value("x=y"), Vars::parse_assignment("a=x=y").second);
  EXPECT_EQ(std::string("site_name"), Vars::parse_assignment("site-name=x").first);
  EXPECT_THROWS(UsageError, Vars::parse_assignment("novalue"), "--var expects key=value");
  EXPECT_THROWS(UsageError, Vars::parse_assignment("=x"), "--var expects key=value");
}

TEST(Vars, merges_layers_with_the_last_winning) {
  Value merged = Vars::merge({map({{"a", 1}, {"b", 1}}), map({{"b", 2}}), map({{"c", 3}})});
  EXPECT_EQ(map({{"a", 1}, {"b", 2}, {"c", 3}}), merged);
}

TEST(Vars, layered_vars_remember_where_each_came_from) {
  auto [vars, sources] = Vars::layered({{"vars.scm", map({{"a", 1}, {"b", 1}})}, {"host", map({{"b", 2}})}});
  EXPECT_EQ(Value(2), vars.get("b"));
  EXPECT_EQ(Value("vars.scm"), sources.get("a"));
  EXPECT_EQ(Value("host"), sources.get("b"));
}

TEST(Vars, loads_a_scheme_file_and_normalizes_keys) {
  Value vars = Vars::load_file("test/fixtures/vars/vars.scm");
  EXPECT_EQ(Value(4), vars.get("workers"));
  EXPECT_EQ(Value("example.com"), vars.get("server_name"));
  EXPECT_EQ(Value("from string key"), vars.get("string_key"));
}

TEST(Vars, a_missing_file_is_no_vars) { EXPECT_TRUE(Vars::load_file("test/fixtures/vars/nope.scm").empty()); }

TEST(Vars, a_file_that_is_not_an_association_list_is_an_error) {
  EXPECT_THROWS(RecipeError, Vars::load_file("test/fixtures/vars/not_a_hash.scm"), "must evaluate to an association list");
}

TEST(Vars, errors_name_the_file_and_line) {
  EXPECT_THROWS(RecipeError, Vars::load_file("test/fixtures/vars/broken.scm"),
                "test/fixtures/vars/broken.scm:1: Unbound variable: undefined-thing-here");
}

// ---------------------------------------------------------------- shell

TEST(Shell, escape_leaves_plain_words_alone) {
  EXPECT_EQ(std::string("/etc/nginx/nginx.conf"), Shell::escape("/etc/nginx/nginx.conf"));
  EXPECT_EQ(std::string("user@host:22"), Shell::escape("user@host:22"));
}

TEST(Shell, escape_quotes_everything_else) {
  EXPECT_EQ(std::string("''"), Shell::escape(""));
  EXPECT_EQ(std::string("'a b'"), Shell::escape("a b"));
  EXPECT_EQ(std::string("'it'\\''s'"), Shell::escape("it's"));
  EXPECT_EQ(std::string("'$(rm -rf /)'"), Shell::escape("$(rm -rf /)"));
}

TEST(Shell, runs_commands_and_captures_their_output) {
  Shell shell;
  CommandResult result = shell.run("echo out; echo err >&2; exit 3");
  EXPECT_EQ(std::string("out\n"), result.stdout_text);
  EXPECT_EQ(std::string("err\n"), result.stderr_text);
  EXPECT_EQ(3, result.exit_status);
  EXPECT_FALSE(result.success());
}

TEST(Shell, commands_run_in_the_c_locale_with_stdin_closed) {
  Shell shell;
  EXPECT_EQ(std::string("C.UTF-8\n"), shell.run("echo $LC_ALL").stdout_text);
  EXPECT_EQ(std::string(""), shell.run("cat").stdout_text);
}

TEST(Shell, run_checked_raises_with_the_command_and_its_output) {
  Shell shell;
  EXPECT_THROWS(CommandFailed, shell.run_checked("echo nope >&2; exit 1"), "command failed (exit 1): echo nope >&2; exit 1\nnope");
}

TEST(Shell, streams_lines_as_they_arrive) {
  Shell shell;
  std::vector<std::string> lines;
  int status = shell.stream("echo a; echo b >&2", [&](const std::string &line) { lines.push_back(line); });
  EXPECT_EQ(0, status);
  EXPECT_EQ((std::vector<std::string>{"a\n", "b\n"}), lines);
}

TEST(Shell, reads_and_writes_files) {
  Shell shell;
  std::string path = "/tmp/sadame-shell-test-" + std::to_string(::getpid());
  EXPECT_FALSE(shell.read_file(path).has_value());
  shell.write_file(path, "content\n");
  EXPECT_EQ(std::optional<std::string>("content\n"), shell.read_file(path));
  shell.run("rm -f " + path);
}

// ----------------------------------------------------------------- json

TEST(JsonWriter, writes_objects_arrays_and_scalars_with_stable_indentation) {
  Value document = map({{"name", "x"}, {"list", list({1, "two", true})}, {"empty", Value::array()}, {"none", Value()},
                        {"nested", map({{"a", 1.5}})}, {"object", Value::map()}});
  EXPECT_EQ(std::string("{\n  \"name\": \"x\",\n  \"list\": [\n    1,\n    \"two\",\n    true\n  ],\n  \"empty\": [],\n"
                        "  \"none\": null,\n  \"nested\": {\n    \"a\": 1.5\n  },\n  \"object\": {}\n}\n"),
            JsonWriter::generate(document));
}

TEST(JsonWriter, escapes_strings) {
  EXPECT_EQ(std::string("\"a\\\"b\\\\c\\nd\\te\\u0001\"\n"), JsonWriter::generate(Value(std::string("a\"b\\c\nd\te\x01"))));
  EXPECT_EQ(std::string("\"héllo\"\n"), JsonWriter::generate(Value("héllo")));
}

TEST(JsonParser, reads_what_the_writer_writes) {
  Value document = map({{"a", list({1, 2.5, "x", Value(), true, map({{"b", false}})})}, {"s", "line\nbreak \"q\" é"}});
  EXPECT_EQ(document, JsonParser::parse(JsonWriter::generate(document)));
}

TEST(JsonParser, decodes_unicode_escapes) {
  EXPECT_EQ(Value("é€😀"), JsonParser::parse("\"\\u00e9\\u20ac\\ud83d\\ude00\""));
}

TEST(JsonParser, reports_where_the_text_is_wrong) {
  EXPECT_THROWS(Error, JsonParser::parse("{\"a\": }"), "invalid JSON");
  EXPECT_THROWS(Error, JsonParser::parse("[1, 2"), "invalid JSON");
  EXPECT_THROWS(Error, JsonParser::parse("{} x"), "unexpected text after the value");
}

// -------------------------------------------------------- scheme literal

TEST(SchemeLiteral, writes_values_as_scheme_source) {
  EXPECT_EQ(std::string("\"a \\\"b\\\"\\n\""), SchemeLiteral::dump(Value("a \"b\"\n")));
  EXPECT_EQ(std::string("'(1 \"x\" #t)"), SchemeLiteral::dump(list({1, "x", true})));
  EXPECT_EQ(std::string("'((workers . 4) (tags . (\"a\" \"b\")))"),
            SchemeLiteral::dump(map({{"workers", 4}, {"tags", list({"a", "b"})}})));
  EXPECT_EQ(std::string("'()"), SchemeLiteral::dump(Value::map()));
  EXPECT_EQ(std::string("'running"), SchemeLiteral::dump(sym("running")));
  EXPECT_EQ(std::string("#f"), SchemeLiteral::dump(Value()));
}
