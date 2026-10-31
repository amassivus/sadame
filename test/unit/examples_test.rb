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
    "examples/notifications/recipe.rb" => [
      "debian",
      ["exec[systemctl daemon-reload]", "file[/etc/systemd/system/ticker.service]", "file[/etc/default/ticker]",
       "service[ticker]"]
    ]
  }.freeze

  # Ruby files that are not entry points: vars, and recipes that are only
  # used through include_recipe.
  SUPPORT_FILE_NAMES = ["vars.rb", "hosts.rb"].freeze
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

  def test_ci_examples_run_drift_and_keep_the_report
    github = File.read("examples/ci/github-actions-drift.yml")
    assert_includes github, "ssh \"$SSH_TARGET\" 'sudo sadame drift sadame-recipe --json' > drift.json"
    assert_includes github, "if: always()"
    assert_includes github, "path: drift.json"

    gitlab = File.read("examples/ci/gitlab-ci-drift.yml")
    assert_includes gitlab, "ssh \"$SSH_TARGET\" 'sudo sadame drift sadame-recipe --json' > drift.json"
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
      path.end_with?(".rb") && !SUPPORT_FILE_NAMES.include?(File.basename(path)) &&
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
