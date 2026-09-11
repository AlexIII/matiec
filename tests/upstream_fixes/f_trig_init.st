(* Functional regression test for b082b44 / b3df950 (thiagoralves/matiec,
 * f-trigger-fix branch): F_TRIG's internal memory M was seeded FALSE. Since
 * F_TRIG_body__() computes Q := !CLK && !M *before* updating M := !CLK, an M
 * of FALSE means the very first evaluation with CLK still at its IEC-mandated
 * initial value of FALSE reports Q = TRUE -- a spurious trigger with no
 * preceding rising edge. M seeded TRUE fixes this (see f_trig_main.c, which
 * actually runs the compiled cycle and checks Q).
 *)
PROGRAM prog0
  VAR
    trig : F_TRIG;
    clk_in : BOOL := FALSE;
  END_VAR
  VAR_EXTERNAL
    q_out : BOOL;
  END_VAR
  trig(CLK := clk_in);
  q_out := trig.Q;
END_PROGRAM

CONFIGURATION config
  VAR_GLOBAL
    q_out : BOOL;
  END_VAR
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
