# Debian 12 as a server would have it: no Ruby. The static sadame binary
# from dist/ is linked in when the container starts.
FROM debian:12
RUN apt-get update && \
    apt-get install -y --no-install-recommends sudo && \
    rm -rf /var/lib/apt/lists/*
