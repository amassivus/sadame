# frozen_string_literal: true

class ShellTest < SadameTest
  def test_escape_leaves_plain_words_alone
    assert_equal "nginx", Sadame::Shell.escape("nginx")
    assert_equal "/etc/nginx/nginx.conf", Sadame::Shell.escape("/etc/nginx/nginx.conf")
    assert_equal "user@host:2222", Sadame::Shell.escape("user@host:2222")
  end

  def test_escape_quotes_everything_else
    assert_equal "''", Sadame::Shell.escape("")
    assert_equal "'two words'", Sadame::Shell.escape("two words")
    assert_equal "'$HOME'", Sadame::Shell.escape("$HOME")
    assert_equal "'it'\\''s'", Sadame::Shell.escape("it's")
    assert_equal "''\\'''", Sadame::Shell.escape("'")
  end

  def test_run_captures_stdout_stderr_and_exit_status
    result = Sadame::Shell.new.run("echo out; echo err >&2; exit 3")
    assert_equal "out\n", result.stdout
    assert_equal "err\n", result.stderr
    assert_equal 3, result.exit_status
    refute result.success?
  end

  def test_run_closes_stdin
    result = Sadame::Shell.new.run("cat")
    assert result.success?
    assert_equal "", result.stdout
  end

  def test_run_handles_multiline_scripts_and_comments
    result = Sadame::Shell.new.run("x=1\necho $x # trailing comment")
    assert_equal "1\n", result.stdout
  end

  # Output sadame parses must not depend on the user's language.
  def test_commands_run_in_the_c_utf8_locale
    saved = [ENV["LANG"], ENV["LC_ALL"], ENV["LANGUAGE"]]
    ENV["LANG"] = "tr_TR.UTF-8"
    ENV["LC_ALL"] = "tr_TR.UTF-8"
    ENV["LANGUAGE"] = "tr"
    shell = Sadame::Shell.new
    assert_equal "C.UTF-8 tr_TR.UTF-8 none\n", shell.run("echo $LC_ALL $LANG ${LANGUAGE:-none}").stdout
    lines = []
    shell.stream("echo $LC_ALL ${LANGUAGE:-none}") { |line| lines << line }
    assert_equal ["C.UTF-8 none\n"], lines
  ensure
    ENV["LANG"], ENV["LC_ALL"], ENV["LANGUAGE"] = saved
  end

  def test_run_bang_raises_with_the_error_output
    error = assert_raises(Sadame::CommandFailed) { Sadame::Shell.new.run!("echo broken >&2; exit 4") }
    assert_equal 4, error.result.exit_status
    assert_includes error.message, "exit 4"
    assert_includes error.message, "broken"
  end

  def test_read_and_write_files
    shell = Sadame::Shell.new
    path = "/tmp/sadame-shell-test-#{Process.pid}"
    assert_nil shell.read_file(path)
    shell.write_file(path, "content\n")
    assert_equal "content\n", shell.read_file(path)
  ensure
    File.delete(path) if File.exist?(path)
  end
end
