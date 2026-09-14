(* Pre-existing behaviour probe: a plain (unbounded) STRING as a TYPE...STRUCT member,
 * with a member default, without one, and overridden by a per-instance initializer.
 * No STRING[n] anywhere - this must already work before X-37a builds on it.
 *)
TYPE
  REC : STRUCT
    F : STRING := 'abc';
    G : STRING;
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
