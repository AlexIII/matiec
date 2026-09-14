(* R4: narrowing writes and widening reads through a direct member, a member of a
 * nested struct, and a struct passed as a FUNCTION_BLOCK input - the DISPLAY4 shape.
 *)
TYPE
  INNER : STRUCT
    D : STRING[10];
  END_STRUCT;
  OUTER : STRUCT
    I : INNER;
    T : STRING[10];
  END_STRUCT;
END_TYPE

FUNCTION_BLOCK SINK
VAR_INPUT
  LINE : INNER;
END_VAR
VAR_OUTPUT
  SEEN : STRING;
END_VAR
  SEEN := LINE.D;
END_FUNCTION_BLOCK

PROGRAM prog0
  VAR
    WIDE : STRING := '123456789012345678901234567890';
    O    : OUTER;
    S    : SINK;
    BACK : STRING;
  END_VAR
  O.T   := WIDE;
  O.I.D := WIDE;
  BACK  := O.I.D;
  S(LINE := O.I);
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
