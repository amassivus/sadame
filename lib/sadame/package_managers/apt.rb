# frozen_string_literal: true

module Sadame
  module PackageManagers
    # Debian and Ubuntu. The package index is refreshed with apt-get update
    # once per run, right before the first install.
    class Apt < Base
      def name
        "apt"
      end

      def installed?(package)
        result = shell.run(query_command(package))
        result.success? && result.stdout.strip.split(" ").last == "installed"
      end

      def install(package, options = nil)
        update_index
        super
      end

      def query_command(package)
        "dpkg-query -W -f='${Status}' #{Shell.escape(package)}"
      end

      def install_command(package, options = nil)
        "DEBIAN_FRONTEND=noninteractive apt-get install -y #{extra_flags(options)}#{Shell.escape(package)}"
      end

      def remove_command(package, options = nil)
        "DEBIAN_FRONTEND=noninteractive apt-get remove -y #{extra_flags(options)}#{Shell.escape(package)}"
      end

      def update_command
        "DEBIAN_FRONTEND=noninteractive apt-get update"
      end

      private

      def update_index
        return if @index_updated

        shell.run!(update_command)
        @index_updated = true
      end
    end
  end
end
