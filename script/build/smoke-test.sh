#!/bin/sh
# Runs a sadame binary through plan, apply and drift with examples/01-hello.
# Used to verify release binaries, inside containers and on macOS.
#
#   script/build/smoke-test.sh BINARY EXAMPLES_DIR
set -eu

binary=$1
examples=$2
output=$(mktemp)
target=/tmp/sadame-hello.txt
rm -f "$target"

"$binary" --version
"$binary" plan "$examples/01-hello" > "$output"
"$binary" apply "$examples/01-hello" > "$output"
"$binary" drift "$examples/01-hello" > "$output"
grep -q "Hello from sadame!" "$target"

echo "edited by hand" > "$target"
status=0
"$binary" drift "$examples/01-hello" --json > "$output" || status=$?
if [ "$status" -ne 1 ]; then
  echo "expected drift to exit 1 after editing $target, got $status" >&2
  exit 1
fi
grep -q '"drift": true' "$output"

rm -f "$target" "$output"
echo "smoke test passed: $binary"
