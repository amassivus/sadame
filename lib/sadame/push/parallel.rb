# frozen_string_literal: true

module Sadame
  module Push
    # Runs one job per target at the same time, or at most limit at a
    # time, and prints their output as it arrives, each line prefixed with
    # "[target] ".
    #
    # mruby has no threads, so each job runs in a child process (fork). The
    # child sends its output lines and, at the end, its result through a
    # pipe; the parent reads all pipes with IO.select. Every message is one
    # line: "O" plus an output line, or "R" plus the result written with
    # RubyLiteral. Results must therefore be made of strings, numbers,
    # booleans, nil, arrays and hashes.
    #
    # With forking: false, jobs run one after another in this process,
    # which tests use.
    class Parallel
      COLOR_PREFIX = "\e[36m"
      COLOR_RESET = "\e[0m"

      def initialize(io, color: false, forking: true)
        @io = io
        @color = color
        @forking = forking
      end

      # Yields each item and a callable that prints one line for it.
      # Returns the block's results in the order of items. With limit, at
      # most that many jobs run at once; the next one starts as soon as one
      # ends.
      def map(items, label:, limit: nil, &job)
        return items.map { |item| job.call(item, printer(label.call(item))) } unless @forking

        children = []
        collect(items.dup, children, limit || items.size, label, job)
        children.map { |child| child[:result] }
      end

      private

      def printer(name)
        prefix = @color ? "#{COLOR_PREFIX}[#{name}]#{COLOR_RESET} " : "[#{name}] "
        ->(line) { @io.write("#{line.chomp.empty? ? prefix.rstrip : prefix + line.chomp}\n") }
      end

      def start(item, name, job)
        # Output still buffered here would be written again by the child.
        @io.flush if @io.respond_to?(:flush)
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          emit = ->(line) { writer.write("O#{line.chomp}\n") }
          result = run_job(job, item, emit)
          writer.write("R#{RubyLiteral.dump(result)}\n")
          writer.close
          exit!(0)
        end
        writer.close
        { pid: pid, reader: reader, buffer: String.new, print: printer(name), result: nil, open: true }
      end

      # A job that raises still reports something the parent can show.
      def run_job(job, item, emit)
        job.call(item, emit)
      rescue StandardError => e
        { "status" => "error", "exit_status" => 2, "error" => "#{e.class}: #{e.message}" }
      end

      # Starts jobs from pending while fewer than limit run, and reads the
      # output of the running ones, until every job has ended. Children are
      # added in the order of their items.
      def collect(pending, children, limit, label, job)
        loop do
          running = children.select { |child| child[:open] }
          while running.size < limit && !pending.empty?
            item = pending.shift
            child = start(item, label.call(item), job)
            children << child
            running << child
          end
          break if running.empty?

          ready = IO.select(running.map { |child| child[:reader] })[0]
          ready.each do |reader|
            child = running.find { |candidate| candidate[:reader] == reader }
            chunk = read_chunk(reader)
            chunk.nil? ? finish(child) : consume(child, chunk)
          end
        end
      end

      # mruby returns nil at the end of a pipe, CRuby raises EOFError.
      def read_chunk(reader)
        reader.sysread(4096)
      rescue EOFError
        nil
      end

      def consume(child, chunk)
        child[:buffer] << chunk
        while (index = child[:buffer].index("\n"))
          message = child[:buffer][0...index]
          child[:buffer] = child[:buffer][(index + 1)..]
          handle(child, message)
        end
      end

      def handle(child, message)
        if message.start_with?("O")
          child[:print].call(message[1..])
        elsif message.start_with?("R")
          child[:result] = ResultReader.new.read(message[1..])
        end
      end

      def finish(child)
        child[:reader].close
        child[:open] = false
        Process.waitpid(child[:pid])
        return unless child[:result].nil?

        child[:result] = { "status" => "error", "exit_status" => 2, "error" => "the job ended without a result" }
      end

      # Reads a result written with RubyLiteral.
      class ResultReader
        def read(text)
          instance_eval(text)
        end
      end
    end
  end
end
