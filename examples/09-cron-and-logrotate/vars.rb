{
  # Each job: when (cron syntax), the user to run as, the command.
  jobs: [
    { schedule: "*/15 * * * *", user: "app", command: "find /var/lib/app/tmp -type f -mmin +60 -delete" },
    { schedule: "30 2 * * *", user: "app", command: "tar -czf /var/lib/app/backup.tar.gz -C /var/lib/app data" }
  ],
  rotate_days: 14
}
