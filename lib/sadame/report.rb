# frozen_string_literal: true

module Sadame
  # The outcome of a plan or apply run: one entry per resource, plus the
  # notifications that ran.
  class Report
    # Plan statuses: :create, :update, :remove, :run, :unchanged, :failed.
    # Apply statuses: :changed, :unchanged, :failed, :skipped.
    class Entry
      attr_reader :resource, :status, :changes, :error

      def initialize(resource, status:, changes: [], error: nil)
        @resource = resource
        @status = status
        @changes = changes
        @error = error
      end

      def failed?
        status == :failed
      end

      def unchanged?
        status == :unchanged
      end

      def to_h
        {
          id: resource.id,
          type: resource.class.type_name,
          name: resource.name,
          status: status.to_s,
          changes: changes.map { |change| change_to_h(change) },
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

    # A notification that ran at the end of apply.
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
    PLAN_STATUSES = [:create, :update, :remove, :run, :unchanged, :failed].freeze
    APPLY_STATUSES = [:changed, :unchanged, :failed, :skipped].freeze

    attr_reader :command, :host, :entries, :notification_runs

    def initialize(command, host)
      @command = command
      @host = host
      @entries = []
      @notification_runs = []
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

    def changed?
      entries.any? { |entry| !entry.unchanged? && !entry.failed? && entry.status != :skipped }
    end

    # Number of entries per status, in a fixed order.
    def counts
      result = {}
      (command == :plan ? PLAN_STATUSES : APPLY_STATUSES).each { |status| result[status] = 0 }
      entries.each { |entry| result[entry.status] += 1 }
      result
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
        failed: failed?
      }
    end
  end
end
