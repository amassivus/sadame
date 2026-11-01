# frozen_string_literal: true

class FileResourceTest < SadameTest
  PATH = "/etc/motd"
  STAT = "stat -c '%a %U %G %F' /etc/motd"

  def file_resource(options, shell: linux_shell, vars: {}, source_dir: "test/fixtures/recipes/templates_and_files")
    build_resource(Sadame::FileResource, PATH, options, shell: shell, vars: vars, source_dir: source_dir)
  end

  def test_creates_a_missing_file_with_mode
    shell = stub_missing(linux_shell, PATH)
    file = file_resource({ content: "hello\n", mode: "0640" }, shell: shell)
    changes = file.diff
    assert_equal :create, file.plan_action(changes)
    assert_equal [:state, :mode, :content], change_attributes(changes)

    file.apply(changes)
    assert_equal "hello\n", shell.files["/etc/motd.sadame-new"]
    expected = [
      "write /etc/motd.sadame-new",
      "chmod 0640 /etc/motd.sadame-new",
      "mv -f /etc/motd.sadame-new /etc/motd"
    ]
    assert_equal expected, shell.commands.last(3)
  end

  def test_matching_file_has_no_changes
    shell = stub_stat(linux_shell, PATH, mode: "644")
    shell.files[PATH] = "hello\n"
    assert_empty file_resource({ content: "hello\n", mode: "0644", owner: "root", group: "root" }, shell: shell).diff
  end

  def test_content_change_keeps_existing_mode_and_owner
    shell = stub_stat(linux_shell, PATH, mode: "600", owner: "app", group: "staff")
    shell.files[PATH] = "old\n"
    file = file_resource({ content: "new\n" }, shell: shell)
    changes = file.diff
    assert_equal [:content], change_attributes(changes)
    assert_equal "old\n", changes.first.from

    file.apply(changes)
    expected = [
      "write /etc/motd.sadame-new",
      "chmod 0600 /etc/motd.sadame-new",
      "chown app:staff /etc/motd.sadame-new",
      "mv -f /etc/motd.sadame-new /etc/motd"
    ]
    assert_equal expected, shell.commands.last(4)
  end

  def test_mode_and_owner_changes_do_not_rewrite_content
    shell = stub_stat(linux_shell, PATH, mode: "600", owner: "root", group: "root")
    shell.files[PATH] = "same\n"
    file = file_resource({ content: "same\n", mode: "0644", owner: "www-data" }, shell: shell)
    changes = file.diff
    assert_equal [:mode, :owner], change_attributes(changes)

    file.apply(changes)
    assert_equal ["chmod 0644 /etc/motd", "chown www-data /etc/motd"], shell.commands.last(2)
  end

  def test_group_only_change
    shell = stub_stat(linux_shell, PATH)
    file = file_resource({ group: "adm" }, shell: shell)
    file.apply(file.diff)
    assert_equal "chown :adm /etc/motd", shell.commands.last
  end

  def test_file_without_content_options_only_manages_metadata
    shell = stub_stat(linux_shell, PATH, mode: "644")
    shell.files[PATH] = "anything\n"
    file = file_resource({ mode: "0644" }, shell: shell)
    assert_empty file.diff
  end

  def test_missing_file_without_content_is_created_empty
    shell = stub_missing(linux_shell, PATH)
    file = file_resource({}, shell: shell)
    file.apply(file.diff)
    assert_equal "", shell.files["/etc/motd.sadame-new"]
  end

  def test_removes_a_file
    shell = stub_stat(linux_shell, PATH)
    file = file_resource({ state: :absent }, shell: shell)
    changes = file.diff
    assert_equal :remove, file.plan_action(changes)
    file.apply(changes)
    assert_equal "rm -f /etc/motd", shell.commands.last
  end

  def test_absent_file_that_is_already_gone
    shell = stub_missing(linux_shell, PATH)
    assert_empty file_resource({ state: :absent }, shell: shell).diff
  end

  def test_refuses_to_replace_a_directory_or_symlink
    shell = stub_stat(linux_shell, PATH, type: "directory")
    error = assert_raises(Sadame::ResourceError) { file_resource({ content: "x" }, shell: shell).diff }
    assert_includes error.message, "/etc/motd is a directory, not a regular file"

    shell = stub_stat(linux_shell, PATH, type: "symbolic link")
    error = assert_raises(Sadame::ResourceError) { file_resource({ content: "x" }, shell: shell).diff }
    assert_includes error.message, "is a symbolic link"
  end

  def test_renders_templates_with_vars_and_locals
    shell = stub_missing(linux_shell, PATH)
    file = file_resource({ template: "motd.erb", locals: { greeting: "Welcome" } }, shell: shell, vars: { host: "web1" })
    assert_equal "Welcome to web1\n", file.diff.last.to
    assert_equal "test/fixtures/recipes/templates_and_files/templates/motd.erb", file.local_file
  end

  def test_copies_source_files
    shell = stub_missing(linux_shell, PATH)
    file = file_resource({ source: "banner.txt" }, shell: shell)
    assert_equal "static banner\n", file.diff.last.to
    assert_equal "test/fixtures/recipes/templates_and_files/files/banner.txt", file.local_file
  end

  def test_missing_template_is_reported_when_declared
    error = assert_raises(Sadame::ResourceError) { file_resource({ template: "nope.erb" }) }
    assert_includes error.message, "cannot find nope.erb"
  end

  def test_validation_errors
    error = assert_raises(Sadame::ResourceError) { file_resource({ content: "a", source: "banner.txt" }) }
    assert_includes error.message, "use only one of content:, template: and source:"

    error = assert_raises(Sadame::ResourceError) { file_resource({ mode: 644 }) }
    assert_includes error.message, "mode must be a string of octal digits"

    error = assert_raises(Sadame::ResourceError) { file_resource({ mode: "0999" }) }
    assert_includes error.message, "mode must be a string"

    error = assert_raises(Sadame::ResourceError) { file_resource({ content: "a", locals: { a: 1 } }) }
    assert_includes error.message, "locals: only applies to template:"

    error = assert_raises(Sadame::ResourceError) { file_resource({ content: "a", state: :absent }) }
    assert_includes error.message, "makes no sense with state: :absent"
  end

  def test_sensitive_files
    assert file_resource({ content: "secret", sensitive: true }).sensitive?
    refute file_resource({ content: "public" }).sensitive?
  end

  def test_failed_write_removes_the_temporary_file
    shell = stub_missing(linux_shell, PATH)
    shell.on("mv -f /etc/motd.sadame-new /etc/motd", stderr: "mv: permission denied\n", exit_status: 1)
    file = file_resource({ content: "x" }, shell: shell)
    assert_raises(Sadame::CommandFailed) { file.apply(file.diff) }
    assert_equal "rm -f /etc/motd.sadame-new", shell.commands.last
  end

  def test_verify_checks_the_new_content_before_it_replaces_the_file
    shell = stub_missing(linux_shell, "/etc/sudoers.d/deploy")
    file = build_resource(Sadame::FileResource, "/etc/sudoers.d/deploy",
                          { content: "deploy ALL=(ALL) NOPASSWD: ALL\n", mode: "0440", verify: "visudo -cf %{path}" },
                          shell: shell)
    file.apply(file.diff)
    assert_equal ["visudo -cf /etc/sudoers.d/deploy.sadame-new",
                  "mv -f /etc/sudoers.d/deploy.sadame-new /etc/sudoers.d/deploy"], shell.commands.last(2)

    shell = stub_missing(linux_shell, "/etc/sudoers.d/deploy")
    shell.on("visudo -cf /etc/sudoers.d/deploy.sadame-new", stderr: "syntax error near line 1\n", exit_status: 1)
    file = build_resource(Sadame::FileResource, "/etc/sudoers.d/deploy", { content: "nonsense", verify: "visudo -cf %{path}" },
                          shell: shell)
    error = assert_raises(Sadame::ResourceError) { file.apply(file.diff) }
    assert_includes error.message, "verify failed, /etc/sudoers.d/deploy was not changed"
    assert_includes error.message, "syntax error near line 1"
    assert_equal "rm -f /etc/sudoers.d/deploy.sadame-new", shell.commands.last
  end

  def test_verify_needs_the_path_placeholder
    error = assert_raises(Sadame::ResourceError) { file_resource({ content: "x", verify: "visudo -c" }) }
    assert_includes error.message, "verify must be a command containing %{path}"
  end

  def test_uses_bsd_stat_on_macos
    shell = FakeShell.new.on("uname -s", stdout: "Darwin\n")
    shell.on("stat -f '%Lp %Su %Sg %HT' /etc/motd", stdout: "644 root wheel Regular File\n")
    shell.files[PATH] = "x"
    assert_empty file_resource({ content: "x", mode: "0644", group: "wheel" }, shell: shell).diff
  end
end
