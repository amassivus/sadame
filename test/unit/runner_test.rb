# frozen_string_literal: true

class RunnerTest < SadameTest
  def fresh_debian_shell
    fresh_shell("debian")
  end

  def collection(shell, *declarations)
    host = host_for(shell)
    resources = Sadame::ResourceCollection.new
    declarations.each do |resource_class, name, options|
      resources.add(resource_class.new(name, options, host: host, source_dir: ".", vars: {}))
    end
    resources
  end

  def runner(shell, output: Sadame::Output::Json.new(FakeIO.new))
    Sadame::Runner.new(host: host_for(shell), output: output, clock: fixed_clock)
  end

  # A clock that advances 1.5 seconds per call.
  def fixed_clock
    ticks = [100.0]
    lambda do
      ticks << ticks.last + 1.5
      ticks[-2]
    end
  end

  def test_plan_reads_state_without_changing_anything
    shell = fresh_debian_shell
    resources = collection(shell, [Sadame::PackageResource, "nginx", {}], [Sadame::ExecResource, "date", {}])
    report = runner(shell).plan(resources)
    assert_equal [:create, :run], report.entries.map { |entry| entry.status }
    refute_includes shell.commands, "date"
    refute report.failed?
  end

  def test_plan_marks_failing_resources_and_continues
    shell = fresh_debian_shell.on("test -d /run/systemd/system", exit_status: 1)
    resources = collection(shell, [Sadame::ServiceResource, "nginx", { state: :running }], [Sadame::PackageResource, "git", {}])
    report = runner(shell).plan(resources)
    assert_equal [:failed, :create], report.entries.map { |entry| entry.status }
    assert_includes report.entries.first.error, "systemd is not running"
    assert report.failed?
  end

  def test_apply_runs_delayed_notifications_once_at_the_end
    shell = fresh_debian_shell
    resources = collection(
      shell,
      [Sadame::ServiceResource, "nginx", {}],
      [Sadame::ExecResource, "write a", { notifies: [:reload, "service[nginx]"] }],
      [Sadame::ExecResource, "write b", { notifies: [:reload, "service[nginx]"] }],
      [Sadame::ExecResource, "last", {}]
    )
    report = runner(shell).apply(resources)
    assert_equal [:unchanged, :changed, :changed, :changed], report.entries.map { |entry| entry.status }
    assert_equal ["write a", "write b", "last", "systemctl reload nginx"], (shell.commands - ["uname -s"]).last(4)
    assert_equal 1, report.notification_runs.size
  end

  def test_unchanged_resources_do_not_notify
    shell = fresh_debian_shell.on("test -e /done")
    resources = collection(
      shell,
      [Sadame::ServiceResource, "nginx", {}],
      [Sadame::ExecResource, "work", { creates: "/done", notifies: [:restart, "service[nginx]"] }]
    )
    report = runner(shell).apply(resources)
    assert_empty report.notification_runs
    refute_includes shell.commands, "systemctl restart nginx"
  end

  def test_apply_stops_at_the_first_failure
    shell = fresh_debian_shell
    shell.on("broken", stderr: "nope\n", exit_status: 1)
    resources = collection(
      shell,
      [Sadame::ServiceResource, "nginx", {}],
      [Sadame::ExecResource, "broken", { notifies: [:reload, "service[nginx]"] }],
      [Sadame::ExecResource, "after", { notifies: [:reload, "service[nginx]"] }]
    )
    report = runner(shell).apply(resources)
    assert_equal [:unchanged, :failed, :skipped], report.entries.map { |entry| entry.status }
    assert_includes report.entries[1].error, "nope"
    refute_includes shell.commands, "after"
    refute_includes shell.commands, "systemctl reload nginx"
    assert report.failed?
  end

  def test_failed_notification_fails_the_run
    shell = fresh_debian_shell
    shell.on("systemctl reload nginx", stderr: "Job failed\n", exit_status: 1)
    resources = collection(
      shell,
      [Sadame::ServiceResource, "nginx", {}],
      [Sadame::ExecResource, "work", { notifies: [:reload, "service[nginx]"] }]
    )
    report = runner(shell).apply(resources)
    assert report.notification_runs.first.failed?
    assert report.failed?
  end

  def test_immediate_notifications_run_right_after_the_resource
    shell = fresh_debian_shell
    resources = collection(
      shell,
      [Sadame::ExecResource, "systemctl daemon-reload", { action: :nothing }],
      [Sadame::ServiceResource, "app", {}],
      [Sadame::ExecResource, "write unit",
       { notifies: [[:run, "exec[systemctl daemon-reload]", :immediately], [:restart, "service[app]"]] }],
      [Sadame::ExecResource, "next step", {}]
    )
    report = runner(shell).apply(resources)
    expected = ["write unit", "systemctl daemon-reload", "next step", "systemctl restart app"]
    assert_equal expected, (shell.commands - ["uname -s"]).last(4)
    assert_equal [:immediately, :delayed], report.notification_runs.map { |run| run.notification.timing }
  end

  def test_failed_immediate_notification_stops_the_run
    shell = fresh_debian_shell
    shell.on("systemctl daemon-reload", stderr: "Access denied\n", exit_status: 1)
    resources = collection(
      shell,
      [Sadame::ExecResource, "systemctl daemon-reload", { action: :nothing }],
      [Sadame::ServiceResource, "app", {}],
      [Sadame::ExecResource, "write unit",
       { notifies: [[:run, "exec[systemctl daemon-reload]", :immediately], [:restart, "service[app]"]] }],
      [Sadame::ExecResource, "next step", {}]
    )
    report = runner(shell).apply(resources)
    assert_equal [:unchanged, :unchanged, :changed, :skipped], report.entries.map { |entry| entry.status }
    refute_includes shell.commands, "next step"
    refute_includes shell.commands, "systemctl restart app"
    assert report.failed?
    assert_equal 1, report.exit_status
  end

  def test_subscribers_are_notified
    shell = fresh_debian_shell
    resources = collection(
      shell,
      [Sadame::ExecResource, "write config", {}],
      [Sadame::ServiceResource, "app", { subscribes: [:reload, "exec[write config]"] }]
    )
    report = runner(shell).apply(resources)
    assert_equal "systemctl reload app", (shell.commands - ["uname -s"]).last
    assert_equal "exec[write config]", report.notification_runs.first.notification.source_id
  end

  def test_action_nothing_only_runs_when_notified
    shell = fresh_debian_shell
    resources = collection(shell, [Sadame::ExecResource, "systemctl daemon-reload", { action: :nothing }])
    report = runner(shell).apply(resources)
    assert_equal [:unchanged], report.entries.map { |entry| entry.status }
    refute_includes shell.commands, "systemctl daemon-reload"
  end

  def test_plan_lists_notifications_only_for_changed_resources
    shell = fresh_debian_shell.on("test -e /done")
    resources = collection(
      shell,
      [Sadame::ServiceResource, "app", {}],
      [Sadame::ExecResource, "skipped work", { creates: "/done", notifies: [:restart, "service[app]"] }],
      [Sadame::ExecResource, "pending work", { notifies: [:restart, "service[app]", :immediately] }]
    )
    report = runner(shell).plan(resources)
    assert_empty report.entries[1].notifications
    assert_equal ["restart service[app]"], report.entries[2].notifications.map { |notification| notification.key }
  end

  def test_drift_reports_differences_through_the_exit_status
    shell = fresh_debian_shell
    report = runner(shell).drift(collection(shell, [Sadame::PackageResource, "nginx", {}]))
    assert_equal :drift, report.command
    assert report.drift?
    assert_equal 1, report.exit_status

    shell = linux_shell("debian").on("dpkg-query -W -f='${Status}' nginx", stdout: "install ok installed")
    report = runner(shell).drift(collection(shell, [Sadame::PackageResource, "nginx", {}]))
    refute report.drift?
    assert_equal 0, report.exit_status
  end

  def test_apply_summary_table
    shell = fresh_debian_shell
    shell.on("broken", stderr: "nope\n", exit_status: 1)
    resources = collection(
      shell,
      [Sadame::ServiceResource, "nginx", {}],
      [Sadame::ExecResource, "first", { notifies: [:reload, "service[nginx]", :immediately] }],
      [Sadame::ExecResource, "second", {}],
      [Sadame::ExecResource, "broken", {}],
      [Sadame::ExecResource, "never", {}]
    )
    io = FakeIO.new
    runner(shell, output: Sadame::Output::Human.new(io)).apply(resources)
    expected = <<~TEXT

      Summary
        changed      2  exec[first]
                        exec[second]
        unchanged    1
        failed       1  exec[broken]
        skipped      1  exec[never]
        notified     1  service[nginx]: reload

      Finished in 1.50s.
    TEXT
    assert io.string.end_with?(expected), io.string
  end

  def test_duration_is_recorded
    shell = fresh_debian_shell
    report = runner(shell).plan(collection(shell, [Sadame::PackageResource, "nginx", {}]))
    assert_equal 1.5, report.duration
    assert_equal 1.5, report.to_h[:duration_seconds]
  end

  def test_unexpected_errors_keep_their_class_name
    shell = fresh_debian_shell
    resources = collection(shell, [Sadame::FileResource, "/etc/x", { content: "x" }])
    shell.on("stat -c '%a %U %G %F' /etc/x", stdout: "", exit_status: 0)
    report = runner(shell).plan(resources)
    assert report.entries.first.failed?
  end
end
