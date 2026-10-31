# frozen_string_literal: true

class InventoryTest < SadameTest
  BASIC = "test/fixtures/inventories/basic/hosts.rb"

  def inventory(path = BASIC, shell: linux_shell)
    Sadame::Inventory.load(path, shell: shell)
  end

  def target(name, base_vars: {}, cli_vars: {})
    inventory.select(host_specs: [name], base_vars: base_vars, cli_vars: cli_vars).first
  end

  def names(targets)
    targets.map { |target| target.name }
  end

  def test_hosts_and_groups_in_declaration_order
    loaded = inventory
    assert_equal ["web1.example.com", "web2.example.com", "db1.example.com", "standalone.example.com"], loaded.host_names
    assert_equal [:web, :db, :all, :monitoring], loaded.group_names
  end

  def test_included_groups_contribute_their_hosts
    assert_equal ["web1.example.com", "web2.example.com", "db1.example.com"], inventory.hosts_in_group(:all)
  end

  def test_groups_are_ordered_so_including_groups_come_later
    assert_equal [:web, :all, :monitoring], inventory.groups_of("web1.example.com")
    assert_equal [:db, :all], inventory.groups_of("db1.example.com")
  end

  def test_connection_options
    db = target("db1.example.com")
    assert_equal ["admin", 2222, true, ["-i", "~/.ssh/db"]], [db.user, db.port, db.sudo, db.ssh_opts]
    assert_equal "db1.example.com", db.address
    assert_equal "192.0.2.10", target("standalone.example.com").address
  end

  # Precedence, highest first: --var, host vars, group vars (the including
  # group over the included one), vars.rb. One assertion per layer.
  def test_vars_rb_is_the_lowest_layer
    web2 = target("web2.example.com", base_vars: { only_in_vars_rb: 1, from_web: false })
    assert_equal 1, web2.vars[:only_in_vars_rb]
    assert_equal "vars.rb", web2.var_sources[:only_in_vars_rb]
    assert_equal true, web2.vars[:from_web]
  end

  def test_group_vars_override_vars_rb
    web2 = target("web2.example.com", base_vars: { env: "staging" })
    assert_equal "production", web2.vars[:env]
    assert_equal "group all", web2.var_sources[:env]
  end

  def test_including_group_overrides_included_group
    web2 = target("web2.example.com")
    assert_equal "group all", web2.vars[:layer]
    assert_equal true, web2.vars[:from_web]
    assert_equal "group web", web2.var_sources[:from_web]
  end

  def test_host_vars_override_group_vars
    web1 = target("web1.example.com")
    assert_equal "host", web1.vars[:layer]
    assert_equal "host", web1.var_sources[:layer]
  end

  def test_cli_vars_override_host_vars
    web1 = target("web1.example.com", cli_vars: { layer: "cli" })
    assert_equal "cli", web1.vars[:layer]
    assert_equal "--var", web1.var_sources[:layer]
  end

  def test_select_by_group_host_and_limit
    loaded = inventory
    assert_equal ["web1.example.com", "web2.example.com"], names(loaded.select(group_names: ["web"]))
    assert_equal ["web1.example.com", "web2.example.com", "db1.example.com"], names(loaded.select(group_names: ["all"]))
    assert_equal ["db1.example.com", "web1.example.com"],
                 names(loaded.select(group_names: ["db"], host_specs: ["web1.example.com"]))
    assert_equal ["web1.example.com"], names(loaded.select(group_names: ["all"], limit: "web1*"))
    assert_equal ["web1.example.com", "web2.example.com"], names(loaded.select(limit: "web*"))
  end

  def test_host_flag_overrides_user_and_port
    db = inventory.select(host_specs: ["root@db1.example.com:22"]).first
    assert_equal ["root", 22, true], [db.user, db.port, db.sudo]
  end

  def test_hosts_not_in_the_inventory_still_work
    adhoc = inventory.select(host_specs: ["deploy@new.example.com:2200"], base_vars: { a: 1 }).first
    assert_equal ["new.example.com", "deploy", 2200, []], [adhoc.name, adhoc.user, adhoc.port, adhoc.groups]
    assert_equal({ a: 1 }, adhoc.vars)
    assert_equal "plain", Sadame::Inventory.empty.select(host_specs: ["plain"]).first.name
  end

  def test_sudo_flag_applies_to_every_target
    assert inventory.select(group_names: ["web"], sudo: true).all? { |selected| selected.sudo }
  end

  def test_selection_errors
    error = assert_raises(Sadame::UsageError) { inventory.select(group_names: ["cache"]) }
    assert_includes error.message, "unknown group cache (defined: web, db, all, monitoring)"
    error = assert_raises(Sadame::UsageError) { inventory.select(limit: "nothing*") }
    assert_includes error.message, "no hosts match --limit nothing*"
  end

  def test_include_cycles_and_unknown_groups_are_rejected
    error = assert_raises(Sadame::RecipeError) { inventory("test/fixtures/inventories/cycle/hosts.rb") }
    assert_includes error.message, "groups include each other: a -> b -> c -> a"
    error = assert_raises(Sadame::RecipeError) { inventory("test/fixtures/inventories/missing_include/hosts.rb") }
    assert_includes error.message, "group all includes web, which is not defined"
  end

  def test_conflicting_declarations_are_rejected
    error = assert_raises(Sadame::RecipeError) { inventory("test/fixtures/inventories/conflict/hosts.rb") }
    assert_includes error.message, "host db1 is declared with port 22 and 2222"
  end

  def test_option_errors_point_at_the_line
    error = assert_raises(Sadame::RecipeError) { inventory("test/fixtures/inventories/bad_option/hosts.rb") }
    assert_includes error.message, "test/fixtures/inventories/bad_option/hosts.rb:2"
    assert_includes error.message, "host web1: unknown option :prot"
  end

  def test_dynamic_inventory_from_json_and_a_command
    shell = linux_shell.on("printf 'extra1\\nextra2\\n'", stdout: "extra1\nextra2\n")
    loaded = inventory("test/fixtures/inventories/dynamic/hosts.rb", shell: shell)
    assert_equal ["app1", "app2", "data1", "extra1", "extra2"], loaded.host_names
    assert_equal [:web, :db, :listed], loaded.group_names
    assert_equal "198.51.100.21", loaded.select(group_names: ["db"]).first.address
  end
end
