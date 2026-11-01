# Debian 12 booting systemd, as fresh as the official image: no package
# index, nothing installed beyond systemd.
FROM debian:12
RUN apt-get update && \
    apt-get install -y --no-install-recommends systemd systemd-sysv && \
    rm -rf /var/lib/apt/lists/*
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
