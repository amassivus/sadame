# frozen_string_literal: true

class LinkResourceTest < SadameTest
  PATH = "/etc/nginx/sites-enabled/app"
  TARGET = "/etc/nginx/sites-available/app"

  def link_resource(options, shell)
    build_resource(Sadame::LinkResource, PATH, options, shell: shell)
  end

  def symlink_shell(target)
    shell = stub_stat(linux_shell, PATH, mode: "777", type: "symbolic link")
    shell.on("readlink #{PATH}", stdout: "#{target}\n")
  end

  def test_creates_a_missing_link
    shell = stub_missing(linux_shell, PATH)
    link = link_resource({ to: TARGET }, shell)
    changes = link.diff
    assert_equal :create, link.plan_action(changes)
    assert_equal [:state, :to], change_attributes(changes)
    link.apply(changes)
    assert_equal "ln -sfn #{TARGET} #{PATH}", shell.commands.last
  end

  def test_a_link_to_the_target_is_unchanged
    assert_empty link_resource({ to: TARGET }, symlink_shell(TARGET)).diff
  end

  def test_repoints_a_link
    shell = symlink_shell("/etc/nginx/sites-available/old")
    link = link_resource({ to: TARGET }, shell)
    changes = link.diff
    assert_equal :update, link.plan_action(changes)
    assert_equal ["/etc/nginx/sites-available/old", TARGET], [changes.first.from, changes.first.to]
    link.apply(changes)
    assert_equal "ln -sfn #{TARGET} #{PATH}", shell.commands.last
  end

  def test_relative_targets_are_compared_as_written
    assert_empty link_resource({ to: "../sites-available/app" }, symlink_shell("../sites-available/app")).diff
  end

  def test_removes_a_link
    shell = symlink_shell(TARGET)
    link = link_resource({ state: :absent }, shell)
    changes = link.diff
    assert_equal :remove, link.plan_action(changes)
    link.apply(changes)
    assert_equal "rm -f #{PATH}", shell.commands.last
    assert_empty link_resource({ state: :absent }, stub_missing(linux_shell, PATH)).diff
  end

  def test_a_regular_file_in_the_way
    shell = stub_stat(linux_shell, PATH)
    error = assert_raises(Sadame::ResourceError) { link_resource({ to: TARGET }, shell).diff }
    assert_includes error.message, "is a regular file, not a symbolic link (force: true replaces it)"

    link = link_resource({ to: TARGET, force: true }, shell)
    changes = link.diff
    assert_equal ["regular file", "present"], [changes.first.from, changes.first.to]
    link.apply(changes)
    assert_equal "ln -sfn #{TARGET} #{PATH}", shell.commands.last

    error = assert_raises(Sadame::ResourceError) { link_resource({ state: :absent }, shell).diff }
    assert_includes error.message, "is a regular file, not a symbolic link"
  end

  def test_a_directory_in_the_way_is_always_an_error
    shell = stub_stat(linux_shell, PATH, type: "directory")
    error = assert_raises(Sadame::ResourceError) { link_resource({ to: TARGET, force: true }, shell).diff }
    assert_includes error.message, "is a directory, not a symbolic link"
  end

  def test_validation
    error = assert_raises(Sadame::ResourceError) { link_resource({}, linux_shell) }
    assert_includes error.message, "to: must name the target of the link"
    error = assert_raises(Sadame::ResourceError) { link_resource({ to: TARGET, state: :absent }, linux_shell) }
    assert_includes error.message, "to: makes no sense with state: :absent"
  end
end
