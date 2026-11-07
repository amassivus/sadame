#include <filesystem>

#include "../support/test_helpers.hpp"

#include "../../lib/sadame/recipe.hpp"
#include "../../lib/sadame/resource_collection.hpp"

using namespace sadame;
using namespace test;

namespace {

const std::string kRecipes = "test/fixtures/recipes";

std::vector<std::string> ids(const ResourceCollection &resources) {
  std::vector<std::string> result;
  for (const auto &resource : resources.resources()) result.push_back(resource->id());
  return result;
}

ResourceCollection load(Machine &machine, const std::string &path, const Value &vars = Value::map(),
                        std::vector<std::string> *loaded = nullptr) {
  return Recipe::load(path, machine.host, vars, {}, loaded);
}

}  // namespace

TEST(Recipe, loads_every_resource_type_in_order) {
  auto machine = fresh_machine();
  Value vars = map({{"port", 80}, {"server_name", "example.com"}, {"with_user", true}});
  auto resources = load(*machine, kRecipes + "/basic/recipe.scm", vars);
  EXPECT_EQ((std::vector<std::string>{"package[nginx]", "directory[/var/www/app]", "file[/etc/nginx/conf.d/app.conf]",
                                      "service[nginx]", "exec[touch /var/www/app/.ready]", "user[deploy]"}),
            ids(resources));
}

TEST(Recipe, vars_decide_what_is_declared) {
  auto machine = fresh_machine();
  auto resources = load(*machine, kRecipes + "/basic/recipe.scm", map({{"port", 80}, {"server_name", "x"}, {"with_user", false}}));
  EXPECT_EQ(5, static_cast<int>(resources.size()));
}

TEST(Recipe, an_included_recipe_is_evaluated_once) {
  auto machine = fresh_machine();
  std::vector<std::string> loaded;
  load(*machine, kRecipes + "/basic/recipe.scm", map({{"port", 80}, {"server_name", "x"}}), &loaded);
  EXPECT_EQ(2, static_cast<int>(loaded.size()));
  EXPECT_CONTAINS(loaded[0], "basic/recipe.scm");
  EXPECT_CONTAINS(loaded[1], "basic/roles/web.scm");
}

TEST(Recipe, host_name_and_groups_are_available) {
  auto shell = std::make_unique<FakeShell>(std::map<std::string, std::string>{{"/etc/os-release", os_release("debian")}});
  shell->on("uname -s", "Linux\n");
  Host host(*shell, "web1", {"web", "all"});
  auto resources = Recipe::load(kRecipes + "/roles/site.scm", host, Value::map());
  EXPECT_EQ((std::vector<std::string>{"file[/etc/motd]", "package[nginx]"}), ids(resources));
  EXPECT_EQ(std::string("web1\n"), resources.resources().front()->desired().get("content").to_s());

  Host db(*shell, "db1", {"db"});
  EXPECT_EQ(1, static_cast<int>(Recipe::load(kRecipes + "/roles/site.scm", db, Value::map()).size()));
}

TEST(Recipe, facts_are_read_when_the_recipe_asks) {
  auto machine = fresh_machine();
  machine->shell.on("systemd-detect-virt --container", "", "", 1);
  machine->shell.on("systemd-detect-virt", "none\n");
  auto resources = load(*machine, kRecipes + "/facts/recipe.scm");
  EXPECT_EQ((std::vector<std::string>{"file[/etc/app.conf]", "file[/etc/cpus]"}), ids(resources));
  EXPECT_EQ(std::string("2\n"), resources.find("file[/etc/cpus]")->desired().get("content").to_s());
  EXPECT_EQ(std::string("workers = 4\nlisten = :8080\n"), resources.find("file[/etc/app.conf]")->desired().get("content").to_s());
}

TEST(Recipe, duplicate_resources_are_an_error) {
  auto machine = fresh_machine();
  EXPECT_THROWS(RecipeError, load(*machine, kRecipes + "/duplicate/recipe.scm"),
                "recipe.scm:3: package[git] is declared more than once");
}

TEST(Recipe, a_missing_include_is_an_error) {
  auto machine = fresh_machine();
  EXPECT_THROWS(RecipeError, load(*machine, kRecipes + "/missing_include/recipe.scm"),
                "recipe.scm:2: include-recipe cannot find test/fixtures/recipes/missing_include/roles/missing.scm");
}

TEST(Recipe, notifications_are_checked_when_the_recipe_is_loaded) {
  auto machine = fresh_machine();
  EXPECT_THROWS(ResourceError, load(*machine, kRecipes + "/bad_notification/recipe.scm"), "file[/etc/app.conf] notifies service[app], which is not declared");
}

TEST(Recipe, unknown_options_are_reported_on_the_line_that_names_them) {
  auto machine = fresh_machine();
  EXPECT_THROWS(RecipeError, load(*machine, kRecipes + "/unknown_option/recipe.scm"),
                "test/fixtures/recipes/unknown_option/recipe.scm:2: file[/etc/motd]: unknown option #:contents");
  EXPECT_THROWS(RecipeError, load(*machine, kRecipes + "/unknown_option_multiline/recipe.scm"),
                "test/fixtures/recipes/unknown_option_multiline/recipe.scm:3: file[/etc/motd]: unknown option #:contents");
}

