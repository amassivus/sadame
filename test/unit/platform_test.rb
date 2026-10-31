# frozen_string_literal: true

class PlatformTest < SadameTest
  def platform(name)
    Sadame::Platform.from_os_release(os_release(name))
  end

  def test_ubuntu
    assert_equal "debian", platform("ubuntu").family
    assert_equal "apt", platform("ubuntu").package_manager
    assert_equal "Ubuntu 24.04.5 LTS", platform("ubuntu").description
  end

  def test_debian
    assert_equal "debian", platform("debian").family
    assert_equal "apt", platform("debian").package_manager
    assert_equal "12", platform("debian").version
  end

  def test_rocky
    assert_equal "rhel", platform("rocky").family
    assert_equal "dnf", platform("rocky").package_manager
    assert_equal "rocky", platform("rocky").id
  end

  def test_alpine
    assert_equal "alpine", platform("alpine").family
    assert_equal "apk", platform("alpine").package_manager
  end

  def test_arch
    assert_equal "arch", platform("arch").family
    assert_equal "pacman", platform("arch").package_manager
  end

  def test_omarchy_is_detected_as_arch
    assert_equal "arch", platform("omarchy").family
    assert_equal "pacman", platform("omarchy").package_manager
    assert_nil platform("omarchy").version
  end

  def test_family_falls_back_to_id_like
    text = "ID=linuxmint-like\nID_LIKE=\"ubuntu debian\"\n"
    assert_equal "debian", Sadame::Platform.from_os_release(text).family

    text = "ID=garuda\nID_LIKE=arch\n"
    assert_equal "pacman", Sadame::Platform.from_os_release(text).package_manager
  end

  def test_unknown_distribution
    platform = Sadame::Platform.from_os_release("ID=plan9\nNAME=\"Plan 9\"\n")
    assert_nil platform.family
    assert_nil platform.package_manager
    assert_equal "Plan 9", platform.description
  end

  def test_parse_handles_quotes_comments_and_blank_lines
    fields = Sadame::Platform.parse_os_release("# comment\n\nNAME='Single'\nID=\"double\"\nEMPTY=\nBROKEN\n")
    assert_equal "Single", fields["NAME"]
    assert_equal "double", fields["ID"]
    assert_equal "", fields["EMPTY"]
    assert_nil fields["BROKEN"]
  end

  def test_detect_reads_os_release_through_the_shell
    platform = Sadame::Platform.detect(linux_shell("rocky"))
    assert_equal "rhel", platform.family
    assert platform.linux?
  end

  def test_detect_falls_back_to_usr_lib_os_release
    shell = FakeShell.new(files: { "/usr/lib/os-release" => os_release("alpine") }).on("uname -s", stdout: "Linux\n")
    assert_equal "alpine", Sadame::Platform.detect(shell).family
  end

  def test_detect_on_macos
    shell = FakeShell.new.on("uname -s", stdout: "Darwin\n")
    platform = Sadame::Platform.detect(shell)
    assert platform.darwin?
    assert_nil platform.package_manager
    assert_equal "macOS", platform.description
  end
end
