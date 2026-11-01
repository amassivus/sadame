# Homebrew formula for the release binaries of sadame, published in the
# enderkus/homebrew-sadame tap: brew install enderkus/sadame/sadame.
# Written for each release by script/build/packaging.rb in
# enderkus/sadame (homebrew/sadame.rb), then copied to the tap's
# Formula/; do not edit it by hand.
class Sadame < Formula
  desc "Configuration management in plain Ruby, in one binary"
  homepage "https://enderkus.github.io/sadame/"
  version "0.5.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.0/sadame-darwin-arm64"
      sha256 "385aae9b8bc83653c91d7bb7fb0cb977d9d235e2c719e4ea78afddb79e6f749e"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.0/sadame-darwin-amd64"
      sha256 "9f67d3b2301c3cc7764ee1909ff0192aa4146fee844be016138a81967f528ac2"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.0/sadame-linux-arm64"
      sha256 "ece591ef1ad7c86c353b92a84994d189b4281e9e30bf6652d53b13764900c032"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.0/sadame-linux-amd64"
      sha256 "236026bd8872d16ab658465fdbd9d59a69c7634f2f206426c0835785e1c3d650"
    end
  end

  def install
    bin.install Dir["sadame-*"].first => "sadame"
  end

  test do
    assert_equal "sadame #{version}", shell_output("#{bin}/sadame --version").strip
  end
end
