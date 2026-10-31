# Database servers: SQLite, a system user to own the data, and a nightly
# dump at vars[:backup_hour].
package "sqlite3"
package "cron"

user "demo-db", system: true, home: "/var/lib/demo-db", shell: "/usr/sbin/nologin"
directory "/var/lib/demo-db", owner: "demo-db", group: "demo-db", mode: "0750"

file "/etc/cron.d/demo-db-backup",
     content: "0 #{vars[:backup_hour]} * * * demo-db sqlite3 /var/lib/demo-db/app.db .dump > /var/lib/demo-db/backup.sql\n",
     mode: "0644"
