# frozen_string_literal: true

class ReportFormatsTest < SadameTest
  DRIFT = "test/fixtures/reports/drift-push.json"

  # An apply on one host: a sensitive file changed, a package failed, a
  # service was skipped.
  APPLY = <<~JSON
    {
      "format_version": 1, "command": "apply", "host": "web1", "exit_status": 1,
      "resources": [
        { "id": "file[/etc/app/secret.env]", "status": "changed",
          "changes": [{ "attribute": "content", "sensitive": true, "diff": null }], "error": null },
        { "id": "package[nginx & co]", "status": "failed", "changes": [],
          "error": "command failed (exit 100): apt-get install <nginx>" },
        { "id": "service[nginx]", "status": "skipped", "changes": [], "error": null },
        { "id": "user[deploy]", "status": "unchanged", "changes": [], "error": null }
      ]
    }
  JSON

  def render(format, text)
    Sadame::ReportFormats.render(format, Sadame::ReportFormats::Document.parse(text))
  end

  def test_markdown_for_a_push
    status, stdout, = run_cli(["report", DRIFT])
    assert_equal 0, status
    assert stdout.start_with?("### sadame drift on 3 hosts: 1 ok, 1 drift, 1 unreachable\n\n| Host | Result | Resources |\n"), stdout
    assert_includes stdout, "| web1.example.com | ok | 6 unchanged |\n"
    assert_includes stdout, "| web2.example.com | **drift** | 1 of 6 differ |\n"
    assert_includes stdout, "| db1.example.com | **unreachable** | connect failed: ssh: connect to host"
    assert_includes stdout, "<summary>web2.example.com: 1 of 6 differ</summary>\n\n**~ file[/etc/demo-app/web.conf]**\n\n" \
                            "```diff\n--- current\n+++ desired\n"
    refute_includes stdout, "<summary>web1.example.com"
  end

  def test_junit_for_a_push
    status, stdout, = run_cli(["report", DRIFT, "--format", "junit"])
    assert_equal 0, status
    assert_includes stdout, "<testsuites name=\"sadame drift\" tests=\"13\" failures=\"1\" errors=\"1\">\n"
    assert_includes stdout, "<testcase classname=\"web2.example.com\" name=\"file[/etc/demo-app/web.conf]\">\n" \
                            "      <failure message=\"differs from the recipe\" type=\"update\">--- current\n"
    assert_includes stdout, "<error message=\"connect failed: ssh: connect to host db1.example.com port 2222: " \
                            "Connection refused\" type=\"unreachable\"/>"
  end

  def test_markdown_for_one_host_apply
    text = render("markdown", APPLY)
    assert_includes text, "### sadame apply on 1 host: 1 failed\n"
    assert_includes text, "| web1 | **failed** | 1 changed, 1 unchanged, 1 failed, 1 skipped |\n"
    assert_includes text, "**changed file[/etc/app/secret.env]**\n\n- content: (sensitive, diff hidden)\n\n"
    assert_includes text, "**x package[nginx & co]**\n\n- error: command failed (exit 100): apt-get install <nginx>\n"
  end

  def test_junit_for_one_host_apply_escapes_xml
    text = render("junit", APPLY)
    assert_includes text, "tests=\"4\" failures=\"1\" errors=\"0\""
    assert_includes text, "name=\"package[nginx &amp; co]\">\n      <failure message=\"command failed (exit 100): " \
                          "apt-get install &lt;nginx&gt;\" type=\"failed\">"
    assert_includes text, "<testcase classname=\"web1\" name=\"service[nginx]\">\n      <skipped/>"
    assert_includes text, "<system-out>content: (sensitive, diff hidden)</system-out>"
  end

  def test_a_skipped_host
    text = render("junit", '{"command": "apply", "hosts": [{"name": "db1", "status": "skipped", ' \
                           '"error": "not run: batch 1 failed", "report": null}]}')
    assert_includes text, "<testcase classname=\"db1\" name=\"sadame\">\n      <skipped message=\"not run: batch 1 failed\"/>"
  end

  def test_errors
    status, _stdout, stderr = run_cli(["report", "missing.json"])
    assert_equal [2, true], [status, stderr.include?("report file not found: missing.json")]

    status, _stdout, stderr = run_cli(["report", "examples/01-hello/recipe.rb"])
    assert_equal [2, true], [status, stderr.include?("examples/01-hello/recipe.rb is not a sadame JSON report")]

    status, _stdout, stderr = run_cli(["report", DRIFT, "--format", "html"])
    assert_equal [2, true], [status, stderr.include?("--format must be one of markdown, junit, got html")]

    status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "--format", "junit"])
    assert_equal [2, true], [status, stderr.include?("--format only applies to report")]

    error = assert_raises(Sadame::Error) { Sadame::ReportFormats::Document.parse('{"command": "facts"}') }
    assert_includes error.message, "report reads the JSON of plan, apply and drift, not of facts"
  end
end
