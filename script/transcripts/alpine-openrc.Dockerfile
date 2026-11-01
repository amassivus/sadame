# Alpine 3.20 booting OpenRC, for the service resource on Alpine. BusyBox
# init runs OpenRC's runlevels; rc_sys="docker" skips what a container
# cannot do, and without consoles there is no getty to start.
FROM alpine:3.20
RUN apk add --no-cache openrc sudo && \
    sed -i 's/^#\?rc_sys=.*/rc_sys="docker"/' /etc/rc.conf && \
    sed -i 's/^tty/#tty/' /etc/inittab
CMD ["/sbin/init"]
