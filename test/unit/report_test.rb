# frozen_string_literal: true

class ReportTest < SadameTest
  def report(command, statuses, failed_notification: false)
    host = host_for(linux_shell)
    report = Sadame::Report.new(command, host)
    statuses.each_with_index do |status, index|
      resource = Sadame::ExecResource.new("step #{index}", {}, host: host, source_dir: ".", vars: {})
      report.add(Sadame::Report::Entry.new(resource, status: status))
    end
    if failed_notification
      notification = Sadame::Notification.new(:reload, source_id: "exec[step 0]", target_id: "service[x]",
                                                       timing: :delayed, declared_by: "exec[step 0]", option: :notifies)
      report.add_notification_run(Sadame::Report::NotificationRun.new(notification, error: "boom"))
    end
    report
  end

  def test_plan_exit_status
    assert_equal 0, report(:plan, [:unchanged]).exit_status
    assert_equal 0, report(:plan, [:create, :update, :remove, :run]).exit_status
    assert_equal 2, report(:plan, [:create, :failed]).exit_status
  end

  def test_drift_exit_status
    assert_equal 0, report(:drift, [:unchanged, :unchanged]).exit_status
    assert_equal 1, report(:drift, [:unchanged, :update]).exit_status
    assert_equal 1, report(:drift, [:run]).exit_status
    assert_equal 2, report(:drift, [:update, :failed]).exit_status
  end

  def test_apply_exit_status
    assert_equal 0, report(:apply, [:changed, :unchanged]).exit_status
    assert_equal 1, report(:apply, [:changed, :failed, :skipped]).exit_status
    assert_equal 1, report(:apply, [:changed], failed_notification: true).exit_status
  end

  def test_counts_keep_a_fixed_order
    assert_equal({ create: 1, update: 0, remove: 0, run: 0, unchanged: 1, failed: 0 },
                 report(:drift, [:unchanged, :create]).counts)
    assert_equal({ changed: 0, unchanged: 0, failed: 1, skipped: 2 }, report(:apply, [:failed, :skipped, :skipped]).counts)
  end

  def test_json_fields
    hash = report(:drift, [:update]).to_h
    assert_equal "drift", hash[:command]
    assert_equal true, hash[:drift]
    assert_equal false, hash[:failed]
    assert_equal 1, hash[:exit_status]
    assert_nil report(:apply, [:changed]).to_h[:drift]
  end
end
