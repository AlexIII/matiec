(* Regression test for f7185c6 (beremiz/matiec): the stage3 enum-symtable
 * population visitors walked into aggregate initializer *values*, not just
 * their *specifications*, and crashed treating a referenced enum value
 * (RED, here) as if it were declaring a new one.
 *
 * Requires -p (forward references) since the STRUCT type is used the same file.
 *
 * Expect: clean compile, exit 0.
 *)
TYPE
  color_t : (RED, GREEN, BLUE);
  my_struct : STRUCT
    c : color_t;
  END_STRUCT;
END_TYPE

PROGRAM prog0
  VAR
    s : my_struct := (c := RED);
  END_VAR
  s.c := s.c;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
