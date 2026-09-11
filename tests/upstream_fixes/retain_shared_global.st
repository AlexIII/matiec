(* Regression test for 12e4828 (beremiz/matiec): the per-name loop in
 * global_var_list_c::visit() reset current_varqualifier to none_vq after emitting
 * the first global of a shared VAR_GLOBAL RETAIN block, so every global after the
 * first fell back to print_retain()'s "retain" branch -- the literal identifier
 * `retain`, which config_init__() defines as 0 -- silently losing RETAIN.
 *
 * Expect: every one of g1, g2, g3 generates __INIT_GLOBAL(..., 1) in config.c,
 * not just g1.
 *)
PROGRAM prog0
  VAR
    x : INT;
  END_VAR
  x := 1;
END_PROGRAM

CONFIGURATION config
  VAR_GLOBAL RETAIN
    g1, g2, g3 : INT;
  END_VAR
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
