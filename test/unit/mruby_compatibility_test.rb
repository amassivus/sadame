# frozen_string_literal: true

# The mruby test build includes mruby-metaprog, because mruby-mtest needs it;
# release builds do not. Code in lib/ that calls its methods passes every
# unit test and fails in the binary, so this looks for them in the source.
class MrubyCompatibilityTest < SadameTest
  METAPROG_NAMES = "send|public_send|instance_variable_get|instance_variable_set|instance_variables|" \
                   "define_singleton_method|singleton_methods|class_variable_get|class_variable_set|remove_method|" \
                   "instance_methods"
  # obj.send(...), or a bare send(...) / send :name; not the word in a string.
  METAPROG_CALL = /\.(#{METAPROG_NAMES})\b|(?<![\w.])(#{METAPROG_NAMES})(?:\(|\s+:)/

  def test_library_code_avoids_mruby_metaprog
    skip "needs Dir.glob and Regexp captures, checked on CRuby" unless RUBY_ENGINE == "ruby"

    Dir.glob("lib/**/*.rb").each do |path|
      File.readlines(path).each_with_index do |line, index|
        next if line.strip.start_with?("#")

        match = METAPROG_CALL.match(line)
        refute match, "#{path}:#{index + 1} calls #{match && (match[1] || match[2])}, which release builds do not have"
      end
    end
  end
end
