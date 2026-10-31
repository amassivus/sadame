# frozen_string_literal: true

# Captures real terminal output for the documentation (needs Docker).
# Each scenario in scenarios.rb runs in a fresh container with this checkout
# mounted read-only at /sadame. Saved steps are written to
# docs/transcripts/NAME.txt, which the docs embed with --8<--.
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

  # The systemd image runs natively: systemd does not boot under every
  # emulator. The others are amd64, the most common server architecture.
  IMAGES = {
    "debian" => { platform: "linux/amd64", systemd: false },
    "debian-systemd" => { platform: nil, systemd: true },
    "arch" => { platform: "linux/amd64", systemd: false }
  }.freeze

  module_function

  def main(names)
    scenarios = names.empty? ? SCENARIOS : SCENARIOS.select { |scenario| names.include?(scenario[:name]) }
    abort "unknown scenario: #{names.join(", ")}" if scenarios.empty?

    scenarios.map { |scenario| scenario[:image] }.uniq.each { |image| build_image(image) }
    scenarios.each { |scenario| capture(scenario) }
  end

  def tag(image)
    "sadame-transcripts-#{image}"
  end

  def build_image(image)
    puts "building #{tag(image)}"
    command = ["docker", "build", "--quiet", "-t", tag(image), "-f", File.join(__dir__, "#{image}.Dockerfile")]
    command += ["--platform", IMAGES.fetch(image)[:platform]] if IMAGES.fetch(image)[:platform]
    system(*command, __dir__, out: File::NULL, exception: true)
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
    if settings[:systemd]
      command += ["--privileged", "--cgroupns=host", "--volume", "/sys/fs/cgroup:/sys/fs/cgroup:rw", tag(image)]
    else
      command += [tag(image), "sleep", "infinity"]
    end
    system(*command, out: File::NULL, exception: true)
    return unless settings[:systemd]

    system("docker", "exec", container, "systemctl", "is-system-running", "--wait", out: File::NULL, err: File::NULL)
  end

  def run_step(container, step)
    script = "#{step[:commands].join("\n")}\n"
    output, = Open3.capture2e("docker", "exec", "--interactive", "--workdir", step[:dir] || "/sadame", container,
                              "sh", "/sadame/script/transcripts/session.sh", stdin_data: script)
    return unless step[:save]

    File.write(File.join(OUTPUT_DIR, "#{step[:save]}.txt"), output)
    puts "  docs/transcripts/#{step[:save]}.txt"
  end

  def remove(container)
    system("docker", "rm", "--force", container, out: File::NULL, err: File::NULL)
  end
end

Transcripts.main(ARGV) if $PROGRAM_NAME == __FILE__
