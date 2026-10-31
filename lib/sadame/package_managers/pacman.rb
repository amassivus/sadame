# frozen_string_literal: true

module Sadame
  module PackageManagers
    # Arch Linux and Arch-based systems such as Omarchy. The sync database
    # is not refreshed automatically: pacman -Sy without -u is a partial
    # upgrade, which Arch does not support.
    class Pacman < Base
      def name
        "pacman"
      end

      def query_command(package)
        "pacman -Q #{Shell.escape(package)}"
      end

      def install_command(package, options = nil)
        "pacman -S --needed --noconfirm #{extra_flags(options)}#{Shell.escape(package)}"
      end

      def remove_command(package, options = nil)
        "pacman -Rns --noconfirm #{extra_flags(options)}#{Shell.escape(package)}"
      end
    end
  end
end
