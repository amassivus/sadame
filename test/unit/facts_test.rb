# frozen_string_literal: true

class FactsTest < SadameTest
  MEMINFO = "MemTotal:        8131592 kB\nMemFree:          512000 kB\nSwapTotal:       2097148 kB\n"
  DF = "Filesystem     1024-blocks    Used Available Capacity Mounted on\n/dev/vda1         41152736 9876543  29163210      26% /\n"
  IP_ADDR = "1: lo    inet 127.0.0.1/8 scope host lo\\       valid_lft forever\n" \
            "2: eth0    inet 203.0.113.10/24 brd 203.0.113.255 scope global eth0\\       valid_lft forever\n" \
            "3: wg0    inet 10.8.0.1/24 scope global wg0\\       valid_lft forever\n"
  IF_INET6 = "00000000000000000000000000000001 01 80 10 80       lo\n" \
             "20010db8000000000000000000000010 02 40 00 00     eth0\n" \
             "fe8000000000000002163efffe00abcd 02 40 20 80     eth0\n"
  FIB_TRIE = <<~TEXT
    Main:
      +-- 0.0.0.0/0 3 0 5
         |-- 0.0.0.0
            /0 universe UNICAST
         +-- 127.0.0.0/8 2 0 2
            |-- 127.0.0.1
               /32 host LOCAL
         |-- 172.17.0.2
            /32 host LOCAL
    Local:
      +-- 0.0.0.0/0 3 0 5
         |-- 172.17.0.2
            /32 host LOCAL
  TEXT
  ROUTE = "Iface\tDestination\tGateway\tFlags\nlo\t0000007F\t00000000\t0001\neth0\t00000000\t010011AC\t0003\n"

  def server_shell
    shell = linux_shell
    shell.on("uname -n", stdout: "web1\n")
    shell.on("hostname -f 2>/dev/null", stdout: "web1.example.com\n")
    shell.on("uname -m", stdout: "x86_64\n")
    shell.on("uname -r", stdout: "6.1.0-26-amd64\n")
    shell.on("nproc", stdout: "4\n")
    shell.on("df -Pk /", stdout: DF)
    shell.on("ip -4 route get 1.1.1.1", stdout: "1.1.1.1 via 203.0.113.1 dev eth0 src 203.0.113.10 uid 0 \n    cache \n")
    shell.on("ip -4 -o addr show", stdout: IP_ADDR)
    shell.on("systemd-detect-virt", stdout: "kvm\n")
    shell.on("systemd-detect-virt --container", stdout: "none\n", exit_status: 1)
    shell.on("test -d /run/systemd/system")
    shell.files["/proc/meminfo"] = MEMINFO
    shell.files["/proc/net/if_inet6"] = IF_INET6
    shell.files["/etc/machine-id"] = "4c2a0f5e9b1d4e7f8a6b3c2d1e0f9a8b\n"
    shell
  end

  def facts_for(shell)
    host_for(shell).facts
  end

  def test_a_server
    expected = {
      hostname: "web1", fqdn: "web1.example.com", arch: "x86_64", kernel: "6.1.0-26-amd64", cpus: 4,
      memory_mb: 7941, swap_mb: 2047, root_disk_gb: 39, ipv4: "203.0.113.10", default_interface: "eth0",
      ipv4_addresses: ["203.0.113.10", "10.8.0.1"], ipv6_addresses: ["2001:db8::10"],
      virtualization: "kvm", container: false, service_manager: "systemd",
      machine_id: "4c2a0f5e9b1d4e7f8a6b3c2d1e0f9a8b"
    }
    assert_equal expected, facts_for(server_shell).to_h
  end

  def test_facts_are_read_when_asked_for_and_kept
    shell = server_shell
    facts = facts_for(shell)
    assert_equal 4, facts[:cpus]
    assert_equal 4, facts["cpus"]
    assert_equal 1, shell.commands.count("nproc")
    refute_includes shell.commands, "df -Pk /"
  end

  def test_unknown_facts_are_errors
    error = assert_raises(Sadame::RecipeError) { facts_for(server_shell)[:cpu] }
    assert_includes error.message, "unknown fact :cpu (facts: arch, container, cpus,"
  end

  def test_what_cannot_be_read_is_nil
    shell = linux_shell(default_exit_status: 1)
    facts = facts_for(shell)
    [:cpus, :memory_mb, :ipv4, :ipv4_addresses, :machine_id, :fqdn].each do |name|
      assert_includes [nil, []], facts[name], name.inspect
    end
  end

  # Minimal containers have no ip command and no systemd-detect-virt.
  def test_a_container_without_ip_or_systemd
    shell = linux_shell
    shell.on("ip -4 route get 1.1.1.1", stderr: "sh: ip: not found\n", exit_status: 127)
    shell.on("ip -4 -o addr show", stderr: "sh: ip: not found\n", exit_status: 127)
    shell.on("systemd-detect-virt", stderr: "sh: systemd-detect-virt: not found\n", exit_status: 127)
    shell.on("systemd-detect-virt --container", stderr: "not found\n", exit_status: 127)
    shell.on("test -e /.dockerenv")
    shell.on("test -d /run/systemd/system", exit_status: 1).on("test -e /run/openrc/softlevel", exit_status: 1)
    shell.files["/proc/net/fib_trie"] = FIB_TRIE
    shell.files["/proc/net/route"] = ROUTE
    facts = facts_for(shell)
    assert_equal ["172.17.0.2"], facts[:ipv4_addresses]
    assert_equal "172.17.0.2", facts[:ipv4]
    assert_equal "eth0", facts[:default_interface]
    assert_equal "docker", facts[:virtualization]
    assert_equal true, facts[:container]
    assert_nil facts[:service_manager]
  end

  def test_virtualization_from_dmi
    shell = linux_shell
    shell.on("systemd-detect-virt", exit_status: 127)
    shell.on("test -e /.dockerenv", exit_status: 1).on("test -e /run/.containerenv", exit_status: 1)
    shell.files["/sys/class/dmi/id/sys_vendor"] = "QEMU\n"
    assert_equal "qemu", facts_for(shell)[:virtualization]
  end

  def test_openrc_service_manager
    shell = linux_shell("alpine").on("test -d /run/systemd/system", exit_status: 1).on("test -e /run/openrc/softlevel")
    assert_equal "openrc", facts_for(shell)[:service_manager]
  end

  def test_fqdn_falls_back_to_the_hostname
    shell = linux_shell.on("uname -n", stdout: "db1\n").on("hostname -f 2>/dev/null", exit_status: 127)
    assert_equal "db1", facts_for(shell)[:fqdn]
  end

  def test_macos
    shell = FakeShell.new
    shell.on("uname -s", stdout: "Darwin\n")
    shell.on("sysctl -n hw.ncpu", stdout: "10\n")
    shell.on("sysctl -n hw.memsize", stdout: "17179869184\n")
    shell.on("sysctl -n vm.swapusage", stdout: "total = 2048.00M  used = 1003.25M  free = 1044.75M  (encrypted)\n")
    shell.on("route -n get default", stdout: "   route to: default\ndestination: default\n  interface: en0\n")
    shell.on("ipconfig getifaddr en0", stdout: "192.168.1.20\n")
    shell.on("ifconfig", stdout: "lo0: flags\n\tinet 127.0.0.1 netmask 0xff000000\n\tinet6 ::1 prefixlen 128\n" \
                                 "en0: flags\n\tinet6 fe80::1c2b%en0 prefixlen 64\n\tinet 192.168.1.20 netmask 0xffffff00\n" \
                                 "\tinet6 2001:db8::20 prefixlen 64 autoconf\n")
    facts = facts_for(shell)
    assert_equal [10, 16_384, 2048], [facts[:cpus], facts[:memory_mb], facts[:swap_mb]]
    assert_equal ["192.168.1.20", "en0"], [facts[:ipv4], facts[:default_interface]]
    assert_equal [["192.168.1.20"], ["2001:db8::20"]], [facts[:ipv4_addresses], facts[:ipv6_addresses]]
    assert_equal [nil, false, nil], [facts[:virtualization], facts[:container], facts[:machine_id]]
  end

  def test_ipv6_formatting
    shell = linux_shell
    shell.files["/proc/net/if_inet6"] = [
      "20010db8000000000000000000000001 02 40 00 00 eth0",
      "20010db80000000100000000000000ab 02 40 00 00 eth0",
      "fd00000000000000000000000000000a 03 40 00 00 wg0",
      "2a0104f8c0c1abcd0000000000000000 02 40 00 00 eth0"
    ].join("\n")
    expected = ["2001:db8::1", "2001:db8:0:1::ab", "fd00::a", "2a01:4f8:c0c1:abcd::"]
    assert_equal expected, facts_for(shell)[:ipv6_addresses]
  end

  def test_recipes_and_templates_see_facts
    shell = server_shell
    resources = Sadame::Recipe.load("test/fixtures/recipes/facts/recipe.rb", host: host_for(shell), vars: {})
    file = resources.find("file[/etc/app.conf]")
    assert_equal "workers = 8\nlisten = 203.0.113.10:8080\n", file.desired[:content]
  end

  def test_facts_command
    status, stdout, = run_cli(["facts"], shell: server_shell)
    assert_equal 0, status
    assert_includes stdout, "sadame #{Sadame::VERSION} facts on local (Debian GNU/Linux 12 (bookworm))\n\n" \
                            "hostname           web1\n"
    assert_includes stdout, "\nipv4_addresses     203.0.113.10, 10.8.0.1\n"
    assert_includes stdout, "\ncontainer          false\n"

    status, stdout, = run_cli(["facts", "--json", "--host-name", "web1"], shell: server_shell)
    assert_equal 0, status
    assert_includes stdout, "\"command\": \"facts\",\n  \"host\": \"web1\","
    assert_includes stdout, "\"cpus\": 4,"
    assert_includes stdout, "\"ipv4_addresses\": [\n      \"203.0.113.10\",\n      \"10.8.0.1\"\n    ],"

    status, _stdout, stderr = run_cli(["facts", "--serial", "2"], shell: server_shell)
    assert_equal 2, status
    assert_includes stderr, "--serial only applies to -h, -g and --limit"
  end
end
