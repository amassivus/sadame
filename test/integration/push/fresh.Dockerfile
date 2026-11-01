# A freshly created cloud server: Debian 12 booting systemd and sshd, with
# only root, reachable with a key, as Hetzner Cloud and DigitalOcean hand
# them over. Used by the provisioning guide's transcripts.
FROM debian:12
RUN apt-get update && \
    apt-get install -y --no-install-recommends systemd systemd-sysv openssh-server && \
    rm -rf /var/lib/apt/lists/*
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
