# frozen_string_literal: true

# Collects everything written to it; stands in for $stdout and $stderr.
class FakeIO
  attr_reader :string

  def initialize(tty: false)
    @string = String.new
    @tty = tty
  end

  def write(text)
    @string << text.to_s
    text.to_s.size
  end

  def tty?
    @tty
  end
end
