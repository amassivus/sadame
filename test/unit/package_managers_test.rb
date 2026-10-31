# frozen_string_literal: true

class PackageManagersTest < SadameTest
  def manager_for(distribution, shell = linux_shell(distribution))
    Sadame::PackageManagers.for(Sadame::Platform.detect(shell), shell)
  end

  def test_selects_the_manager_from_the_platform
    assert_equal "apt", manager_for("ubuntu").name
    assert_equal "apt", manager_for("debian").name
    assert_equal "dnf", manager_for("rocky").name
    assert_equal "apk", manager_for("alpine").name
    assert_equal "pacman", manager_for("arch").name
    assert_equal "pacman", manager_for("omarchy").name
  end

  def test_unsupported_platform
    shell = FakeShell.new.on("uname -s", stdout: "Darwin\n")
    error = assert_raises(Sadame::ResourceError) { Sadame::PackageManagers.for(Sadame::Platform.detect(shell), shell) }
    assert_includes error.message, "no supported package manager on macOS"
  end

  def test_apt_command_lines
    apt = manager_for("debian")
    assert_equal "dpkg-query -W -f='${Status}' nginx", apt.query_command("nginx")
    assert_equal "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx", apt.install_command("nginx")
    assert_equal "DEBIAN_FRONTEND=noninteractive apt-get remove -y nginx", apt.remove_command("nginx")
    assert_equal "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nginx",
                 apt.install_command("nginx", "--no-install-recommends")
  end

  def test_apt_installed_requires_the_installed_status
    shell = linux_shell("debian")
    shell.on("dpkg-query -W -f='${Status}' nginx", stdout: "install ok installed")
    shell.on("dpkg-query -W -f='${Status}' old", stdout: "deinstall ok config-files")
    shell.on("dpkg-query -W -f='${Status}' missing", exit_status: 1)
    apt = manager_for("debian", shell)
    assert apt.installed?("nginx")
    refute apt.installed?("old")
    refute apt.installed?("missing")
  end

  def test_apt_updates_the_index_once_before_the_first_install
    shell = linux_shell("debian")
    apt = manager_for("debian", shell)
    apt.install("nginx")
    apt.install("git")
    expected = [
      "DEBIAN_FRONTEND=noninteractive apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y git"
    ]
    assert_equal expected, shell.commands.last(3)
  end

  def test_dnf_command_lines
    dnf = manager_for("rocky")
    assert_equal "rpm -q nginx", dnf.query_command("nginx")
    assert_equal "dnf install -y nginx", dnf.install_command("nginx")
    assert_equal "dnf remove -y nginx", dnf.remove_command("nginx")
  end

  def test_apk_command_lines
    apk = manager_for("alpine")
    assert_equal "apk info -e nginx", apk.query_command("nginx")
    assert_equal "apk add nginx", apk.install_command("nginx")
    assert_equal "apk del nginx", apk.remove_command("nginx")
  end

  def test_pacman_command_lines
    pacman = manager_for("arch")
    assert_equal "pacman -Q nginx", pacman.query_command("nginx")
    assert_equal "pacman -S --needed --noconfirm nginx", pacman.install_command("nginx")
    assert_equal "pacman -Rns --noconfirm nginx", pacman.remove_command("nginx")
  end

  def test_pacman_extra_options
    pacman = manager_for("omarchy")
    assert_equal "pacman -S --needed --noconfirm --asdeps nginx", pacman.install_command("nginx", "--asdeps")
    assert_equal "pacman -S --needed --noconfirm --asdeps '--overwrite=/usr/lib/*' nginx",
                 pacman.install_command("nginx", ["--asdeps", "--overwrite=/usr/lib/*"])
  end

  def test_install_failure_raises
    shell = linux_shell("arch")
    shell.on("pacman -S --needed --noconfirm nope", stderr: "error: target not found: nope\n", exit_status: 1)
    error = assert_raises(Sadame::CommandFailed) { manager_for("arch", shell).install("nope") }
    assert_includes error.message, "target not found: nope"
  end
end
