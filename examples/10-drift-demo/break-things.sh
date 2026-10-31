#!/bin/sh
# Simulates what happens to servers over time: a hand edit, a permissions
# "fix" and a stopped service. Run it as root after `sadame apply`, then run
# `sadame drift` to see each change reported.
set -e

# Someone tunes a setting by hand.
sed -i 's/^workers   = .*/workers   = 16/' /etc/demo-app/app.conf

# Someone makes the file world-readable while debugging.
chmod 0644 /etc/demo-app/app.conf

# Someone stops nginx and forgets to start it again.
systemctl stop nginx

echo "break-things: edited app.conf, changed its mode, stopped nginx"
