# frozen_string_literal: true

class GitResourceTest < SadameTest
  PATH = "/srv/app"
  REPO = "https://github.com/example/app.git"
  OLD = "1" * 40
  NEW = "2" * 40
  TAG_OBJECT = "3" * 40

  def git_command(arguments)
    "GIT_TERMINAL_PROMPT=0 git -c safe.directory=#{PATH} #{arguments}"
  end

  def ls_remote(revision)
    refs = ["'refs/tags/#{revision}^{}'", "refs/tags/#{revision}", "refs/heads/#{revision}"].join(" ")
    git_command("ls-remote #{REPO} #{refs}")
  end

  def git_resource(options, shell)
    build_resource(Sadame::GitResource, PATH, { repository: REPO }.merge(options), shell: shell)
  end

  def fresh(remote_output)
    shell = stub_missing(linux_shell, PATH)
    shell.on(ls_remote("main"), stdout: remote_output)
  end

  def checkout(head: OLD, url: REPO)
    shell = stub_stat(linux_shell, PATH, type: "directory")
    shell.on("test -d #{PATH}/.git")
    shell.on(git_command("-C #{PATH} config --get remote.origin.url"), stdout: "#{url}\n")
    shell.on(git_command("-C #{PATH} rev-parse HEAD"), stdout: "#{head}\n")
  end

  def test_clones_and_checks_out_the_branch_head
    shell = fresh("#{NEW}\trefs/heads/main\n")
    git = git_resource({ revision: "main" }, shell)
    changes = git.diff
    assert_equal :create, git.plan_action(changes)
    assert_equal [:state, :repository, :revision], change_attributes(changes)
    git.apply(changes)
    assert_equal [
      git_command("clone --quiet --no-checkout #{REPO} #{PATH}"),
      git_command("-C #{PATH} checkout --quiet --force --detach #{NEW}")
    ], shell.commands.last(2)
  end

  def test_tags_win_over_branches_and_are_peeled
    output = "#{OLD}\trefs/heads/main\n#{TAG_OBJECT}\trefs/tags/main\n#{NEW}\trefs/tags/main^{}\n"
    assert_equal NEW, git_resource({ revision: "main" }, fresh(output)).diff.last.to
    assert_equal TAG_OBJECT, git_resource({ revision: "main" }, fresh("#{TAG_OBJECT}\trefs/tags/main\n")).diff.last.to
  end

  def test_without_revision_follows_the_remote_head
    shell = stub_missing(linux_shell, PATH).on(git_command("ls-remote #{REPO} HEAD"), stdout: "#{NEW}\tHEAD\n")
    assert_equal NEW, git_resource({}, shell).diff.last.to
  end

  def test_a_commit_needs_no_remote_lookup
    shell = checkout(head: NEW)
    assert_empty git_resource({ revision: NEW }, shell).diff
    refute(shell.commands.any? { |command| command.include?("ls-remote") })
  end

  def test_an_up_to_date_checkout_is_unchanged
    shell = checkout(head: NEW).on(ls_remote("main"), stdout: "#{NEW}\trefs/heads/main\n")
    assert_empty git_resource({ revision: "main" }, shell).diff
  end

  def test_moves_the_checkout_when_the_branch_moved
    shell = checkout(head: OLD).on(ls_remote("main"), stdout: "#{NEW}\trefs/heads/main\n")
    git = git_resource({ revision: "main" }, shell)
    changes = git.diff
    assert_equal :update, git.plan_action(changes)
    assert_equal [[:revision, OLD, NEW]], changes.map { |change| [change.attribute, change.from, change.to] }
    git.apply(changes)
    assert_equal [
      git_command("-C #{PATH} fetch --quiet --tags origin"),
      git_command("-C #{PATH} checkout --quiet --force --detach #{NEW}")
    ], shell.commands.last(2)
  end

  def test_a_new_repository_url_is_set_without_moving_the_checkout
    shell = checkout(head: NEW, url: "https://old.example.com/app.git").on(ls_remote("main"), stdout: "#{NEW}\trefs/heads/main\n")
    git = git_resource({ revision: "main" }, shell)
    git.apply(git.diff)
    assert_equal [
      git_command("-C #{PATH} remote set-url origin #{REPO}"),
      git_command("-C #{PATH} fetch --quiet --tags origin")
    ], shell.commands.last(2)
  end

  def test_runs_git_as_the_user
    shell = stub_missing(linux_shell, PATH)
    lookup = "cd / && GIT_TERMINAL_PROMPT=0 git ls-remote #{REPO} HEAD"
    shell.on("su -s /bin/sh deploy -c '#{lookup}'", stdout: "#{NEW}\tHEAD\n")
    git = git_resource({ user: "deploy" }, shell)
    git.apply(git.diff)
    assert_equal "su -s /bin/sh deploy -c 'cd / && GIT_TERMINAL_PROMPT=0 git -C /srv/app checkout --quiet " \
                 "--force --detach #{NEW}'", shell.commands.last
  end

  def test_plan_on_a_machine_without_git_shows_the_revision_as_written
    shell = stub_missing(linux_shell, PATH).on("command -v git", exit_status: 1)
    git = git_resource({ revision: "v1.4.2" }, shell)
    changes = git.diff
    assert_equal "v1.4.2", changes.last.to
    error = assert_raises(Sadame::ResourceError) { git.apply(changes) }
    assert_includes error.message, "git is not installed"
  end

  def test_errors_from_the_remote
    error = assert_raises(Sadame::ResourceError) { git_resource({ revision: "main" }, fresh("")).diff }
    assert_includes error.message, "#{REPO} has no branch or tag named main"

    shell = stub_missing(linux_shell, PATH)
    shell.on(ls_remote("main"), stderr: "fatal: repository '#{REPO}' not found\n", exit_status: 128)
    error = assert_raises(Sadame::ResourceError) { git_resource({ revision: "main" }, shell).diff }
    assert_includes error.message, "cannot read #{REPO}"
    assert_includes error.message, "fatal: repository"
  end

  def test_an_empty_directory_is_cloned_into
    shell = stub_stat(linux_shell, PATH, type: "directory").on("test -d #{PATH}/.git", exit_status: 1)
    shell.on(ls_remote("main"), stdout: "#{NEW}\trefs/heads/main\n")
    git = git_resource({ revision: "main" }, shell)
    assert_equal :create, git.plan_action(git.diff)

    shell.on("ls -A #{PATH}", stdout: "index.html\n")
    error = assert_raises(Sadame::ResourceError) { git_resource({ revision: "main" }, shell).diff }
    assert_includes error.message, "is a directory with files in it, but not a git checkout"
  end

  def test_removes_a_checkout
    shell = checkout
    git = git_resource({ state: :absent }, shell)
    changes = git.diff
    assert_equal :remove, git.plan_action(changes)
    git.apply(changes)
    assert_equal "rm -rf #{PATH}", shell.commands.last
  end

  def test_validation
    error = assert_raises(Sadame::ResourceError) { build_resource(Sadame::GitResource, PATH, {}, shell: linux_shell) }
    assert_includes error.message, "repository: is required"
    error = assert_raises(Sadame::ResourceError) { git_resource({ revision: 3 }, linux_shell) }
    assert_includes error.message, "revision must be a non-empty String"
  end
end
