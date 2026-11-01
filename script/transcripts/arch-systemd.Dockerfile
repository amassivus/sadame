# Arch Linux booting systemd, with sudo, for the workstation guide. The base
# is archlinux:latest on x86_64 and the Arch Linux ARM community image on
# ARM64, because systemd does not boot under every emulator.
ARG BASE=archlinux:latest
FROM ${BASE}
RUN sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf && \
    pacman -Syu --noconfirm sudo && \
    pacman -Scc --noconfirm
STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
