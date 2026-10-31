# frozen_string_literal: true

# Every recipe under examples/ is loaded, planned and applied against a fake
# fresh machine here, so the examples the docs show keep working.
class ExamplesTest < SadameTest
  EXAMPLES = {
    "examples/01-hello/recipe.rb" => ["debian", ["file[/tmp/sadame-hello.txt]"]],
    "examples/basics/recipe.rb" => [
      "debian",
      ["package[curl]", "package[less]", "directory[/etc/sadame-demo]", "file[/etc/motd]"]
    ],
    "examples/quickstart/recipe.rb" => [
      "debian", ["package[nginx]", "file[/var/www/html/index.html]", "service[nginx]"]
    ],
    "examples/resources/package/recipe.rb" => ["arch", ["package[tree]", "package[htop]", "package[nano]"]],
    "examples/resources/package/aur.rb" => ["arch", ["exec[runuser -u alice -- yay -S --needed --noconfirm visual-studio-code-bin]"]],
    "examples/resources/file/recipe.rb" => [
      "debian",
      ["file[/etc/issue.net]", "directory[/etc/hello]", "file[/etc/hello/hello.conf]", "file[/usr/local/bin/hello]",
       "file[/etc/hello/old.conf]"]
    ],
    "examples/resources/directory/recipe.rb" => [
      "debian", ["directory[/srv/app]", "directory[/srv/app/shared]", "directory[/srv/app/tmp]"]
    ],
    "examples/resources/service/recipe.rb" => ["debian", ["package[nginx]", "service[nginx]"]],
    "examples/resources/exec/recipe.rb" => [
      "debian",
      ["directory[/opt/demo]", "exec[tar -czf /opt/demo/etc-backup.tar.gz -C /etc hostname hosts]",
       "exec[echo 'EDITOR=vim' >> /etc/environment]", "exec[git config --system init.defaultBranch main]",
       "exec[echo \"built by $BUILDER\" > build-info.txt]"]
    ],
    "examples/resources/user/recipe.rb" => ["debian", ["user[deploy]", "user[svc-backup]"]],
    "examples/resources/package/minimal.rb" => ["debian", ["package[htop]"]],
    "examples/resources/package/by_family.rb" => ["rocky", ["package[httpd]"]],
    "examples/resources/file/minimal.rb" => ["debian", ["file[/etc/motd]"]],
    "examples/resources/directory/minimal.rb" => ["debian", ["directory[/srv/app]"]],
    "examples/resources/service/minimal.rb" => ["debian", ["service[nginx]"]],
    "examples/resources/service/reload_on_change.rb" => [
      "debian", ["package[nginx]", "file[/etc/nginx/conf.d/status.conf]", "service[nginx]"]
    ],
    "examples/resources/exec/minimal.rb" => ["debian", ["exec[tar -czf /var/backups/etc.tar.gz /etc]"]],
    "examples/resources/user/minimal.rb" => ["debian", ["user[deploy]"]],
    "examples/resources/user/docker_group.rb" => ["debian", ["package[docker.io]", "user[deploy]"]],
    "examples/resources/user/remove.rb" => ["debian", ["user[olduser]"]],
    "examples/10-drift-demo/recipe.rb" => [
      "debian",
      ["package[nginx]", "user[demo-app]", "directory[/etc/demo-app]", "file[/etc/demo-app/app.conf]", "service[nginx]"]
    ],
    "examples/08-multi-role-inventory/site.rb" => ["debian", ["file[/etc/motd]"]],
    "examples/11-dynamic-inventory/recipe.rb" => ["debian", ["file[/etc/motd]"]],
    "examples/notifications/recipe.rb" => [
      "debian",
      ["exec[systemctl daemon-reload]", "file[/etc/systemd/system/ticker.service]", "file[/etc/default/ticker]",
       "service[ticker]"]
    ]
  }.freeze

  # Inventories, and the cloud CLI output their commands are faked with.
  INVENTORIES = {
    "examples/08-multi-role-inventory/hosts.rb" => [
      nil, { web: ["web1.example.com", "web2.example.com"], db: ["db1.example.com"],
             all: ["web1.example.com", "web2.example.com", "db1.example.com"] }
    ],
    "examples/11-dynamic-inventory/hosts.rb" => [
      nil, { web: ["web1.example.com", "web2.example.com"], db: ["db1.example.com"],
             all: ["web1.example.com", "web2.example.com", "db1.example.com"] }
    ],
    "examples/11-dynamic-inventory/hosts-hcloud.rb" => [
      ["hcloud server list -o json", "test/fixtures/cloud/hcloud.json"], { web: ["web-1"], db: ["db-1"] }
    ],
    "examples/11-dynamic-inventory/hosts-doctl.rb" => [
      ["doctl compute droplet list --output json", "test/fixtures/cloud/doctl.json"],
      { web: ["web-01"], frontend: ["web-01"], db: ["db-01"] }
    ],
    "examples/11-dynamic-inventory/hosts-aws.rb" => [
      ["aws ec2 describe-instances --filters Name=instance-state-name,Values=running --output json",
       "test/fixtures/cloud/aws.json"],
      { web: ["web-a"], db: ["i-0a1b2c3d4e5f60003"] }
    ]
  }.freeze

  # Ruby files that are not entry points: vars, inventories, and recipes
  # that are only used through include_recipe.
  SUPPORT_FILE_NAMES = ["vars.rb"].freeze
  INCLUDED_RECIPE_DIRECTORIES = ["parts", "roles"].freeze

  # --var values that make examples independent of the machine running the tests.
  FIXED_VARS = ["--var", "aur_user=alice"].freeze

  def test_every_recipe_is_covered
    recipe_files("examples").each do |path|
      assert_includes EXAMPLES.keys, path, "#{path} is not exercised by ExamplesTest"
    end
  end

  def test_examples_declare_the_expected_resources
    EXAMPLES.each do |path, (distribution, ids)|
      resources = Sadame::Recipe.load(path, host: host_for(fresh_shell(distribution)), vars: example_vars(path))
      assert_equal ids, resources.to_a.map { |resource| resource.id }, path
    end
  end

  def test_examples_plan_and_apply_on_a_fresh_machine
    EXAMPLES.each do |path, (distribution, _ids)|
      status, stdout, stderr = run_cli(["plan", path] + FIXED_VARS, shell: fresh_shell(distribution))
      assert_equal 0, status, "plan #{path}: #{stderr}"
      refute_includes stdout, "\nx ", path

      status, stdout, stderr = run_cli(["apply", path] + FIXED_VARS, shell: fresh_shell(distribution))
      assert_equal 0, status, "apply #{path}: #{stdout}#{stderr}"
    end
  end

  def test_inventories_build_the_expected_groups
    INVENTORIES.each do |path, (fake_command, groups)|
      shell = linux_shell
      shell.on(fake_command[0], stdout: File.read(fake_command[1])) if fake_command
      inventory = Sadame::Inventory.load(path, shell: shell)
      groups.each do |group, hosts|
        assert_equal hosts, inventory.hosts_in_group(group), "#{path} group #{group}"
      end
    end
  end

  def test_every_inventory_is_covered
    walk("examples").select { |path| File.basename(path).start_with?("hosts") && path.end_with?(".rb") }.each do |path|
      assert_includes INVENTORIES.keys, path, "#{path} is not exercised by ExamplesTest"
    end
  end

  def test_multi_role_example_includes_roles_by_group
    path = "examples/08-multi-role-inventory/site.rb"
    vars = Sadame::Vars.merge(Sadame::Vars.load_file("examples/08-multi-role-inventory/vars.rb"))
    expectations = {
      [:web, :all] => ["file[/etc/motd]", "package[nginx]", "directory[/etc/demo-app]", "file[/etc/demo-app/web.conf]",
                       "file[/etc/nginx/conf.d/demo-app.conf]", "service[nginx]"],
      [:db, :all] => ["file[/etc/motd]", "package[sqlite3]", "package[cron]", "user[demo-db]",
                      "directory[/var/lib/demo-db]", "file[/etc/cron.d/demo-db-backup]"]
    }
    expectations.each do |groups, ids|
      host = Sadame::Host.new(fresh_shell("debian"), name: "#{groups.first}1.example.com", groups: groups)
      resources = Sadame::Recipe.load(path, host: host, vars: vars)
      assert_equal ids, resources.to_a.map { |resource| resource.id }
    end
  end

  def test_ci_examples_run_drift_and_keep_the_report
    github = File.read("examples/ci/github-actions-drift.yml")
    assert_includes github, "run: sadame drift site/site.rb -g all --json > drift.json"
    assert_includes github, "install.sh | sh"
    assert_includes github, "if: always()"
    assert_includes github, "path: drift.json"

    gitlab = File.read("examples/ci/gitlab-ci-drift.yml")
    assert_includes gitlab, "- sadame drift site/site.rb -g all --json > drift.json"
    assert_includes gitlab, "install.sh | sh"
    assert_includes gitlab, "when: always"
    assert_includes gitlab, "- drift.json"
  end

  def test_ci_examples_are_valid_yaml
    skip "mruby has no YAML parser" unless RUBY_ENGINE == "ruby"

    require "yaml"
    github = YAML.safe_load(File.read("examples/ci/github-actions-drift.yml"))
    assert_equal ["drift"], github["jobs"].keys
    gitlab = YAML.safe_load(File.read("examples/ci/gitlab-ci-drift.yml"))
    assert_equal ["always"], [gitlab["drift"]["artifacts"]["when"]]
  end

  def test_paths_mentioned_in_the_docs_exist
    (markdown_files("docs") + ["README.md"]).each do |document|
      File.read(document).scan(%r{examples/[A-Za-z0-9_./-]+}).each do |reference|
        path = reference.sub(%r{[.]+\z}, "")
        assert File.exist?(path), "#{document} mentions #{path}, which does not exist"
      end
    end
  end

  private

  def example_vars(path)
    Sadame::Vars.merge(Sadame::Vars.load_file(File.join(File.dirname(path), "vars.rb")), { aur_user: "alice" })
  end

  def recipe_files(directory)
    walk(directory).select do |path|
      name = File.basename(path)
      path.end_with?(".rb") && !SUPPORT_FILE_NAMES.include?(name) && !name.start_with?("hosts") &&
        !INCLUDED_RECIPE_DIRECTORIES.include?(File.basename(File.dirname(path)))
    end
  end

  def markdown_files(directory)
    walk(directory).select { |path| path.end_with?(".md") }
  end

  # Dir.glob is not available in mruby, so walk the tree by hand.
  def walk(directory)
    paths = []
    Dir.entries(directory).sort.each do |entry|
      next if entry.start_with?(".")

      path = File.join(directory, entry)
      if File.directory?(path)
        paths.concat(walk(path))
      else
        paths << path
      end
    end
    paths
  end
end
