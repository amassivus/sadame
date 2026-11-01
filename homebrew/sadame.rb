# Homebrew formula for the release binaries of sadame, published in the
# enderkus/homebrew-sadame tap: brew install enderkus/sadame/sadame.
# Written for each release by script/build/packaging.rb in
# enderkus/sadame (homebrew/sadame.rb), then copied to the tap's
# Formula/; do not edit it by hand.
class Sadame < Formula
  desc "Configuration management in plain Ruby, in one binary"
  homepage "https://enderkus.github.io/sadame/"
  version "0.3.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.3.0/sadame-darwin-arm64"
      sha256 "be3ddb02fddca7d9c9ca779acb12215483ec6165f987f0c30567744cecdb00ec"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.3.0/sadame-darwin-amd64"
      sha256 "cab896b83117c1d3bdf61eef72f15b44e7da48a7a56f4a6d20c769222830045a"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.3.0/sadame-linux-arm64"
      sha256 "ddb29d93cbdcb51d6948ec5edbe5b185e97db7595d559e7e5a5b687bf0353276"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.3.0/sadame-linux-amd64"
      sha256 "8682a6c45845a49991bd54eb7cf996659aa21bde00f16ae6fd5c2053ccc7e265"
    end
  end

  def install
    bin.install Dir["sadame-*"].first => "sadame"
  end

  test do
    assert_equal "sadame #{version}", shell_output("#{bin}/sadame --version").strip
  end
end
