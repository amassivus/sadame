# frozen_string_literal: true

module Sadame
  # Differences between the desired and the current state of a resource.
  module Diff
    # One attribute that differs. For content changes, from and to hold the
    # full text; output turns them into a unified diff.
    class Change
      attr_reader :attribute, :from, :to, :reason

      def initialize(attribute, from, to, reason: nil)
        @attribute = attribute
        @from = from
        @to = to
        @reason = reason
      end

      def content?
        attribute == :content
      end
    end

    # Compares the attributes present in desired with the same keys in current.
    def self.changes(desired, current)
      result = []
      desired.each do |attribute, value|
        result << Change.new(attribute, current[attribute], value) unless value == current[attribute]
      end
      result
    end

    # Returns a unified diff between two texts, or "" when they are equal.
    def self.unified(old_text, new_text, old_label:, new_label:, context: 3)
      old_lines = split_lines(old_text.to_s)
      new_lines = split_lines(new_text.to_s)
      operations = edit_script(old_lines, new_lines)
      hunks = group_hunks(operations, context)
      return "" if hunks.empty?

      output = String.new
      output << "--- #{old_label}\n"
      output << "+++ #{new_label}\n"
      hunks.each { |hunk| output << format_hunk(operations, hunk) }
      output
    end

    # Splits text into lines that keep their trailing newline, so a missing
    # newline at the end of a file shows up as a difference.
    def self.split_lines(text)
      lines = []
      start = 0
      while (index = text.index("\n", start))
        lines << text[start..index]
        start = index + 1
      end
      lines << text[start..] if start < text.size
      lines
    end

    # Myers' O(ND) diff algorithm. Returns operations of the form
    # [type, line, old_position, new_position] where type is :equal,
    # :delete or :insert and positions count lines consumed before this one.
    def self.edit_script(old_lines, new_lines)
      trace = shortest_edit_trace(old_lines, new_lines)
      operations = backtrack(trace, old_lines, new_lines)
      add_positions(operations)
    end

    def self.shortest_edit_trace(old_lines, new_lines)
      old_size = old_lines.size
      new_size = new_lines.size
      max = old_size + new_size
      offset = max
      frontier = Array.new((2 * max) + 2, 0)
      trace = []

      (0..max).each do |distance|
        trace << frontier.dup
        k = -distance
        while k <= distance
          x = next_x(frontier, k, distance, offset)
          y = x - k
          while x < old_size && y < new_size && old_lines[x] == new_lines[y]
            x += 1
            y += 1
          end
          frontier[k + offset] = x
          return trace if x >= old_size && y >= new_size

          k += 2
        end
      end
      trace
    end

    def self.next_x(frontier, k, distance, offset)
      if k == -distance || (k != distance && frontier[k - 1 + offset] < frontier[k + 1 + offset])
        frontier[k + 1 + offset]
      else
        frontier[k - 1 + offset] + 1
      end
    end

    def self.backtrack(trace, old_lines, new_lines)
      offset = old_lines.size + new_lines.size
      x = old_lines.size
      y = new_lines.size
      reversed = []

      (trace.size - 1).downto(0) do |distance|
        frontier = trace[distance]
        k = x - y
        previous_k = if k == -distance || (k != distance && frontier[k - 1 + offset] < frontier[k + 1 + offset])
                       k + 1
                     else
                       k - 1
                     end
        previous_x = frontier[previous_k + offset]
        previous_y = previous_x - previous_k

        while x > previous_x && y > previous_y
          reversed << [:equal, old_lines[x - 1]]
          x -= 1
          y -= 1
        end
        next if distance == 0

        if x == previous_x
          reversed << [:insert, new_lines[y - 1]]
        else
          reversed << [:delete, old_lines[x - 1]]
        end
        x = previous_x
        y = previous_y
      end
      reversed.reverse
    end

    def self.add_positions(operations)
      old_position = 0
      new_position = 0
      operations.map do |type, line|
        operation = [type, line, old_position, new_position]
        old_position += 1 unless type == :insert
        new_position += 1 unless type == :delete
        operation
      end
    end

    # Groups changed operations into hunks of [first_index, last_index],
    # each padded with context lines and merged when they overlap.
    def self.group_hunks(operations, context)
      hunks = []
      operations.each_with_index do |operation, index|
        next if operation[0] == :equal

        first = [index - context, 0].max
        last = [index + context, operations.size - 1].min
        if hunks.empty? || first > hunks.last[1] + 1
          hunks << [first, last]
        else
          hunks.last[1] = last
        end
      end
      hunks
    end

    def self.format_hunk(operations, hunk)
      first, last = hunk
      slice = operations[first..last]
      old_count = slice.count { |operation| operation[0] != :insert }
      new_count = slice.count { |operation| operation[0] != :delete }
      old_start = operations[first][2] + (old_count == 0 ? 0 : 1)
      new_start = operations[first][3] + (new_count == 0 ? 0 : 1)

      output = String.new
      output << "@@ -#{hunk_range(old_start, old_count)} +#{hunk_range(new_start, new_count)} @@\n"
      slice.each do |type, line|
        output << line_prefix(type) << line
        output << "\n\\ No newline at end of file\n" unless line.end_with?("\n")
      end
      output
    end

    def self.hunk_range(start, count)
      count == 1 ? start.to_s : "#{start},#{count}"
    end

    def self.line_prefix(type)
      case type
      when :delete then "-"
      when :insert then "+"
      else " "
      end
    end
  end
end
