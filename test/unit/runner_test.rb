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

  def runner(shell)
    Sadame::Runner.new(host: host_for(shell), output: Sadame::Output::Json.new(FakeIO.new))
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

  def test_unexpected_errors_keep_their_class_name
    shell = fresh_debian_shell
    resources = collection(shell, [Sadame::FileResource, "/etc/x", { content: "x" }])
    shell.on("stat -c '%a %U %G %F' /etc/x", stdout: "", exit_status: 0)
    report = runner(shell).plan(resources)
    assert report.entries.first.failed?
  end
end
