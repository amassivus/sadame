# frozen_string_literal: true

# Push-mode tests against real SSH servers in Docker (see lab.rb).
#
#   rake test:push          (needs Docker and dist/sadame-linux-ARCH)
#   KEEP_LAB=1 rake test:push   leaves the containers running afterwards
#
# Covers: -h user@host:2222, port: 2222 in hosts.rb, a ProxyJump host from
# a test-scoped ssh config passed with -F, vars precedence on the target,
# parallel runs with prefixed output, --forks and --serial, --tags, facts,
# the binary cache, sudo and --sudo, drift with --json, and an unreachable
# host.

require_relative "lab"

class PushTest
  LAB_RECIPE = "/sadame/test/integration/push/recipe"
  EXAMPLE = "/sadame/examples/08-multi-role-inventory"

  def initialize
    @lab = Lab::Environment.new
    @failures = []
    @count = 0
  end

  def run
    puts "starting the lab"
    @lab.up
    scenarios.each { |name| run_scenario(name) }
    report
  ensure
    @lab.down unless ENV["KEEP_LAB"]
  end

  private

  def scenarios
    %i[
      hosts_lists_the_inventory
      host_flag_with_user_and_port
      binary_is_copied_once
      port_from_hosts_rb
      proxy_jump_from_test_scoped_config
      vars_precedence_on_the_target
      sudo_is_needed_for_root_files
      parallel_run_of_a_multi_role_inventory
      drift_json_after_a_hand_edit
      forks_limit_runs_hosts_one_at_a_time
      serial_stops_after_a_failed_batch
      facts_of_every_host
      tags_reach_every_target
      unreachable_host
    ]
  end

  def hosts_lists_the_inventory
    status, output = sadame("hosts -g all", dir: EXAMPLE)
    expect_status(0, status, output)
    expect_includes(output, "db1.example.com\n  address   db1.example.com\n  user      deploy\n  port      2222\n")
  end

  def host_flag_with_user_and_port
    status, output = sadame("plan recipe.rb -h deploy@db1.example.com:2222")
    expect_status(0, status, output)
    expect_includes(output, "[db1.example.com] sadame #{version} plan on db1.example.com (Debian GNU/Linux 12 (bookworm))")
    expect_includes(output, "[db1.example.com] + file[/tmp/sadame-lab.txt]")
  end

  def binary_is_copied_once
    _status, first = sadame("apply recipe.rb -h deploy@web1.example.com")
    status, second = sadame("drift recipe.rb -h deploy@web1.example.com")
    expect_status(0, status, second)
    expect_includes(first + second, "[web1.example.com] copying #{@lab.binary} to ~/.sadame/bin/")
    expect_excludes(second, "copying")
  end

  def port_from_hosts_rb
    status, output = sadame("apply recipe.rb -g db")
    expect_status(0, status, output)
    expect_includes(output, "[db1.example.com] changed    file[/tmp/sadame-lab.txt]")
    status, output = sadame("drift recipe.rb -g db")
    expect_status(0, status, output)
  end

  def proxy_jump_from_test_scoped_config
    status, output = sadame("apply recipe.rb -g internal")
    expect_status(0, status, output)
    expect_includes(output, "[app1.internal] changed    file[/tmp/sadame-lab.txt]")
    expect_includes(@lab.target("app1", "cat /tmp/sadame-lab.txt"), "hello from the lab")
  end

  def vars_precedence_on_the_target
    status, output = sadame("apply recipe.rb -g db --var color=green")
    expect_status(0, status, output)
    # greeting from group all (over vars.rb), color from --var (over vars.rb).
    expect_equal("hello from the lab\ncolor: green\n", @lab.target("db1", "cat /tmp/sadame-lab.txt"))
  end

  def sudo_is_needed_for_root_files
    status, output = sadame("apply root.rb -h deploy@web2.example.com")
    expect_status(1, status, output)
    expect_includes(output, "web2.example.com  failed")
    status, output = sadame("apply root.rb -h deploy@web2.example.com --sudo")
    expect_status(0, status, output)
    expect_equal("managed by sadame on web2.example.com\n", @lab.target("web2", "cat /etc/sadame-lab.conf"))
    expect_equal("600 root\n", @lab.target("web2", "stat -c '%a %U' /etc/sadame-lab.conf"))
  end

  def parallel_run_of_a_multi_role_inventory
    status, output = sadame("apply site.rb -g all", dir: EXAMPLE)
    expect_status(0, status, output)
    %w[web1.example.com web2.example.com db1.example.com].each do |host|
      expect_includes(output, "[#{host}] Summary")
    end
    expect_includes(output, "apply on 3 hosts: 3 ok.")
    expect_includes(@lab.target("web2", "cat /etc/demo-app/web.conf"), "workers     = 8")
    expect_includes(@lab.target("web1", "cat /etc/demo-app/web.conf"), "workers     = 4")
    expect_equal("active\n", @lab.target("web1", "systemctl is-active nginx"))
    status, output = sadame("drift site.rb -g all", dir: EXAMPLE)
    expect_status(0, status, output)
  end

  def drift_json_after_a_hand_edit
    @lab.target("web1", "sed -i 's/workers     = 4/workers     = 32/' /etc/demo-app/web.conf")
    status, output = sadame("drift site.rb --limit 'web*' --json", dir: EXAMPLE)
    expect_status(1, status, output)
    expect_includes(output, "\"name\": \"web1.example.com\",\n      \"status\": \"drift\"")
    expect_includes(output, "\"name\": \"web2.example.com\",\n      \"status\": \"ok\"")
    expect_includes(output, "-workers     = 32\\n+workers     = 4")
    sadame("apply site.rb -h web1.example.com", dir: EXAMPLE)
  end

  # One host at a time: each host's lines come out together.
  def forks_limit_runs_hosts_one_at_a_time
    status, output = sadame("plan site.rb -g all --forks 1", dir: EXAMPLE)
    expect_status(0, status, output)
    lines = output.split("\n")
    names = %w[web1.example.com web2.example.com db1.example.com]
    blocks = names.map do |host|
      indexes = lines.each_index.select { |index| lines[index].start_with?("[#{host}]") }
      [indexes.min, indexes.max]
    end
    expect(blocks.each_cons(2).all? { |first, second| first[1] < second[0] }, "host output interleaved", output)
  end

  # web2 has a file where the recipe wants a directory: batch 2 fails, and
  # db1, alone in batch 3, is never contacted.
  def serial_stops_after_a_failed_batch
    @lab.target("web2", "rm -rf /etc/demo-app && touch /etc/demo-app")
    status, output = sadame("apply site.rb -g all --serial 1", dir: EXAMPLE)
    expect_status(1, status, output)
    expect_includes(output, "Batch 2 of 3: web2.example.com\n")
    expect_includes(output, "Stopped after batch 2 of 3: web2.example.com did not succeed; 1 host not run.")
    expect_includes(output, "db1.example.com   skipped      not run: batch 2 failed")
    expect_includes(output, "apply on 3 hosts: 1 ok, 1 failed, 1 skipped.")
    expect_excludes(output, "[db1.example.com]")
    @lab.target("web2", "rm -f /etc/demo-app")
    status, output = sadame("apply site.rb -g all --serial 1", dir: EXAMPLE)
    expect_status(0, status, output)
  end

  # facts runs no recipe; each target reads its own facts.
  def facts_of_every_host
    status, output = sadame("facts -g all", dir: EXAMPLE)
    expect_status(0, status, output)
    %w[web1.example.com web2.example.com db1.example.com].each do |host|
      expect_includes(output, "[#{host}] hostname           #{host.split(".").first}")
      expect_includes(output, "[#{host}] service_manager    systemd")
    end
    expect_includes(output, "facts on 3 hosts: 3 ok.")
    status, output = sadame("facts -h db1.example.com:2222 --json", dir: EXAMPLE)
    expect_status(0, status, output)
    expect_includes(output, "\"command\": \"facts\",")
    expect_includes(output, "\"container\": true,")
  end

  # Only the role tagged web runs; the base file is left out of the report.
  def tags_reach_every_target
    status, output = sadame("plan site.rb -g all --tags web", dir: EXAMPLE)
    expect_status(0, status, output)
    expect_includes(output, "[web1.example.com] Only resources tagged web: 5 of 6.")
    expect_includes(output, "[db1.example.com] Only resources tagged web: 0 of 6.")
    expect_excludes(output, "file[/etc/motd]")
  end

  def unreachable_host
    status, output = sadame("plan recipe.rb -h deploy@nowhere.example.com")
    expect_status(2, status, output)
    expect_includes(output, "nowhere.example.com  unreachable  connect failed: ssh: Could not resolve hostname")
  end

  def sadame(arguments, dir: LAB_RECIPE)
    @lab.controller("sadame #{arguments}", dir: dir)
  end

  def version
    @version ||= @lab.controller("sadame --version", dir: "/").last.split(" ").last
  end

  def run_scenario(name)
    @current = name
    print "#{name} ... "
    before = @failures.size
    send(name)
    puts @failures.size == before ? "ok" : "FAILED"
  end

  def expect_status(expected, actual, output)
    expect(actual == expected, "exit status #{actual}, expected #{expected}", output)
  end

  def expect_includes(text, part)
    expect(text.include?(part), "missing #{part.inspect}", text)
  end

  def expect_excludes(text, part)
    expect(!text.include?(part), "unexpected #{part.inspect}", text)
  end

  def expect_equal(expected, actual)
    expect(expected == actual, "expected #{expected.inspect}, got #{actual.inspect}", "")
  end

  def expect(condition, message, output)
    @count += 1
    return if condition

    @failures << "#{@current}: #{message}\n#{output}"
  end

  def report
    puts
    if @failures.empty?
      puts "#{@count} checks passed"
    else
      puts @failures.join("\n\n")
      puts "#{@failures.size} of #{@count} checks failed"
      exit 1
    end
  end
end

PushTest.new.run if $PROGRAM_NAME == __FILE__
