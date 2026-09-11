# Upstream (beremiz) merge analysis

Reviewed 2026-08-28 against `beremiz/default` @ `7949c0b` (2026-05-03),
merge-base `97d311d` (2024-12-13). **Nothing was merged.**

Next review: `git log 7949c0b..beremiz/default` lists only what is new since
this one, so only those commits need classifying.

## 2026-09-11 — seven commits merged, on `worktree-adopt-upstream-fixes` (off `main`)

`default` had stalled at `7949c0b`; `beremiz/master` kept going to `b5ecabe`
(2026-08-14) and is where the commits below live — track `master` from now on.
A follow-up survey also covered `thiagoralves/matiec`, `Autonomy-Logic/matiec`
and `embox/matiec`; nothing there duplicates or supersedes what's below except
where noted. None of these were in the "Commits considered" list further down
in this file — they postdate that review's cutoff.

Cherry-picked with `-x` (commit message keeps the source hash), all applying
clean or with a trivial auto-merge:

- `c1df93e` (beremiz) — struct initializer silently bound to the wrong member:
  `list_c::find_element()` used a strict-weak-ordering "less than" functor as
  an equality test, so it returned the first member that sorted
  alphabetically at-or-after the target name instead of the exact match.
- `12e4828` (beremiz) — `RETAIN` silently dropped after the first global in a
  shared `VAR_GLOBAL RETAIN` block.
- `5b9968b` (beremiz) — **discovered as a hard prerequisite for `c73c55d`
  while writing tests, not part of the original picklist.** Adds the
  `fill_candidate_datatypes_c`/`narrow_candidate_datatypes_c` visitors for
  `array_initial_elements_list_c`. Without it, `c73c55d`'s check reads
  `symbol->datatype` off that node, finds it NULL (nothing ever sets it), and
  silently no-ops — the array-initializer-overflow test in this commit still
  hits the exact same internal compiler error `c73c55d` claims to fix. Also
  needed for the array-of-enum half of `f7185c6` (a plain enum-in-struct
  initializer doesn't need it, but `ARRAY[..] OF enum_t := [...]` does).
- `f7185c6` (beremiz) — crash referencing (not declaring) an enum value inside
  a struct/array initializer.
- `c73c55d` (beremiz) — too many initial values for an array was an internal
  compiler error instead of a stage-3 diagnostic. **Depends on `5b9968b`** —
  see above.
- `b082b44` + `b3df950` (thiagoralves, `f-trigger-fix` branch — never merged
  upstream even by its own author) — `F_TRIG`'s internal memory `M` seeded
  `FALSE` instead of `TRUE`, causing a spurious `Q = TRUE` on the very first
  cycle when `CLK` is still at its IEC-mandated initial value of `FALSE`.

Regression tests for all of the above: `tests/upstream_fixes/run.sh` (one
fixture per fix; the F_TRIG one is compiled *and run*, not just compiled — it
checks the actual output value). All six pass.

**Re-confirmed: still do not take `0dff6e0` / `b807242`** (see Conclusions
below) — they reappear on `master` too, and `embox/matiec` independently
reimplemented the same `IEC_TIMESPEC` change as `9eba44f`. Same rejection
applies regardless of which fork it comes from.

**Not yet triaged**, spotted on `master` while surveying but not individually
vetted (no dry-run, no diff read): `acf5513` ("Rework SFC codegen so that all
states are in instance tree"), `9ac98cb` ("Wrap simple types that are inside
structures and arrays"), the `9d24514`/`5bfa3c1`/`3cdc69f` POUS.c-inclusion
back-and-forth, `2c6b459`, `07f032a`, `3145bc2`, `55cb455`, `c52ba66`,
`45d9a8d`, `b05a98e`, `d14e9a9`, `e3193a9`, `2349573`, `68eb808`, `5845351`,
`79410c7`. The first two in particular look substantive enough to deserve
their own review pass before assuming they're safe.

Also found but out of scope for a fix-only pass: `Autonomy-Logic/matiec` has
`4185fde` ("Add GCC-style error reporting with source context", pure DX, no
codegen change — an easy separate pick) and a non-standard extension
(`b8dc496` + array-of-FB support) that's a feature decision, not a bugfix.

## State at review time

25 commits ahead upstream, 7 ahead here. A read-only `git merge-tree` conflicted
in two files only, both ours and both small:

- `lib/C/iec_std_lib.h` — our `__STRING_LITERAL` macro and `__iec_error()`
- `stage4/generate_c/generate_c_il.cc` — our array function parameter fix

Upstream does not touch the string literal visitor in `generate_c_base.cc`, so
`KNOWN_ISSUES.md` still applies and our lexer change is unaffected.

## Commits considered

**Correctness in generated C**
`2b595ef` explicit casts for untyped numeric literals ·
`c7e83ef` multiple resources: static declarations ·
`1e4bb24` multiple resources: shared task names ·
`2f78973` config globals from POUs instantiated in resources ·
`61b4295` generate_c_sfc.cc update

**Generated symbol naming** — stays inside generated code; our runtime only
references `config_init__` / `config_run__`, so it costs nothing
`b5ecabe` `a4bea86` prefix IEC function C names with `___` ·
`bb12c0b` `9d4c537` `bd624e9` `_data__` suffix on POU data structs ·
`681c644` `fed726a` `823fcbb` DECLARE_GLOBAL_PROTOTYPE_FB in accessors

**Type layout** — rejected, see conclusions
`0dff6e0` IEC_TIMESPEC to int64 tv_sec + int32 tv_nsec ·
`b807242` pack DT and STRING structs

**Freestanding / no-libc** — the most interesting part for a bare-metal target
`7810b24` generated code calls the runtime, not libC ·
`915c827` PLC_NO_DEBUG define instead of an extern `__DEBUG`

**Warning cleanup**
`4f87a31` `28071ba` `b23e745` `59f5bb9` `7949c0b`

**No net effect** `dba6829` reverted by `4149c0a` ·
**Plumbing** `ade68e7` merge of ooplc/default

## Conclusions

Not merged: nothing here fixes a defect we currently hit. The resource fixes
address multi-resource / multi-task configurations, and we use one of each.

**Do not take `0dff6e0` / `b807242`.** IEC_TIMESPEC grows 8 to 12 bytes on rv32,
and `packed` makes every `tv_sec` read a byte-wise reassembly — measured at -O3
with the SDK's gcc, one `lw` becomes roughly sixteen instructions, in the per
scan timer path. The upstream motive is a struct of identical size on 32b and
64b hosts, which serves the Beremiz host-side debugger; we build for rv32 only.
`iec_types.h` is a runtime header and the compiler does not bake the layout into
generated code, so keeping our layout while taking the rest is safe.

**`7810b24` is the one worth wanting.** It stops generated code reaching into
stdio.h / math.h / string.h, which suits a `-nostdlib -ffreestanding` build. The
cost is supplying roughly thirteen `iec_lib_*` symbols; our existing
`st_snprintf` does not fit `iec_lib_snprintf` (IEC_STRING format plus void\*\*
args, versus printf varargs), so it needs an adapter rather than a rename.

**The bulk of the work is not the merge itself** but the SDK's vendored copy of
`lib/`, which is patched: `accessor.h` differs by 71 lines
(MATIEC_LIB_DISABLE_FLAGS), `iec_types_all.h` by 14, `iec_std_lib.h` by 2,
`ieclib.txt` by 3. Upstream rewrites `accessor.h` and the `iec_std_*` headers
heavily, so those patches have to be re-applied by hand.

If merging later, do it on its own branch, with a full compiler rebuild and an
end-to-end build of a real project as the gate.
