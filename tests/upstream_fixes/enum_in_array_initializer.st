(* Regression test for f7185c6, exercising the array_spec_init_c path (rather
 * than initialized_structure_c) and depending on 5b9968b (see
 * array_initializer_overflow.st) to reach codegen at all: without 5b9968b,
 * narrow_candidate_datatypes_c never assigns a datatype to the
 * array_initial_elements_list_c node, and this crashes downstream in
 * generate_c_base.cc instead of exercising f7185c6's fix.
 *
 * Requires -p (forward references).
 *
 * Expect: clean compile, exit 0.
 *)
TYPE
  color_t : (RED, GREEN, BLUE);
END_TYPE

PROGRAM prog0
  VAR
    colors : ARRAY[0..2] OF color_t := [RED, GREEN, BLUE];
  END_VAR
  colors[0] := colors[0];
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
