# frozen_string_literal: true

class UserResourceTest < SadameTest
  def user_resource(options, shell)
    build_resource(Sadame::UserResource, "deploy", options, shell: shell)
  end

  def existing_user_shell(groups: "deploy", shell_path: "/bin/sh")
    shell = linux_shell
    shell.on("getent passwd deploy", stdout: "deploy:x:1001:1001::/home/deploy:#{shell_path}\n")
    shell.on("id -nG deploy", stdout: "#{groups}\n")
  end

  def test_creates_a_missing_user
    shell = linux_shell.on("getent passwd deploy", exit_status: 2)
    user = user_resource({ shell: "/bin/bash", groups: ["docker", "adm"], uid: 1500 }, shell)
    changes = user.diff
    assert_equal :create, user.plan_action(changes)

    user.apply(changes)
    assert_equal "useradd -m -u 1500 -s /bin/bash -G docker,adm deploy", shell.commands.last
  end

  def test_creates_a_system_user
    shell = linux_shell.on("getent passwd backup", exit_status: 2)
    user = build_resource(Sadame::UserResource, "backup", { system: true, home: "/var/lib/backup" }, shell: shell)
    user.apply(user.diff)
    assert_equal "useradd -r -d /var/lib/backup backup", shell.commands.last
  end

  def test_existing_user_without_differences
    shell = existing_user_shell(groups: "deploy docker wheel", shell_path: "/bin/bash")
    assert_empty user_resource({ shell: "/bin/bash", groups: ["docker"], uid: 1001, home: "/home/deploy" }, shell).diff
  end

  def test_adds_missing_groups_and_changes_the_shell
    shell = existing_user_shell(groups: "deploy wheel")
    user = user_resource({ shell: "/bin/bash", groups: ["wheel", "docker"] }, shell)
    changes = user.diff
    assert_equal [:shell, :groups], change_attributes(changes)
    assert_equal ["wheel"], changes.last.from
    assert_equal ["wheel", "docker"], changes.last.to

    user.apply(changes)
    assert_equal "usermod -s /bin/bash -a -G wheel,docker deploy", shell.commands.last
  end

  def test_removes_a_user
    shell = existing_user_shell
    user = user_resource({ state: :absent }, shell)
    user.apply(user.diff)
    assert_equal "userdel deploy", shell.commands.last
  end

  def test_explains_missing_useradd
    shell = linux_shell("alpine").on("getent passwd deploy", exit_status: 2).on("command -v useradd", exit_status: 1)
    user = user_resource({}, shell)
    error = assert_raises(Sadame::ResourceError) { user.apply(user.diff) }
    assert_includes error.message, "on Alpine, declare package \"shadow\""
  end

  def test_linux_only
    shell = FakeShell.new.on("uname -s", stdout: "Darwin\n")
    error = assert_raises(Sadame::ResourceError) { user_resource({}, shell).diff }
    assert_includes error.message, "only supports Linux"
  end

  def test_validation
    error = assert_raises(Sadame::ResourceError) { user_resource({ groups: "docker" }, linux_shell) }
    assert_includes error.message, "groups must be an Array"
    error = assert_raises(Sadame::ResourceError) { user_resource({ uid: "1000" }, linux_shell) }
    assert_includes error.message, "uid must be an Integer"
  end
end
