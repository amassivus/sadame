# A push target: Debian 12 booting systemd, with sshd, a "deploy" user who
# may use sudo without a password, and an "ops" user whose sudo asks
# for one. The lab installs their SSH keys and, for db1, moves sshd to port
# 2222 when the container starts.
FROM debian:12
RUN apt-get update && \
    apt-get install -y --no-install-recommends systemd systemd-sysv openssh-server sudo && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -s /bin/bash deploy && \
    echo "deploy ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/deploy && \
    chmod 0440 /etc/sudoers.d/deploy && \
    useradd -m -s /bin/bash -G sudo ops && \
    echo "ops:lab-only-password" | chpasswd && \
    printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' > /etc/ssh/sshd_config.d/lab.conf
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
