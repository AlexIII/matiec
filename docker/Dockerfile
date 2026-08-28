# Build environment for cross-compiling matiec to a static 32-bit (i686)
# Windows iec2c.exe. See README.build section 3.

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        bison \
        build-essential \
        file \
        flex \
        libtool \
        mingw-w64 \
    && rm -rf /var/lib/apt/lists/*

COPY build-win.sh /usr/local/bin/build-win.sh
RUN chmod +x /usr/local/bin/build-win.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/build-win.sh"]
