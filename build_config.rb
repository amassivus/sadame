# mruby build configuration for sadame.
#
# Every gem listed in sadame_gems ends up in the sadame binary, so each one
# must build on all release targets. Add a gem only when it is strictly
# needed and say why in the commit that adds it.

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
  conf.gem core: "mruby-object-ext"  # instance_exec, used to evaluate DSL blocks

  # Third-party gems.
  conf.gem github: "iij/mruby-env"
  conf.gem github: "iij/mruby-process"
  conf.gem github: "haconiwa/mruby-exec"
  conf.gem github: "iij/mruby-regexp-pcre"
  conf.gem github: "iij/mruby-iijson"

  conf.gem File.expand_path(__dir__)
end

# Host build: the sadame binary for this machine plus an mruby interpreter
# that has sadame and mruby-mtest compiled in, used to run the test suite.
MRuby::Build.new do |conf|
  conf.toolchain
  sadame_gems(conf)
  conf.gem github: "iij/mruby-mtest"
  conf.gem core: "mruby-bin-mruby"
  conf.enable_debug
end
