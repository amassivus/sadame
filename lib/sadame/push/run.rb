# frozen_string_literal: true

module Sadame
  module Push
    # Runs plan, apply or drift on several targets over SSH and combines
    # the results:
    #
    # 1. bundle the recipe's directory (without .git, vars.rb and hosts.rb,
    #    which are evaluated here) and write each target's vars;
    # 2. detect every target's system, in parallel;
    # 3. find the sadame binary for each system needed;
    # 4. run sadame on every reachable target, in parallel, printing its
    #    output prefixed with the target's name;
    # 5. print a summary, or one JSON document with every target's report.
    #
    # The exit status is the highest of the targets' statuses; a target that
    # could not be reached or prepared counts as 2.
    class Run
      STATUS_LABELS = { 0 => "ok", 2 => "error" }.freeze
      BUNDLE_EXCLUDES = [".git", "vars.rb", "hosts.rb"].freeze

      # work_dir and run_id are generated unless given (tests give them).
      def initialize(targets:, command:, recipe_path:, shell:, stdout:, binary_store:, parallel:,
                     json: false, color: false, clock: nil, work_dir: nil, run_id: nil)
        @targets = targets
        @command = command
        @recipe_path = recipe_path
        @shell = shell
        @stdout = stdout
        @binary_store = binary_store
        @parallel = parallel
        @json = json
        @color = color
        @clock = clock || -> { Time.now }
        @work_dir = work_dir || "/tmp/sadame-push-#{Process.pid}-#{Time.now.to_i}"
        @run_id = run_id || "#{Time.now.to_i}-#{Process.pid}"
      end

      def call
        started = @clock.call
        work_dir = make_work_dir
        bundle = build_bundle(work_dir)
        vars_files = write_vars(work_dir)
        control_dir = File.join(work_dir, "ssh")
        @shell.run!("mkdir -p #{Shell.escape(control_dir)} && chmod 0700 #{Shell.escape(control_dir)}")

        results = execute(bundle, vars_files, control_dir)
        close_connections(control_dir)
        report(results, @clock.call - started)
      ensure
        @shell.run("rm -rf #{Shell.escape(work_dir)}") if work_dir
      end

      private

      def execute(bundle, vars_files, control_dir)
        platforms = @parallel.map(@targets, label: ->(target) { target.name }) do |target, _print|
          detect(target, control_dir)
        end

        binaries = resolve_binaries(platforms)
        jobs = []
        @targets.each_with_index { |target, index| jobs << [target, index] }
        @parallel.map(jobs, label: ->(job) { job[0].name }) do |job, print|
          target, index = job
          early = platforms[index]["error"] ? platforms[index] : binaries[index]
          next early if early

          run_target(target, binaries_for(platforms[index]), bundle, vars_files[index], control_dir, print)
        end
      end

      def detect(target, control_dir)
        os, arch = Session.new(target, shell: @shell, ssh: SSH.new(target, control_dir: control_dir)).detect_platform
        { "os" => os, "arch" => arch, "error" => nil }
      rescue Failure => e
        failure_result(e.kind, e.message)
      end

      # Looks up each needed binary once. Returns, per target, nil or the
      # failure result when no binary could be found for its system.
      def resolve_binaries(platforms)
        @found = {}
        platforms.map do |platform|
          next nil if platform["error"]

          key = "#{platform["os"]}-#{platform["arch"]}"
          @found[key] ||= find_binary(platform)
          @found[key].is_a?(Hash) ? @found[key] : nil
        end
      end

      def find_binary(platform)
        @binary_store.find(platform["os"], platform["arch"])
      rescue Error => e
        failure_result(:error, e.message)
      end

      def binaries_for(platform)
        @found["#{platform["os"]}-#{platform["arch"]}"]
      end

      def run_target(target, binary, bundle, vars_file, control_dir, print)
        session = Session.new(target, shell: @shell, ssh: SSH.new(target, control_dir: control_dir))
        arguments = []
        arguments << "--json" if @json
        arguments << "--color" if @color && !@json
        status, stdout, stderr = session.run(command: @command, binary: binary, bundle: bundle, vars_file: vars_file,
                                             recipe: File.basename(@recipe_path), run_id: @run_id,
                                             arguments: arguments, capture: @json) { |line| print.call(line) }
        result_for(status, stdout, stderr)
      rescue Failure => e
        failure_result(e.kind, e.message)
      end

      def result_for(status, stdout, stderr)
        report = @json && !stdout.strip.empty? ? stdout : nil
        error = nil
        if status == 255
          error = "the connection was lost while sadame ran"
        elsif status > 1
          error = stderr.strip.empty? ? nil : stderr.strip.split("\n").last
        end
        { "status" => label_for(status), "exit_status" => status > 2 ? 2 : status, "error" => error,
          "report" => report }
      end

      def label_for(status)
        return STATUS_LABELS.fetch(status) if STATUS_LABELS.key?(status)
        return (@command == "drift" ? "drift" : "failed") if status == 1

        "error"
      end

      def failure_result(kind, message)
        { "status" => kind.to_s, "exit_status" => 2, "error" => message, "report" => nil }
      end

      # Under /tmp rather than $TMPDIR by default: the SSH control sockets
      # live inside, and socket paths are limited to about 100 characters.
      def make_work_dir
        @shell.run!("mkdir -p #{Shell.escape(@work_dir)} && chmod 0700 #{Shell.escape(@work_dir)}")
        @work_dir
      end

      # Copies the recipe's directory without the files that are evaluated
      # here, and packs it with tar options every tar supports.
      def build_bundle(work_dir)
        stage = File.join(work_dir, "recipe")
        source = File.dirname(@recipe_path)
        removals = BUNDLE_EXCLUDES.map { |name| Shell.escape(File.join(stage, name)) }.join(" ")
        @shell.run!("mkdir -p #{Shell.escape(stage)} && cp -R #{Shell.escape(source)}/. #{Shell.escape(stage)}/ && " \
                    "rm -rf #{removals}")
        bundle = File.join(work_dir, "bundle.tgz")
        @shell.run!("tar -czf #{Shell.escape(bundle)} -C #{Shell.escape(stage)} .")
        bundle
      end

      def write_vars(work_dir)
        paths = []
        @targets.each_with_index do |target, index|
          path = File.join(work_dir, "vars-#{index}.rb")
          @shell.write_file(path, "#{RubyLiteral.dump(target.vars)}\n")
          paths << path
        end
        paths
      end

      def close_connections(control_dir)
        @targets.each do |target|
          command = SSH.new(target, control_dir: control_dir).close
          @shell.run("#{command} 2>/dev/null") if command
        end
      end

      def report(results, duration)
        if @json
          @stdout.write(JsonWriter.generate(json_document(results, duration)))
        else
          print_summary(results, duration)
        end
        results.map { |result| result["exit_status"] }.max || 0
      end

      def json_document(results, duration)
        hosts = []
        @targets.each_with_index do |target, index|
          result = results[index]
          report = result["report"] ? JsonWriter::Raw.new(result["report"]) : nil
          hosts << { name: target.name, status: result["status"], exit_status: result["exit_status"],
                     error: result["error"], report: report }
        end
        {
          format_version: Report::FORMAT_VERSION,
          sadame_version: VERSION,
          command: @command,
          hosts: hosts,
          exit_status: results.map { |result| result["exit_status"] }.max || 0,
          duration_seconds: (duration * 100).round / 100.0
        }
      end

      def print_summary(results, duration)
        width = @targets.map { |target| target.name.size }.max + 2
        @stdout.write("\nHosts\n")
        @targets.each_with_index do |target, index|
          result = results[index]
          line = "  #{target.name.ljust(width)}#{paint(result["status"].ljust(13), result["status"])}"
          line += result["error"].to_s if result["error"]
          @stdout.write("#{line.rstrip}\n")
        end
        counts = Hash.new(0)
        results.each { |result| counts[result["status"]] += 1 }
        parts = counts.map { |status, count| "#{count} #{status}" }
        noun = @targets.size == 1 ? "host" : "hosts"
        @stdout.write("\n#{@command} on #{@targets.size} #{noun}: #{parts.join(", ")}. " \
                      "Finished in #{format("%.2f", duration.to_f)}s.\n")
      end

      def paint(text, status)
        return text unless @color

        code = status == "ok" ? 32 : (status == "drift" ? 33 : 31)
        "\e[#{code}m#{text}\e[0m"
      end
    end
  end
end
