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
      APPLY_COLORS = { changed: :yellow, unchanged: :dim, failed: :red, skipped: :dim }.freeze

      PLAN_LABELS = { create: "to create", update: "to update", remove: "to remove", run: "to run",
                      unchanged: "unchanged", failed: "failed" }.freeze

      PLAN_INDENT = "    "
      APPLY_INDENT = "           "

      def initialize(io, color: false)
        @io = io
        @color = color
      end

      def start(command, host)
        line(paint("sadame #{VERSION} #{command} on #{host.name} (#{host.platform.description})", :bold))
        line
      end

      def planned(entry)
        return if entry.unchanged?

        symbol = PLAN_SYMBOLS[entry.status]
        line(paint("#{symbol} #{entry.resource.id}", PLAN_COLORS[entry.status]))
        details(entry, PLAN_INDENT)
        notifications(entry, PLAN_INDENT)
        line
      end

      def applied(entry)
        label = entry.status.to_s.ljust(APPLY_INDENT.size)
        line("#{paint(label, APPLY_COLORS[entry.status])}#{entry.resource.id}")
        details(entry, APPLY_INDENT) unless entry.unchanged?
      end

      def notified(run)
        notification = run.notification
        label = run.failed? ? paint("failed".ljust(APPLY_INDENT.size), :red) : paint("notified".ljust(APPLY_INDENT.size), :cyan)
        line("#{label}#{notification.target_id}: #{notification.action} (from #{notification.source.id})")
        indented(run.error, APPLY_INDENT, :red) if run.failed?
      end

      def finish(report)
        line if report.command == :apply
        line(paint(summary(report), :bold))
      end

      private

      def details(entry, indent)
        entry.changes.each { |change| change_lines(entry.resource, change, indent) }
        indented("error: #{entry.error}", indent, :red) if entry.error
      end

      def notifications(entry, indent)
        entry.resource.notifications.each do |notification|
          line("#{indent}#{paint("notifies: #{notification.action} #{notification.target_id}", :cyan)}")
        end
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

        old_label = change.from.nil? ? "/dev/null" : resource.name
        diff = Diff.unified(change.from, change.to, old_label: old_label, new_label: "#{resource.name} (desired)")
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

      def summary(report)
        counts = report.counts
        if report.command == :plan
          parts = counts.map { |status, count| "#{count} #{PLAN_LABELS[status]}" unless status == :failed && count == 0 }
          "Plan: #{parts.compact.join(", ")}."
        else
          parts = counts.map { |status, count| "#{count} #{status}" unless status == :skipped && count == 0 }
          "Apply: #{parts.compact.join(", ")}."
        end
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

      def start(_command, _host); end

      def planned(_entry); end

      def applied(_entry); end

      def notified(_run); end

      def finish(report)
        @io.write(JsonWriter.generate(report.to_h))
      end
    end
  end
end
