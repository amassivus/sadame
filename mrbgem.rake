# Builds sadame as an mrbgem. lib/sadame.rb is the single source of truth for
# the load order: CRuby follows its require_relative lines, and this file
# compiles the same files in the same order into the binary.

def sadame_rbfiles(root)
  manifest = File.join(root, "lib", "sadame.rb")
  File.readlines(manifest).filter_map do |line|
    match = line.match(/\Arequire_relative "(.+)"/)
    File.join(root, "lib", "#{match[1]}.rb") if match
  end
end

MRuby::Gem::Specification.new("sadame") do |spec|
  spec.license = "MIT"
  spec.author = "Ender Kus"
  spec.summary = "Configuration management in plain Ruby, in one binary"
  spec.bins = ["sadame"]
  spec.rbfiles = sadame_rbfiles(__dir__)

  %w[
    mruby-io mruby-dir mruby-sprintf mruby-time mruby-struct mruby-string-ext
    mruby-array-ext mruby-hash-ext mruby-enum-ext mruby-kernel-ext mruby-eval
    mruby-env mruby-process mruby-exec mruby-regexp-pcre mruby-iijson
  ].each { |name| spec.add_dependency(name) }
end
