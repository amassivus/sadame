# frozen_string_literal: true

# A shell that records commands instead of running them, with an in-memory
# file system. Responses are set per command with #on; any other command
# exits with default_exit_status and prints nothing.
class FakeShell < Sadame::Shell
  attr_reader :commands, :files

  def initialize(files: {}, default_exit_status: 0)
    super()
    @files = files.dup
    @responses = {}
    @commands = []
    @default_exit_status = default_exit_status
  end

  def on(command, stdout: "", stderr: "", exit_status: 0)
    @responses[command] = { stdout: stdout, stderr: stderr, exit_status: exit_status }
    self
  end

  def run(command)
    @commands << command
    response = @responses[command] || { stdout: "", stderr: "", exit_status: @default_exit_status }
    Sadame::CommandResult.new(command, stdout: response[:stdout], stderr: response[:stderr],
                                       exit_status: response[:exit_status])
  end

  def stream(command)
    result = run(command)
    Sadame::Diff.split_lines(result.stdout + result.stderr).each { |line| yield line }
    result.exit_status
  end

  def read_file(path)
    @files[path]
  end

  def write_file(path, content)
    @commands << "write #{path}"
    @files[path] = content
  end
end

# A fake shell for a machine where nothing has been configured yet: state
# queries report "missing" and every other command succeeds. Files given
# to it (such as /etc/os-release, or a configuration file a package would
# ship) exist as regular files.
class FreshHostShell < FakeShell
  QUERY_PREFIXES = [
    "stat ", "dpkg-query ", "rpm -q ", "apk info ", "pacman -Q ", "getent ", "id -nG ",
    "systemctl is-", "test "
  ].freeze

  def initialize(files: {})
    super(files: files)
    on("test -d /run/systemd/system")
  end

  # A remote a git resource asks about has every branch and tag asked for.
  FAKE_COMMIT = "0123456789abcdef0123456789abcdef01234567"

  STAT = "stat -c '%a %U %G %F' "

  def run(command)
    return super if @responses.key?(command)
    return remote_refs(command) if command.include?("git ls-remote ") || command.include?(" ls-remote ")
    return existing_file(command) if command.start_with?(STAT) && @files.key?(command[STAT.size..])
    return super unless query?(command)

    @commands << command
    Sadame::CommandResult.new(command, stdout: "", stderr: "No such file or directory\n", exit_status: 1)
  end

  private

  def existing_file(command)
    @commands << command
    Sadame::CommandResult.new(command, stdout: "644 root root regular file\n", stderr: "", exit_status: 0)
  end

  def remote_refs(command)
    @commands << command
    refs = command.tr("'", " ").split(" ").select { |word| word == "HEAD" || word.start_with?("refs/") }
    Sadame::CommandResult.new(command, stdout: refs.map { |ref| "#{FAKE_COMMIT}\t#{ref}\n" }.join, stderr: "",
                                       exit_status: 0)
  end

  def query?(command)
    QUERY_PREFIXES.any? { |prefix| command.start_with?(prefix) }
  end
end
