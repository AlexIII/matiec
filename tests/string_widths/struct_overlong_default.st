(* R6: a member default longer than the declared width is a build error,
 * not a silent truncation.
 *)
TYPE
  REC : STRUCT
    F : STRING[10] := 'ABCDEFGHIJK';
  END_STRUCT;
END_TYPE

PROGRAM prog0
  VAR
    R : REC;
  END_VAR
  R.F := R.F;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
