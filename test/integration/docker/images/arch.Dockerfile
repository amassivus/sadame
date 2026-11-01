# Arch Linux booting systemd: archlinux:latest on amd64, the Arch Linux ARM
# community image on arm64. pacman's sandbox cannot set up seccomp under
# emulation, so it is disabled; the system is brought up to date once, as an
# installed system would be.
ARG BASE=archlinux:latest
FROM ${BASE}
RUN sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf && \
    pacman -Syu --noconfirm && \
    pacman -Scc --noconfirm
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
