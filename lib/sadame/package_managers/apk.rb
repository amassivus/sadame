# frozen_string_literal: true

module Sadame
  module PackageManagers
    # Alpine Linux.
    class Apk < Base
      def name
        "apk"
      end

      def query_command(package)
        "apk info -e #{Shell.escape(package)}"
      end

      def install_command(package, options = nil)
        "apk add #{extra_flags(options)}#{Shell.escape(package)}"
      end

      def remove_command(package, options = nil)
        "apk del #{extra_flags(options)}#{Shell.escape(package)}"
      end
    end
  end
end
