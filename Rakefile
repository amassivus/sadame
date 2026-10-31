# frozen_string_literal: true

# Development tasks. This file runs on CRuby only; the mruby subset rules
# apply to lib/, not to build tooling.

require "digest"

MRUBY_VERSION = "3.4.0"
ROOT = __dir__
MRUBY_DIR = File.join(ROOT, "vendor", "mruby-#{MRUBY_VERSION}")
BUILD_DIR = File.join(ROOT, "build")
HOST_BIN_DIR = File.join(BUILD_DIR, "host", "bin")
DIST_DIR = File.join(ROOT, "dist")

LINUX_PLATFORMS = { "amd64" => "linux/amd64", "arm64" => "linux/arm64" }.freeze

# Images every static Linux binary must run in, unmodified. archlinux has no
# official arm64 image.
VERIFY_IMAGES = {
  "amd64" => ["ubuntu:24.04", "debian:12", "rockylinux/rockylinux:9", "alpine:3.20", "archlinux:latest"],
  "arm64" => ["ubuntu:24.04", "debian:12", "rockylinux/rockylinux:9", "alpine:3.20"]
}.freeze

file MRUBY_DIR do
  mkdir_p File.dirname(MRUBY_DIR)
  sh "git", "-c", "advice.detachedHead=false", "clone", "--quiet", "--depth", "1",
     "--branch", MRUBY_VERSION, "https://github.com/mruby/mruby.git", MRUBY_DIR
end

def run_mruby_rake(target, build_dir)
  env = {
    "MRUBY_CONFIG" => File.join(ROOT, "build_config.rb"),
    "MRUBY_BUILD_DIR" => build_dir,
    "SADAME_TARGET" => target
  }
  Dir.chdir(MRUBY_DIR) { sh env, "rake", "all" }
end

# Builds inside an Alpine container of the target architecture, so the
# result is a static musl binary. Files are created as the calling user.
def build_linux(arch)
  platform = LINUX_PLATFORMS.fetch(arch)
  image = "sadame-builder-#{arch}"
  sh "docker", "build", "--quiet", "--platform", platform, "--tag", image,
     "--file", File.join(ROOT, "script", "build", "alpine.Dockerfile"), File.join(ROOT, "script", "build")

  build_dir = "/src/build/linux-#{arch}"
  binary = "/src/dist/sadame-linux-#{arch}"
  script = "rake all && mkdir -p /src/dist && strip -o #{binary} #{build_dir}/host/bin/sadame"
  sh "docker", "run", "--rm", "--platform", platform, "--user", "#{Process.uid}:#{Process.gid}",
     "--env", "HOME=/tmp", "--env", "MRUBY_CONFIG=/src/build_config.rb", "--env", "MRUBY_BUILD_DIR=#{build_dir}",
     "--env", "SADAME_TARGET=linux-static", "--volume", "#{ROOT}:/src",
     "--workdir", "/src/vendor/mruby-#{MRUBY_VERSION}", image, "sh", "-c", script
end

def build_macos(arch)
  target = "darwin-#{arch}"
  build_dir = File.join(BUILD_DIR, target)
  run_mruby_rake(target, build_dir)
  mkdir_p DIST_DIR
  sh "strip", "-o", File.join(DIST_DIR, "sadame-#{target}"), File.join(build_dir, target, "bin", "sadame")
end

namespace :build do
  desc "Build a development binary for this machine into build/host/bin/sadame"
  task native: MRUBY_DIR do
    run_mruby_rake("development", BUILD_DIR)
  end

  LINUX_PLATFORMS.each_key do |arch|
    desc "Build a static Linux #{arch} binary into dist/sadame-linux-#{arch} (needs Docker)"
    task "linux-#{arch}" => MRUBY_DIR do
      build_linux(arch)
    end
  end

  desc "Build macOS arm64 and amd64 binaries into dist/ (run on macOS)"
  task macos: MRUBY_DIR do
    build_macos("arm64")
    build_macos("amd64")
  end
end

namespace :verify do
  LINUX_PLATFORMS.each do |arch, platform|
    desc "Run dist/sadame-linux-#{arch} in #{VERIFY_IMAGES.fetch(arch).join(", ")} (needs Docker)"
    task "linux-#{arch}" do
      binary = "sadame-linux-#{arch}"
      VERIFY_IMAGES.fetch(arch).each do |image|
        puts "== #{binary} in #{image} (#{platform})"
        sh "docker", "run", "--rm", "--platform", platform,
           "--volume", "#{DIST_DIR}:/dist:ro", "--volume", "#{ROOT}/examples:/examples:ro",
           "--volume", "#{ROOT}/script/build/smoke-test.sh:/smoke-test.sh:ro",
           image, "sh", "/smoke-test.sh", "/dist/#{binary}", "/examples"
      end
    end
  end

  desc "Run the macOS binaries on this Mac (amd64 through Rosetta when it is installed)"
  task :macos do
    smoke_test = File.join(ROOT, "script", "build", "smoke-test.sh")
    sh smoke_test, File.join(DIST_DIR, "sadame-darwin-arm64"), File.join(ROOT, "examples")
    if system("arch", "-x86_64", "/usr/bin/true", out: File::NULL, err: File::NULL)
      sh "arch", "-x86_64", smoke_test, File.join(DIST_DIR, "sadame-darwin-amd64"), File.join(ROOT, "examples")
    else
      puts "Rosetta is not installed; skipping sadame-darwin-amd64"
    end
  end
end

desc "Write dist/SHA256SUMS for the binaries in dist/"
task :checksums do
  binaries = Dir.glob(File.join(DIST_DIR, "sadame-*")).sort
  abort "no binaries in dist/" if binaries.empty?

  lines = binaries.map { |path| "#{Digest::SHA256.file(path).hexdigest}  #{File.basename(path)}\n" }
  File.write(File.join(DIST_DIR, "SHA256SUMS"), lines.join)
  puts lines
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

namespace :docs do
  desc "Capture the terminal sessions shown in the docs (needs Docker); SCENARIO=name for one"
  task :transcripts do
    scenarios = ENV.fetch("SCENARIO", "").split(",")
    sh "ruby", File.join(ROOT, "script", "transcripts", "capture.rb"), *scenarios
  end
end

desc "Run the test suite on CRuby and on mruby"
task test: ["test:cruby", "test:mruby"]

task default: "test:cruby"
