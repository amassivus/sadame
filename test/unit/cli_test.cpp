#include <sys/stat.h>
#include <unistd.h>

#include <fstream>

#include "../support/test_helpers.hpp"

#include "../../lib/sadame/scaffold.hpp"

using namespace sadame;
using namespace test;

namespace {

const std::string kRecipes = "test/fixtures/recipes";

// A fresh Debian machine where the basic recipe's nginx is missing.
std::unique_ptr<Machine> machine_for_plans() { return fresh_machine("debian"); }

std::string temporary_directory() {
  char pattern[] = "/tmp/sadame-cli-test-XXXXXX";
  return mkdtemp(pattern);
}

}  // namespace

TEST(CLI, help_and_version) {
  auto help = run_cli({"--help"});
  EXPECT_EQ(0, help.status);
  EXPECT_CONTAINS(help.out, "Usage: sadame COMMAND [RECIPE] [options]");
  EXPECT_CONTAINS(help.out, "(default: ./recipe.scm)");
  auto version = run_cli({"--version"});
  EXPECT_EQ(std::string("sadame 0.5.1\n"), version.out);
}

TEST(CLI, usage_errors_exit_with_two_and_point_at_help) {
  auto missing = run_cli({});
  EXPECT_EQ(2, missing.status);
  EXPECT_EQ(std::string("sadame: missing command\nRun 'sadame --help' for usage.\n"), missing.err);

  EXPECT_CONTAINS(run_cli({"frobnicate"}).err, "unknown command frobnicate");
  EXPECT_CONTAINS(run_cli({"plan", "--wat"}).err, "unknown option --wat");
  EXPECT_CONTAINS(run_cli({"plan", "a", "b"}).err, "too many arguments: a b");
  EXPECT_CONTAINS(run_cli({"plan", "--var"}).err, "--var expects key=value");
  EXPECT_CONTAINS(run_cli({"plan", "--limit"}).err, "--limit needs a value");
  EXPECT_CONTAINS(run_cli({"plan", "--forks", "0"}).err, "--forks needs a whole number of hosts, at least 1");
  EXPECT_CONTAINS(run_cli({"plan", "--serial", "150%"}).err, "--serial needs a number of hosts or a percentage");
  EXPECT_CONTAINS(run_cli({"plan", "/nonexistent"}).err, "recipe not found: /nonexistent");
}

TEST(CLI, options_apply_only_to_their_commands) {
  EXPECT_CONTAINS(run_cli({"hosts", "--tags", "x"}).err, "--tags only applies to plan, apply and drift");
  EXPECT_CONTAINS(run_cli({"plan", "--platform", "arch"}).err, "--platform only applies to validate");
  EXPECT_CONTAINS(run_cli({"plan", "--format", "junit"}).err, "--format only applies to report");
  EXPECT_CONTAINS(run_cli({"plan", "--ci", "github"}).err, "--ci only applies to init");
  EXPECT_CONTAINS(run_cli({"plan", kRecipes + "/basic", "--sudo"}).err, "--sudo only applies to -h, -g and --limit");
  EXPECT_CONTAINS(run_cli({"plan", kRecipes + "/basic", "--forks", "2"}).err, "--forks only applies");
}

TEST(CLI, plan_prints_the_changes_and_exits_zero) {
  auto machine = machine_for_plans();
  auto result = run_cli({"plan", kRecipes + "/basic"}, machine->shell);
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "sadame 0.5.1 plan on local (Debian GNU/Linux 12 (bookworm))");
  EXPECT_CONTAINS(result.out, "+ package[nginx]");
  EXPECT_CONTAINS(result.out, "+  server_name example.com;");
  EXPECT_CONTAINS(result.out, "notifies: reload service[nginx] (delayed)");
  EXPECT_CONTAINS(result.out, "Plan: ");
}

TEST(CLI, drift_exits_one_when_a_host_differs) {
  auto machine = machine_for_plans();
  EXPECT_EQ(1, run_cli({"drift", kRecipes + "/basic"}, machine->shell).status);
}

TEST(CLI, apply_runs_the_commands) {
  auto machine = machine_for_plans();
  auto result = run_cli({"apply", kRecipes + "/basic"}, machine->shell);
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "changed    package[nginx]");
  EXPECT_CONTAINS(result.out, "notified   service[nginx]: reload (delayed, from file[/etc/nginx/conf.d/app.conf])");
  bool installed = false;
  for (const std::string &command : machine->shell.commands) installed = installed || command == "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx";
  EXPECT_TRUE(installed);
}

