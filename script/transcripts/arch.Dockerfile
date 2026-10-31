# Arch Linux. pacman's download sandbox cannot set up seccomp when the
# image runs under emulation, so it is disabled.
FROM archlinux:latest
RUN sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf && \
    pacman -Syu --noconfirm sudo && \
    pacman -Scc --noconfirm
