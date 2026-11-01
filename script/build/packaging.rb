# frozen_string_literal: true

# Writes the Homebrew formula (homebrew/sadame.rb) and the AUR package
# (packaging/aur/PKGBUILD and .SRCINFO) for a published release, with the
# checksums from that release's SHA256SUMS.
#
#   ruby script/build/packaging.rb 0.1.0
#   ruby script/build/packaging.rb 0.1.0 path/to/SHA256SUMS
#
# Without a path, SHA256SUMS is downloaded from the GitHub release.
# Development tooling: CRuby only.

require "digest"
require "open3"

module Packaging
  ROOT = File.expand_path("../..", __dir__)
  REPOSITORY = "enderkus/sadame"
  DESCRIPTION = "Configuration management in plain Ruby, in one binary"
  HOMEPAGE = "https://enderkus.github.io/sadame/"
  MAINTAINER = "Ender Kus <enderkus at msn dot com>"

  module_function

  def main(version, sums_path)
    abort "usage: packaging.rb VERSION [SHA256SUMS]" if version.nil? || !version.match?(/\A\d+\.\d+\.\d+\z/)

    sums = parse_sums(sums_path ? File.read(sums_path) : download("#{release_url(version)}/SHA256SUMS"))
    # The tagged LICENSE, which the AUR package downloads, is this one.
    license_sum = Digest::SHA256.file(File.join(ROOT, "LICENSE")).hexdigest
    write("homebrew/sadame.rb", formula(version, sums))
    write("packaging/aur/PKGBUILD", pkgbuild(version, sums, license_sum))
    write("packaging/aur/.SRCINFO", srcinfo(version, sums, license_sum))
  end

  def release_url(version)
    "https://github.com/#{REPOSITORY}/releases/download/v#{version}"
  end

  def parse_sums(text)
    text.lines.to_h do |line|
      sum, name = line.split
      [name, sum]
    end
  end

  def download(url)
    output, status = Open3.capture2("curl", "-fsSL", url)
    abort "could not download #{url}" unless status.success?

    output
  end

  def write(path, content)
    File.write(File.join(ROOT, path), content)
    puts path
  end

  def formula(version, sums)
    url = release_url(version)
    <<~RUBY
      # Homebrew formula for the release binaries. To publish it, put this
      # file in Formula/ of a repository named homebrew-sadame; then
      # `brew install enderkus/sadame/sadame` installs it. Written by
      # script/build/packaging.rb: regenerate it for each release.
      class Sadame < Formula
        desc "#{DESCRIPTION}"
        homepage "#{HOMEPAGE}"
        version "#{version}"
        license "MIT"

        on_macos do
          on_arm do
            url "#{url}/sadame-darwin-arm64"
            sha256 "#{sums.fetch("sadame-darwin-arm64")}"
          end
          on_intel do
            url "#{url}/sadame-darwin-amd64"
            sha256 "#{sums.fetch("sadame-darwin-amd64")}"
          end
        end

        on_linux do
          on_arm do
            url "#{url}/sadame-linux-arm64"
            sha256 "#{sums.fetch("sadame-linux-arm64")}"
          end
          on_intel do
            url "#{url}/sadame-linux-amd64"
            sha256 "#{sums.fetch("sadame-linux-amd64")}"
          end
        end

        def install
          bin.install Dir["sadame-*"].first => "sadame"
        end

        test do
          assert_equal "sadame \#{version}", shell_output("\#{bin}/sadame --version").strip
        end
      end
    RUBY
  end

  def pkgbuild(version, sums, license_sum)
    <<~SH
      # Maintainer: #{MAINTAINER}
      #
      # The release binaries of sadame, ready to submit to the AUR as
      # sadame-bin. Written by script/build/packaging.rb: regenerate it and
      # .SRCINFO for each release.
      pkgname=sadame-bin
      pkgver=#{version}
      pkgrel=1
      pkgdesc="#{DESCRIPTION}"
      arch=('x86_64' 'aarch64')
      url="#{HOMEPAGE}"
      license=('MIT')
      provides=('sadame')
      conflicts=('sadame')
      options=('!strip' '!debug')
      source=("LICENSE-$pkgver::https://raw.githubusercontent.com/#{REPOSITORY}/v$pkgver/LICENSE")
      source_x86_64=("sadame-$pkgver-x86_64::https://github.com/#{REPOSITORY}/releases/download/v$pkgver/sadame-linux-amd64")
      source_aarch64=("sadame-$pkgver-aarch64::https://github.com/#{REPOSITORY}/releases/download/v$pkgver/sadame-linux-arm64")
      sha256sums=('#{license_sum}')
      sha256sums_x86_64=('#{sums.fetch("sadame-linux-amd64")}')
      sha256sums_aarch64=('#{sums.fetch("sadame-linux-arm64")}')

      package() {
        install -Dm755 "sadame-$pkgver-$CARCH" "$pkgdir/usr/bin/sadame"
        install -Dm644 "LICENSE-$pkgver" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
      }
    SH
  end

  # The same as `makepkg --printsrcinfo` prints for the PKGBUILD above.
  def srcinfo(version, sums, license_sum)
    release = release_url(version)
    <<~TEXT
      pkgbase = sadame-bin
      \tpkgdesc = #{DESCRIPTION}
      \tpkgver = #{version}
      \tpkgrel = 1
      \turl = #{HOMEPAGE}
      \tarch = x86_64
      \tarch = aarch64
      \tlicense = MIT
      \tprovides = sadame
      \tconflicts = sadame
      \toptions = !strip
      \toptions = !debug
      \tsource = LICENSE-#{version}::https://raw.githubusercontent.com/#{REPOSITORY}/v#{version}/LICENSE
      \tsha256sums = #{license_sum}
      \tsource_x86_64 = sadame-#{version}-x86_64::#{release}/sadame-linux-amd64
      \tsha256sums_x86_64 = #{sums.fetch("sadame-linux-amd64")}
      \tsource_aarch64 = sadame-#{version}-aarch64::#{release}/sadame-linux-arm64
      \tsha256sums_aarch64 = #{sums.fetch("sadame-linux-arm64")}

      pkgname = sadame-bin
    TEXT
  end
end

Packaging.main(ARGV[0], ARGV[1]) if $PROGRAM_NAME == __FILE__
