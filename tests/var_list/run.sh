#!/bin/sh
# Compile each fixture with iec2c and assert on the generated VARIABLES.csv.
# Usage: run.sh   (IEC2C=<path> overrides the compiler; default ../../iec2c)
set -u
cd "$(dirname "$0")"
IEC2C=${IEC2C:-../../iec2c}
rc=0

want() { grep -qF -- "$1" "$csv" || { echo "MISSING: $1"; frc=1; }; }
deny() { grep -qF -- "$1" "$csv" && { echo "UNEXPECTED: $1"; frc=1; }; }

compile() {
  name=$1; frc=0
  out=out/$name
  rm -rf "$out"; mkdir -p "$out"
  csv="$out/VARIABLES.csv"
  "$IEC2C" -I ../../lib -T "$out" "$name.st" > "$out/log" 2>&1 || { echo "FAIL $name: iec2c failed, see $out/log"; rc=1; return 1; }
}

check_rows() {
  awk -F';' '/^[0-9]+;(VAR|FB|EXT);/ { if ($1 != n++) { print "NUMBERING GAP at " $0; bad=1 } } END { exit bad }' "$csv" || frc=1
  awk -F';' '/^[0-9]+;[A-Z]+;/ && NF != 8 { print "MALFORMED ROW: " $0; bad=1 } END { exit bad }' "$csv" || frc=1
}

finish() {
  [ $frc -eq 0 ] && echo "PASS $name" || { echo "FAIL $name"; rc=1; }
}

if compile struct_leaf; then
  want ';VAR;CFG.RES.INST.P.X;CFG.RES.INST.P.X;UDINT;UDINT;0;'
  want ';VAR;CFG.RES.INST.P.S;CFG.RES.INST.P.S;STRING;__STRING_7;0;'
  want ';VAR;CFG.RES.INST.P.IN1.A;CFG.RES.INST.P.IN1.A;UDINT;UDINT;0;'
  want ';VAR;CFG.RES.INST.F.ST.X;CFG.RES.INST.F.ST.X;UDINT;UDINT;0;'
  want ';VAR;CFG.RES.INST.F.ST.IN1.A;CFG.RES.INST.F.ST.IN1.A;UDINT;UDINT;0;'
  deny ';STRUCT;'
  deny 'P.ARR'
  deny 'P;OUTER'
  check_rows
  finish
fi

# FB instances and structs declared as comma lists (a, b, c : T)
if compile decl_list; then
  want ';FB;CFG.RES.INST.F.T3;CFG.RES.INST.F.T3;TON;;0;'
  want ';VAR;CFG.RES.INST.F.T3.ET;CFG.RES.INST.F.T3.ET;TIME;TIME;0;'
  want ';FB;CFG.RES.INST.G3;CFG.RES.INST.G3;FB1;;0;'
  want ';VAR;CFG.RES.INST.G2.T2.Q;CFG.RES.INST.G2.T2.Q;BOOL;BOOL;0;'
  want ';VAR;CFG.RES.INST.G3.T3.ET;CFG.RES.INST.G3.T3.ET;TIME;TIME;0;'
  want ';VAR;CFG.RES.INST.S2.A;CFG.RES.INST.S2.A;UDINT;UDINT;0;'
  want ';VAR;CFG.RES.INST.S3.B;CFG.RES.INST.S3.B;INT;INT;0;'
  want ';VAR;CFG.RES.INST.N;CFG.RES.INST.N;INT;INT;0;'
  deny 'CFG.RES.INST.F.IN;'
  deny 'CFG.RES.INST.IN;'
  deny 'CFG.RES.INST.A;'
  n=$(grep -c ';FB;' "$csv")
  [ "$n" = "17" ] || { echo "FB ROWS: expected 17, got $n"; frc=1; }
  check_rows
  finish
fi

exit $rc
