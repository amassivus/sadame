#include "../support/test_helpers.hpp"

#include "../../lib/sadame/facts.hpp"
#include "../../lib/sadame/template.hpp"

using namespace sadame;
using namespace test;

namespace {

std::string render(const std::string &source, const Value &vars = Value::map(), const Value &locals = Value::map(),
                   Facts *facts = nullptr) {
  return Template(source, "t.tmpl").render(vars, locals, facts);
}

}  // namespace

TEST(Template, plain_text_is_copied_as_it_is) {
  EXPECT_EQ(std::string("a\n  b ~ c\n"), render("a\n  b ~ c\n"));
  EXPECT_EQ(std::string(""), render(""));
}

TEST(Template, expressions_insert_values) {
  Value vars = map({{"port", 80}, {"name", "example.com"}, {"on", true}, {"off", false}});
  EXPECT_EQ(std::string("listen 80; example.com\n"), render("listen ~{(vars 'port)}; ~{(vars 'name)}\n", vars));
  EXPECT_EQ(std::string("true|\n"), render("~{(vars 'on)}|~{(vars 'off)}\n", vars));
  EXPECT_EQ(std::string("160"), render("~{(* 2 (vars 'port))}", vars));
  EXPECT_EQ(std::string("x"), render("~{(vars 'missing \"x\")}", vars));
  EXPECT_EQ(std::string(""), render("~{(vars 'missing)}", vars));
}

TEST(Template, names_may_use_dashes_or_underscores) {
  Value vars = map({{"site_name", "demo"}});
  EXPECT_EQ(std::string("demo demo"), render("~{(vars 'site_name)} ~{(vars 'site-name)}", vars));
}

TEST(Template, locals_are_separate_from_vars) {
  EXPECT_EQ(std::string("Welcome to web1\n"),
            render("~{(locals 'greeting)} to ~{(vars 'host)}\n", map({{"host", "web1"}}), map({{"greeting", "Welcome"}})));
}

TEST(Template, braces_and_strings_inside_expressions_are_balanced) {
  EXPECT_EQ(std::string("a}b"), render("~{(string-append \"a}\" \"b\")}"));
  EXPECT_EQ(std::string("(x)"), render("~{(string-append \"(\" \"x\" \")\")}"));
}

TEST(Template, if_else_and_end) {
  Value vars = map({{"on", true}});
  EXPECT_EQ(std::string("yes\n"), render("~(if (vars 'on))\nyes\n~(else)\nno\n~(end)\n", vars));
  EXPECT_EQ(std::string("no\n"), render("~(if (vars 'off))\nyes\n~(else)\nno\n~(end)\n", vars));
  EXPECT_EQ(std::string(""), render("~(if (vars 'off))\nyes\n~(end)\n", vars));
  EXPECT_EQ(std::string("inline!"), render("~(if #t)inline~(end)!"));
}

TEST(Template, each_binds_the_item) {
  Value vars = map({{"upstreams", list({"a", "b"})}});
  EXPECT_EQ(std::string("server a;\nserver b;\n"), render("~(each u (vars 'upstreams))\nserver ~{u};\n~(end)\n", vars));
  EXPECT_EQ(std::string(""), render("~(each u (vars 'nothing))\nx\n~(end)\n", vars));
}

TEST(Template, items_that_are_maps_are_read_with_ref) {
  Value vars = map({{"jobs", list({map({{"name", "backup"}, {"schedule", "daily"}}), map({{"name", "clean"}, {"schedule", "weekly"}})})}});
  EXPECT_EQ(std::string("backup@daily\nclean@weekly\n"),
            render("~(each j (vars 'jobs))\n~{(ref j 'name)}@~{(ref j 'schedule)}\n~(end)\n", vars));
}

TEST(Template, loops_and_conditions_nest) {
  Value vars = map({{"rows", list({1, 2, 3})}});
  EXPECT_EQ(std::string("odd 1\neven 2\nodd 3\n"),
            render("~(each n (vars 'rows))\n~(if (odd? n))\nodd ~{n}\n~(else)\neven ~{n}\n~(end)\n~(end)\n", vars));
}

TEST(Template, tag_lines_leave_no_blank_lines_but_inline_tags_keep_their_text) {
  EXPECT_EQ(std::string("a\nb\n"), render("a\n  ~(if #t)  \nb\n  ~(end)\n"));
  EXPECT_EQ(std::string("a\nb\n"), render("a\n~; a comment\nb\n"));
  EXPECT_EQ(std::string("a \nb\n"), render("a ~; trailing comment\nb\n"));
}

TEST(Template, a_literal_tilde) {
  EXPECT_EQ(std::string("~{x} ~/path ~"), render("~~{x} ~/path ~"));
}

TEST(Template, facts_are_read_when_asked_for) {
  auto machine = fresh_machine();
  EXPECT_EQ(std::string("fresh has 2 cpus"),
            render("~{(facts 'hostname)} has ~{(facts 'cpus)} cpus", Value::map(), Value::map(), &machine->host.facts()));
  EXPECT_THROWS(RecipeError, render("~{(facts 'cpus)}"), "t.tmpl:1: facts are not available here");
  EXPECT_THROWS(RecipeError, render("~{(facts 'nope)}", Value::map(), Value::map(), &machine->host.facts()), "unknown fact nope");
}

TEST(Template, errors_name_the_file_and_line) {
  EXPECT_THROWS(RecipeError, render("a\nb\n~{nmae}\n"), "t.tmpl:3: Unbound variable: nmae");
  EXPECT_THROWS(RecipeError, render("~{(+ 1}\n"), "t.tmpl:1:");
  EXPECT_THROWS(RecipeError, render("a\n~{(vars 'x)"), "t.tmpl:2: unclosed ~{ tag");
  EXPECT_THROWS(RecipeError, render("x\n~(if #t)\ny\n"), "t.tmpl:2: ~(if) is never closed with ~(end)");
  EXPECT_THROWS(RecipeError, render("~(end)\n"), "t.tmpl:1: ~(end) without ~(if) or ~(each)");
  EXPECT_THROWS(RecipeError, render("~(frob 1)\n"), "t.tmpl:1: unknown tag ~(frob)");
  EXPECT_THROWS(RecipeError, render("~(each x)\n~(end)\n"), "~(each) needs a name and a list");
  EXPECT_THROWS(RecipeError, render("~(each x 5)\n~(end)\n"), "~(each) needs a list, got an Integer");
}

TEST(Template, templates_cannot_reach_each_others_definitions_through_state) {
  EXPECT_EQ(std::string("1"), render("~{(let ((x 1)) x)}"));
  EXPECT_THROWS(RecipeError, render("~{x}"), "Unbound variable: x");
}
