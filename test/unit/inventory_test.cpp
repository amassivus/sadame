#include <unistd.h>

#include "../support/test_helpers.hpp"

#include "../../lib/sadame/inventory.hpp"

using namespace sadame;
using namespace test;

namespace {

const std::string kInventories = "test/fixtures/inventories";

Inventory load(const std::string &name) {
  Shell shell;
  return Inventory::load(kInventories + "/" + name + "/hosts.scm", shell);
}

std::vector<std::string> names(const std::vector<Target> &targets) {
  std::vector<std::string> result;
  for (const Target &target : targets) result.push_back(target.name);
  return result;
}

}  // namespace

TEST(Inventory, reads_groups_hosts_and_options) {
  Inventory inventory = load("basic");
  EXPECT_EQ((std::vector<std::string>{"web", "db", "all", "monitoring"}), inventory.group_names());
  EXPECT_EQ((std::vector<std::string>{"web1.example.com", "web2.example.com", "db1.example.com", "standalone.example.com"}),
            inventory.host_names());
  EXPECT_TRUE(inventory.has_group("web"));
  EXPECT_FALSE(inventory.has_group("nope"));
}

TEST(Inventory, a_group_includes_the_hosts_of_the_groups_it_includes) {
  Inventory inventory = load("basic");
  EXPECT_EQ((std::vector<std::string>{"web1.example.com", "web2.example.com", "db1.example.com"}), inventory.hosts_in_group("all"));
}

TEST(Inventory, groups_of_a_host_come_after_the_groups_they_include) {
  Inventory inventory = load("basic");
  EXPECT_EQ((std::vector<std::string>{"web", "all", "monitoring"}), inventory.groups_of("web1.example.com"));
  EXPECT_EQ((std::vector<std::string>{"db", "all"}), inventory.groups_of("db1.example.com"));
  EXPECT_EMPTY(inventory.groups_of("standalone.example.com"));
}

TEST(Inventory, selects_everything_without_flags) {
  Inventory inventory = load("basic");
  EXPECT_EQ(4, static_cast<int>(inventory.select({}).size()));
}

TEST(Inventory, selects_by_group_host_and_limit) {
  Inventory inventory = load("basic");
  Inventory::Selection by_group;
  by_group.group_names = {"db"};
  EXPECT_EQ((std::vector<std::string>{"db1.example.com"}), names(inventory.select(by_group)));

  Inventory::Selection by_host;
  by_host.host_specs = {"root@elsewhere:2200", "web1.example.com"};
  auto targets = inventory.select(by_host);
  EXPECT_EQ((std::vector<std::string>{"elsewhere", "web1.example.com"}), names(targets));
  EXPECT_EQ(std::optional<std::string>("root"), targets[0].user);
  EXPECT_EQ(std::optional<int>(2200), targets[0].port);
  EXPECT_TRUE(targets[0].groups.empty());

  Inventory::Selection limited;
  limited.group_names = {"all"};
  limited.limit = "web*";
  EXPECT_EQ((std::vector<std::string>{"web1.example.com", "web2.example.com"}), names(inventory.select(limited)));
}

TEST(Inventory, vars_layers_in_precedence_order) {
  Inventory inventory = load("basic");
  Inventory::Selection selection;
  selection.host_specs = {"web1.example.com"};
  selection.base_vars = map({{"layer", "vars.scm"}, {"base_only", 1}});
  selection.cli_vars = map({{"cli", true}});
  Target target = inventory.select(selection).front();
  EXPECT_EQ(Value("host"), target.vars.get("layer"));
  EXPECT_EQ(Value("web1"), target.vars.get("from_host"));
  EXPECT_EQ(Value(true), target.vars.get("from_web"));
  EXPECT_EQ(Value("production"), target.vars.get("env"));
  EXPECT_EQ(Value("vars.scm"), target.var_sources.get("base_only"));
  EXPECT_EQ(Value("group web"), target.var_sources.get("from_web"));
  EXPECT_EQ(Value("--var"), target.var_sources.get("cli"));

  Inventory::Selection db;
  db.host_specs = {"db1.example.com"};
  db.base_vars = map({{"layer", "vars.scm"}});
  EXPECT_EQ(Value("group all"), inventory.select(db).front().vars.get("layer"));
}

