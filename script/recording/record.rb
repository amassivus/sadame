# frozen_string_literal: true

# Records docs/assets/demo.gif from demo.tape with vhs, against the push lab
# (test/integration/push/lab.rb): the same SSH targets the docs
# transcripts use. Run with `rake docs:recording`; needs Docker.
#
# Development tooling: CRuby only.

require "fileutils"
require "open3"
require "tmpdir"
require_relative "../../test/integration/push/lab"

module Recording
  ROOT = File.expand_path("../..", __dir__)
  IMAGE = "sadame-recorder"
  CONTAINER = "sadame-lab-recorder"
  EXAMPLE_08 = "/sadame/examples/08-multi-role-inventory"

  module_function

  def main
    lab = Lab::Environment.new
    puts "starting the SSH lab"
    lab.up
    # db1 as after a first rollout, with backup_hour 3.
    lab.controller("sadame apply site.rb -g db", dir: EXAMPLE_08)
    Dir.mktmpdir("sadame-recording") do |output|
      start_recorder(lab, output)
      puts "recording"
      run!("docker", "exec", CONTAINER, "vhs", "/sadame/script/recording/demo.tape")
      FileUtils.cp(File.join(output, "demo.gif"), File.join(ROOT, "docs", "assets", "demo.gif"))
      puts "docs/assets/demo.gif"
    end
  ensure
    system("docker", "rm", "--force", CONTAINER, out: File::NULL, err: File::NULL)
    lab&.down
  end

  def start_recorder(lab, output)
    run!("docker", "build", "--quiet", "--tag", IMAGE, "--file", File.join(__dir__, "recorder.Dockerfile"), __dir__)
    run!("docker", "run", "--detach", "--name", CONTAINER, "--network", Lab::NETWORK,
         "--volume", "#{ROOT}:/sadame:ro", "--volume", "#{output}:/out",
         "--entrypoint", "sleep", IMAGE, "infinity")
    # The controller's SSH key and configuration, which the targets trust.
    run!("sh", "-c", "docker cp #{Lab::PREFIX}-controller:/root/.ssh - | docker cp - #{CONTAINER}:/root/")
    setup = <<~SCRIPT
      ln -s /sadame/dist/#{lab.binary} /usr/local/bin/sadame
      cp -r #{EXAMPLE_08} /tmp/fleet
      sed -i 's/backup_hour: 3/backup_hour: 4/' /tmp/fleet/hosts.rb
    SCRIPT
    run!("docker", "exec", CONTAINER, "sh", "-c", setup)
  end

  def run!(*command)
    output, status = Open3.capture2e(*command)
    abort "#{command.join(" ")} failed:\n#{output}" unless status.success?

    output
  end
end

Recording.main if $PROGRAM_NAME == __FILE__
