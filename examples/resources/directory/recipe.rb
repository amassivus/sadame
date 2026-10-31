directory "/srv/app", mode: "0755"
directory "/srv/app/shared", owner: "www-data", group: "www-data", mode: "0750"

# Remove a directory and everything in it.
directory "/srv/app/tmp", state: :absent, recursive: true
