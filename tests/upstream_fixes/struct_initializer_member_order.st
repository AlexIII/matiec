(* Regression test for c1df93e (beremiz/matiec): list_c::find_element() used
 * nocasecmp_c (a strict-weak "less than" functor) as an equality test. !ncc(a,b)
 * actually means a >= b, so the lookup returned the first member that sorts
 * alphabetically at-or-after the target name, instead of the exact match.
 *
 * "b" is declared before "a" here specifically to trigger the bug: looking up
 * "a" would incorrectly stop at "b" (the first element, which sorts after "a").
 *
 * Expect: generated C initializes the struct as {7,5} (b=7, a=5), matching the
 * ST initializer (a := 5, b := 7) -- not both fields getting the same value.
 *)
TYPE
  my_struct : STRUCT
    b : INT;
    a : INT;
  END_STRUCT;
END_TYPE

PROGRAM prog0
  VAR
    s : my_struct := (a := 5, b := 7);
  END_VAR
  s.a := s.a;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
