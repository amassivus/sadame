# frozen_string_literal: true

module Sadame
  # Renders reports. Human writes progress as resources are processed; Json
  # writes one document when the run is finished. Both only call io.write.
  module Output
    # Terminal output with optional ANSI colors.
    class Human
      COLORS = { bold: 1, dim: 2, red: 31, green: 32, yellow: 33, cyan: 36 }.freeze

      PLAN_SYMBOLS = { create: "+", update: "~", remove: "-", run: "!", failed: "x" }.freeze
      PLAN_COLORS = { create: :green, update: :yellow, remove: :red, run: :cyan, failed: :red }.freeze
      APPLY_COLORS = { changed: :yellow, unchanged: :dim, failed: :red, skipped: :dim, notified: :cyan }.freeze

      PLAN_LABELS = { create: "to create", update: "to update", remove: "to remove", run: "to run",
                      unchanged: "unchanged", failed: "failed" }.freeze

      PLAN_INDENT = "    "
      APPLY_INDENT = "           "
      SUMMARY_LABEL_WIDTH = 11
      SUMMARY_COUNT_WIDTH = 3

      def initialize(io, color: false)
        @io = io
        @color = color
      end

      # note says which resources a --tags run covers.
      def start(command, host, note = nil)
        line(paint("sadame #{VERSION} #{command} on #{host.name} (#{host.platform.description})", :bold))
        line(paint(note, :cyan)) if note
        line
      end

      # Used by plan and drift.
      def planned(entry)
        return if entry.unchanged?

        symbol = PLAN_SYMBOLS[entry.status]
        line(paint("#{symbol} #{entry.resource.id}", PLAN_COLORS[entry.status]))
        details(entry, PLAN_INDENT)
        entry.notifications.each do |notification|
          text = "notifies: #{notification.action} #{notification.target_id} (#{notification.timing})"
          line("#{PLAN_INDENT}#{paint(text, :cyan)}")
        end
        line
      end

      def applied(entry)
        label = entry.status.to_s.ljust(APPLY_INDENT.size)
        line("#{paint(label, APPLY_COLORS[entry.status])}#{entry.resource.id}")
        details(entry, APPLY_INDENT) unless entry.unchanged?
      end

      def notified(run)
        notification = run.notification
        label = run.failed? ? "failed" : "notified"
        color = run.failed? ? :red : :cyan
        line("#{paint(label.ljust(APPLY_INDENT.size), color)}#{notification.target_id}: #{notification.action} " \
             "(#{notification.timing}, from #{notification.source_id})")
        indented("error: #{run.error}", APPLY_INDENT, :red) if run.failed?
      end

      def finish(report)
        case report.command
        when :plan then line(paint(plan_summary(report), :bold))
        when :drift then drift_summary(report)
        else apply_summary(report)
        end
      end

      private

      def details(entry, indent)
        entry.changes.each { |change| change_lines(entry.resource, change, indent) }
        indented("error: #{entry.error}", indent, :red) if entry.error
      end

      def change_lines(resource, change, indent)
        if change.content?
          content_lines(resource, change, indent)
        else
          line("#{indent}#{change.attribute}: #{transition(change)}")
        end
        line("#{indent}#{paint("(#{change.reason})", :dim)}") if change.reason
      end

      def transition(change)
        return format_value(change.to) if change.from.nil?

        "#{format_value(change.from)} -> #{format_value(change.to)}"
      end

      def content_lines(resource, change, indent)
        if resource.sensitive?
          line("#{indent}content: (sensitive, diff hidden)")
          return
        end

        old_label = change.from.nil? ? "/dev/null" : resource.content_path
        diff = Diff.unified(change.from, change.to, old_label: old_label, new_label: "#{resource.content_path} (desired)")
        diff.split("\n").each { |diff_line| line("#{indent}#{paint_diff_line(diff_line)}") }
      end

      def paint_diff_line(text)
        return paint(text, :bold) if text.start_with?("---") || text.start_with?("+++")
        return paint(text, :cyan) if text.start_with?("@@")
        return paint(text, :red) if text.start_with?("-")
        return paint(text, :green) if text.start_with?("+")

        text
      end

      def format_value(value)
        case value
        when nil then "(none)"
        when Array then value.empty? ? "(none)" : value.join(", ")
        else value.to_s
        end
      end

      def plan_summary(report)
        parts = report.counts.map do |status, count|
          "#{count} #{PLAN_LABELS[status]}" unless status == :failed && count == 0
        end
        "Plan: #{parts.compact.join(", ")}."
      end

      def drift_summary(report)
        total = report.entries.size
        drifted = report.entries.count { |entry| entry.pending? }
        if drifted > 0
          verb = drifted == 1 ? "differs" : "differ"
          line(paint("Drift: #{drifted} of #{plural(total, "resource")} #{verb} from the recipe.", :yellow))
        elsif !report.failed?
          verb = total == 1 ? "matches" : "match"
          line(paint("No drift: #{plural(total, "resource")} #{verb} the recipe.", :green))
        end
        failed = report.entries_with(:failed).size
        return if failed == 0

        line(paint("Could not check #{plural(failed, "resource")}; see the errors above.", :red))
      end

      # A table of results by status, then the run time:
      #
      #   Summary
      #     changed      2  package[nginx]
      #                     file[/etc/nginx/nginx.conf]
      #     unchanged    5
      #     failed       0
      #     skipped      0
      #     notified     1  service[nginx]: reload
      def apply_summary(report)
        line
        line(paint("Summary", :bold))
        report.counts.each do |status, count|
          ids = status == :unchanged ? [] : report.entries_with(status).map { |entry| entry.resource.id }
          summary_row(status, count, ids)
        end
        runs = report.notification_runs.map do |run|
          text = "#{run.notification.target_id}: #{run.notification.action}"
          run.failed? ? "#{text} (failed)" : text
        end
        summary_row(:notified, runs.size, runs)
        line
        line(paint(format("Finished in %.2fs.", report.duration.to_f), :bold))
      end

      def summary_row(status, count, items)
        label = status.to_s.ljust(SUMMARY_LABEL_WIDTH)
        label = paint(label, APPLY_COLORS[status]) if count > 0
        prefix = "  #{label}#{count.to_s.rjust(SUMMARY_COUNT_WIDTH)}"
        if items.empty?
          line(prefix)
          return
        end

        continuation = " " * (2 + SUMMARY_LABEL_WIDTH + SUMMARY_COUNT_WIDTH + 2)
        line("#{prefix}  #{items.first}")
        items[1..].each { |item| line("#{continuation}#{item}") }
      end

      def plural(count, noun)
        count == 1 ? "1 #{noun}" : "#{count} #{noun}s"
      end

      def indented(text, indent, color)
        text.to_s.split("\n").each { |text_line| line("#{indent}#{paint(text_line, color)}") }
      end

      def paint(text, color)
        return text unless @color && color

        "\e[#{COLORS[color]}m#{text}\e[0m"
      end

      def line(text = "")
        @io.write("#{text}\n")
      end
    end

    # Machine-readable output for --json.
    class Json
      def initialize(io)
        @io = io
      end

      def start(_command, _host, _note = nil); end

      def planned(_entry); end

      def applied(_entry); end

      def notified(_run); end

      def finish(report)
        @io.write(JsonWriter.generate(report.to_h))
      end
    end
  end
end
