# frozen_string_literal: true

class PushParallelTest < SadameTest
  def run_jobs(forking)
    io = FakeIO.new
    parallel = Sadame::Push::Parallel.new(io, forking: forking)
    results = parallel.map(["web1", "web2", "db1"], label: ->(name) { name }) do |name, print|
      print.call("starting\n")
      print.call("done with #{name}")
      { "name" => name, "count" => name.size, "ok" => true }
    end
    [results, io.string]
  end

  def test_runs_jobs_in_child_processes
    results, output = run_jobs(true)
    assert_equal ["web1", "web2", "db1"], results.map { |result| result["name"] }
    assert_equal [4, 4, 3], results.map { |result| result["count"] }
    ["[web1] starting", "[web1] done with web1", "[web2] done with web2", "[db1] done with db1"].each do |line|
      assert_includes output.split("\n"), line
    end
  end

  def test_runs_jobs_in_order_without_forking
    results, output = run_jobs(false)
    assert_equal ["web1", "web2", "db1"], results.map { |result| result["name"] }
    assert_equal "[web1] starting\n[web1] done with web1\n[web2] starting\n", output[0, 54]
  end

  # With one job at a time, each job's lines come out together and in
  # order, whatever the timing.
  def test_a_limit_of_one_runs_jobs_one_after_another
    io = FakeIO.new
    names = ["web1", "web2", "web3", "db1"]
    results = Sadame::Push::Parallel.new(io, forking: true).map(names, label: ->(name) { name }, limit: 1) do |name, print|
      3.times { |step| print.call("#{name} step #{step}") }
      { "name" => name }
    end
    assert_equal names, results.map { |result| result["name"] }
    expected = names.map { |name| (0..2).map { |step| "[#{name}] #{name} step #{step}\n" }.join }.join
    assert_equal expected, io.string
  end

  def test_a_limit_keeps_results_in_the_order_of_items
    names = ["web1", "web2", "web3", "web4", "db1"]
    results = Sadame::Push::Parallel.new(FakeIO.new, forking: true).map(names, label: ->(name) { name }, limit: 2) do |name, _print|
      { "name" => name }
    end
    assert_equal names, results.map { |result| result["name"] }
  end

  def test_a_failing_job_reports_an_error
    parallel = Sadame::Push::Parallel.new(FakeIO.new, forking: true)
    results = parallel.map(["boom"], label: ->(name) { name }) { |_name, _print| raise ArgumentError, "broken" }
    assert_equal "error", results.first["status"]
    assert_includes results.first["error"], "broken"
  end

  def test_colored_prefixes
    io = FakeIO.new
    Sadame::Push::Parallel.new(io, color: true, forking: false).map(["web1"], label: ->(name) { name }) do |_name, print|
      print.call("hello")
    end
    assert_equal "\e[36m[web1]\e[0m hello\n", io.string
  end
end
