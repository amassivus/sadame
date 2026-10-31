#!/bin/sh
# Installs sadame from its GitHub releases.
#
#   curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
#
# Environment variables:
#   SADAME_VERSION       release to install, such as v0.1.0 (default: the latest)
#   SADAME_INSTALL_DIR   where to put the binary (default: /usr/local/bin)
#   SADAME_DOWNLOAD_URL  base URL holding the binaries and SHA256SUMS
#                        (default: the GitHub release; set it for mirrors)
#
# The binary's SHA-256 checksum is checked against the release's SHA256SUMS
# before anything is installed.
set -eu

repository="https://github.com/enderkus/sadame"
install_dir="${SADAME_INSTALL_DIR:-/usr/local/bin}"

fail() {
  echo "sadame install: $*" >&2
  exit 1
}

detect_os() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo darwin ;;
    *) fail "unsupported operating system: $(uname -s) (supported: Linux, macOS)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) fail "unsupported architecture: $(uname -m) (supported: x86_64, aarch64/arm64)" ;;
  esac
}

download_url() {
  if [ -n "${SADAME_DOWNLOAD_URL:-}" ]; then
    echo "$SADAME_DOWNLOAD_URL"
  elif [ -n "${SADAME_VERSION:-}" ]; then
    echo "$repository/releases/download/$SADAME_VERSION"
  else
    echo "$repository/releases/latest/download"
  fi
}

fetch() {
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL -o "$2" "$1"
  elif command -v wget > /dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    fail "curl or wget is required"
  fi
}

sha256_of() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  elif command -v shasum > /dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  else
    fail "sha256sum or shasum is required to verify the download"
  fi
}

asset="sadame-$(detect_os)-$(detect_arch)"
base_url=$(download_url)
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

echo "Downloading $asset from $base_url"
fetch "$base_url/$asset" "$workdir/$asset" || fail "could not download $base_url/$asset"
fetch "$base_url/SHA256SUMS" "$workdir/SHA256SUMS" || fail "could not download $base_url/SHA256SUMS"

expected=$(awk -v name="$asset" '$2 == name { print $1 }' "$workdir/SHA256SUMS")
[ -n "$expected" ] || fail "SHA256SUMS has no entry for $asset"
actual=$(sha256_of "$workdir/$asset")
[ "$expected" = "$actual" ] || fail "checksum mismatch for $asset: expected $expected, got $actual"
echo "Checksum verified: $actual"

if [ -w "$install_dir" ] || { [ ! -e "$install_dir" ] && mkdir -p "$install_dir" 2> /dev/null; }; then
  install -m 0755 "$workdir/$asset" "$install_dir/sadame"
elif command -v sudo > /dev/null 2>&1; then
  echo "Installing into $install_dir with sudo"
  sudo mkdir -p "$install_dir"
  sudo install -m 0755 "$workdir/$asset" "$install_dir/sadame"
else
  fail "$install_dir is not writable; set SADAME_INSTALL_DIR or run as root"
fi

echo "Installed $("$install_dir/sadame" --version) to $install_dir/sadame"
