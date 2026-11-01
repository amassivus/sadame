# Two releases of an application side by side, and a link that says which
# one is live: deploying another release is a change to the link.
directory "/srv/app/releases/1"
directory "/srv/app/releases/2"
file "/srv/app/releases/2/console", content: "#!/bin/sh\necho \"release 2\"\n", mode: "0755"
link "/srv/app/current", to: "releases/2"

# A command on the PATH that runs whichever release is live.
link "/usr/local/bin/app-console", to: "/srv/app/current/console"

# A link that must not exist.
link "/usr/local/bin/old-console", state: :absent
