# frozen_string_literal: true

class PushRunTest < SadameTest
  SUM = "e" * 64
  WORK = "/tmp/sadame-push-test"

  # Stands in for BinaryStore: every system gets the same fake binary.
  class FakeBinaryStore
    def find(os, arch)
      Sadame::Push::BinaryStore::LocalBinary.new("sadame-#{os}-#{arch}", "/dist/sadame-#{os}-#{arch}", SUM)
    end
  end

  def setup
    @shell = linux_shell
    @web = Sadame::Target.new("web1.example.com", vars: { role: "web" })
    @db = Sadame::Target.new("db1.example.com", user: "admin", port: 2222)
  end

  def ssh(target)
    Sadame::Push::SSH.new(target, control_dir: "#{WORK}/ssh")
  end

  def remote_script(target, arguments)
    invocation = ["\"$HOME/.sadame/bin/#{SUM}/sadame\"", "drift", "recipe.rb", "--vars-file", ".sadame-vars.rb",
                  "--host-name", target.name] + arguments
    "cd .sadame/run/r1 && tar -xzf bundle.tgz && rm -f bundle.tgz && #{invocation.join(" ")}; " \
      "status=$?; cd && rm -rf .sadame/run/r1; exit $status"
  end

  def push(targets, json: false, serial: nil, command: "drift")
    stdout = FakeIO.new
    clock_values = [10.0, 12.5]
    run = Sadame::Push::Run.new(
      targets: targets, command: command, recipe_path: "examples/01-hello/recipe.rb", shell: @shell, stdout: stdout,
      binary_store: FakeBinaryStore.new, parallel: Sadame::Push::Parallel.new(stdout, forking: false),
      json: json, serial: serial, clock: -> { clock_values.shift }, work_dir: WORK, run_id: "r1"
    )
    [run.call, stdout.string]
  end

  def fleet(count)
    (1..count).map { |number| Sadame::Target.new("web#{number}.example.com") }
  end

  # Every target answers uname; the ones in failing exit 1 from apply.
  def stub_fleet(targets, failing: [])
    targets.each do |target|
      @shell.on(ssh(target).ssh("uname -sm"), stdout: "Linux x86_64\n")
      script = remote_script(target, []).sub(" drift ", " apply ")
      @shell.on(ssh(target).ssh(script), exit_status: failing.include?(target) ? 1 : 0)
    end
  end

  def applied_hosts
    @shell.commands.select { |command| command.include?("tar -xzf bundle.tgz") }
          .map { |command| command.split("--host-name ")[1].split(";").first }
  end

  def test_runs_on_each_target_and_summarizes
    @shell.on(ssh(@web).ssh("uname -sm"), stdout: "Linux x86_64\n")
    @shell.on(ssh(@web).ssh(remote_script(@web, [])), stdout: "Drift: 1 of 1 resource differs from the recipe.\n",
                                                     exit_status: 1)
    @shell.on(ssh(@db).ssh("uname -sm"), stderr: "ssh: connect to host db1.example.com port 2222: Connection refused\n",
                                         exit_status: 255)
    status, output = push([@web, @db])
    assert_equal 2, status
    assert_includes output, "[web1.example.com] Drift: 1 of 1 resource differs from the recipe.\n"
    expected = <<~TEXT

      Hosts
        web1.example.com  drift
        db1.example.com   unreachable  connect failed: ssh: connect to host db1.example.com port 2222: Connection refused

      drift on 2 hosts: 1 drift, 1 unreachable. Finished in 2.50s.
    TEXT
    assert output.end_with?(expected), output
  end

  def test_bundles_the_recipe_without_files_evaluated_locally_and_cleans_up
    @shell.on(ssh(@web).ssh("uname -sm"), stdout: "Linux x86_64\n")
    push([@web])
    stage = "#{WORK}/recipe"
    assert_includes @shell.commands, "mkdir -p #{stage} && cp -R examples/01-hello/. #{stage}/ && " \
                                     "rm -rf #{stage}/.git #{stage}/vars.rb #{stage}/hosts.rb"
    assert_includes @shell.commands, "tar -czf #{WORK}/bundle.tgz -C #{stage} ."
    assert_equal "{ :role => \"web\" }\n", @shell.files["#{WORK}/vars-0.rb"]
    assert_equal "rm -rf #{WORK}", @shell.commands.last
    assert_includes @shell.commands, "#{ssh(@web).close} 2>/dev/null"
  end

  def test_json_combines_the_reports
    @shell.on(ssh(@web).ssh("uname -sm"), stdout: "Linux x86_64\n")
    report = "{\n  \"command\": \"drift\",\n  \"drift\": false\n}\n"
    @shell.on(ssh(@web).ssh(remote_script(@web, ["--json"])), stdout: report)
    status, output = push([@web], json: true)
    assert_equal 0, status
    expected = <<~JSON
      {
        "format_version": 1,
        "sadame_version": "#{Sadame::VERSION}",
        "command": "drift",
        "hosts": [
          {
            "name": "web1.example.com",
            "status": "ok",
            "exit_status": 0,
            "error": null,
            "report": {
              "command": "drift",
              "drift": false
            }
          }
        ],
        "exit_status": 0,
        "duration_seconds": 2.5
      }
    JSON
    assert_equal expected, output
  end

  def test_serial_runs_batches_in_order
    targets = fleet(5)
    stub_fleet(targets)
    status, output = push(targets, serial: 2, command: "apply")
    assert_equal 0, status
    assert_equal targets.map { |target| target.name }, applied_hosts
    assert output.start_with?("Batch 1 of 3: web1.example.com, web2.example.com\n"), output
    assert_includes output, "\nBatch 2 of 3: web3.example.com, web4.example.com\n"
    assert_includes output, "\nBatch 3 of 3: web5.example.com\n"
    assert_includes output, "apply on 5 hosts: 5 ok."
  end

  def test_serial_stops_after_a_failed_batch
    targets = fleet(4)
    stub_fleet(targets, failing: [targets[1]])
    status, output = push(targets, serial: 2, command: "apply")
    assert_equal 1, status
    assert_equal ["web1.example.com", "web2.example.com"], applied_hosts
    assert_includes output, "\nStopped after batch 1 of 2: web2.example.com did not succeed; 2 hosts not run.\n"
    assert_includes output, "  web3.example.com  skipped      not run: batch 1 failed\n"
    assert_includes output, "apply on 4 hosts: 1 ok, 1 failed, 2 skipped."
  end

  def test_serial_by_percentage_and_drift_does_not_stop
    targets = fleet(4)
    targets.each do |target|
      @shell.on(ssh(target).ssh("uname -sm"), stdout: "Linux x86_64\n")
      @shell.on(ssh(target).ssh(remote_script(target, [])), exit_status: 1)
    end
    status, output = push(targets, serial: "50%")
    assert_equal 1, status
    assert_includes output, "Batch 2 of 2: web3.example.com, web4.example.com"
    assert_includes output, "drift on 4 hosts: 4 drift."
  end

  def test_skipped_hosts_in_json_have_no_exit_status
    targets = fleet(2)
    @shell.on(ssh(targets[0]).ssh("uname -sm"), stderr: "ssh: Could not resolve hostname\n", exit_status: 255)
    status, output = push(targets, serial: 1, json: true)
    assert_equal 2, status
    refute_includes output, "Batch"
    assert_includes output, "\"status\": \"skipped\",\n      \"exit_status\": null,\n" \
                            "      \"error\": \"not run: batch 1 failed\""
  end

  def test_facts_run_without_a_recipe
    @shell.on(ssh(@web).ssh("uname -sm"), stdout: "Linux x86_64\n")
    script = "cd .sadame/run/r1 && tar -xzf bundle.tgz && rm -f bundle.tgz && " \
             "\"$HOME/.sadame/bin/#{SUM}/sadame\" facts --host-name web1.example.com; " \
             "status=$?; cd && rm -rf .sadame/run/r1; exit $status"
    @shell.on(ssh(@web).ssh(script), stdout: "cpus               4\n")
    stdout = FakeIO.new
    status = Sadame::Push::Run.new(
      targets: [@web], command: "facts", recipe_path: nil, shell: @shell, stdout: stdout,
      binary_store: FakeBinaryStore.new, parallel: Sadame::Push::Parallel.new(stdout, forking: false),
      work_dir: WORK, run_id: "r1"
    ).call
    assert_equal 0, status
    assert_includes stdout.string, "[web1.example.com] cpus               4\n"
    assert_includes stdout.string, "facts on 1 host: 1 ok."
    assert_includes @shell.commands, "mkdir -p #{WORK}/recipe"
    assert_includes @shell.commands, "tar -czf #{WORK}/bundle.tgz -C #{WORK}/recipe ."
  end

  def test_tags_are_passed_to_each_target
    @shell.on(ssh(@web).ssh("uname -sm"), stdout: "Linux x86_64\n")
    stdout = FakeIO.new
    Sadame::Push::Run.new(
      targets: [@web], command: "drift", recipe_path: "examples/01-hello/recipe.rb", shell: @shell, stdout: stdout,
      binary_store: FakeBinaryStore.new, parallel: Sadame::Push::Parallel.new(stdout, forking: false),
      arguments: ["--tags", "web,db"], work_dir: WORK, run_id: "r1"
    ).call
    assert_includes @shell.commands, ssh(@web).ssh(remote_script(@web, ["--tags", "web,db"]))
  end

  def test_a_missing_binary_fails_only_that_platform
    store = Object.new
    def store.find(os, arch)
      raise Sadame::Error, "no sadame-#{os}-#{arch} here" if arch == "arm64"

      Sadame::Push::BinaryStore::LocalBinary.new("sadame-#{os}-#{arch}", "/dist/x", SUM)
    end
    @shell.on(ssh(@web).ssh("uname -sm"), stdout: "Linux x86_64\n")
    @shell.on(ssh(@db).ssh("uname -sm"), stdout: "Linux aarch64\n")
    stdout = FakeIO.new
    status = Sadame::Push::Run.new(
      targets: [@web, @db], command: "apply", recipe_path: "examples/01-hello/recipe.rb", shell: @shell,
      stdout: stdout, binary_store: store, parallel: Sadame::Push::Parallel.new(stdout, forking: false),
      work_dir: WORK, run_id: "r1"
    ).call
    assert_equal 2, status
    assert_includes stdout.string, "db1.example.com   error        no sadame-linux-arm64 here"
    assert_includes stdout.string, "web1.example.com  ok"
  end
end
