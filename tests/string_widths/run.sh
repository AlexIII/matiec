#!/bin/sh
# Compile every fixture with the freshly built iec2c and report per-fixture status.
#   <name>.expect       every line must appear in the generated C
#   <name>.expect_fail  the compile must fail, and every line must appear on stderr
#   <name>.main.c       built against the generated C and run; non-zero exit is a failure
# Usage: run.sh [fixture ...]   (default: all *.st)
set -u
cd "$(dirname "$0")"
IEC2C=../../iec2c
rc=0

check_lines() {  # check_lines <expectation file> <files to search...>
    ef=$1; shift
    while IFS= read -r want; do
        want=$(printf %s "$want" | tr -d "")   # the fixtures may be checked out with CRLF
        [ -z "$want" ] && continue
        if ! grep -qF -- "$want" "$@" 2>/dev/null; then
            echo "  MISSING: $want"
            rc=1
        fi
    done < "$ef"
}

for f in ${*:-*.st}; do
    name=$(basename "$f" .st)
    out="out/$name"
    rm -rf "$out"; mkdir -p "$out"
    "$IEC2C" -I ../../lib -T "$out" "$f" > "$out/stdout.txt" 2> "$out/stderr.txt"
    status=$?

    if [ -f "$name.expect_fail" ]; then
        if [ $status -eq 0 ]; then
            echo "FAIL(compiled, expected an error) $name"
            rc=1
        else
            echo "PASS(rejected, exit=$status) $name"
            check_lines "$name.expect_fail" "$out/stderr.txt"
        fi
        continue
    fi

    if [ $status -ne 0 ]; then
        echo "FAIL(exit=$status) $name"
        sed -n '1,10p' "$out/stderr.txt" | sed 's/^/  /'
        rc=1
        continue
    fi
    echo "PASS(compiled) $name"
    [ -f "$name.expect" ] && check_lines "$name.expect" "$out"/*.c "$out"/*.h "$out"/VARIABLES.csv

    if [ -f "$name.main.c" ]; then
        if ! gcc -w -I ../../lib/C -I "$out" "$name.main.c" "$out/config.c" "$out/res.c" -o "$out/run" > "$out/cc.txt" 2>&1; then
            echo "  GENERATED C DOES NOT COMPILE (see $out/cc.txt)"
            sed -n '1,10p' "$out/cc.txt" | sed 's/^/    /'
            rc=1
        elif ! "$out/run" > "$out/run.txt" 2>&1; then
            echo "  BEHAVIOUR TEST FAILED:"
            sed 's/^/    /' "$out/run.txt"
            rc=1
        else
            sed 's/^/  /' "$out/run.txt"
        fi
    fi
done
exit $rc
