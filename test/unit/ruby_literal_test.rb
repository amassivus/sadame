# frozen_string_literal: true

class RubyLiteralTest < SadameTest
  # Evaluates inside a method; see the mruby note in docs/contributing/architecture.md.
  class Reader
    def read(text)
      instance_eval(text)
    end
  end

  def round_trip(value)
    text = Sadame::RubyLiteral.dump(value)
    refute_includes text, "\n"
    Reader.new.read(text)
  end

  def test_round_trips_every_supported_type
    value = { workers: 8, ratio: 1.5, tls: true, debug: false, missing: nil, "name" => "web",
              list: [1, "two", :three], nested: { deep: { deeper: [] } } }
    assert_equal value, round_trip(value)
  end

  def test_strings_survive_quotes_interpolation_and_newlines
    value = "say \"hi\" \#{not_code} \\ path\nnext line\ttab\x01"
    assert_equal value, round_trip(value)
    assert_equal :"two words", round_trip(:"two words")
  end

  def test_rejects_other_objects
    assert_raises(Sadame::Error) { Sadame::RubyLiteral.dump(Object.new) }
  end
end
