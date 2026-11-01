# Homebrew formula for the release binaries of sadame, published in the
# enderkus/homebrew-sadame tap: brew install enderkus/sadame/sadame.
# Written for each release by script/build/packaging.rb in
# enderkus/sadame (homebrew/sadame.rb), then copied to the tap's
# Formula/; do not edit it by hand.
class Sadame < Formula
  desc "Configuration management in plain Ruby, in one binary"
  homepage "https://enderkus.github.io/sadame/"
  version "0.2.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.2.0/sadame-darwin-arm64"
      sha256 "d81d62580ea0abc832bb7f6fcb262b373297c36ce620c314be644450c5c65fa7"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.2.0/sadame-darwin-amd64"
      sha256 "e0dc0f92b08b5a192934a95724bbcae0de2dfa932042731446cc8950e020f9a5"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/enderkus/sadame/releases/download/v0.2.0/sadame-linux-arm64"
      sha256 "506c6f1bff94679ba2fd7ad417daada1e83802d80a3fe3a56febf45cb884d10f"
    end
    on_intel do
      url "https://github.com/enderkus/sadame/releases/download/v0.2.0/sadame-linux-amd64"
      sha256 "1fc5b297dbf1cf3e0b0c35b20b05ef0035b54c44645873bcb0b165485dfb5cd3"
    end
  end

  def install
    bin.install Dir["sadame-*"].first => "sadame"
  end

  test do
    assert_equal "sadame #{version}", shell_output("#{bin}/sadame --version").strip
  end
end
