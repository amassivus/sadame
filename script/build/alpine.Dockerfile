# Build environment for static Linux binaries: Alpine's musl libc links
# statically without the caveats glibc has. `rake build:linux-amd64` and
# `rake build:linux-arm64` run mruby's build inside this image.
FROM alpine:3.20
RUN apk add --no-cache build-base bison git ruby ruby-rake
