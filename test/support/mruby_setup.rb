# frozen_string_literal: true

# Base class for tests under mruby. Tests are written with minitest
# assertion names; the few that mruby-mtest names differently are mapped
# here.
class SadameTest < MTest::Unit::TestCase
  include TestHelpers

  def assert_includes(collection, object, message = nil)
    assert_include(collection, object, message)
  end

  def refute_includes(collection, object, message = nil)
    assert_not_include(collection, object, message)
  end

  def refute(test, message = nil)
    assert(!test, message || "expected #{test.inspect} to be falsy")
  end

  def refute_nil(object, message = nil)
    assert(!object.nil?, message || "expected a value, got nil")
  end

  def refute_empty(object, message = nil)
    assert_not_empty(object, message)
  end

  # Like minitest: passes for subclasses of the expected classes and
  # returns the exception.
  def assert_raises(*classes)
    yield
  rescue MTest::Assertion => e
    raise e
  rescue Exception => e
    expected = classes.any? { |klass| e.is_a?(klass) }
    assert(expected, "expected #{classes.join(" or ")}, got #{e.class}: #{e.message}")
    e
  else
    flunk("expected #{classes.join(" or ")} to be raised")
  end
end
