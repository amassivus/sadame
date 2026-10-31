# frozen_string_literal: true

class PushSessionTest < SadameTest
  SUM = "f" * 64

  def setup
    @target = Sadame::Target.new("db1", user: "admin", port: 2222)
    @ssh = Sadame::Push::SSH.new(@target)
    @shell = linux_shell
    @binary = Sadame::Push::BinaryStore::LocalBinary.new("sadame-linux-amd64", "/dist/sadame-linux-amd64", SUM)
  end

  def session(target = @target)
    Sadame::Push::Session.new(target, shell: @shell, ssh: Sadame::Push::SSH.new(target))
  end

  def run_session(target = @target, capture: false, &block)
    session(target).run(command: "apply", binary: @binary, bundle: "/w/bundle.tgz", vars_file: "/w/vars-0.rb",
                        recipe: "site.rb", run_id: "r1", arguments: ["--color"], capture: capture, &block)
  end

  def test_detect_platform
    @shell.on(@ssh.ssh("uname -sm"), stdout: "Linux aarch64\n")
    assert_equal ["linux", "arm64"], session.detect_platform
  end

  def test_unreachable_hosts
    @shell.on(@ssh.ssh("uname -sm"), stderr: "ssh: connect to host db1 port 2222: Connection refused\n", exit_status: 255)
    failure = assert_raises(Sadame::Push::Failure) { session.detect_platform }
    assert_equal :unreachable, failure.kind
    assert_equal "connect failed: ssh: connect to host db1 port 2222: Connection refused", failure.message
  end

  def test_copies_the_binary_only_when_missing
    @shell.on(@ssh.ssh("test -x .sadame/bin/#{SUM}/sadame"), exit_status: 1)
    lines = []
    run_session { |line| lines << line }
    assert_equal "copying sadame-linux-amd64 to ~/.sadame/bin/#{SUM}/\n", lines.first
    assert_includes @shell.commands, @ssh.scp("/dist/sadame-linux-amd64", ".sadame/bin/#{SUM}/sadame.part")

    @shell = linux_shell
    run_session { |line| lines << line }
    refute(@shell.commands.any? { |command| command.include?("sadame.part") })
  end

  def test_runs_sadame_from_a_temporary_directory
    run_session
    expected = [
      @ssh.ssh("test -x .sadame/bin/#{SUM}/sadame"),
      @ssh.ssh("mkdir -p .sadame/run/r1"),
      @ssh.scp("/w/bundle.tgz", ".sadame/run/r1/bundle.tgz"),
      @ssh.scp("/w/vars-0.rb", ".sadame/run/r1/.sadame-vars.rb"),
      @ssh.ssh("cd .sadame/run/r1 && tar -xzf bundle.tgz && rm -f bundle.tgz && " \
               "\"$HOME/.sadame/bin/#{SUM}/sadame\" apply site.rb --vars-file .sadame-vars.rb --name db1 --color; " \
               "status=$?; cd && rm -rf .sadame/run/r1; exit $status")
    ]
    assert_equal expected, @shell.commands.last(5)
  end

  def test_sudo_is_checked_first_and_used_for_sadame
    target = @target.with(sudo: true)
    ssh = Sadame::Push::SSH.new(target)
    @shell.on(ssh.ssh("sudo -n true"), stderr: "sudo: a password is required\n", exit_status: 1)
    failure = assert_raises(Sadame::Push::Failure) { run_session(target) }
    assert_equal :error, failure.kind
    assert_equal "sudo failed: sudo: a password is required", failure.message

    @shell = linux_shell
    run_session(target)
    assert_includes @shell.commands.last, "sudo -n \"$HOME/.sadame/bin/#{SUM}/sadame\" apply"
  end

  def test_streams_or_captures_the_output
    script = "cd .sadame/run/r1 && tar -xzf bundle.tgz && rm -f bundle.tgz && " \
             "\"$HOME/.sadame/bin/#{SUM}/sadame\" apply site.rb --vars-file .sadame-vars.rb --name db1 --color; " \
             "status=$?; cd && rm -rf .sadame/run/r1; exit $status"
    @shell.on(@ssh.ssh(script), stdout: "line one\nline two\n", exit_status: 1)
    lines = []
    assert_equal [1, "", ""], run_session { |line| lines << line }
    assert_equal ["line one\n", "line two\n"], lines
    assert_equal [1, "line one\nline two\n", ""], run_session(capture: true)
  end
end
