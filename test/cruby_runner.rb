# frozen_string_literal: true

# Runs the suite on CRuby with minitest. `rake test:mruby` runs the same
# test files under mruby with mruby-mtest.
require "minitest/autorun"
require "sadame"
require "support/test_helpers"
require "support/fake_shell"
require "support/fake_io"

class SadameTest < Minitest::Test
  include TestHelpers
end

Dir.glob(File.join(__dir__, "unit", "**", "*_test.rb")).sort.each { |path| require path }
