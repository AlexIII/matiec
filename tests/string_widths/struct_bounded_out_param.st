(* C4 parity: a bounded struct member receiving a function block output behaves
 * exactly as the bounded variable in bounded_out_param does - a truncating
 * __SET_STRVAR at the declared width, not an unchecked copy.
 *)
TYPE
  REC : STRUCT
    F : STRING[10];
  END_STRUCT;
END_TYPE

FUNCTION_BLOCK SRC
VAR_OUTPUT
  O : STRING;
END_VAR
  O := 'abcdefghijklmno';
END_FUNCTION_BLOCK

PROGRAM prog0
  VAR
    R : REC;
    S : SRC;
  END_VAR
  S(O => R.F);
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
