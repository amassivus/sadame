# frozen_string_literal: true

class TargetTest < SadameTest
  def test_parse_forms
    assert_equal [nil, "web1.example.com", nil], Sadame::Target.parse("web1.example.com")
    assert_equal ["admin", "db1.example.com", nil], Sadame::Target.parse("admin@db1.example.com")
    assert_equal [nil, "db1.example.com", 2222], Sadame::Target.parse("db1.example.com:2222")
    assert_equal ["admin", "db1.example.com", 2222], Sadame::Target.parse("admin@db1.example.com:2222")
    assert_equal ["root", "2001:db8::1", 22], Sadame::Target.parse("root@[2001:db8::1]:22")
    assert_equal [nil, "2001:db8::1", nil], Sadame::Target.parse("[2001:db8::1]")
  end

  def test_parse_errors
    ["@host", "admin@", "host:0", "host:70000", "host:ssh", "2001:db8::1", "[::1", "[::1]x"].each do |spec|
      assert_raises(Sadame::UsageError) { Sadame::Target.parse(spec) }
    end
  end

  def test_with_replaces_attributes
    target = Sadame::Target.new("db1", user: "admin", port: 2222)
    changed = target.with(port: 22, sudo: true)
    assert_equal ["admin", 22, true], [changed.user, changed.port, changed.sudo]
    assert_equal 2222, target.port
  end
end
