# frozen_string_literal: true

module Sadame
  # Runs plan or apply over a loaded recipe on one host.
  #
  # plan only reads state. apply walks the resources in order, reads each
  # resource's current state right before acting (earlier resources may
  # have changed it), applies only when there is a difference, stops at the
  # first failure, and runs queued notifications at the end.
  class Runner
    def initialize(host:, output:)
      @host = host
      @output = output
    end

    def plan(resources)
      report = Report.new(:plan, @host)
      @output.start(:plan, @host)
      resources.each do |resource|
        entry = plan_entry(resource)
        report.add(entry)
        @output.planned(entry)
      end
      @output.finish(report)
      report
    end

    def apply(resources)
      report = Report.new(:apply, @host)
      @output.start(:apply, @host)
      queue = []
      stopped = false

      resources.each do |resource|
        entry = stopped ? Report::Entry.new(resource, status: :skipped) : apply_entry(resource)
        stopped ||= entry.failed?
        queue_notifications(queue, resource) if entry.status == :changed
        report.add(entry)
        @output.applied(entry)
      end

      run_notifications(queue, resources, report) unless stopped
      @output.finish(report)
      report
    end

    private

    def plan_entry(resource)
      changes = resource.diff
      Report::Entry.new(resource, status: resource.plan_action(changes), changes: changes)
    rescue StandardError => e
      Report::Entry.new(resource, status: :failed, error: error_message(e))
    end

    def apply_entry(resource)
      changes = resource.diff
      return Report::Entry.new(resource, status: :unchanged) if changes.empty?

      resource.apply(changes)
      Report::Entry.new(resource, status: :changed, changes: changes)
    rescue StandardError => e
      Report::Entry.new(resource, status: :failed, changes: changes || [], error: error_message(e))
    end

    # Notifications run once each, in the order they were first queued.
    def queue_notifications(queue, resource)
      resource.notifications.each do |notification|
        queue << notification unless queue.any? { |queued| queued.key == notification.key }
      end
    end

    def run_notifications(queue, resources, report)
      queue.each do |notification|
        run = run_notification(notification, resources)
        report.add_notification_run(run)
        @output.notified(run)
      end
    end

    def run_notification(notification, resources)
      resources.find(notification.target_id).run_action(notification.action)
      Report::NotificationRun.new(notification)
    rescue StandardError => e
      Report::NotificationRun.new(notification, error: error_message(e))
    end

    # Our own errors carry a message meant for users; anything else is a
    # bug or an unexpected condition, so keep its class name visible.
    def error_message(error)
      return error.message if error.is_a?(Error)

      "#{error.class}: #{error.message}"
    end
  end
end
