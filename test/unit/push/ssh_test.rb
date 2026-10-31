# frozen_string_literal: true

class PushSSHTest < SadameTest
  def ssh(target, control_dir: nil)
    Sadame::Push::SSH.new(target, control_dir: control_dir)
  end

  def test_plain_host
    command = ssh(Sadame::Target.new("web1.example.com")).ssh("uname -sm")
    assert_equal "ssh -o BatchMode=yes -o ConnectTimeout=10 web1.example.com 'uname -sm'", command
  end

  def test_user_and_port_use_p_for_ssh_and_capital_p_for_scp
    target = Sadame::Target.new("db1.example.com", user: "admin", port: 2222)
    assert_equal "ssh -o BatchMode=yes -o ConnectTimeout=10 -p 2222 admin@db1.example.com true", ssh(target).ssh("true")
    assert_equal "scp -q -o BatchMode=yes -o ConnectTimeout=10 -P 2222 /tmp/b admin@db1.example.com:.sadame/b",
                 ssh(target).scp("/tmp/b", ".sadame/b")
  end

  def test_ssh_opts_come_first_so_they_can_override_defaults
    target = Sadame::Target.new("app1", ssh_opts: ["-F", "/tests/ssh config", "-o", "BatchMode=no"])
    assert_equal "ssh -F '/tests/ssh config' -o BatchMode=no -o BatchMode=yes -o ConnectTimeout=10 app1 true",
                 ssh(target).ssh("true")
  end

  def test_address_ipv6_and_control_socket
    target = Sadame::Target.new("v6", address: "2001:db8::1", user: "root")
    connection = ssh(target, control_dir: "/tmp/s")
    control = "-o ControlMaster=auto -o ControlPath=/tmp/s/%C -o ControlPersist=60"
    assert_equal "ssh -o BatchMode=yes -o ConnectTimeout=10 #{control} root@2001:db8::1 true", connection.ssh("true")
    assert_includes connection.scp("/tmp/b", "b"), "root@[2001:db8::1]:b"
    assert_equal "ssh -o BatchMode=yes -o ConnectTimeout=10 #{control} -O exit root@2001:db8::1", connection.close
    assert_nil ssh(target).close
  end
end
