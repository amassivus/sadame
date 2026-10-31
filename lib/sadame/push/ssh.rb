# frozen_string_literal: true

module Sadame
  module Push
    # Builds ssh and scp command lines for one target. The system's ssh and
    # scp are used, so ~/.ssh/config, keys and the agent apply as usual.
    #
    # The target's ssh_opts come first, because ssh uses the first value it
    # sees for an option; that lets them override sadame's defaults. They
    # are passed to scp too, so they must be options both accept, such as
    # -i, -F, -J and -o.
    class SSH
      DEFAULT_OPTIONS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10"].freeze

      attr_reader :target

      # control_dir, when given, holds an SSH control socket per target, so
      # the several commands a push runs share one connection.
      def initialize(target, control_dir: nil)
        @target = target
        @control_dir = control_dir
      end

      def ssh(remote_command)
        parts = ["ssh"] + options
        parts += ["-p", target.port.to_s] if target.port
        parts << destination
        parts << remote_command
        join(parts)
      end

      # ssh takes the port with -p, scp with -P.
      def scp(local_path, remote_path)
        parts = ["scp", "-q"] + options
        parts += ["-P", target.port.to_s] if target.port
        parts << local_path
        parts << "#{scp_host}:#{remote_path}"
        join(parts)
      end

      # Closes the shared connection, if one was opened.
      def close
        return nil if @control_dir.nil?

        parts = ["ssh"] + options + ["-O", "exit"]
        parts += ["-p", target.port.to_s] if target.port
        parts << destination
        join(parts)
      end

      private

      def options
        result = target.ssh_opts + DEFAULT_OPTIONS
        return result if @control_dir.nil?

        result + ["-o", "ControlMaster=auto", "-o", "ControlPath=#{@control_dir}/%C", "-o", "ControlPersist=60"]
      end

      def destination
        target.user ? "#{target.user}@#{target.address}" : target.address
      end

      # scp needs brackets around IPv6 addresses.
      def scp_host
        host = target.address.include?(":") ? "[#{target.address}]" : target.address
        target.user ? "#{target.user}@#{host}" : host
      end

      def join(parts)
        parts.map { |part| Shell.escape(part) }.join(" ")
      end
    end
  end
end
