# frozen_string_literal: true

module Sadame
  # Runs plan, drift or apply over a loaded recipe on one host.
  #
  # plan and drift only read state; they differ in what the exit status
  # means (see Report#exit_status). apply walks the resources in order,
  # reads each resource's current state right before acting (earlier
  # resources may have changed it), applies only when there is a
  # difference, and stops at the first failure. Notifications marked
  # :immediately run right after the resource that triggered them; the
  # others run once each at the end.
  #
  # With a selection (--tags, --skip-tags), only the selected resources are
  # read, applied and reported; notifications still reach any resource.
  class Runner
    def initialize(host:, output:, clock: nil, selection: nil)
      @host = host
      @output = output
      @clock = clock || -> { Time.now }
      @selection = selection || Selection.new
    end

    def plan(resources)
      check(:plan, resources)
    end

    def drift(resources)
      check(:drift, resources)
    end

    def apply(resources)
      report = Report.new(:apply, @host, selection: @selection)
      started = @clock.call
      selected = start(:apply, resources)
      delayed = []
      stopped = false

      selected.each do |resource|
        entry = stopped ? Report::Entry.new(resource, status: :skipped) : apply_entry(resource, resources)
        report.add(entry)
        @output.applied(entry)
        stopped ||= entry.failed?
        next if stopped || entry.status != :changed

        stopped = !notify(entry.notifications, resources, report, delayed)
      end

      run_delayed(delayed, resources, report) unless stopped
      finish(report, started)
    end

    private

    def check(command, resources)
      report = Report.new(command, @host, selection: @selection)
      started = @clock.call
      selected = start(command, resources)
      selected.each do |resource|
        entry = check_entry(resource, resources)
        report.add(entry)
        @output.planned(entry)
      end
      finish(report, started)
    end

    # Prints the header and returns the resources to work on.
    def start(command, resources)
      all = resources.to_a
      selected = all.select { |resource| @selection.include?(resource) }
      note = @selection.all? ? nil : @selection.description(selected.size, all.size)
      @output.start(command, @host, note)
      selected
    end

    def finish(report, started)
      report.duration = @clock.call - started
      @output.finish(report)
      report
    end

    def check_entry(resource, resources)
      changes = resource.diff
      notifications = changes.empty? ? [] : resources.notifications_from(resource)
      Report::Entry.new(resource, status: resource.plan_action(changes), changes: changes,
                                  notifications: notifications)
    rescue StandardError => e
      Report::Entry.new(resource, status: :failed, error: error_message(e))
    end

    def apply_entry(resource, resources)
      changes = resource.diff
      return Report::Entry.new(resource, status: :unchanged) if changes.empty?

      resource.apply(changes)
      Report::Entry.new(resource, status: :changed, changes: changes,
                                  notifications: resources.notifications_from(resource))
    rescue StandardError => e
      Report::Entry.new(resource, status: :failed, changes: changes || [], error: error_message(e))
    end

    # Runs immediate notifications now and queues delayed ones. Returns
    # false when an immediate notification failed, which stops the run.
    def notify(notifications, resources, report, delayed)
      notifications.each do |notification|
        if notification.immediately?
          return false unless run_notification(notification, resources, report)
        elsif delayed.none? { |queued| queued.key == notification.key }
          delayed << notification
        end
      end
      true
    end

    def run_delayed(delayed, resources, report)
      delayed.each { |notification| run_notification(notification, resources, report) }
    end

    def run_notification(notification, resources, report)
      resources.find(notification.target_id).run_action(notification.action)
      record(report, Report::NotificationRun.new(notification))
    rescue StandardError => e
      record(report, Report::NotificationRun.new(notification, error: error_message(e)))
    end

    def record(report, run)
      report.add_notification_run(run)
      @output.notified(run)
      !run.failed?
    end

    # Our own errors carry a message meant for users; anything else is a
    # bug or an unexpected condition, so keep its class name visible.
    def error_message(error)
      return error.message if error.is_a?(Error)

      "#{error.class}: #{error.message}"
    end
  end
end
