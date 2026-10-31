# frozen_string_literal: true

class ExecResourceTest < SadameTest
  COMMAND = "certbot --nginx -d example.com"
  CERTIFICATE = "test -f /etc/letsencrypt/live/example.com/fullchain.pem"

  def exec_resource(options, shell, command = COMMAND)
    build_resource(Sadame::ExecResource, command, options, shell: shell)
  end

  def test_not_if_success_skips_the_command
    shell = linux_shell.on(CERTIFICATE)
    command = exec_resource({ not_if: CERTIFICATE }, shell)
    assert_empty command.diff
    refute_includes shell.commands, COMMAND
  end

  def test_not_if_failure_runs_the_command
    shell = linux_shell.on(CERTIFICATE, exit_status: 1)
    command = exec_resource({ not_if: CERTIFICATE }, shell)
    changes = command.diff
    assert_equal :run, command.plan_action(changes)
    assert_equal COMMAND, changes.first.to
    assert_equal "not_if exited non-zero", changes.first.reason

    command.apply(changes)
    assert_equal COMMAND, shell.commands.last
  end

  def test_only_if
    shell = linux_shell.on("test -x /usr/bin/yay", exit_status: 1)
    assert_empty exec_resource({ only_if: "test -x /usr/bin/yay" }, shell).diff

    shell = linux_shell.on("test -x /usr/bin/yay")
    assert_equal "only_if exited zero", exec_resource({ only_if: "test -x /usr/bin/yay" }, shell).diff.first.reason
  end

  def test_creates
    shell = linux_shell.on("test -e /usr/local/bin/app")
    assert_empty exec_resource({ creates: "/usr/local/bin/app" }, shell, "make install").diff

    shell = linux_shell.on("test -e /usr/local/bin/app", exit_status: 1)
    changes = exec_resource({ creates: "/usr/local/bin/app" }, shell, "make install").diff
    assert_equal "/usr/local/bin/app does not exist", changes.first.reason
  end

  def test_without_guards_it_always_runs
    changes = exec_resource({}, linux_shell, "date").diff
    assert_equal "no guard, runs on every apply", changes.first.reason
  end

  def test_cwd_and_env_wrap_the_command_and_guards
    guard = "export RAILS_ENV=production\ncd /opt/app && {\ntest -f done\n}"
    script = "export RAILS_ENV=production\ncd /opt/app && {\nbin/setup\n}"
    shell = linux_shell.on(guard, exit_status: 1)
    command = exec_resource({ cwd: "/opt/app", env: { "RAILS_ENV" => "production" }, not_if: "test -f done" },
                            shell, "bin/setup")
    command.apply(command.diff)
    assert_equal [guard, script], shell.commands.last(2)
  end

  def test_command_option_overrides_the_name
    shell = linux_shell
    command = exec_resource({ command: "systemctl daemon-reload" }, shell, "reload units")
    assert_equal "exec[reload units]", command.id
    command.run_action(:run)
    assert_equal "systemctl daemon-reload", shell.commands.last
  end

  def test_failure_raises_with_output
    shell = linux_shell.on("false-command", stderr: "boom\n", exit_status: 2)
    command = exec_resource({}, shell, "false-command")
    error = assert_raises(Sadame::CommandFailed) { command.apply(command.diff) }
    assert_includes error.message, "boom"
  end

  def test_validation
    error = assert_raises(Sadame::ResourceError) { exec_resource({ env: { "BAD-NAME" => "x" } }, linux_shell) }
    assert_includes error.message, "is not a valid variable name"
    error = assert_raises(Sadame::ResourceError) { exec_resource({ not_if: ["test", "-f"] }, linux_shell) }
    assert_includes error.message, "not_if must be a String"
  end
end
