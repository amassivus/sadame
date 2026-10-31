# frozen_string_literal: true

class GlobTest < SadameTest
  def test_literal_patterns
    assert Sadame::Glob.match?("web1", "web1")
    refute Sadame::Glob.match?("web1", "web10")
  end

  def test_star
    assert Sadame::Glob.match?("web*", "web1.example.com")
    assert Sadame::Glob.match?("*.example.com", "db1.example.com")
    assert Sadame::Glob.match?("*", "")
    assert Sadame::Glob.match?("w*b*", "web1-backup")
    refute Sadame::Glob.match?("web*", "db1")
  end

  def test_question_mark
    assert Sadame::Glob.match?("web?", "web2")
    refute Sadame::Glob.match?("web?", "web10")
  end
end
