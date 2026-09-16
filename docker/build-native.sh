#!/bin/sh
# Native Linux build of iec2c, always from a fresh copy (same pattern as build-win.sh)
# so it can't fail from leftover state in a previous build. Mounts: /src = source tree.
set -eu

TREE=/work/build-native

GITVERSION=$(git -C /src rev-parse --short HEAD 2> /dev/null || true)

rm -rf "$TREE"
mkdir -p "$TREE"

tar -C /src -cf - \
    --exclude=./.git \
    --exclude=./docker \
    --exclude=./dist \
    --exclude=./iec2c \
    --exclude=./iec2iec \
    --exclude='*.o' \
    --exclude='*.a' \
    --exclude='*.exe' \
    . | tar -C "$TREE" -xf -

cd "$TREE"

autoreconf -i
./configure
make -j"$(nproc)" GITVERSION="$GITVERSION"

mkdir -p /src/dist
cp iec2c /src/dist/iec2c
