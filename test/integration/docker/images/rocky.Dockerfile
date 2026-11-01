# Rocky Linux 9 booting systemd.
FROM rockylinux/rockylinux:9
RUN dnf install -y systemd && dnf clean all
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
