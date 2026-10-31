# frozen_string_literal: true

class JsonWriterTest < SadameTest
  def test_scalars
    assert_equal "null\n", Sadame::JsonWriter.generate(nil)
    assert_equal "true\n", Sadame::JsonWriter.generate(true)
    assert_equal "42\n", Sadame::JsonWriter.generate(42)
    assert_equal "\"plan\"\n", Sadame::JsonWriter.generate(:plan)
  end

  def test_string_escaping
    assert_equal "\"a\\\"b\\\\c\\nd\\te\\u0001\"\n", Sadame::JsonWriter.generate("a\"b\\c\nd\te\x01")
  end

  def test_nested_structures_are_indented
    expected = "{\n  \"a\": [\n    1,\n    {}\n  ],\n  \"b\": []\n}\n"
    assert_equal expected, Sadame::JsonWriter.generate({ a: [1, {}], b: [] })
  end
end
