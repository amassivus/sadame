#!/bin/sh
# Runs a sadame binary through plan, apply and drift with examples/01-hello,
# then through the commands that need no machine (validate, facts, init,
# report) and a short language server session. Used to verify release
# binaries, inside containers and on macOS: code that only works in the
# test build fails here.
#
#   script/build/smoke-test.sh BINARY EXAMPLES_DIR
set -eu

# Absolute paths: part of the test runs in another directory.
binary=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
examples=$(cd "$2" && pwd)
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

work=$(mktemp -d)
"$binary" drift "$examples/01-hello" --json > "$work/drift.json" || true
"$binary" report "$work/drift.json" --format junit | grep -q '<testsuites name="sadame drift"'
"$binary" validate "$examples/08-multi-role-inventory/site.rb" -g all | grep -q "validate on 3 hosts: 3 ok."
"$binary" facts | grep -q "^cpus "
(cd "$work" && "$binary" init demo > /dev/null && "$binary" validate demo > /dev/null)

# A language server session: open a recipe with a misspelled option, ask
# for completions, shut down. The answer must name the option.
message() {
  printf 'Content-Length: %s\r\n\r\n%s' "$(printf '%s' "$1" | wc -c | tr -d ' ')" "$1"
}
uri="file://$work/demo/recipe.rb"
{
  message '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
  message "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"$uri\",\"languageId\":\"ruby\",\"version\":1,\"text\":\"file \\\"/etc/motd\\\", contnet: \\\"hi\\\"\\n\"}}}"
  message "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"$uri\"},\"position\":{\"line\":0,\"character\":0}}}"
  message '{"jsonrpc":"2.0","id":3,"method":"shutdown"}'
  message '{"jsonrpc":"2.0","method":"exit"}'
} | "$binary" lsp > "$output"
grep -q "unknown option :contnet" "$output"
grep -q '"label": "package"' "$output"

rm -rf "$target" "$output" "$work"
echo "smoke test passed: $binary"
