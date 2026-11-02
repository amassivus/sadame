# Homebrew formula for the release binaries of sadame, published in the
# enderkus/homebrew-sadame tap: brew install enderkus/sadame/sadame.
# Written for each release by script/build/packaging.rb in
# enderkus/sadame (homebrew/sadame.rb), then copied to the tap's
# Formula/; do not edit it by hand.
class Sadame < Formula
  desc "Configuration management in plain Ruby, in one binary"
  homepage "https://enderkus.github.io/sadame/"
  version "0.5.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.1/sadame-darwin-arm64"
      sha256 "0f53def806b2ae313676c26e239db64f341c41a00288c2dfab1682d2053bf30c"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.1/sadame-darwin-amd64"
      sha256 "24c3b4148f73bf05770a51908d2bd6f94654883baa93d6b983d30ee16138b3dd"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.1/sadame-linux-arm64"
      sha256 "dcf637ae7d2f79587cd36cc4fb47eff845444424933647a5e75565917475c21d"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.5.1/sadame-linux-amd64"
      sha256 "33c88ad9d3071dc1288a314d396a88e301ee1aff048cc80a213281f353d0ddee"
    end
  end

  def install
    bin.install Dir["sadame-*"].first => "sadame"
  end

  test do
    assert_equal "sadame #{version}", shell_output("#{bin}/sadame --version").strip
  end
end
