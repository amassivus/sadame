# Debian 12 with Ruby, to run sadame from the mounted checkout.
FROM debian:12
RUN apt-get update && \
    apt-get install -y --no-install-recommends ruby sudo && \
    rm -rf /var/lib/apt/lists/*
COPY sadame-from-source /usr/local/bin/sadame