TEST(Inventory, connection_options_come_from_the_host) {
  Inventory inventory = load("basic");
  Inventory::Selection selection;
  selection.host_specs = {"db1.example.com"};
  Target target = inventory.select(selection).front();
  EXPECT_EQ(std::optional<std::string>("admin"), target.user);
  EXPECT_EQ(std::optional<int>(2222), target.port);
  EXPECT_TRUE(target.sudo);
  EXPECT_EQ((std::vector<std::string>{"-i", "~/.ssh/db"}), target.ssh_opts);

  Inventory::Selection standalone;
  standalone.host_specs = {"standalone.example.com"};
  EXPECT_EQ(std::string("192.0.2.10"), inventory.select(standalone).front().address);

  Inventory::Selection sudo;
  sudo.host_specs = {"web2.example.com"};
  sudo.sudo = true;
  EXPECT_TRUE(inventory.select(sudo).front().sudo);
}

TEST(Inventory, hosts_not_in_the_inventory_can_still_be_given) {
  Inventory inventory = load("basic");
  Inventory::Selection selection;
  selection.host_specs = {"new.example.com"};
  selection.base_vars = map({{"a", 1}});
  Target target = inventory.select(selection).front();
  EXPECT_EQ(std::string("new.example.com"), target.address);
  EXPECT_EQ(Value(1), target.vars.get("a"));
}

TEST(Inventory, selection_errors) {
  Inventory inventory = load("basic");
  Inventory::Selection unknown;
  unknown.group_names = {"nope"};
  EXPECT_THROWS(UsageError, inventory.select(unknown), "unknown group nope (defined: web, db, all, monitoring)");

  Inventory::Selection none;
  none.group_names = {"db"};
  none.limit = "web*";
  EXPECT_THROWS(UsageError, inventory.select(none), "no hosts match -g db --limit web*");
  EXPECT_THROWS(UsageError, Inventory::empty().select({}), "no hosts match (the inventory is empty)");
}

TEST(Inventory, load_errors) {
  EXPECT_THROWS(RecipeError, load("bad_option"), "hosts.scm:2: host web1: unknown option #:prot");
  EXPECT_THROWS(RecipeError, load("conflict"), "host db1 is declared with port 22 and 2222");
  EXPECT_THROWS(RecipeError, load("cycle"), "groups include each other: a -> b -> c -> a");
  EXPECT_THROWS(RecipeError, load("missing_include"), "group all includes web, which is not defined");
}

TEST(Inventory, an_inventory_can_be_built_from_data) {
  Inventory inventory = load("dynamic");
  EXPECT_EQ((std::vector<std::string>{"web", "db", "listed"}), inventory.group_names());
  EXPECT_EQ((std::vector<std::string>{"app1", "app2"}), inventory.hosts_in_group("web"));
  EXPECT_EQ((std::vector<std::string>{"extra1", "extra2"}), inventory.hosts_in_group("listed"));
  Inventory::Selection selection;
  selection.host_specs = {"app1"};
  EXPECT_EQ(std::string("198.51.100.11"), inventory.select(selection).front().address);
}

TEST(Inventory, an_empty_inventory_has_no_hosts) {
  Shell shell;
  Inventory inventory = Inventory::load(kInventories + "/empty.scm", shell);
  EXPECT_TRUE(inventory.is_empty());
}

TEST(Inventory, groups_cannot_nest_and_vars_need_a_group) {
  Shell shell;
  std::string path = "/tmp/sadame-inventory-test-" + std::to_string(::getpid()) + ".scm";
  shell.write_file(path, "(group 'a (group 'b))");
  EXPECT_THROWS(RecipeError, Inventory::load(path, shell), "groups cannot be nested");
  shell.write_file(path, "(vars #:a 1)");
  EXPECT_THROWS(RecipeError, Inventory::load(path, shell), "vars must be inside a group");
  shell.write_file(path, "(host \"h\" #:port 70000)");
  EXPECT_THROWS(RecipeError, Inventory::load(path, shell), "port must be an integer from 1 to 65535");
  shell.run("rm -f " + path);
}
