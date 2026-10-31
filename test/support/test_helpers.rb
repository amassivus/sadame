# frozen_string_literal: true

# Helpers shared by the CRuby (minitest) and mruby (mruby-mtest) runs.
# Only use assertions both frameworks know: see test/support/mruby_setup.rb.
module TestHelpers
  FIXTURES = "test/fixtures"

  def fixture(path)
    File.read(File.join(FIXTURES, path))
  end

  def os_release(name)
    fixture("os-release/#{name}")
  end

  # A fake Linux shell whose /etc/os-release is the named fixture.
  def linux_shell(distribution = "debian", default_exit_status: 0)
    shell = FakeShell.new(files: { "/etc/os-release" => os_release(distribution) },
                          default_exit_status: default_exit_status)
    shell.on("uname -s", stdout: "Linux\n")
  end

  # A fake Linux machine on which nothing from the recipe exists yet.
  def fresh_shell(distribution = "debian")
    FreshHostShell.new(files: { "/etc/os-release" => os_release(distribution) }).on("uname -s", stdout: "Linux\n")
  end

  def host_for(shell)
    Sadame::Host.new(shell)
  end

  def build_resource(resource_class, name, options = {}, shell: linux_shell, vars: {}, source_dir: ".")
    resource_class.new(name, options, host: host_for(shell), source_dir: source_dir, vars: vars)
  end

  # Makes `stat` report path as existing with the given attributes.
  def stub_stat(shell, path, mode: "644", owner: "root", group: "root", type: "regular file")
    shell.on("stat -c '%a %U %G %F' #{Sadame::Shell.escape(path)}", stdout: "#{mode} #{owner} #{group} #{type}\n")
  end

  # Makes `stat` report path as missing.
  def stub_missing(shell, path)
    shell.on("stat -c '%a %U %G %F' #{Sadame::Shell.escape(path)}",
             stderr: "stat: cannot statx '#{path}': No such file or directory\n", exit_status: 1)
  end

  def change_attributes(changes)
    changes.map { |change| change.attribute }
  end

  # Runs the CLI with a fake shell and returns [exit_status, stdout, stderr].
  def run_cli(arguments, shell: linux_shell, environment: {})
    stdout = FakeIO.new
    stderr = FakeIO.new
    status = Sadame::CLI.new(arguments, stdout: stdout, stderr: stderr, shell: shell,
                                        environment: environment).run
    [status, stdout.string, stderr.string]
  end
end
