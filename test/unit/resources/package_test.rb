# frozen_string_literal: true

class PackageResourceTest < SadameTest
  QUERIES = {
    "debian" => "dpkg-query -W -f='${Status}' nginx",
    "ubuntu" => "dpkg-query -W -f='${Status}' nginx",
    "rocky" => "rpm -q nginx",
    "alpine" => "apk info -e nginx",
    "arch" => "pacman -Q nginx",
    "omarchy" => "pacman -Q nginx"
  }.freeze

  INSTALLS = {
    "debian" => "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx",
    "ubuntu" => "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx",
    "rocky" => "dnf install -y nginx",
    "alpine" => "apk add nginx",
    "arch" => "pacman -S --needed --noconfirm nginx",
    "omarchy" => "pacman -S --needed --noconfirm nginx"
  }.freeze

  REMOVALS = {
    "debian" => "DEBIAN_FRONTEND=noninteractive apt-get remove -y nginx",
    "rocky" => "dnf remove -y nginx",
    "alpine" => "apk del nginx",
    "arch" => "pacman -Rns --noconfirm nginx"
  }.freeze

  def missing_package_shell(distribution)
    linux_shell(distribution).on(QUERIES[distribution], exit_status: 1)
  end

  def installed_package_shell(distribution)
    stdout = distribution == "debian" || distribution == "ubuntu" ? "install ok installed" : "nginx 1.26.2-1\n"
    linux_shell(distribution).on(QUERIES[distribution], stdout: stdout)
  end

  def test_plans_and_installs_a_missing_package_on_every_manager
    INSTALLS.each do |distribution, install_command|
      shell = missing_package_shell(distribution)
      package = build_resource(Sadame::PackageResource, "nginx", {}, shell: shell)
      changes = package.diff
      assert_equal :create, package.plan_action(changes), distribution
      assert_equal "absent", changes.first.from
      assert_equal "installed", changes.first.to

      package.apply(changes)
      assert_equal install_command, shell.commands.last, distribution
    end
  end

  def test_installed_package_has_no_changes
    QUERIES.each_key do |distribution|
      shell = installed_package_shell(distribution)
      package = build_resource(Sadame::PackageResource, "nginx", {}, shell: shell)
      assert_empty package.diff, distribution
      refute_includes shell.commands, INSTALLS[distribution]
    end
  end

  def test_removes_an_installed_package_when_absent
    REMOVALS.each do |distribution, remove_command|
      shell = installed_package_shell(distribution)
      package = build_resource(Sadame::PackageResource, "nginx", { state: :absent }, shell: shell)
      changes = package.diff
      assert_equal :remove, package.plan_action(changes)
      package.apply(changes)
      assert_equal remove_command, shell.commands.last
    end
  end

  def test_pacman_exact_command_sequence
    shell = missing_package_shell("arch")
    package = build_resource(Sadame::PackageResource, "nginx", { options: "--asdeps" }, shell: shell)
    package.apply(package.diff)
    assert_equal ["uname -s", "pacman -Q nginx", "pacman -S --needed --noconfirm --asdeps nginx"], shell.commands
  end

  def test_rejects_unknown_state
    error = assert_raises(Sadame::ResourceError) { build_resource(Sadame::PackageResource, "nginx", { state: :latest }) }
    assert_includes error.message, "state must be one of installed, absent"
  end

  def test_rejects_unknown_options
    error = assert_raises(Sadame::ResourceError) { build_resource(Sadame::PackageResource, "nginx", { version: "1.2" }) }
    assert_includes error.message, "package[nginx]: unknown option :version"
  end
end
