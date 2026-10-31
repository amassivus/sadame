# frozen_string_literal: true

# Prints the CHANGELOG.md section for a version, used as the GitHub release
# notes. Exits non-zero when the section is missing.
#
#   ruby script/build/release-notes.rb 0.1.0
#   ruby script/build/release-notes.rb Unreleased

version = ARGV.fetch(0) { abort "usage: release-notes.rb VERSION" }
changelog = File.read(File.expand_path("../../CHANGELOG.md", __dir__))

section = []
inside = false
changelog.each_line do |line|
  if line.start_with?("## ")
    break if inside

    inside = line.start_with?("## [#{version}]")
    next
  end
  section << line if inside
end

notes = section.join.strip
abort "CHANGELOG.md has no section for #{version}" if notes.empty?

puts notes
