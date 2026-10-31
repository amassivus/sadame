# frozen_string_literal: true

module Sadame
  module PackageManagers
    # Common behaviour of the package managers. A subclass provides the
    # three command lines; everything else is shared.
    class Base
      attr_reader :shell

      def initialize(shell)
        @shell = shell
      end

      def name
        raise NotImplementedError, "#{self.class} must define name"
      end

      def installed?(package)
        shell.run(query_command(package)).success?
      end

      def install(package, options = nil)
        shell.run!(install_command(package, options))
      end

      def remove(package, options = nil)
        shell.run!(remove_command(package, options))
      end

      private

      # Extra flags from the package resource's options: argument, given as
      # a string (used as is) or an array (each element quoted).
      def extra_flags(options)
        case options
        when nil then ""
        when Array then "#{options.map { |flag| Shell.escape(flag) }.join(" ")} "
        else "#{options} "
        end
      end
    end
  end
end
