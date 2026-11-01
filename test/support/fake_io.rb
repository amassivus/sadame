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

# Text to read, as stdin gives it: line by line with gets, or a number of
# bytes with read. Offsets count bytes.
class FakeInput
  def initialize(text)
    @text = text.respond_to?(:b) ? text.b : text
    @position = 0
  end

  def gets
    return nil if @position >= @text.size

    stop = @text.index("\n", @position)
    stop = stop ? stop + 1 : @text.size
    line = @text[@position, stop - @position]
    @position = stop
    line
  end

  def read(length)
    return nil if @position >= @text.size

    chunk = @text[@position, length]
    @position += chunk.size
    chunk
  end
end
