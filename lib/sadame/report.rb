# frozen_string_literal: true

module Sadame
  # The outcome of a plan, drift or apply run: one entry per resource, the
  # notifications that ran, and the exit status that follows from them.
  class Report
    # One resource's result.
    #
    # plan and drift statuses: :create, :update, :remove, :run, :unchanged,
    # :failed. apply statuses: :changed, :unchanged, :failed, :skipped.
    class Entry
      attr_reader :resource, :status, :changes, :notifications, :error

      def initialize(resource, status:, changes: [], notifications: [], error: nil)
        @resource = resource
        @status = status
        @changes = changes
        @notifications = notifications
        @error = error
      end

      def failed?
        status == :failed
      end

      def unchanged?
        status == :unchanged
      end

      # True when plan or drift found a difference for this resource.
      def pending?
        PENDING_STATUSES.include?(status)
      end

      def to_h
        {
          id: resource.id,
          type: resource.class.type_name,
          name: resource.name,
          status: status.to_s,
          changes: changes.map { |change| change_to_h(change) },
          notifications: notifications.map { |notification| notification.to_h },
          error: error
        }
      end

      private

      def change_to_h(change)
        hash = { attribute: change.attribute.to_s }
        if change.content?
          hash[:sensitive] = resource.sensitive?
          hash[:diff] = resource.sensitive? ? nil : Diff.unified(change.from, change.to, old_label: "current", new_label: "desired")
        else
          hash[:from] = change.from
          hash[:to] = change.to
        end
        hash[:reason] = change.reason if change.reason
        hash
      end
    end

    # A notification that ran during apply.
    class NotificationRun
      attr_reader :notification, :error

      def initialize(notification, error: nil)
        @notification = notification
        @error = error
      end

      def failed?
        !error.nil?
      end

      def to_h
        notification.to_h.merge(status: failed? ? "failed" : "ok", error: error)
      end
    end

    FORMAT_VERSION = 1
    PENDING_STATUSES = [:create, :update, :remove, :run].freeze
    PLAN_STATUSES = (PENDING_STATUSES + [:unchanged, :failed]).freeze
    APPLY_STATUSES = [:changed, :unchanged, :failed, :skipped].freeze

    attr_reader :command, :host, :entries, :notification_runs
    attr_accessor :duration

    def initialize(command, host)
      @command = command
      @host = host
      @entries = []
      @notification_runs = []
      @duration = nil
    end

    def add(entry)
      @entries << entry
    end

    def add_notification_run(run)
      @notification_runs << run
    end

    def failed?
      entries.any? { |entry| entry.failed? } || notification_runs.any? { |run| run.failed? }
    end

    # True when plan or drift found at least one resource that differs
    # from the recipe.
    def drift?
      entries.any? { |entry| entry.pending? }
    end

    # 0: success (plan computed, apply converged, drift found nothing).
    # 1: apply had a failure, or drift found differences.
    # 2: plan or drift could not read the state of every resource.
    def exit_status
      return failed? ? 1 : 0 if command == :apply
      return 2 if failed?
      return 1 if command == :drift && drift?

      0
    end

    # Number of entries per status, in a fixed order.
    def counts
      result = {}
      (command == :apply ? APPLY_STATUSES : PLAN_STATUSES).each { |status| result[status] = 0 }
      entries.each { |entry| result[entry.status] += 1 }
      result
    end

    def entries_with(status)
      entries.select { |entry| entry.status == status }
    end

    def to_h
      {
        format_version: FORMAT_VERSION,
        sadame_version: VERSION,
        command: command.to_s,
        host: host.name,
        platform: host.platform.to_h,
        resources: entries.map { |entry| entry.to_h },
        notifications: notification_runs.map { |run| run.to_h },
        summary: counts,
        drift: command == :apply ? nil : drift?,
        failed: failed?,
        exit_status: exit_status,
        duration_seconds: duration ? (duration * 100).round / 100.0 : nil
      }
    end
  end
end
