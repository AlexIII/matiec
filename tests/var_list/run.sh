#!/bin/sh
# Compile the fixture with iec2c and assert on the generated VARIABLES.csv.
# Usage: run.sh   (IEC2C=<path> overrides the compiler; default ../../iec2c)
set -u
cd "$(dirname "$0")"
IEC2C=${IEC2C:-../../iec2c}
rc=0
out=out/struct_leaf
rm -rf "$out"; mkdir -p "$out"
"$IEC2C" -I ../../lib -T "$out" struct_leaf.st > "$out/log" 2>&1 || { echo "FAIL iec2c: see $out/log"; exit 1; }
csv="$out/VARIABLES.csv"

want() { grep -qF -- "$1" "$csv" || { echo "MISSING: $1"; rc=1; }; }
deny() { grep -qF -- "$1" "$csv" && { echo "UNEXPECTED: $1"; rc=1; }; }

want ';VAR;CFG.RES.INST.P.X;CFG.RES.INST.P.X;UDINT;UDINT;0;'
want ';VAR;CFG.RES.INST.P.S;CFG.RES.INST.P.S;STRING;__STRING_7;0;'
want ';VAR;CFG.RES.INST.P.IN1.A;CFG.RES.INST.P.IN1.A;UDINT;UDINT;0;'
want ';VAR;CFG.RES.INST.F.ST.X;CFG.RES.INST.F.ST.X;UDINT;UDINT;0;'
want ';VAR;CFG.RES.INST.F.ST.IN1.A;CFG.RES.INST.F.ST.IN1.A;UDINT;UDINT;0;'
deny ';STRUCT;'
deny 'P.ARR'
deny 'P;OUTER'

awk -F';' '/^[0-9]+;(VAR|FB|EXT);/ { if ($1 != n++) { print "NUMBERING GAP at " $0; bad=1 } } END { exit bad }' "$csv" || rc=1

[ $rc -eq 0 ] && echo "PASS struct_leaf" || echo "FAIL struct_leaf"
exit $rc
