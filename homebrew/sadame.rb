# Homebrew formula for the release binaries of sadame, published in the
# enderkus/homebrew-sadame tap: brew install enderkus/sadame/sadame.
# Written for each release by script/build/packaging.rb in
# enderkus/sadame (homebrew/sadame.rb), then copied to the tap's
# Formula/; do not edit it by hand.
class Sadame < Formula
  desc "Configuration management in plain Ruby, in one binary"
  homepage "https://enderkus.github.io/sadame/"
  version "0.4.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.4.0/sadame-darwin-arm64"
      sha256 "496cd74be6825f39fef82ed0aa6496b91ae662ff5fbde3e83799b0fc618b36ca"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.4.0/sadame-darwin-amd64"
      sha256 "8daef1b926018ed908871db0ed93bcb2bb1c74b048fdc17144d794800604470f"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.4.0/sadame-linux-arm64"
      sha256 "b3ee017faf9f137c63a3b6ea1698fea0fe70bb0f9b7223fbf2bdf9e2c3356f20"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.4.0/sadame-linux-amd64"
      sha256 "0f97ae119ab89783e8e130da3bf217d3c87f1e3993d98b322766ff3feb7983c5"
    end
  end

  def install
    bin.install Dir["sadame-*"].first => "sadame"
  end

  test do
    assert_equal "sadame #{version}", shell_output("#{bin}/sadame --version").strip
  end
end
