cron "backup", schedule: "0 3 * * *", command: "/usr/local/bin/backup"
cron "cleanup", schedule: "*/15 * * * *", command: "find /tmp/app -mtime +1 -delete", user: "app"
