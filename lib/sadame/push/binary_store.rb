# frozen_string_literal: true

module Sadame
  module Push
    # Finds the sadame binary to copy to a target, on the machine running
    # sadame. For a target running Linux on x86_64 that is
    # sadame-linux-amd64, and so on. Looked up in this order:
    #
    # 1. $SADAME_BINARY_DIR/sadame-OS-ARCH, when the variable is set;
    # 2. the running binary itself, when it was built for the same system;
    # 3. ~/.sadame/dist/VERSION/sadame-OS-ARCH, downloaded earlier;
    # 4. a download from the GitHub release of this version (or
    #    $SADAME_DOWNLOAD_URL), checked against its SHA256SUMS.
    class BinaryStore
      # A binary on this machine and its SHA-256 checksum.
      class LocalBinary
        attr_reader :name, :path, :sha256

        def initialize(name, path, sha256)
          @name = name
          @path = path
          @sha256 = sha256
        end
      end

      RELEASE_URL = "https://github.com/enderkus/sadame/releases/download"

      def initialize(shell, environment: ENV, engine: RUBY_ENGINE, pid: Process.pid)
        @shell = shell
        @environment = environment
        @engine = engine
        @pid = pid
        @found = {}
      end

      # Platform names as in release file names: "linux" or "darwin", and
      # "amd64" or "arm64".
      def self.platform_from_uname(output)
        kernel, machine = output.strip.split(" ", 2)
        os = { "Linux" => "linux", "Darwin" => "darwin" }[kernel]
        arch = { "x86_64" => "amd64", "amd64" => "amd64", "aarch64" => "arm64", "arm64" => "arm64" }[machine]
        return [os, arch] if os && arch

        raise Error, "sadame has no binary for #{output.strip} (available: Linux and macOS on x86_64 and arm64)"
      end

      def find(os, arch)
        name = "sadame-#{os}-#{arch}"
        @found[name] ||= LocalBinary.new(name, *locate(name, os, arch))
      end

      private

      # Returns [path, sha256].
      def locate(name, os, arch)
        directory = @environment["SADAME_BINARY_DIR"]
        if directory && !directory.empty?
          path = File.join(directory, name)
          raise Error, "#{path} does not exist (SADAME_BINARY_DIR is set)" unless File.file?(path)

          return [path, checksum(path)]
        end

        own = own_binary(os, arch)
        return [own, checksum(own)] if own

        cached = File.join(cache_dir, name)
        return [cached, checksum(cached)] if File.file?(cached)

        download(name, cached)
      end

      # The running process is the binary for os/arch when sadame runs as
      # the compiled binary on that system. Linux exposes the executable as
      # /proc/PID/exe, which scp can read directly.
      def own_binary(os, arch)
        return nil unless @engine == "mruby" && os == "linux"
        return nil unless BinaryStore.platform_from_uname(@shell.run!("uname -sm").stdout) == [os, arch]

        path = "/proc/#{@pid}/exe"
        File.exist?(path) ? path : nil
      end

      def cache_dir
        File.join(@environment["HOME"].to_s, ".sadame", "dist", VERSION)
      end

      def download(name, destination)
        if VERSION.include?(".dev") && (@environment["SADAME_DOWNLOAD_URL"].nil? || @environment["SADAME_DOWNLOAD_URL"].empty?)
          raise Error, "no #{name} for this development version of sadame; build it " \
                       "(rake build:linux-amd64 build:linux-arm64) and set SADAME_BINARY_DIR=dist"
        end

        base = @environment["SADAME_DOWNLOAD_URL"]
        base = "#{RELEASE_URL}/v#{VERSION}" if base.nil? || base.empty?
        @shell.run!("mkdir -p #{Shell.escape(File.dirname(destination))}")
        partial = "#{destination}.download"
        fetch("#{base}/#{name}", partial)
        sums = fetch_text("#{base}/SHA256SUMS")
        expected = expected_checksum(sums, name)
        actual = checksum(partial)
        if expected != actual
          @shell.run("rm -f #{Shell.escape(partial)}")
          raise Error, "checksum mismatch for #{name} from #{base}: expected #{expected}, got #{actual}"
        end

        @shell.run!("chmod 0755 #{Shell.escape(partial)} && mv -f #{Shell.escape(partial)} #{Shell.escape(destination)}")
        [destination, actual]
      end

      def fetch(url, path)
        @shell.run!("if command -v curl >/dev/null 2>&1; then curl -fsSL -o #{Shell.escape(path)} #{Shell.escape(url)}; " \
                    "else wget -q -O #{Shell.escape(path)} #{Shell.escape(url)}; fi")
      end

      def fetch_text(url)
        @shell.run!("if command -v curl >/dev/null 2>&1; then curl -fsSL #{Shell.escape(url)}; " \
                    "else wget -q -O - #{Shell.escape(url)}; fi").stdout
      end

      def expected_checksum(sums, name)
        sums.split("\n").each do |line|
          checksum, file = line.split(" ", 2)
          return checksum if file && file.strip == name
        end
        raise Error, "SHA256SUMS has no entry for #{name}"
      end

      def checksum(path)
        command = "if command -v sha256sum >/dev/null 2>&1; then sha256sum #{Shell.escape(path)}; " \
                  "else shasum -a 256 #{Shell.escape(path)}; fi"
        @shell.run!(command).stdout.split(" ").first
      end
    end
  end
end
