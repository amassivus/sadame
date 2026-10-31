# frozen_string_literal: true

class DirectoryResourceTest < SadameTest
  PATH = "/var/www/app"

  def directory_resource(options, shell)
    build_resource(Sadame::DirectoryResource, PATH, options, shell: shell)
  end

  def test_creates_a_missing_directory_with_mode_and_owner
    shell = stub_missing(linux_shell, PATH)
    directory = directory_resource({ mode: "0755", owner: "www-data", group: "www-data" }, shell)
    changes = directory.diff
    assert_equal :create, directory.plan_action(changes)

    directory.apply(changes)
    expected = ["mkdir -p /var/www/app", "chmod 0755 /var/www/app", "chown www-data:www-data /var/www/app"]
    assert_equal expected, shell.commands.last(3)
  end

  def test_existing_directory_without_differences
    shell = stub_stat(linux_shell, PATH, mode: "755", type: "directory")
    assert_empty directory_resource({ mode: "0755", owner: "root" }, shell).diff
  end

  def test_fixes_mode_only
    shell = stub_stat(linux_shell, PATH, mode: "700", type: "directory")
    directory = directory_resource({ mode: "0755" }, shell)
    directory.apply(directory.diff)
    assert_equal "chmod 0755 /var/www/app", shell.commands.last
  end

  def test_removal
    shell = stub_stat(linux_shell, PATH, type: "directory")
    directory = directory_resource({ state: :absent }, shell)
    directory.apply(directory.diff)
    assert_equal "rmdir /var/www/app", shell.commands.last

    shell = stub_stat(linux_shell, PATH, type: "directory")
    directory = directory_resource({ state: :absent, recursive: true }, shell)
    directory.apply(directory.diff)
    assert_equal "rm -rf /var/www/app", shell.commands.last
  end

  def test_refuses_a_regular_file
    shell = stub_stat(linux_shell, PATH, type: "regular empty file")
    error = assert_raises(Sadame::ResourceError) { directory_resource({}, shell).diff }
    assert_includes error.message, "is a regular file, not a directory"
  end
end