TEST(CLI, vars_come_from_vars_scm_a_vars_file_and_var_flags) {
  auto machine = machine_for_plans();
  auto result = run_cli({"plan", kRecipes + "/basic", "--var", "port=8080", "--var=with_user=true"}, machine->shell);
  EXPECT_CONTAINS(result.out, "listen 8080;");
  EXPECT_CONTAINS(result.out, "user[deploy]");

  auto second = machine_for_plans();
  auto from_file = run_cli({"plan", kRecipes + "/basic", "--vars-file", "test/fixtures/vars/vars.scm"}, second->shell);
  EXPECT_CONTAINS(from_file.out, "server_name example.com;");
  EXPECT_CONTAINS(run_cli({"plan", kRecipes + "/basic", "--vars-file", "nope.scm"}, second->shell).err, "vars file not found: nope.scm");
}

TEST(CLI, json_output_is_one_document) {
  auto machine = machine_for_plans();
  auto result = run_cli({"plan", kRecipes + "/basic", "--json"}, machine->shell);
  EXPECT_EQ(0, result.status);
  EXPECT_EQ(std::string("{\n  \"format_version\": 1,"), result.out.substr(0, 24));
  EXPECT_CONTAINS(result.out, "\"command\": \"plan\"");
  EXPECT_CONTAINS(result.out, "\"id\": \"package[nginx]\"");
  EXPECT_NOT_CONTAINS(result.out, "sadame 0.5.1 plan");
}

TEST(CLI, colors_follow_the_flags_and_the_environment) {
  auto machine = machine_for_plans();
  EXPECT_CONTAINS(run_cli({"plan", kRecipes + "/basic", "--color"}, machine->shell).out, "\033[1msadame 0.5.1 plan");
  auto second = machine_for_plans();
  EXPECT_NOT_CONTAINS(run_cli({"plan", kRecipes + "/basic"}, second->shell).out, "\033[");
  auto third = machine_for_plans();
  EXPECT_NOT_CONTAINS(run_cli({"plan", kRecipes + "/basic", "--no-color"}, third->shell).out, "\033[");
}

TEST(CLI, recipe_errors_exit_with_two) {
  auto machine = machine_for_plans();
  auto result = run_cli({"plan", kRecipes + "/duplicate/recipe.scm"}, machine->shell);
  EXPECT_EQ(2, result.status);
  EXPECT_CONTAINS(result.err, "sadame: test/fixtures/recipes/duplicate/recipe.scm:3: package[git] is declared more than once");
}

TEST(CLI, tags_select_resources) {
  auto machine = machine_for_plans();
  auto result = run_cli({"plan", kRecipes + "/tags/site.scm", "--tags", "web"}, machine->shell);
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "Only resources tagged web: 3 of 5.");
  EXPECT_NOT_CONTAINS(result.out, "htop");

  auto second = machine_for_plans();
  auto skipped = run_cli({"plan", kRecipes + "/tags/site.scm", "--skip-tags", "web,tools"}, second->shell);
  EXPECT_CONTAINS(skipped.out, "Only resources not tagged web, tools: 1 of 5.");
}

TEST(CLI, host_name_and_groups_reach_the_recipe) {
  auto machine = machine_for_plans();
  auto result = run_cli({"plan", kRecipes + "/roles/site.scm", "--host-name", "web9", "--host-groups", "web"}, machine->shell);
  EXPECT_CONTAINS(result.out, "plan on web9");
  EXPECT_CONTAINS(result.out, "+web9");
  EXPECT_CONTAINS(result.out, "package[nginx]");
}

TEST(CLI, validate_checks_the_recipe_without_running_commands) {
  auto machine = linux_machine();
  auto result = run_cli({"validate", kRecipes + "/basic", "--var", "port=1", "--var", "server_name=x"}, machine->shell);
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "validate test/fixtures/recipes/basic/recipe.scm, as on Debian GNU/Linux 12 (bookworm)");
  EXPECT_CONTAINS(result.out, "local  ok     5 resources");
  EXPECT_CONTAINS(result.out, "validate on 1 host: 1 ok.");
  EXPECT_EMPTY(machine->shell.commands);
}

TEST(CLI, validate_reports_errors_and_exits_two) {
  auto result = run_cli({"validate", kRecipes + "/unknown_option/recipe.scm"});
  EXPECT_EQ(2, result.status);
  EXPECT_CONTAINS(result.out, "error  test/fixtures/recipes/unknown_option/recipe.scm:2: file[/etc/motd]: unknown option #:contents");
  EXPECT_CONTAINS(result.out, "validate on 1 host: 0 ok, 1 error.");

  auto json = run_cli({"validate", kRecipes + "/broken_template", "--json"});
  EXPECT_EQ(2, json.status);
  EXPECT_CONTAINS(json.out, "\"status\": \"error\"");
  EXPECT_CONTAINS(json.out, "app.conf.tmpl:2: Unbound variable: nmae");
}

TEST(CLI, validate_can_pretend_to_be_another_system) {
  auto rocky = run_cli({"validate", kRecipes + "/roles/site.scm", "--platform", "rocky"});
  EXPECT_CONTAINS(rocky.out, "as on Rocky Linux 9.4 (Blue Onyx)");
  EXPECT_CONTAINS(run_cli({"validate", kRecipes + "/roles/site.scm", "--platform", "plan9"}).err, "unknown platform plan9 for --platform (known: debian, ubuntu, rocky, alpine, arch)");
}

