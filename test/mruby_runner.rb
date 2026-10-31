# frozen_string_literal: true

# Appended to the concatenated test script by `rake test:mruby`.
failures = MTest::Unit.new.run
raise "#{failures} test(s) failed" if failures.to_i > 0
