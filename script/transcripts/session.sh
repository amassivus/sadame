#!/bin/sh
# Runs the commands read from stdin one by one and prints each as
# "$ command" before its output, like a terminal session. $? carries over
# from one command to the next, so "echo $?" shows the previous status.
exec 2>&1
status=0
first=yes
while IFS= read -r command; do
  [ -n "$first" ] || echo
  first=
  printf '$ %s\n' "$command"
  (exit "$status")
  eval "$command" </dev/null
  status=$?
done
