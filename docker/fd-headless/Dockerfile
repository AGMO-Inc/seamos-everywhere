# syntax=docker/dockerfile:1
# JDK (not JRE) is required: FD generates JAVA codegen that compiles via maven/javac inside the container.
FROM --platform=linux/amd64 eclipse-temurin:21-jdk-jammy

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libgtk-3-0 \
        libxtst6 \
        libxrender1 \
        ca-certificates \
        && \
    rm -rf /var/lib/apt/lists/*

# FD Headless binary (tar.gz auto-extracted by ADD)
ADD ref/Linux_HeadlessFD/FD_Headless-linux.gtk.x86_64-8.6.0-SNAPSHOT-260419.0754.tar.gz /opt/fd/

# FD CLI args single source of truth (A.2 output)
COPY docker/fd-headless/scripts/fd-args.sh /opt/fd/fd-args.sh
RUN chmod +x /opt/fd/fd-args.sh

# Entrypoint (TODO A.4 will populate)
COPY docker/fd-headless/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/workspace"]
ENTRYPOINT ["/entrypoint.sh"]
