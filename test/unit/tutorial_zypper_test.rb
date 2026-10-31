# frozen_string_literal: true

# The zypper package manager from docs/contributing/architecture.md,
# "Adding a package manager". The page embeds the sections between the
# --8<-- markers; sadame does not ship zypper support.
module Tutorial
  # --8<-- [start:manager]
  # openSUSE and SUSE Linux Enterprise.
  class Zypper < Sadame::PackageManagers::Base
    def name
      "zypper"
    end

    def query_command(package)
      "rpm -q #{Sadame::Shell.escape(package)}"
    end

    def install_command(package, options = nil)
      "zypper --non-interactive install #{extra_flags(options)}#{Sadame::Shell.escape(package)}"
    end

    def remove_command(package, options = nil)
      "zypper --non-interactive remove #{extra_flags(options)}#{Sadame::Shell.escape(package)}"
    end
  end
  # --8<-- [end:manager]
end

class TutorialZypperTest < SadameTest
  # --8<-- [start:tests]
  def test_zypper_command_lines
    zypper = Tutorial::Zypper.new(linux_shell)
    assert_equal "rpm -q nginx", zypper.query_command("nginx")
    assert_equal "zypper --non-interactive install nginx", zypper.install_command("nginx")
    assert_equal "zypper --non-interactive remove nginx", zypper.remove_command("nginx")
    assert_equal "zypper --non-interactive install --no-recommends nginx",
                 zypper.install_command("nginx", "--no-recommends")
  end

  def test_zypper_installs_through_the_shell
    shell = linux_shell.on("rpm -q nginx", exit_status: 1)
    zypper = Tutorial::Zypper.new(shell)
    refute zypper.installed?("nginx")
    zypper.install("nginx")
    assert_equal "zypper --non-interactive install nginx", shell.commands.last
  end
  # --8<-- [end:tests]
end
