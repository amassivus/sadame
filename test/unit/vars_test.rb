# frozen_string_literal: true

class VarsTest < SadameTest
  def test_load_file_returns_symbol_keys
    vars = Sadame::Vars.load_file("test/fixtures/vars/vars.rb")
    assert_equal "example.com", vars[:server_name]
    assert_equal 4, vars[:workers]
    assert_equal "from string key", vars[:string_key]
  end

  def test_missing_file_means_no_vars
    assert_equal({}, Sadame::Vars.load_file("test/fixtures/vars/does-not-exist.rb"))
  end

  def test_file_must_evaluate_to_a_hash
    error = assert_raises(Sadame::RecipeError) { Sadame::Vars.load_file("test/fixtures/vars/not_a_hash.rb") }
    assert_includes error.message, "must evaluate to a Hash"
  end

  def test_errors_point_at_the_line
    error = assert_raises(Sadame::RecipeError) { Sadame::Vars.load_file("test/fixtures/vars/broken.rb") }
    assert_includes error.message, "test/fixtures/vars/broken.rb:3"
  end

  def test_parse_assignment
    assert_equal [:name, "web"], Sadame::Vars.parse_assignment("name=web")
    assert_equal [:url, "a=b"], Sadame::Vars.parse_assignment("url=a=b")
    assert_equal [:empty, ""], Sadame::Vars.parse_assignment("empty=")
  end

  def test_parse_assignment_converts_booleans_and_integers
    assert_equal [:tls, true], Sadame::Vars.parse_assignment("tls=true")
    assert_equal [:tls, false], Sadame::Vars.parse_assignment("tls=false")
    assert_equal [:workers, 8], Sadame::Vars.parse_assignment("workers=8")
    assert_equal [:offset, -2], Sadame::Vars.parse_assignment("offset=-2")
    assert_equal [:version, "1.2"], Sadame::Vars.parse_assignment("version=1.2")
    assert_equal [:mode, "0644"], Sadame::Vars.parse_assignment("mode=0644")
    assert_equal [:zero, 0], Sadame::Vars.parse_assignment("zero=0")
  end

  def test_parse_assignment_rejects_malformed_input
    assert_raises(Sadame::UsageError) { Sadame::Vars.parse_assignment("novalue") }
    assert_raises(Sadame::UsageError) { Sadame::Vars.parse_assignment("=value") }
  end

  def test_merge_later_layers_win
    merged = Sadame::Vars.merge({ a: 1, b: 1 }, { "b" => 2, c: 2 }, { c: 3 })
    assert_equal({ a: 1, b: 2, c: 3 }, merged)
  end
end
