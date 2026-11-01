# vhs (terminal recorder) with the OpenSSH client, joined to the push lab's
# network so the recording shows sadame working on real SSH targets.
FROM ghcr.io/charmbracelet/vhs:v0.12.1
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-client && \
    rm -rf /var/lib/apt/lists/*
