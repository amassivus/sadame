# frozen_string_literal: true

module Sadame
  # Facts about the operating system, read from /etc/os-release.
  #
  #   platform = Sadame::Platform.from_os_release(File.read("/etc/os-release"))
  #   platform.family           # => "arch"
  #   platform.package_manager  # => "pacman"
  class Platform
    # Distribution IDs (ID and ID_LIKE in os-release) for each family.
    FAMILY_IDS = {
      "debian" => %w[debian ubuntu linuxmint pop raspbian],
      "rhel" => %w[rhel centos fedora rocky almalinux ol],
      "alpine" => %w[alpine],
      "arch" => %w[arch archarm manjaro endeavouros]
    }.freeze

    PACKAGE_MANAGERS = {
      "debian" => "apt",
      "rhel" => "dnf",
      "alpine" => "apk",
      "arch" => "pacman"
    }.freeze

    OS_RELEASE_PATHS = ["/etc/os-release", "/usr/lib/os-release"].freeze

    attr_reader :id, :name, :version, :codename, :family, :kernel

    def self.detect(shell)
      kernel = shell.run("uname -s").stdout.strip
      text = nil
      OS_RELEASE_PATHS.each { |path| text ||= shell.read_file(path) }
      from_os_release(text || "", kernel: kernel)
    end

    def self.from_os_release(text, kernel: "Linux")
      fields = parse_os_release(text)
      new(
        id: fields["ID"],
        id_like: fields["ID_LIKE"],
        name: fields["PRETTY_NAME"] || fields["NAME"],
        version: fields["VERSION_ID"],
        codename: fields["VERSION_CODENAME"] || fields["UBUNTU_CODENAME"],
        kernel: kernel
      )
    end

    def self.parse_os_release(text)
      fields = {}
      text.split("\n").each do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")

        key, value = line.split("=", 2)
        fields[key] = unquote(value) if value
      end
      fields
    end

    def self.unquote(value)
      if value.size >= 2 && (value.start_with?('"') || value.start_with?("'")) && value.end_with?(value[0])
        value[1...-1]
      else
        value
      end
    end

    def initialize(id:, id_like: nil, name: nil, version: nil, codename: nil, kernel: "Linux")
      @id = id
      @name = name
      @version = version
      @codename = codename
      @kernel = kernel
      @family = detect_family([id] + id_like.to_s.split(" "))
    end

    def package_manager
      PACKAGE_MANAGERS[family]
    end

    def linux?
      kernel == "Linux"
    end

    def darwin?
      kernel == "Darwin"
    end

    # Human-readable label used in output headers.
    def description
      return name if name
      return "macOS" if darwin?

      kernel.to_s.empty? ? "unknown system" : kernel
    end

    def to_h
      { name: description, family: family, package_manager: package_manager }
    end

    private

    def detect_family(candidates)
      candidates.each do |candidate|
        FAMILY_IDS.each do |family, ids|
          return family if ids.include?(candidate)
        end
      end
      nil
    end
  end
end
