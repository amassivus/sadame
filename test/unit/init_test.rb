# frozen_string_literal: true

class InitTest < SadameTest
  def test_writes_a_project_that_validates
    shell = linux_shell
    status, stdout, = run_cli(["init", "/tmp/sadame-init-test-does-not-exist"], shell: shell)
    assert_equal 0, status
    dir = "/tmp/sadame-init-test-does-not-exist"
    assert_equal ["#{dir}/recipe.rb", "#{dir}/vars.rb", "#{dir}/hosts.rb", "#{dir}/templates/motd.erb"],
                 shell.files.keys - ["/etc/os-release"]
    assert_includes shell.commands, "mkdir -p #{dir}/templates"
    assert_includes stdout, "created #{dir}/recipe.rb\n"
    assert_includes stdout, "  sudo sadame plan #{dir}       see what it would change on this machine\n"

    host = Sadame::StandIn::Host.new(name: "local", groups: [], platform: Sadame::StandIn.platform("debian"))
    vars = Sadame::Vars.merge(instance_eval(shell.files["#{dir}/vars.rb"]))
    motd = shell.files["#{dir}/templates/motd.erb"]
    rendered = Sadame::Template.new(motd, "motd.erb").render(vars: vars, facts: host.facts)
    assert_equal "local: 2 CPUs, 2048 MB of memory\nManaged by sadame; changes made here by hand will be undone.\n" \
                 "Questions: ops@example.com\n", rendered
    assert_includes shell.files["#{dir}/recipe.rb"], "file \"/etc/motd\", template: \"motd.erb\", mode: \"0644\"\n"
  end

  def test_ci_files_go_in_the_current_directory
    shell = linux_shell
    status, stdout, = run_cli(["init", "infra", "--ci", "github"], shell: shell)
    assert_equal 0, status
    workflow = shell.files[".github/workflows/sadame-drift.yml"]
    assert_includes workflow, "# Written by `sadame init`.\n"
    assert_includes workflow, "run: sadame drift infra/recipe.rb -g all --json > drift.json\n"
    assert_includes stdout, "created .github/workflows/sadame-drift.yml\n"

    shell = linux_shell
    run_cli(["init", "--ci", "gitlab"], shell: shell)
    job = shell.files[".gitlab/sadame-drift.yml"]
    assert_includes job, "#     - local: .gitlab/sadame-drift.yml\n"
    assert_includes job, "- sadame drift recipe.rb -g all --json > drift.json\n"
    assert_includes job, "- sadame report drift.json --format junit > drift.xml\n"
  end

  def test_never_overwrites
    shell = linux_shell
    status, _stdout, stderr = run_cli(["init", "examples/01-hello"], shell: shell)
    assert_equal 2, status
    assert_includes stderr, "init writes nothing when one of its files exists, and these do: examples/01-hello/recipe.rb"
    assert_equal ["/etc/os-release"], shell.files.keys
  end

  def test_options
    status, _stdout, stderr = run_cli(["init", "x", "--ci", "jenkins"])
    assert_equal [2, true], [status, stderr.include?("--ci must be one of github, gitlab, got jenkins")]
    status, _stdout, stderr = run_cli(["init", "/srv/infra", "--ci", "github"])
    assert_equal [2, true], [status, stderr.include?("with --ci, give the directory relative to the repository's root")]
    status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "--ci", "github"])
    assert_equal [2, true], [status, stderr.include?("--ci only applies to init")]
  end

  def test_an_empty_inventory_says_so
    status, _stdout, stderr = run_cli(["hosts", "--inventory", "test/fixtures/inventories/empty.rb"])
    assert_equal 2, status
    assert_includes stderr, "no hosts in test/fixtures/inventories/empty.rb yet; declare some there, or use -h"
  end
end
