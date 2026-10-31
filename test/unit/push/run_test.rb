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

  def push(targets, json: false)
    stdout = FakeIO.new
    clock_values = [10.0, 12.5]
    run = Sadame::Push::Run.new(
      targets: targets, command: "drift", recipe_path: "examples/01-hello/recipe.rb", shell: @shell, stdout: stdout,
      binary_store: FakeBinaryStore.new, parallel: Sadame::Push::Parallel.new(stdout, forking: false),
      json: json, clock: -> { clock_values.shift }, work_dir: WORK, run_id: "r1"
    )
    [run.call, stdout.string]
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
