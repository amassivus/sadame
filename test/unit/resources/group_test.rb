# frozen_string_literal: true

class GroupResourceTest < SadameTest
  def group_resource(options, shell, name = "app")
    build_resource(Sadame::GroupResource, name, options, shell: shell)
  end

  def shadow_shell(entry = nil)
    shell = linux_shell
    if entry
      shell.on("getent group app", stdout: "#{entry}\n")
    else
      shell.on("getent group app", exit_status: 2)
    end
  end

  def busybox_shell(entry = nil)
    shadow_shell(entry).on("command -v groupadd", exit_status: 1)
  end

  def test_creates_a_group
    shell = shadow_shell
    group = group_resource({ gid: 1500, system: true }, shell)
    changes = group.diff
    assert_equal :create, group.plan_action(changes)
    group.apply(changes)
    assert_equal "groupadd -r -g 1500 app", shell.commands.last
  end

  def test_an_existing_group_is_unchanged
    assert_empty group_resource({ gid: 1500 }, shadow_shell("app:x:1500:alice,bob")).diff
    assert_empty group_resource({}, shadow_shell("app:x:1001:")).diff
  end

  def test_changes_the_gid
    shell = shadow_shell("app:x:1001:")
    group = group_resource({ gid: 1500 }, shell)
    changes = group.diff
    assert_equal [1001, 1500], [changes.first.from, changes.first.to]
    group.apply(changes)
    assert_equal "groupmod -g 1500 app", shell.commands.last
  end

  def test_removes_a_group
    shell = shadow_shell("app:x:1001:")
    group = group_resource({ state: :absent }, shell)
    group.apply(group.diff)
    assert_equal "groupdel app", shell.commands.last
  end

  # musl's getent prints no trailing colon for a group without members.
  def test_busybox_tools_on_a_fresh_alpine
    shell = busybox_shell
    group = group_resource({ gid: 1500, system: true }, shell)
    group.apply(group.diff)
    assert_equal "addgroup -g 1500 -S app", shell.commands.last

    shell = busybox_shell("app:x:1500")
    assert_empty group_resource({ gid: 1500 }, shell).diff
    group = group_resource({ state: :absent }, shell)
    group.apply(group.diff)
    assert_equal "delgroup app", shell.commands.last

    group = group_resource({ gid: 1600 }, busybox_shell("app:x:1500"))
    error = assert_raises(Sadame::ResourceError) { group.apply(group.diff) }
    assert_includes error.message, "changing a gid needs groupmod"
  end

  def test_validation
    error = assert_raises(Sadame::ResourceError) { group_resource({ gid: "1500" }, linux_shell) }
    assert_includes error.message, "gid must be a non-negative Integer"
    error = assert_raises(Sadame::ResourceError) { group_resource({ system: "yes" }, linux_shell) }
    assert_includes error.message, "system must be true or false"
  end
end
