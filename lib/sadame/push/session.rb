# frozen_string_literal: true

module Sadame
  module Push
    # A step of a push that failed before sadame ran on the target. kind is
    # :unreachable when ssh could not connect (exit status 255) and :error
    # otherwise.
    class Failure < Error
      attr_reader :kind

      def initialize(kind, message)
        @kind = kind
        super(message)
      end
    end

    # Runs one command on one target over SSH:
    #
    # 1. detect the target's system with `uname -sm`;
    # 2. make sure ~/.sadame/bin/SHA256/sadame holds the right binary,
    #    copying it only when that checksum is not there yet;
    # 3. copy the recipe bundle and the target's vars into
    #    ~/.sadame/run/RUN_ID/, unpack them there;
    # 4. run sadame from that directory, with sudo when asked to, and
    #    remove the directory afterwards.
    class Session
      SSH_CONNECTION_FAILED = 255

      attr_reader :target

      def initialize(target, shell:, ssh:)
        @target = target
        @shell = shell
        @ssh = ssh
      end

      # Returns ["linux", "amd64"] and the like.
      def detect_platform
        BinaryStore.platform_from_uname(remote!("uname -sm", "connect").stdout)
      rescue Failure => e
        raise e
      rescue Error => e
        raise Failure.new(:error, e.message)
      end

      # Copies the binary if needed, then runs `sadame COMMAND`. Output
      # lines are passed to the block as they arrive, unless capture is set
      # (for --json), in which case stdout is returned instead. Returns
      # [exit_status, captured_stdout, captured_stderr].
      def run(command:, binary:, bundle:, vars_file:, recipe:, run_id:, arguments: [], capture: false, &on_line)
        install_binary(binary, &on_line)
        remote!("sudo -n true", "sudo") if target.sudo
        run_dir = ".sadame/run/#{run_id}"
        remote!("mkdir -p #{run_dir}", "prepare #{run_dir}")
        copy!(bundle, "#{run_dir}/bundle.tgz")
        copy!(vars_file, "#{run_dir}/.sadame-vars.rb")

        script = run_script(command, binary, recipe, run_dir, arguments)
        if capture
          result = @shell.run(@ssh.ssh(script))
          [result.exit_status, result.stdout, result.stderr]
        else
          [@shell.stream(@ssh.ssh(script), &on_line), "", ""]
        end
      end

      private

      def install_binary(binary)
        directory = ".sadame/bin/#{binary.sha256}"
        return if remote("test -x #{directory}/sadame").success?

        yield "copying #{binary.name} to ~/#{directory}/\n" if block_given?
        remote!("mkdir -p #{directory}", "prepare #{directory}")
        copy!(binary.path, "#{directory}/sadame.part")
        verify = "cd #{directory} && sum=$({ sha256sum sadame.part 2>/dev/null || shasum -a 256 sadame.part; } | " \
                 "cut -d ' ' -f 1) && [ \"$sum\" = #{binary.sha256} ] && chmod 0755 sadame.part && mv -f sadame.part sadame"
        remote!(verify, "verify the copied binary")
      end

      def run_script(command, binary, recipe, run_dir, arguments)
        sadame = "\"$HOME/.sadame/bin/#{binary.sha256}/sadame\""
        sadame = "sudo -n #{sadame}" if target.sudo
        invocation = ([sadame, command, Shell.escape(recipe), "--vars-file", ".sadame-vars.rb",
                       "--name", Shell.escape(target.name)] + arguments).join(" ")
        "cd #{run_dir} && tar -xzf bundle.tgz && rm -f bundle.tgz && #{invocation}; " \
          "status=$?; cd && rm -rf #{run_dir}; exit $status"
      end

      def remote(command)
        @shell.run(@ssh.ssh(command))
      end

      def remote!(command, step)
        result = remote(command)
        return result if result.success?

        raise failure(result, step)
      end

      def copy!(local_path, remote_path)
        result = @shell.run(@ssh.scp(local_path, remote_path))
        return if result.success?

        raise failure(result, "copy #{File.basename(local_path)}")
      end

      def failure(result, step)
        details = result.stderr.strip
        details = result.stdout.strip if details.empty?
        details = details.split("\n").last.to_s
        kind = result.exit_status == SSH_CONNECTION_FAILED ? :unreachable : :error
        Failure.new(kind, "#{step} failed: #{details.empty? ? "exit #{result.exit_status}" : details}")
      end
    end
  end
end
