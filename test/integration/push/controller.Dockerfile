# The machine sadame runs on in the lab: only the OpenSSH client, tar and
# coreutils. The lab links the static sadame binary in when it starts.
FROM debian:12
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-client && \
    rm -rf /var/lib/apt/lists/*
