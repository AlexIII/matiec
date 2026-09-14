(* Bounded counterpart of struct_plain_init: member default, no default, and a
 * per-instance initializer, all at a declared width. Any difference in behaviour
 * between the two fixtures is attributable to STRING[n].
 *)
TYPE
  REC : STRUCT
    F : STRING[10] := 'abc';
    G : STRING[10];
    N : INT := 7;
  END_STRUCT;
END_TYPE

PROGRAM prog0
  VAR
    R1 : REC;
    R2 : REC := (F := 'xy', N := 9);
  END_VAR
  R1.N := R1.N;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
