# Debian 12 booting systemd, for the service resource and notifications.
FROM debian:12
RUN apt-get update && \
    apt-get install -y --no-install-recommends ruby sudo systemd systemd-sysv && \
    rm -rf /var/lib/apt/lists/*
COPY sadame-from-source /usr/local/bin/sadame
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
