# mruby build configuration for sadame.
#
# Every gem listed in sadame_gems ends up in the sadame binary, so each one
# must build on all release targets. Add a gem only when it is strictly
# needed and say why in the commit that adds it.
#
# SADAME_TARGET selects what to build (the Rakefile sets it):
#
#   development    (default) this machine, with debug info, plus an mruby
#                  interpreter with mruby-mtest for `rake test:mruby`
#   linux-static   a static binary, built inside an Alpine (musl) container
#                  of the target architecture
#   darwin-arm64   macOS on Apple silicon
#   darwin-amd64   macOS on Intel, cross-compiled with clang

def sadame_gems(conf)
  # Core gems shipped with mruby.
  conf.gem core: "mruby-io"          # File, IO, IO.popen; also provides Kernel#puts/print (mruby-print was folded into it in mruby 3.4)
  conf.gem core: "mruby-dir"
  conf.gem core: "mruby-sprintf"
  conf.gem core: "mruby-time"
  conf.gem core: "mruby-struct"
  conf.gem core: "mruby-string-ext"
  conf.gem core: "mruby-array-ext"
  conf.gem core: "mruby-hash-ext"
  conf.gem core: "mruby-enum-ext"
  conf.gem core: "mruby-kernel-ext"
  conf.gem core: "mruby-eval"        # recipes, vars.rb and templates are evaluated at run time

  # Third-party gems.
  conf.gem github: "iij/mruby-env"
  conf.gem github: "iij/mruby-process"
  conf.gem github: "haconiwa/mruby-exec"
  conf.gem github: "iij/mruby-regexp-pcre"
  conf.gem github: "iij/mruby-iijson"

  conf.gem File.expand_path(__dir__)
end

# Line numbers for sadame's own Ruby code in backtraces, which makes bug
# reports from release binaries useful.
def keep_line_numbers(conf)
  conf.mrbc.compile_options += " -g"
end

MACOS_MINIMUM_VERSION = "11.0"

case ENV.fetch("SADAME_TARGET", "development")
when "development"
  MRuby::Build.new do |conf|
    conf.toolchain
    sadame_gems(conf)
    conf.gem github: "iij/mruby-mtest"
    conf.gem core: "mruby-bin-mruby"
    conf.enable_debug
  end

when "linux-static"
  MRuby::Build.new do |conf|
    conf.toolchain :gcc
    sadame_gems(conf)
    keep_line_numbers(conf)
    conf.linker.flags << "-static"
  end

when "darwin-arm64", "darwin-amd64"
  architecture = ENV.fetch("SADAME_TARGET") == "darwin-arm64" ? "arm64" : "x86_64"
  MRuby::CrossBuild.new(ENV.fetch("SADAME_TARGET")) do |conf|
    conf.toolchain :clang
    flags = ["-arch", architecture, "-mmacosx-version-min=#{MACOS_MINIMUM_VERSION}"]
    [conf.cc, conf.linker].each { |tool| tool.flags << flags }
    conf.host_target = "#{architecture}-apple-darwin"
    sadame_gems(conf)
    keep_line_numbers(conf)
  end

else
  raise "unknown SADAME_TARGET: #{ENV.fetch("SADAME_TARGET")}"
end
