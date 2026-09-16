#!/bin/sh
# Cross-compile matiec to a static 32-bit Windows iec2c.exe.
# Mounts: /src = source tree, /out = receives iec2c.exe.
# /src is copied first, so the host's own native build state is left alone.
set -eu

HOST=i686-w64-mingw32
TREE=/work/build

# captured before the .git-excluding tar copy below
GITVERSION=$(git -C /src rev-parse --short HEAD 2> /dev/null || true)

rm -rf "$TREE"
mkdir -p "$TREE" /out

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

# Discard configure state produced by a host build; everything is regenerated.
rm -rf config.status config.log autom4te.cache
find . -name Makefile -type f -delete

autoreconf -i
./configure --host="$HOST" LDFLAGS="-static"
make -j"$(nproc)" GITVERSION="$GITVERSION"

"$HOST-strip" iec2c.exe
cp iec2c.exe /out/iec2c.exe

echo "--- built ---"
file /out/iec2c.exe
