(* Bounded strings inside a FUNCTION body: its variables are plain C objects, so the
 * accessor macros that normally carry the widen/narrow conversions do not apply.
 * Covers a bounded local and a bounded member of the function's return value.
 *)
TYPE
  REC : STRUCT
    F : STRING[10];
  END_STRUCT;
END_TYPE

FUNCTION MAKE_REC : REC
VAR_INPUT
  S : STRING;
END_VAR
VAR
  B : STRING[10];
END_VAR
  B := S;
  MAKE_REC.F := B;
END_FUNCTION

PROGRAM prog0
VAR
  R : REC;
END_VAR
  R := MAKE_REC(S := '123456789012345');
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
