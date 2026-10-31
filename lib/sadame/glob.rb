# frozen_string_literal: true

module Sadame
  # Shell-style wildcard matching for --limit: "*" matches any run of
  # characters (including none), "?" exactly one. Everything else matches
  # itself.
  #
  #   Sadame::Glob.match?("web*", "web1.example.com")  # => true
  module Glob
    def self.match?(pattern, text)
      match_from?(pattern.to_s.chars, 0, text.to_s.chars, 0)
    end

    # Backtracks on "*": tries to let it match zero characters first, then
    # one more each time.
    def self.match_from?(pattern, pattern_index, text, text_index)
      while pattern_index < pattern.size
        char = pattern[pattern_index]
        if char == "*"
          (text_index..text.size).each do |start|
            return true if match_from?(pattern, pattern_index + 1, text, start)
          end
          return false
        end
        return false if text_index >= text.size
        return false unless char == "?" || char == text[text_index]

        pattern_index += 1
        text_index += 1
      end
      text_index == text.size
    end
  end
end
