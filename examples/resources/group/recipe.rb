# The same gid on every server, so files on shared storage or in backups
# keep their group.
group "app", gid: 1500

# A system group: its gid comes from the system range, for service accounts.
group "metrics", system: true

# A group that must not exist. Nothing happens when it is already gone.
group "oldteam", state: :absent
