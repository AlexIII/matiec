#!/bin/sh
# Native Linux build of iec2c inside the matiec-mingw image, for fast iteration.
# Mounts: /src = source tree, built in place (the mingw build copies instead).
set -eu
cd /src
if [ ! -f Makefile ]; then
    autoreconf -i
    ./configure
fi
make -j"$(nproc)"
