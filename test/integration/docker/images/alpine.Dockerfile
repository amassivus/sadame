# Alpine 3.20 booting OpenRC, as an Alpine server does: BusyBox init runs
# OpenRC's sysinit, boot and default runlevels. rc_sys="docker" skips what
# a container cannot do (hardware clock, kernel modules); without consoles
# there is no getty to start.
FROM alpine:3.20
RUN apk add --no-cache openrc && \
    sed -i 's/^#\?rc_sys=.*/rc_sys="docker"/' /etc/rc.conf && \
    sed -i 's/^tty/#tty/' /etc/inittab
CMD ["/sbin/init"]
