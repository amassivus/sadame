# frozen_string_literal: true

module Sadame
  module PackageManagers
    # Rocky Linux, AlmaLinux, RHEL and Fedora.
    class Dnf < Base
      def name
        "dnf"
      end

      def query_command(package)
        "rpm -q #{Shell.escape(package)}"
      end

      def install_command(package, options = nil)
        "dnf install -y #{extra_flags(options)}#{Shell.escape(package)}"
      end

      def remove_command(package, options = nil)
        "dnf remove -y #{extra_flags(options)}#{Shell.escape(package)}"
      end
    end
  end
end
