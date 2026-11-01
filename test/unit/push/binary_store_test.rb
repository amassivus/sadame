# frozen_string_literal: true

class PushBinaryStoreTest < SadameTest
  def setup
    @dir = "/tmp/sadame-binary-store-test-#{Process.pid}"
    @shell = linux_shell
    Sadame::Shell.new.run!("rm -rf #{@dir} && mkdir -p #{@dir}")
  end

  def teardown
    Sadame::Shell.new.run("rm -rf #{@dir}")
  end

  def checksum_command(path)
    "if command -v sha256sum >/dev/null 2>&1; then sha256sum #{path}; else shasum -a 256 #{path}; fi"
  end

  def create(path)
    Sadame::Shell.new.run!("mkdir -p #{File.dirname(path)} && echo binary > #{path}")
    @shell.on(checksum_command(path), stdout: "#{"a" * 64}  #{path}\n")
  end

  def store(environment)
    Sadame::Push::BinaryStore.new(@shell, environment: environment, engine: "ruby")
  end

  def test_platform_from_uname
    assert_equal ["linux", "amd64"], Sadame::Push::BinaryStore.platform_from_uname("Linux x86_64\n")
    assert_equal ["linux", "arm64"], Sadame::Push::BinaryStore.platform_from_uname("Linux aarch64")
    assert_equal ["darwin", "arm64"], Sadame::Push::BinaryStore.platform_from_uname("Darwin arm64")
    error = assert_raises(Sadame::Error) { Sadame::Push::BinaryStore.platform_from_uname("Linux riscv64") }
    assert_includes error.message, "sadame has no binary for Linux riscv64"
  end

  def test_binary_dir_comes_first
    path = "#{@dir}/dist/sadame-linux-arm64"
    create(path)
    binary = store("SADAME_BINARY_DIR" => "#{@dir}/dist").find("linux", "arm64")
    assert_equal ["sadame-linux-arm64", path, "a" * 64], [binary.name, binary.path, binary.sha256]

    error = assert_raises(Sadame::Error) { store("SADAME_BINARY_DIR" => "#{@dir}/dist").find("linux", "amd64") }
    assert_includes error.message, "sadame-linux-amd64 does not exist (SADAME_BINARY_DIR is set)"
  end

  def test_cached_downloads_are_reused
    path = "#{@dir}/.sadame/dist/#{Sadame::VERSION}/sadame-linux-amd64"
    create(path)
    assert_equal path, store("HOME" => @dir).find("linux", "amd64").path
  end

  def test_development_versions_are_not_downloaded
    development = Sadame::Push::BinaryStore.new(@shell, environment: { "HOME" => @dir }, engine: "ruby",
                                                        version: "0.2.0.dev")
    error = assert_raises(Sadame::Error) { development.find("linux", "amd64") }
    assert_includes error.message, "set SADAME_BINARY_DIR=dist"
  end

  def test_download_is_checked_against_sha256sums
    base = "https://mirror.example.com/sadame"
    partial = "#{@dir}/.sadame/dist/#{Sadame::VERSION}/sadame-linux-amd64.download"
    @shell.on("if command -v curl >/dev/null 2>&1; then curl -fsSL #{base}/SHA256SUMS; " \
              "else wget -q -O - #{base}/SHA256SUMS; fi", stdout: "#{"b" * 64}  sadame-linux-amd64\n")
    @shell.on(checksum_command(partial), stdout: "#{"c" * 64}  #{partial}\n")
    error = assert_raises(Sadame::Error) { store("HOME" => @dir, "SADAME_DOWNLOAD_URL" => base).find("linux", "amd64") }
    assert_includes error.message, "checksum mismatch for sadame-linux-amd64"
    assert_equal "rm -f #{partial}", @shell.commands.last
  end

  def test_each_binary_is_looked_up_once
    path = "#{@dir}/dist/sadame-linux-amd64"
    create(path)
    binaries = store("SADAME_BINARY_DIR" => "#{@dir}/dist")
    binaries.find("linux", "amd64")
    binaries.find("linux", "amd64")
    assert_equal 1, @shell.commands.count { |command| command == checksum_command(path) }
  end
end
