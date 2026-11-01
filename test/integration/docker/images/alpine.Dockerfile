# Alpine 3.20. It uses OpenRC instead of systemd, so examples with service
# resources are skipped here; the container just waits.
FROM alpine:3.20
CMD ["sleep", "infinity"]
