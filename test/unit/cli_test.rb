# frozen_string_literal: true

class CLITest < SadameTest
  BASIC = "test/fixtures/recipes/basic"

  def fresh_debian_shell
    fresh_shell("debian")
  end

  def test_help_and_version
    status, stdout, = run_cli(["--help"])
    assert_equal 0, status
    assert_includes stdout, "Usage: sadame COMMAND [RECIPE] [options]"

    status, stdout, = run_cli(["--version"])
    assert_equal 0, status
    assert_equal "sadame #{Sadame::VERSION}\n", stdout
  end

  def test_usage_errors_exit_with_two
    [[[], "missing command"], [["deploy"], "unknown command deploy"], [["plan", "--frobnicate"], "unknown option --frobnicate"],
     [["plan", "a", "b"], "too many arguments"], [["plan", "--var"], "--var expects key=value"],
     [["plan", "test/fixtures/nowhere"], "recipe not found: test/fixtures/nowhere"]].each do |arguments, message|
      status, stdout, stderr = run_cli(arguments)
      assert_equal 2, status, arguments.join(" ")
      assert_equal "", stdout
      assert_includes stderr, message
    end
  end

  def test_plan_accepts_a_directory_and_loads_vars_rb
    status, stdout, = run_cli(["plan", BASIC], shell: fresh_debian_shell)
    assert_equal 0, status
    assert_includes stdout, "sadame #{Sadame::VERSION} plan on local (Debian GNU/Linux 12 (bookworm))"
    assert_includes stdout, "+ package[nginx]\n    state: absent -> installed\n"
    assert_includes stdout, "+  listen 80;\n"
    assert_includes stdout, "notifies: reload service[nginx]"
    assert_includes stdout, "Plan: 3 to create, 1 to update, 0 to remove, 1 to run, 0 unchanged."
  end

  def test_var_overrides_vars_rb
    _status, stdout, = run_cli(["plan", BASIC, "--var", "port=8080", "--var=with_user=true"], shell: fresh_debian_shell)
    assert_includes stdout, "+  listen 8080;\n"
    assert_includes stdout, "+ user[deploy]"
  end

  def test_plan_json
    status, stdout, = run_cli(["plan", BASIC, "--json"], shell: fresh_debian_shell)
    assert_equal 0, status
    assert stdout.start_with?("{\n  \"format_version\": 1,\n")
    assert_includes stdout, "\"command\": \"plan\""
    assert_includes stdout, "\"package_manager\": \"apt\""
    assert_includes stdout, "\"id\": \"package[nginx]\""
    assert_includes stdout, "\"diff\": \"--- current\\n+++ desired\\n@@ -0,0 +1,4 @@\\n+server {\\n"
  end

  def test_apply_returns_one_when_a_resource_fails
    shell = fresh_debian_shell
    shell.on("DEBIAN_FRONTEND=noninteractive apt-get update", stderr: "network down\n", exit_status: 100)
    status, stdout, = run_cli(["apply", BASIC], shell: shell)
    assert_equal 1, status
    assert_includes stdout, "failed     package[nginx]"
    assert_includes stdout, "network down"
    assert_includes stdout, "skipped    directory[/var/www/app]"
  end

  def test_apply_on_a_fresh_host
    shell = fresh_debian_shell
    status, stdout, = run_cli(["apply", BASIC], shell: shell)
    assert_equal 0, status, stdout
    assert_includes stdout, "notified   service[nginx]: reload (delayed, from file[/etc/nginx/conf.d/app.conf])"
    assert_includes stdout, "\nSummary\n  changed      5  package[nginx]\n"
    assert_includes stdout, "  notified     1  service[nginx]: reload\n"
    expected = [
      "DEBIAN_FRONTEND=noninteractive apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx",
      "mkdir -p /var/www/app",
      "chmod 0755 /var/www/app",
      "chown www-data /var/www/app",
      "write /etc/nginx/conf.d/app.conf.sadame-new",
      "chmod 0644 /etc/nginx/conf.d/app.conf.sadame-new",
      "mv -f /etc/nginx/conf.d/app.conf.sadame-new /etc/nginx/conf.d/app.conf",
      "systemctl enable nginx",
      "systemctl start nginx",
      "touch /var/www/app/.ready",
      "systemctl reload nginx"
    ]
    changes = shell.commands.reject { |command| FreshHostShell::QUERY_PREFIXES.any? { |prefix| command.start_with?(prefix) } }
    assert_equal expected, changes - ["uname -s"]
  end

  def test_drift_exits_one_when_the_host_differs
    status, stdout, = run_cli(["drift", BASIC], shell: fresh_debian_shell)
    assert_equal 1, status
    assert_includes stdout, "sadame #{Sadame::VERSION} drift on local"
    assert_includes stdout, "+ package[nginx]\n"
    assert_includes stdout, "Drift: 5 of 5 resources differ from the recipe.\n"
  end

  def test_drift_exits_zero_when_the_host_matches
    shell = linux_shell("debian")
    status, stdout, = run_cli(["drift", "examples/resources/package/minimal.rb"], shell: shell)
    assert_equal 1, status, stdout

    shell.on("dpkg-query -W -f='${Status}' htop", stdout: "install ok installed")
    status, stdout, = run_cli(["drift", "examples/resources/package/minimal.rb"], shell: shell)
    assert_equal 0, status
    assert_includes stdout, "No drift: 1 resource matches the recipe.\n"
  end

  def test_drift_and_plan_exit_two_when_state_cannot_be_read
    shell = fresh_debian_shell.on("test -d /run/systemd/system", exit_status: 1)
    status, stdout, = run_cli(["drift", BASIC], shell: shell)
    assert_equal 2, status
    assert_includes stdout, "x service[nginx]\n"
    assert_includes stdout, "Could not check 1 resource; see the errors above.\n"

    status, = run_cli(["plan", BASIC], shell: shell)
    assert_equal 2, status
  end

  def test_drift_json
    status, stdout, = run_cli(["drift", BASIC, "--json"], shell: fresh_debian_shell)
    assert_equal 1, status
    assert_includes stdout, "\"command\": \"drift\""
    assert_includes stdout, "\"drift\": true,\n  \"failed\": false,\n  \"exit_status\": 1,\n"
    assert_includes stdout, "\"notifications\": [\n        {\n          \"action\": \"reload\",\n"
  end

  def test_hosts_lists_targets_with_their_vars
    status, stdout, = run_cli(["hosts", "--inventory", "test/fixtures/inventories/basic/hosts.rb", "-g", "db"])
    assert_equal 0, status
    assert_includes stdout, "sadame #{Sadame::VERSION} hosts: 1 host from test/fixtures/inventories/basic/hosts.rb\n"
    assert_includes stdout, "\ndb1.example.com\n  address   db1.example.com\n  user      admin\n  port      2222\n"
    assert_includes stdout, "  sudo      yes\n  ssh_opts  -i '~/.ssh/db'\n  groups    db, all\n"
    assert_includes stdout, "    env    \"production\"  group all\n"
  end

  def test_hosts_json
    _status, stdout, = run_cli(["hosts", "--inventory", "test/fixtures/inventories/basic/hosts.rb", "--limit", "web2*",
                                "--json"])
    assert_includes stdout, "\"command\": \"hosts\""
    assert_includes stdout, "\"name\": \"web2.example.com\""
    assert_includes stdout, "\"layer\": \"group all\""
  end

  def test_hosts_needs_an_inventory_or_hosts
    status, _stdout, stderr = run_cli(["hosts", "examples/01-hello"])
    assert_equal 2, status
    assert_includes stderr, "no hosts: examples/01-hello/hosts.rb not found; use --inventory or -h"
  end

  def test_remote_only_and_local_only_options
    status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "--sudo"])
    assert_equal 2, status
    assert_includes stderr, "--sudo only applies to -h, -g and --limit"

    status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "-h", "web1", "--vars-file", "x.rb"])
    assert_equal 2, status
    assert_includes stderr, "--vars-file is for local runs"

    status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "-g", "web"])
    assert_equal 2, status
    assert_includes stderr, "unknown group web (no groups are defined)"

    status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "--inventory", "missing.rb", "-g", "web"])
    assert_equal 2, status
    assert_includes stderr, "inventory not found: missing.rb"

    ["--forks", "--serial"].each do |flag|
      status, _stdout, stderr = run_cli(["plan", "examples/01-hello", flag, "2"])
      assert_equal 2, status
      assert_includes stderr, "#{flag} only applies to -h, -g and --limit"
    end
  end

  def test_forks_and_serial_values
    ["0", "-1", "two", "1.5", ""].each do |value|
      status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "-h", "web1", "--forks", value])
      assert_equal 2, status, value
      assert_includes stderr, "--forks needs", value
    end
    ["0%", "101%", "x%", "0"].each do |value|
      status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "-h", "web1", "--serial=#{value}"])
      assert_equal 2, status, value
      assert_includes stderr, "--serial needs", value
    end
  end

  def test_vars_file_and_name_for_local_runs
    status, stdout, = run_cli(["plan", BASIC, "--vars-file", "test/fixtures/vars/vars.rb", "--host-name", "web1", "--json"],
                              shell: fresh_debian_shell)
    assert_equal 0, status
    assert_includes stdout, "\"host\": \"web1\""
    assert_includes stdout, "server_name example.com;"
  end

  def test_host_groups_for_local_runs
    _status, stdout, = run_cli(["plan", "test/fixtures/recipes/roles/site.rb", "--host-groups", "web"],
                               shell: fresh_debian_shell)
    assert_includes stdout, "+ package[nginx]"
  end

  def test_option_values_can_be_attached_with_equals
    status, stdout, = run_cli(["hosts", "--inventory=test/fixtures/inventories/basic/hosts.rb", "--group=db",
                               "--host=extra.example.com", "--limit=*.example.com"])
    assert_equal 0, status
    assert_includes stdout, "2 hosts from"
  end

  def test_recipe_errors_exit_with_two
    status, stdout, stderr = run_cli(["plan", "test/fixtures/recipes/unknown_option"])
    assert_equal 2, status
    assert_equal "", stdout
    assert_includes stderr, "sadame: test/fixtures/recipes/unknown_option/recipe.rb:2: file[/etc/motd]: unknown option :contents"
  end

  def test_colors_follow_tty_and_no_color
    stdout = FakeIO.new(tty: true)
    Sadame::CLI.new(["plan", BASIC], stdout: stdout, stderr: FakeIO.new, shell: fresh_debian_shell, environment: {}).run
    assert_includes stdout.string, "\e[32m+ package[nginx]\e[0m"

    stdout = FakeIO.new(tty: true)
    Sadame::CLI.new(["plan", BASIC], stdout: stdout, stderr: FakeIO.new, shell: fresh_debian_shell,
                                     environment: { "NO_COLOR" => "1" }).run
    refute_includes stdout.string, "\e["

    stdout = FakeIO.new(tty: true)
    Sadame::CLI.new(["plan", BASIC, "--no-color"], stdout: stdout, stderr: FakeIO.new, shell: fresh_debian_shell,
                                                   environment: {}).run
    refute_includes stdout.string, "\e["
  end
end
