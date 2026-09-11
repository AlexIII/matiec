#!/bin/sh
# Regression tests for the fixes cherry-picked into this branch from other
# matiec forks -- see UPSTREAM_MERGE_NOTES.md for the source commits and the
# reasoning behind each pick.
#
# Usage (from the repo root, iec2c already built there):
#   MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src \
#       --entrypoint sh matiec-mingw /src/tests/upstream_fixes/run.sh
set -u
cd "$(dirname "$0")"
IEC2C=../../iec2c
LIB=../../lib
rc=0
out=out
rm -rf "$out"
mkdir -p "$out"

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; rc=1; }

# 1. RETAIN must survive for every global in a shared VAR_GLOBAL RETAIN block (12e4828)
d="$out/retain_shared_global"; mkdir -p "$d"
if "$IEC2C" -I "$LIB" -T "$d" retain_shared_global.st > "$d/log" 2>&1; then
    n=$(grep -c '__INIT_GLOBAL(INT,G[123],__INITIAL_VALUE(0),1)' "$d/config.c")
    if [ "$n" = "3" ]; then pass "retain_shared_global"
    else fail "retain_shared_global" "expected all 3 globals retained, got $n (see $d/config.c)"; fi
else
    fail "retain_shared_global" "iec2c failed to compile (see $d/log)"
fi

# 2. struct initializer must bind to the named member, not the first alphabetical match (c1df93e)
d="$out/struct_initializer_member_order"; mkdir -p "$d"
if "$IEC2C" -I "$LIB" -T "$d" struct_initializer_member_order.st > "$d/log" 2>&1; then
    if grep -q 'MY_STRUCT temp = {7,5}' "$d/POUS.c"; then pass "struct_initializer_member_order"
    else fail "struct_initializer_member_order" "expected 'MY_STRUCT temp = {7,5}' (b=7, a=5) in $d/POUS.c"; fi
else
    fail "struct_initializer_member_order" "iec2c failed to compile (see $d/log)"
fi

# 3. enum value referenced (not declared) inside a struct initializer must not crash (f7185c6)
d="$out/enum_in_struct_initializer"; mkdir -p "$d"
if "$IEC2C" -p -I "$LIB" -T "$d" enum_in_struct_initializer.st > "$d/log" 2>&1; then pass "enum_in_struct_initializer"
else fail "enum_in_struct_initializer" "iec2c failed to compile (see $d/log)"; fi

# 4. same, through an array initializer -- also exercises the 5b9968b prerequisite (f7185c6)
d="$out/enum_in_array_initializer"; mkdir -p "$d"
if "$IEC2C" -p -I "$LIB" -T "$d" enum_in_array_initializer.st > "$d/log" 2>&1; then pass "enum_in_array_initializer"
else fail "enum_in_array_initializer" "iec2c failed to compile (see $d/log)"; fi

# 5. too many array initial values must be a clean stage-3 error, not an ICE (c73c55d + 5b9968b)
d="$out/array_initializer_overflow"; mkdir -p "$d"
"$IEC2C" -p -I "$LIB" -T "$d" array_initializer_overflow.st > "$d/log" 2>&1
ec=$?
if [ $ec -eq 0 ]; then
    fail "array_initializer_overflow" "expected a compile error (too many initial values), but it compiled"
elif grep -qi "internal compiler error" "$d/log"; then
    fail "array_initializer_overflow" "still an ICE, not a clean diagnostic (see $d/log)"
elif grep -q "Too many initial values for array" "$d/log"; then
    pass "array_initializer_overflow"
else
    fail "array_initializer_overflow" "compile failed, but not with the expected message (see $d/log)"
fi

# 6. F_TRIG must not report a spurious trigger on cycle 1 when CLK starts at its
#    IEC-mandated initial value of FALSE (b082b44 + b3df950) -- compiled and run, not just compiled.
d="$out/f_trig_init"; mkdir -p "$d"
if "$IEC2C" -I "$LIB" -T "$d" f_trig_init.st > "$d/log" 2>&1; then
    cp f_trig_main.c "$d/"
    if gcc -I "../../lib/C" -c "$d/config.c" -o "$d/config.o" 2>"$d/build.log" \
        && gcc -I "../../lib/C" -c "$d/res.c" -o "$d/res.o" 2>>"$d/build.log" \
        && gcc -I "../../lib/C" "$d/f_trig_main.c" "$d/config.o" "$d/res.o" -o "$d/f_trig_test" 2>>"$d/build.log"
    then
        if "$d/f_trig_test" > "$d/run.log" 2>&1; then pass "f_trig_init"
        else fail "f_trig_init" "spurious trigger on cycle 1 (see $d/run.log)"; fi
    else
        fail "f_trig_init" "gcc failed to build the generated C (see $d/build.log)"
    fi
else
    fail "f_trig_init" "iec2c failed to compile (see $d/log)"
fi

echo
if [ $rc -eq 0 ]; then echo "SUCCESS -> all tests passed!"
else echo "FAILURE -> at least one test failed!"; fi
exit $rc
