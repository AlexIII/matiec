(* Regression test for c73c55d (beremiz/matiec): too many initial values for
 * an array used to reach generate_c_vardecl.cc and hit an internal compiler
 * error instead of being caught in stage 3.
 *
 * c73c55d alone is not enough: its check reads symbol->datatype off the
 * array_initial_elements_list_c node, which is only ever set by 5b9968b ("Fix
 * initialization of arrays of non-simple types" -- it adds the
 * fill_candidate_datatypes_c/narrow_candidate_datatypes_c visitors for that
 * node). Without 5b9968b this test still reaches the same internal compiler
 * error, just as before c73c55d -- discovered while writing this test.
 *
 * Requires -p (forward references), since int_arr_t is used in the same file.
 *
 * Expect: a clean stage-3 error ("Too many initial values for array"),
 * exit != 0, and specifically NOT "Internal compiler error".
 *)
TYPE
  int_arr_t : ARRAY[0..1] OF INT;
END_TYPE

PROGRAM prog0
  VAR
    arr : int_arr_t := [1,2,3];
  END_VAR
  arr[0] := arr[0];
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
