# frozen_string_literal: true

# Captures real terminal output for the documentation (needs Docker and the
# static binaries: rake build:linux-amd64 build:linux-arm64). Each scenario
# in scenarios.rb runs in a fresh container with this checkout mounted
# read-only at /sadame and the release binary for the container's
# architecture installed as /usr/local/bin/sadame. Saved steps are written
# to docs/transcripts/NAME.txt, which the docs embed with --8<--.
#
#   ruby script/transcripts/capture.rb                 # every scenario
#   ruby script/transcripts/capture.rb notifications   # one scenario
#
# This is development tooling and runs on CRuby only.

require "open3"
require_relative "scenarios"

module Transcripts
  ROOT = File.expand_path("../..", __dir__)
  OUTPUT_DIR = File.join(ROOT, "docs", "transcripts")

  # The images that boot a service manager run natively: systemd does not
  # boot under every emulator. The others are amd64, the most common server
  # architecture.
  IMAGES = {
    "debian" => { platform: "linux/amd64", init: nil },
    "debian-systemd" => { platform: nil, init: :systemd },
    "arch" => { platform: "linux/amd64", init: nil },
    "arch-systemd" => { platform: nil, init: :systemd,
                        base: { "amd64" => "archlinux:latest", "arm64" => "menci/archlinuxarm:latest" } },
    "alpine-openrc" => { platform: nil, init: :openrc }
  }.freeze

  module_function

  BINARIES = %w[sadame-linux-amd64 sadame-linux-arm64].freeze

  def main(names)
    scenarios = names.empty? ? SCENARIOS : SCENARIOS.select { |scenario| names.include?(scenario[:name]) }
    lab_scenarios = names.empty? ? LAB_SCENARIOS : LAB_SCENARIOS.select { |scenario| names.include?(scenario[:name]) }
    abort "unknown scenario: #{names.join(", ")}" if scenarios.empty? && lab_scenarios.empty?
    missing = BINARIES.reject { |binary| File.exist?(File.join(ROOT, "dist", binary)) }
    abort "missing dist/#{missing.join(", dist/")}; run rake build:linux-amd64 build:linux-arm64" unless missing.empty?

    scenarios.map { |scenario| scenario[:image] }.uniq.each { |image| build_image(image) }
    scenarios.each { |scenario| capture(scenario) }
    capture_lab(lab_scenarios) unless lab_scenarios.empty?
  end

  def capture_lab(scenarios)
    require_relative "../../test/integration/push/lab"
    lab = Lab::Environment.new
    puts "starting the SSH lab"
    lab.up
    scenarios.each do |scenario|
      puts "scenario #{scenario[:name]}"
      scenario[:steps].each do |step|
        if step[:target]
          step[:commands].each { |command| lab.target(step[:target], command) }
          next
        end
        if step[:controller]
          step[:commands].each { |command| lab.controller(command, dir: "/") }
          next
        end
        output = lab.controller_session(step[:commands], dir: step[:dir])
        write(step[:save], output) if step[:save]
      end
    end
  ensure
    lab&.down
  end

  def write(name, output)
    File.write(File.join(OUTPUT_DIR, "#{name}.txt"), output)
    puts "  docs/transcripts/#{name}.txt"
  end

  def tag(image)
    "sadame-transcripts-#{image}"
  end

  def build_image(image)
    puts "building #{tag(image)}"
    command = ["docker", "build", "--quiet", "-t", tag(image), "-f", File.join(__dir__, "#{image}.Dockerfile")]
    settings = IMAGES.fetch(image)
    command += ["--platform", settings[:platform]] if settings[:platform]
    command += ["--build-arg", "BASE=#{settings[:base].fetch(native_arch)}"] if settings[:base]
    system(*command, __dir__, out: File::NULL, exception: true)
  end

  def native_arch
    machine, = Open3.capture2("docker", "info", "--format", "{{.Architecture}}")
    %w[aarch64 arm64].include?(machine.strip) ? "arm64" : "amd64"
  end

  def capture(scenario)
    puts "scenario #{scenario[:name]}"
    container = "sadame-transcripts-#{scenario[:name]}"
    remove(container)
    start(container, scenario[:image])
    scenario[:steps].each { |step| run_step(container, step) }
  ensure
    remove(container)
  end

  def start(container, image)
    settings = IMAGES.fetch(image)
    command = ["docker", "run", "--detach", "--name", container, "--volume", "#{ROOT}:/sadame:ro", "--workdir", "/sadame"]
    command += ["--platform", settings[:platform]] if settings[:platform]
    if settings[:init]
      command += ["--privileged", "--cgroupns=host", "--volume", "/sys/fs/cgroup:/sys/fs/cgroup:rw", tag(image)]
    else
      command += [tag(image), "sleep", "infinity"]
    end
    system(*command, out: File::NULL, exception: true)
    install_binary(container)
    case settings[:init]
    when :systemd
      system("docker", "exec", container, "systemctl", "is-system-running", "--wait", out: File::NULL, err: File::NULL)
    when :openrc
      wait_for_openrc(container)
    end
  end

  # OpenRC writes the runlevel it reached to /run/openrc/softlevel.
  def wait_for_openrc(container)
    60.times do
      level, = Open3.capture2("docker", "exec", container, "cat", "/run/openrc/softlevel", err: File::NULL)
      return if level.strip == "default"

      sleep 1
    end
    abort "OpenRC did not reach the default runlevel in #{container}"
  end

  def install_binary(container)
    script = 'case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; esac; ' \
             'ln -s "/sadame/dist/sadame-linux-$arch" /usr/local/bin/sadame'
    system("docker", "exec", container, "sh", "-c", script, exception: true)
  end

  def run_step(container, step)
    script = "#{step[:commands].join("\n")}\n"
    user = step[:user] ? ["--user", step[:user]] : []
    output, = Open3.capture2e("docker", "exec", "--interactive", *user, "--workdir", step[:dir] || "/sadame", container,
                              "sh", "/sadame/script/transcripts/session.sh", stdin_data: script)
    write(step[:save], output) if step[:save]
  end

  def remove(container)
    system("docker", "rm", "--force", container, out: File::NULL, err: File::NULL)
  end
end

Transcripts.main(ARGV) if $PROGRAM_NAME == __FILE__
