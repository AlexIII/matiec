#!/bin/sh
# R2 gate: for any program that declares no STRING[n], the generated C must be
# byte-identical to what the reference compiler produces.
#
# Usage: regress.sh [reference iec2c]     (default /out/iec2c.ref)
#
# Each run is given 60s: a couple of the AnnexF examples make matiec loop
# forever after a parse error, and both compilers have to be treated alike.
#
# The corpus is matiec's own AnnexF examples plus, when the SDK tree is next to
# this one, its whole IEC library (PLC_LIB.ST pulls in every POU) compiled as one
# program with the flags the SDK build actually uses.
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
REF=${1:-/out/iec2c.ref}
case $REF in /*) ;; *) REF=$ROOT/$REF ;; esac
NEW=$ROOT/iec2c
LIB=$ROOT/lib
SDK=../kush2-sdk
WORK=/tmp/regress
FLAGS="-l -e -p -i -b -r -R"

[ -x "$REF" ] || { echo "no reference compiler at $REF"; exit 2; }
rm -rf "$WORK"; mkdir -p "$WORK"

corpus="$(ls AnnexF/*.txt) tests/string_widths/plain_string.st"

# The SDK library only resolves its relative includes from a project directory
# two levels below the SDK root.
sdk_corpus=""
if [ -d "$SDK/kush2_iec_lib" ]; then
    mkdir -p "$SDK/scratch/x37-regress"
    sdk_corpus="$SDK/scratch/x37-regress/kush2_lib.st"
    cat > "$sdk_corpus" <<'PROG'
{#include "../../kush2_iec_lib/PLC_LIB.ST" }

PROGRAM MAIN_PRG
  VAR
    D : DISPLAY4;
    MSG : STRING := 'hello';
  END_VAR
  D(Name := MSG);
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK Main(INTERVAL := T#20ms, PRIORITY := 0);
    PROGRAM Inst0 WITH Main : MAIN_PRG;
  END_RESOURCE
END_CONFIGURATION
PROG
    corpus="$corpus $sdk_corpus"
fi

rc=0
checked=0
for f in $corpus; do
    name=$(basename "$f" | tr -c 'A-Za-z0-9._-' '_')
    # The SDK entry is a thin wrapper, so its own text says nothing about whether
    # the library it pulls in declares a width. Once Phase 2b retypes those POUs
    # this skip is what keeps a legitimate difference from reading as a failure.
    scan=$f
    [ "$f" = "$sdk_corpus" ] && scan="$f $(find "$SDK/kush2_iec_lib" -name '*.ST' -o -name '*.txt' 2>/dev/null)"
    if grep -q 'STRING *\[' $scan 2>/dev/null; then echo "SKIP (declares STRING[n]) $f"; continue; fi
    mkdir -p "$WORK/ref/$name" "$WORK/new/$name"
    # Each program is compiled from its own directory: matiec resolves a
    # {#include "..."} against the current directory, and the SDK library's
    # includes are written relative to a project directory.
    dir=$(dirname "$f"); base=$(basename "$f")
    (cd "$dir" && timeout 60 "$REF" $FLAGS -I "$LIB" -T "$WORK/ref/$name" "$base") > "$WORK/ref/$name/.stdout" 2> "$WORK/ref/$name/.stderr"
    echo "exit=$?" >> "$WORK/ref/$name/.stdout"
    (cd "$dir" && timeout 60 "$NEW" $FLAGS -I "$LIB" -T "$WORK/new/$name" "$base") > "$WORK/new/$name/.stdout" 2> "$WORK/new/$name/.stderr"
    echo "exit=$?" >> "$WORK/new/$name/.stdout"
    checked=$((checked+1))
    if diff -r "$WORK/ref/$name" "$WORK/new/$name" > "$WORK/$name.diff" 2>&1; then
        # Say so when a corpus entry generated nothing: identical failure is not coverage.
        if [ "$(ls "$WORK/new/$name" | wc -l)" -le 2 ]; then
            echo "SAME (but no code generated, both compilers) $f"
        else
            echo "SAME $f"
        fi
    else
        echo "DIFFERS $f"
        sed -n '1,20p' "$WORK/$name.diff" | sed 's/^/  /'
        rc=1
    fi
done

[ -n "$sdk_corpus" ] && rm -rf "$SDK/scratch/x37-regress"
echo "$checked programs compared"
exit $rc