TEST(Recipe, unsaved_sources_replace_the_files_text) {
  auto machine = fresh_machine();
  Recipe::Sources sources;
  std::string path = kRecipes + "/duplicate/recipe.scm";
  sources[std::filesystem::absolute(path).lexically_normal().string()] = "(package \"only\")\n";
  auto resources = Recipe::load(path, machine->host, Value::map(), sources);
  EXPECT_EQ((std::vector<std::string>{"package[only]"}), ids(resources));
}

TEST(Recipe, syntax_errors_name_the_file_and_line) {
  auto machine = fresh_machine();
  EXPECT_THROWS(RecipeError, load(*machine, kRecipes + "/syntax_error/recipe.scm"), "recipe.scm:3: a form that starts here is never closed");
}

TEST(Recipe, scheme_errors_name_the_line_of_the_form) {
  auto machine = fresh_machine();
  Recipe::Sources sources;
  std::string path = kRecipes + "/duplicate/recipe.scm";
  sources[std::filesystem::absolute(path).lexically_normal().string()] = "(package \"a\")\n\n(frobnicate 1)\n";
  EXPECT_THROWS(RecipeError, Recipe::load(path, machine->host, Value::map(), sources),
                "duplicate/recipe.scm:3: Unbound variable: frobnicate");
}

TEST(Recipe, options_are_keywords_with_dashes_or_underscores) {
  auto machine = fresh_machine();
  Recipe::Sources sources;
  std::string path = kRecipes + "/duplicate/recipe.scm";
  sources[std::filesystem::absolute(path).lexically_normal().string()] =
      "(exec \"a\" #:not-if \"true\")\n(exec \"b\" #:not_if \"true\")\n(exec \"c\" #:action 'nothing)\n";
  auto resources = Recipe::load(path, machine->host, Value::map(), sources);
  EXPECT_EQ(3, static_cast<int>(resources.size()));
}

TEST(Recipe, lists_of_notifications_and_plain_values_convert_as_written) {
  auto machine = fresh_machine();
  Recipe::Sources sources;
  std::string path = kRecipes + "/duplicate/recipe.scm";
  sources[std::filesystem::absolute(path).lexically_normal().string()] =
      "(service \"nginx\")\n(service \"app\")\n"
      "(file \"/etc/a\" #:content \"x\" #:notifies '((reload \"service[nginx]\") (restart \"service[app]\" immediately)))\n"
      "(user \"u\" #:groups '(\"a\" \"b\") #:uid 7)\n"
      "(exec \"e\" #:env '((A . \"1\") (B . \"2\")))\n";
  auto resources = Recipe::load(path, machine->host, Value::map(), sources);
  EXPECT_EQ(2, static_cast<int>(resources.find("file[/etc/a]")->notifications().size()));
  EXPECT_EQ(std::string("immediately"), resources.find("file[/etc/a]")->notifications()[1].timing);
}

TEST(Recipe, a_recipe_can_use_modules_and_define_helpers) {
  auto machine = fresh_machine();
  Recipe::Sources sources;
  std::string path = kRecipes + "/duplicate/recipe.scm";
  sources[std::filesystem::absolute(path).lexically_normal().string()] =
      "(use-modules (srfi srfi-1))\n"
      "(define (pkg n) (package n))\n"
      "(for-each pkg (delete-duplicates '(\"a\" \"b\" \"a\")))\n";
  EXPECT_EQ((std::vector<std::string>{"package[a]", "package[b]"}), ids(Recipe::load(path, machine->host, Value::map(), sources)));
}

TEST(Recipe, platform_facts_and_vars_are_readable) {
  auto machine = fresh_machine("ubuntu");
  Recipe::Sources sources;
  std::string path = kRecipes + "/duplicate/recipe.scm";
  sources[std::filesystem::absolute(path).lexically_normal().string()] =
      "(file \"/etc/info\" #:content (string-append (platform 'family) \" \" (platform 'package-manager) \" \" "
      "(vars 'name) \" \" (number->string (vars 'count 0)) \" \" (host-name)))\n";
  auto resources = Recipe::load(path, machine->host, map({{"name", "n"}}), sources);
  EXPECT_EQ(std::string("debian apt n 0 local"), resources.find("file[/etc/info]")->desired().get("content").to_s());
}

TEST(Recipe, tags_are_added_to_included_recipes) {
  auto machine = fresh_machine();
  auto resources = load(*machine, kRecipes + "/tags/site.scm");
  EXPECT_EQ((std::vector<std::string>{}), resources.find("file[/etc/motd]")->tags());
  EXPECT_EQ((std::vector<std::string>{"web"}), resources.find("package[nginx]")->tags());
  EXPECT_EQ((std::vector<std::string>{"web", "config"}), resources.find("file[/etc/nginx/conf.d/app.conf]")->tags());
  EXPECT_EQ((std::vector<std::string>{"tools"}), resources.find("package[htop]")->tags());
}

TEST(Recipe, include_recipe_takes_only_tags) {
  auto machine = fresh_machine();
  EXPECT_THROWS(RecipeError, load(*machine, kRecipes + "/tags/bad_include.scm"), "include-recipe takes only #:tags, got #:when");
}
