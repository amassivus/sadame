# frozen_string_literal: true

module Sadame
  # Maps Platform#package_manager to the class that drives it.
  module PackageManagers
    ALL = {
      "apt" => Apt,
      "dnf" => Dnf,
      "apk" => Apk,
      "pacman" => Pacman
    }.freeze

    def self.for(platform, shell)
      manager = ALL[platform.package_manager]
      if manager.nil?
        raise ResourceError, "no supported package manager on #{platform.description} " \
                             "(supported: #{ALL.keys.join(", ")})"
      end

      manager.new(shell)
    end
  end
end