TEST(CLI, validate_with_recipe_facts_uses_made_up_values) {
  auto result = run_cli({"validate", kRecipes + "/facts"});
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "local  ok     2 resources");
}

TEST(CLI, hosts_lists_the_inventory_with_vars_and_their_sources) {
  auto result = run_cli({"hosts", "test/fixtures/inventories/basic", "--inventory", "test/fixtures/inventories/basic/hosts.scm", "-g", "db"});
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "sadame 0.5.1 hosts: 1 host from test/fixtures/inventories/basic/hosts.scm");
  EXPECT_CONTAINS(result.out, "  user      admin\n  port      2222\n  sudo      yes\n  ssh_opts  -i '~/.ssh/db'\n  groups    db, all\n");
  EXPECT_CONTAINS(result.out, "    layer  \"group all\"   group all");

  auto json = run_cli({"hosts", "--inventory", "test/fixtures/inventories/basic/hosts.scm", "--json", "--limit", "web2*"});
  EXPECT_CONTAINS(json.out, "\"command\": \"hosts\"");
  EXPECT_CONTAINS(json.out, "\"name\": \"web2.example.com\"");
}

TEST(CLI, hosts_errors) {
  EXPECT_CONTAINS(run_cli({"hosts", "--inventory", "nope.scm"}).err, "inventory not found: nope.scm");
  EXPECT_CONTAINS(run_cli({"hosts", "--inventory", "test/fixtures/inventories/empty.scm"}).err, "no hosts in test/fixtures/inventories/empty.scm yet");
  EXPECT_CONTAINS(run_cli({"hosts", "/tmp"}).err, "no hosts: /tmp/hosts.scm not found; use --inventory or -h");
}

TEST(CLI, facts_lists_what_recipes_see) {
  auto machine = fresh_machine();
  auto result = run_cli({"facts", "--host-name", "box"}, machine->shell);
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "sadame 0.5.1 facts on box (Debian GNU/Linux 12 (bookworm))");
  EXPECT_CONTAINS(result.out, "hostname           fresh\n");
  EXPECT_CONTAINS(result.out, "cpus               2\n");
  EXPECT_CONTAINS(result.out, "memory_mb          1982\n");
  EXPECT_CONTAINS(result.out, "service_manager    systemd\n");

  auto second = fresh_machine();
  auto json = run_cli({"facts", "--json"}, second->shell);
  EXPECT_CONTAINS(json.out, "\"command\": \"facts\"");
  EXPECT_CONTAINS(json.out, "\"cpus\": 2");
}

TEST(CLI, init_writes_a_project_that_validates) {
  std::string directory = temporary_directory();
  Shell shell;
  auto result = run_cli({"init", directory + "/site"}, shell);
  EXPECT_EQ(0, result.status);
  EXPECT_CONTAINS(result.out, "created " + directory + "/site/recipe.scm\n");
  EXPECT_CONTAINS(result.out, "created " + directory + "/site/templates/motd.tmpl\n");
  EXPECT_CONTAINS(result.out, "sadame validate " + directory + "/site");

  auto validated = run_cli({"validate", directory + "/site"});
  EXPECT_EQ(0, validated.status);
  EXPECT_CONTAINS(validated.out, "local  ok     1 resource\n");

  auto again = run_cli({"init", directory + "/site"}, shell);
  EXPECT_EQ(2, again.status);
  EXPECT_CONTAINS(again.err, "init writes nothing when one of its files exists");
  shell.run("rm -rf " + directory);
}

TEST(CLI, init_with_ci_writes_the_workflow) {
  std::string directory = temporary_directory();
  Shell shell;
  EXPECT_CONTAINS(run_cli({"init", "--ci", "bitbucket"}, shell).err, "--ci must be one of github, gitlab, got bitbucket");
  EXPECT_CONTAINS(run_cli({"init", "/abs", "--ci", "github"}, shell).err, "with --ci, give the directory relative");

  auto files = Scaffold(shell, "site", "github").files();
  EXPECT_EQ(5, static_cast<int>(files.size()));
  EXPECT_EQ(std::string(".github/workflows/sadame-drift.yml"), files.back().first);
  EXPECT_CONTAINS(files.back().second, "sadame drift site/recipe.scm -g all --json > drift.json");
  EXPECT_CONTAINS(Scaffold(shell, ".", "gitlab").files().back().second, "sadame drift recipe.scm -g all --json");
  shell.run("rm -rf " + directory);
}

TEST(CLI, parts_that_are_not_ported_say_so) {
  auto result = run_cli({"lsp"});
  EXPECT_EQ(2, result.status);
  EXPECT_CONTAINS(result.err, "lsp is not available in the Guile Scheme and C++ rewrite yet");
  EXPECT_CONTAINS(run_cli({"plan", kRecipes + "/basic", "-h", "web1"}).err, "push mode");
}
