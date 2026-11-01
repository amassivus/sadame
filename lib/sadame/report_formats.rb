# frozen_string_literal: true

module Sadame
  # `sadame report`: turns the JSON of plan, apply or drift (one host, or a
  # push to several) into Markdown, for a CI job's summary page, or JUnit
  # XML, which GitLab, Jenkins and most CI systems show as test results.
  #
  #   sadame drift site.rb -g all --json > drift.json
  #   sadame report drift.json >> "$GITHUB_STEP_SUMMARY"
  #   sadame report drift.json --format junit > drift.xml
  module ReportFormats
    FORMATS = %w[markdown junit].freeze
    PENDING = %w[create update remove run].freeze
    SYMBOLS = { "create" => "+", "update" => "~", "remove" => "-", "run" => "!", "failed" => "x" }.freeze

    # One host's result: its name, push status (ok, drift, failed, error,
    # unreachable, skipped), error, and report (a Hash, or nil when sadame
    # did not run there).
    HostResult = Struct.new(:name, :status, :error, :report)

    # A parsed JSON document: the command and the hosts' results.
    class Document
      attr_reader :command, :hosts

      def self.parse(text)
        data = JSON.parse(text)
        raise Error, "not a JSON object" unless data.is_a?(Hash)

        command = data["command"].to_s
        unless %w[plan apply drift].include?(command)
          raise Error, "report reads the JSON of plan, apply and drift, not of #{command.empty? ? "this" : command}"
        end

        new(command, data["hosts"] ? push_hosts(data["hosts"]) : [single_host(command, data)])
      end

      def self.push_hosts(hosts)
        hosts.map { |host| HostResult.new(host["name"].to_s, host["status"].to_s, host["error"], host["report"]) }
      end

      def self.single_host(command, data)
        status = case data["exit_status"]
                 when 0 then "ok"
                 when 1 then command == "drift" ? "drift" : "failed"
                 else "error"
                 end
        HostResult.new(data["host"].to_s, status, nil, data)
      end

      def initialize(command, hosts)
        @command = command
        @hosts = hosts
      end

      # "drift on 3 hosts: 2 ok, 1 drift", as the command line prints it.
      def headline
        counts = {}
        hosts.each { |host| counts[host.status] = (counts[host.status] || 0) + 1 }
        noun = hosts.size == 1 ? "host" : "hosts"
        "#{command} on #{hosts.size} #{noun}: #{counts.map { |status, count| "#{count} #{status}" }.join(", ")}"
      end

      def resources(host)
        host.report ? (host.report["resources"] || []) : []
      end
    end

    # Text of one change: a diff for content, "attribute: from -> to"
    # otherwise.
    def self.change_text(change)
      if change.key?("diff")
        return "#{change["attribute"]}: (sensitive, diff hidden)" if change["sensitive"]

        return change["diff"].to_s
      end

      text = "#{change["attribute"]}: #{value_text(change["from"])} -> #{value_text(change["to"])}"
      text = "#{change["attribute"]}: #{value_text(change["to"])}" if change["from"].nil?
      change["reason"] ? "#{text} (#{change["reason"]})" : text
    end

    def self.value_text(value)
      case value
      when nil then "(none)"
      when Array then value.empty? ? "(none)" : value.join(", ")
      else value.to_s
      end
    end

    def self.render(format, document)
      format == "junit" ? Junit.new(document).render : Markdown.new(document).render
    end

    class Markdown
      def initialize(document)
        @document = document
      end

      def render
        out = String.new
        out << "### sadame #{@document.headline}\n\n"
        out << "| Host | Result | Resources |\n|---|---|---|\n"
        @document.hosts.each do |host|
          out << "| #{cell(host.name)} | #{cell(result(host))} | #{cell(summary(host))} |\n"
        end
        @document.hosts.each { |host| out << details(host) }
        out
      end

      private

      def result(host)
        host.status == "ok" ? "ok" : "**#{host.status}**"
      end

      def summary(host)
        return host.error.to_s if host.report.nil?

        entries = @document.resources(host)
        total = entries.size
        count = lambda { |statuses| entries.count { |entry| statuses.include?(entry["status"]) } }
        failed = count.call(["failed"])
        text = case @document.command
               when "apply"
                 parts = ["#{count.call(["changed"])} changed", "#{count.call(["unchanged"])} unchanged"]
                 parts << "#{failed} failed" if failed > 0
                 skipped = count.call(["skipped"])
                 parts << "#{skipped} skipped" if skipped > 0
                 parts.join(", ")
               else
                 pending = count.call(PENDING)
                 verb = @document.command == "drift" ? "differ" : "to change"
                 pending == 0 ? "#{total} unchanged" : "#{pending} of #{total} #{verb}"
               end
        failed > 0 && @document.command != "apply" ? "#{text}, #{failed} could not be read" : text
      end

      def details(host)
        entries = @document.resources(host).reject { |entry| entry["status"] == "unchanged" }
        return "" if entries.empty?

        out = String.new
        out << "\n<details>\n<summary>#{escape_html(host.name)}: #{escape_html(summary(host))}</summary>\n\n"
        entries.each { |entry| out << resource(entry) }
        out << "</details>\n"
        out
      end

      def resource(entry)
        status = entry["status"].to_s
        label = SYMBOLS[status] || status
        out = String.new("**#{label} #{entry["id"]}**\n\n")
        lines = []
        (entry["changes"] || []).each do |change|
          if change.key?("diff") && !change["sensitive"]
            out << fenced(ReportFormats.change_text(change), "diff")
          else
            lines << "- #{ReportFormats.change_text(change)}"
          end
        end
        lines << "- error: #{entry["error"]}" if entry["error"]
        out << "#{lines.join("\n")}\n\n" unless lines.empty?
        out
      end

      def fenced(text, language)
        fence = text.include?("```") ? "````" : "```"
        "#{fence}#{language}\n#{text.chomp}\n#{fence}\n\n"
      end

      def cell(text)
        text.to_s.gsub("|", "\\|").gsub("\n", " ")
      end

      def escape_html(text)
        text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end

    class Junit
      def initialize(document)
        @document = document
      end

      def render
        suites = @document.hosts.map { |host| suite(host) }
        tests = total(suites, :tests)
        failures = total(suites, :failures)
        errors = total(suites, :errors)
        out = String.new("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        out << "<testsuites name=\"#{xml("sadame #{@document.command}")}\" tests=\"#{tests}\" " \
               "failures=\"#{failures}\" errors=\"#{errors}\">\n"
        suites.each { |suite| out << suite[:xml] }
        out << "</testsuites>\n"
      end

      private

      def total(suites, key)
        suites.inject(0) { |sum, suite| sum + suite[key] }
      end

      # One testsuite per host, one testcase per resource. A host sadame
      # did not run on is one testcase named "sadame".
      def suite(host)
        cases = if host.report.nil?
                  [host_case(host)]
                else
                  @document.resources(host).map { |entry| resource_case(host, entry) }
                end
        failures = cases.count { |test| test[:kind] == :failure }
        errors = cases.count { |test| test[:kind] == :error }
        xml = String.new("  <testsuite name=\"#{xml(host.name)}\" tests=\"#{cases.size}\" " \
                         "failures=\"#{failures}\" errors=\"#{errors}\">\n")
        cases.each { |test| xml << test[:xml] }
        xml << "  </testsuite>\n"
        { tests: cases.size, failures: failures, errors: errors, xml: xml }
      end

      def host_case(host)
        if host.status == "skipped"
          return testcase(host.name, "sadame", :skipped, "<skipped message=\"#{xml(host.error.to_s)}\"/>")
        end

        testcase(host.name, "sadame", :error, "<error message=\"#{xml(host.error.to_s)}\" type=\"#{xml(host.status)}\"/>")
      end

      def resource_case(host, entry)
        status = entry["status"].to_s
        body = body_text(entry)
        case kind(status)
        when :failure
          message = entry["error"] || (@document.command == "drift" ? "differs from the recipe" : status)
          testcase(host.name, entry["id"], :failure,
                   "<failure message=\"#{xml(message)}\" type=\"#{xml(status)}\">#{xml(body)}</failure>")
        when :error
          testcase(host.name, entry["id"], :error,
                   "<error message=\"#{xml(entry["error"].to_s)}\" type=\"#{xml(status)}\">#{xml(body)}</error>")
        when :skipped
          testcase(host.name, entry["id"], :skipped, "<skipped/>")
        else
          testcase(host.name, entry["id"], :pass, body.empty? ? nil : "<system-out>#{xml(body)}</system-out>")
        end
      end

      # A resource fails when it makes the command fail: in drift when it
      # differs, in apply when it failed. A state that could not be read
      # is an error.
      def kind(status)
        return :skipped if status == "skipped"
        return (@document.command == "apply" ? :failure : :error) if status == "failed"
        return :failure if @document.command == "drift" && PENDING.include?(status)

        :pass
      end

      def body_text(entry)
        lines = (entry["changes"] || []).map { |change| ReportFormats.change_text(change).chomp }
        lines << "error: #{entry["error"]}" if entry["error"]
        lines.join("\n")
      end

      def testcase(classname, name, kind, inner)
        open = "    <testcase classname=\"#{xml(classname)}\" name=\"#{xml(name)}\""
        xml_text = inner ? "#{open}>\n      #{inner}\n    </testcase>\n" : "#{open}/>\n"
        { kind: kind, xml: xml_text }
      end

      def xml(text)
        text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;")
      end
    end
  end
end
