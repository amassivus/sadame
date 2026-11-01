# Homebrew formula for the release binaries of sadame, published in the
# enderkus/homebrew-sadame tap: brew install enderkus/sadame/sadame.
# Written for each release by script/build/packaging.rb in
# enderkus/sadame (homebrew/sadame.rb), then copied to the tap's
# Formula/; do not edit it by hand.
class Sadame < Formula
  desc "Configuration management in plain Ruby, in one binary"
  homepage "https://enderkus.github.io/sadame/"
  version "0.1.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.1.0/sadame-darwin-arm64"
      sha256 "38680dfed3d410b4ce898deaa9879e14a70139cd5d79ea2bd97ec4a4c6d08f47"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.1.0/sadame-darwin-amd64"
      sha256 "aaa4daddd45139d6265c6fa536dc56adf3a95975086b3ee8b8f1d0dffc90a7b0"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.1.0/sadame-linux-arm64"
      sha256 "af0ca7fd9b4e138bec76af3a44f0d5660e39fd2683706d37b7b9e56e340e1475"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.1.0/sadame-linux-amd64"
      sha256 "7d3b3f45f43bc59bffb6f10a399976878fdb4d485ed99f51a2e2f6b03fe11932"
    end
  end

  def install
    bin.install Dir["sadame-*"].first => "sadame"
  end

  test do
    assert_equal "sadame #{version}", shell_output("#{bin}/sadame --version").strip
  end
end
