# frozen_string_literal: true

class ServiceResourceTest < SadameTest
  def systemd_shell(enabled: "disabled", active: "inactive")
    shell = linux_shell
    shell.on("test -d /run/systemd/system")
    shell.on("systemctl is-enabled nginx", stdout: "#{enabled}\n", exit_status: enabled == "enabled" ? 0 : 1)
    shell.on("systemctl is-active nginx", stdout: "#{active}\n", exit_status: active == "active" ? 0 : 3)
  end

  def service_resource(options, shell)
    build_resource(Sadame::ServiceResource, "nginx", options, shell: shell)
  end

  def test_enables_and_starts_a_stopped_service
    shell = systemd_shell
    service = service_resource({ enable: true, state: :running }, shell)
    changes = service.diff
    assert_equal :update, service.plan_action(changes)
    assert_equal [:enabled, :state], change_attributes(changes)

    service.apply(changes)
    assert_equal ["systemctl enable nginx", "systemctl start nginx"], shell.commands.last(2)
  end

  def test_running_and_enabled_service_has_no_changes
    shell = systemd_shell(enabled: "enabled", active: "active")
    assert_empty service_resource({ enable: true, state: :running }, shell).diff
  end

  def test_disables_and_stops
    shell = systemd_shell(enabled: "enabled", active: "active")
    service = service_resource({ enable: false, state: :stopped }, shell)
    service.apply(service.diff)
    assert_equal ["systemctl disable nginx", "systemctl stop nginx"], shell.commands.last(2)
  end

  def test_only_manages_the_attributes_given
    shell = systemd_shell(enabled: "disabled", active: "active")
    assert_empty service_resource({ state: :running }, shell).diff
    refute_includes shell.commands, "systemctl is-enabled nginx"
  end

  def test_notification_actions
    shell = systemd_shell
    service_resource({}, shell).run_action(:reload)
    assert_equal "systemctl reload nginx", shell.commands.last
    assert_equal [:start, :stop, :restart, :reload, :enable, :disable], Sadame::ServiceResource.actions
  end

  def test_user_units_use_the_users_systemd_instance
    shell = linux_shell.on("test -d /run/systemd/system")
    shell.on("systemctl --user -M alice@ is-enabled backup.timer", stdout: "disabled\n", exit_status: 1)
    service = build_resource(Sadame::ServiceResource, "backup.timer", { user: "alice", enable: true }, shell: shell)
    service.apply(service.diff)
    assert_equal "systemctl --user -M alice@ enable backup.timer", shell.commands.last
  end

  def test_requires_systemd
    shell = linux_shell.on("test -d /run/systemd/system", exit_status: 1)
    error = assert_raises(Sadame::ResourceError) { service_resource({ state: :running }, shell).diff }
    assert_includes error.message, "systemd is not running on this host"
  end

  def test_validation
    error = assert_raises(Sadame::ResourceError) { service_resource({ state: :started }, linux_shell) }
    assert_includes error.message, "state must be one of running, stopped"
    error = assert_raises(Sadame::ResourceError) { service_resource({ enable: "yes" }, linux_shell) }
    assert_includes error.message, "enable must be true or false"
  end
end
