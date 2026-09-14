(* A variable of a struct type with a bounded member: storage is the declared
 * width and the member default-initialises empty.
 *)
TYPE
  REC : STRUCT
    F : STRING[10];
    N : INT;
  END_STRUCT;
END_TYPE

PROGRAM prog0
  VAR
    R : REC;
  END_VAR
  R.N := 1;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
