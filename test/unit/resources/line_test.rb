# frozen_string_literal: true

class LineResourceTest < SadameTest
  PATH = "/etc/ssh/sshd_config"
  SSHD = "Include /etc/ssh/sshd_config.d/*.conf\n#PermitRootLogin prohibit-password\nPasswordAuthentication yes\n"

  def line_resource(name, options, shell)
    build_resource(Sadame::LineResource, name, { path: PATH }.merge(options), shell: shell)
  end

  def shell_with(content, mode: "644", owner: "root", group: "root")
    shell = linux_shell
    shell.files[PATH] = content
    stub_stat(shell, PATH, mode: mode, owner: owner, group: group)
  end

  def edited(name, options, content)
    resource = line_resource(name, options, shell_with(content))
    changes = resource.diff
    changes.empty? ? content : changes.first.to
  end

  def test_replaces_every_matching_line
    result = edited("PermitRootLogin no", { match: /^#?\s*PermitRootLogin\s/ }, SSHD)
    assert_equal SSHD.sub("#PermitRootLogin prohibit-password", "PermitRootLogin no"), result

    twice = "PermitRootLogin yes\nPort 22\n#PermitRootLogin no\n"
    assert_equal "PermitRootLogin no\nPort 22\nPermitRootLogin no\n",
                 edited("PermitRootLogin no", { match: "^#?PermitRootLogin " }, twice)
  end

  def test_appends_when_nothing_matches
    assert_equal "#{SSHD}MaxAuthTries 3\n", edited("MaxAuthTries 3", { match: /^#?MaxAuthTries\s/ }, SSHD)
    assert_equal "a\nb\nc\n", edited("c", {}, "a\nb")
    assert_equal "c\n", edited("c", {}, "")
  end

  def test_an_existing_line_is_left_alone
    shell = shell_with(SSHD)
    assert_empty line_resource("PasswordAuthentication yes", {}, shell).diff
    assert_empty line_resource("PermitRootLogin no", { match: /^PermitRootLogin\s/ }, shell_with("PermitRootLogin no\n")).diff
  end

  def test_removes_the_line_and_matching_lines
    assert_equal "Include /etc/ssh/sshd_config.d/*.conf\n",
                 edited("PasswordAuthentication yes", { state: :absent, match: /PermitRootLogin/ }, SSHD)
    assert_empty line_resource("Port 2222", { state: :absent }, shell_with(SSHD)).diff
  end

  def test_line_option_sets_the_text
    assert_equal "#{SSHD}10.0.0.5 mirror.internal\n", edited("mirror", { line: "10.0.0.5 mirror.internal" }, SSHD)
  end

  def test_apply_keeps_mode_and_owner_and_verifies
    shell = shell_with(SSHD, mode: "600", owner: "root", group: "ssh")
    resource = line_resource("PermitRootLogin no", { match: /^#?PermitRootLogin\s/, verify: "sshd -t -f %{path}" }, shell)
    changes = resource.diff
    assert_equal :update, resource.plan_action(changes)
    resource.apply(changes)
    assert_equal [
      "write #{PATH}.sadame-new",
      "chmod 0600 #{PATH}.sadame-new",
      "chown root:ssh #{PATH}.sadame-new",
      "sshd -t -f #{PATH}.sadame-new",
      "mv -f #{PATH}.sadame-new #{PATH}"
    ], shell.commands.last(5)
    assert_includes shell.files["#{PATH}.sadame-new"], "\nPermitRootLogin no\n"
  end

  def test_a_missing_file_plans_the_line_and_fails_on_apply
    shell = stub_missing(linux_shell, PATH)
    resource = line_resource("PermitRootLogin no", {}, shell)
    changes = resource.diff
    assert_equal [nil, "PermitRootLogin no\n", "#{PATH} does not exist yet"],
                 [changes.first.from, changes.first.to, changes.first.reason]
    error = assert_raises(Sadame::ResourceError) { resource.apply(changes) }
    assert_includes error.message, "does not exist; line only edits existing files"

    assert_empty line_resource("PermitRootLogin no", { state: :absent }, shell).diff
  end

  def test_refuses_a_symbolic_link
    shell = stub_stat(linux_shell, PATH, type: "symbolic link")
    error = assert_raises(Sadame::ResourceError) { line_resource("Port 22", {}, shell).diff }
    assert_includes error.message, "is a symbolic link, not a regular file"
  end

  def test_validation
    shell = linux_shell
    {
      {} => "path must be the absolute path",
      { path: "sshd_config" } => "path must be the absolute path",
      { path: PATH, line: "a\nb" } => "line must be a single line",
      { path: PATH, line: "" } => "line must be a non-empty String",
      { path: PATH, match: 42 } => "match must be a regular expression",
      { path: PATH, match: "(" } => "match is not a valid regular expression",
      { path: PATH, verify: "sshd -t" } => "verify must be a command containing %{path}"
    }.each do |options, message|
      error = assert_raises(Sadame::ResourceError) { build_resource(Sadame::LineResource, "Port 22", options, shell: shell) }
      assert_includes error.message, message, options.inspect
    end
  end
end
