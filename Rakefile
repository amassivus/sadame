# frozen_string_literal: true

# Development tasks. This file runs on CRuby only; the mruby subset rules
# apply to lib/, not to build tooling.

MRUBY_VERSION = "3.4.0"
ROOT = __dir__
MRUBY_DIR = File.join(ROOT, "vendor", "mruby-#{MRUBY_VERSION}")
BUILD_DIR = File.join(ROOT, "build")
HOST_BIN_DIR = File.join(BUILD_DIR, "host", "bin")

file MRUBY_DIR do
  mkdir_p File.dirname(MRUBY_DIR)
  sh "git", "-c", "advice.detachedHead=false", "clone", "--quiet", "--depth", "1",
     "--branch", MRUBY_VERSION, "https://github.com/mruby/mruby.git", MRUBY_DIR
end

def run_mruby_rake(*tasks)
  env = {
    "MRUBY_CONFIG" => File.join(ROOT, "build_config.rb"),
    "MRUBY_BUILD_DIR" => BUILD_DIR
  }
  Dir.chdir(MRUBY_DIR) { sh env, "rake", *tasks }
end

namespace :build do
  desc "Build sadame for this machine into build/host/bin/sadame"
  task native: MRUBY_DIR do
    run_mruby_rake("all")
  end
end

# The mruby test run cannot use require, so every test file is concatenated
# into one script and executed by the mruby interpreter that has sadame and
# mruby-mtest compiled in.
MRUBY_TEST_SCRIPT = File.join(BUILD_DIR, "test", "all_tests.rb")

def test_files
  Dir.glob(File.join(ROOT, "test", "unit", "**", "*_test.rb")).sort
end

def shared_support_files
  %w[test_helpers fake_shell fake_io].map { |name| File.join(ROOT, "test", "support", "#{name}.rb") }
end

namespace :test do
  desc "Run the test suite on CRuby"
  task :cruby do
    sh "ruby", "-w", "-I", File.join(ROOT, "lib"), "-I", File.join(ROOT, "test"),
       File.join(ROOT, "test", "cruby_runner.rb")
  end

  desc "Run the test suite inside the mruby build"
  task mruby: "build:native" do
    mkdir_p File.dirname(MRUBY_TEST_SCRIPT)
    sources = shared_support_files + [File.join(ROOT, "test", "support", "mruby_setup.rb")] + test_files
    File.open(MRUBY_TEST_SCRIPT, "w") do |script|
      sources.each do |path|
        script.puts "# --- #{path.delete_prefix("#{ROOT}/")}"
        script.puts File.read(path)
      end
      script.puts File.read(File.join(ROOT, "test", "mruby_runner.rb"))
    end
    Dir.chdir(ROOT) { sh File.join(HOST_BIN_DIR, "mruby"), MRUBY_TEST_SCRIPT }
  end
end

desc "Run the test suite on CRuby and on mruby"
task test: ["test:cruby", "test:mruby"]

task default: "test:cruby"
