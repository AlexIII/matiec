(* Regression test for c1df93e (beremiz/matiec): list_c::find_element() used
 * nocasecmp_c (a strict-weak "less than" functor) as an equality test. !ncc(a,b)
 * actually means a >= b, so the lookup returned the first member that sorts
 * alphabetically at-or-after the target name, instead of the exact match.
 *
 * "b" is declared before "a" here specifically to trigger the bug: looking up
 * "a" would incorrectly stop at "b" (the first element, which sorts after "a").
 *
 * IMPORTANT: this lookup is used for datatype-compatibility checking of the
 * initializer value, not for choosing which field the value is written to in
 * codegen (that goes through structure_element_name directly, unaffected by
 * this bug) -- a fixture with same-typed fields will compile "correctly" by
 * accident both with and without the fix, and prove nothing. b and a are
 * given deliberately incompatible types (STRING vs INT) so the bug produces
 * an observable false "incompatible datatype" error: with the bug, "a := 5"
 * gets checked against b's type (STRING) instead of a's (INT).
 *
 * Expect: clean compile, exit 0 (before the fix: a false datatype error).
 *)
TYPE
  my_struct : STRUCT
    b : STRING;
    a : INT;
  END_STRUCT;
END_TYPE

PROGRAM prog0
  VAR
    s : my_struct := (a := 5, b := 'hi');
  END_VAR
  s.a := s.a;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
