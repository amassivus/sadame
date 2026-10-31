#!/bin/sh
# Tests install.sh against the binaries in dist/, served over HTTP the way a
# release serves them: it must install a working binary when the checksum
# matches, and refuse when it does not.
#
#   script/build/test-install.sh    (after building dist/ and SHA256SUMS)
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
port=${SADAME_TEST_PORT:-8754}
work=$(mktemp -d)

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work" > /dev/null 2>&1 &
server=$!
trap 'kill "$server" 2> /dev/null; wait "$server" 2> /dev/null; rm -rf "$work"' EXIT

mkdir -p "$work/good" "$work/bad"
cp "$root"/dist/sadame-* "$root/dist/SHA256SUMS" "$work/good/"
cp "$root"/dist/sadame-* "$work/bad/"
sed 's/^[0-9a-f]/0/' "$root/dist/SHA256SUMS" > "$work/bad/SHA256SUMS"
sleep 1

echo "== install with a matching checksum"
SADAME_DOWNLOAD_URL="http://127.0.0.1:$port/good" SADAME_INSTALL_DIR="$work/bin" sh "$root/install.sh"
"$work/bin/sadame" --version

echo "== install with a wrong checksum must fail"
rm -f "$work/bin/sadame"
if SADAME_DOWNLOAD_URL="http://127.0.0.1:$port/bad" SADAME_INSTALL_DIR="$work/bin" sh "$root/install.sh"; then
  echo "install.sh accepted a wrong checksum" >&2
  exit 1
fi
[ ! -e "$work/bin/sadame" ] || { echo "install.sh installed despite the wrong checksum" >&2; exit 1; }

echo "install.sh tests passed"
