# Upstream (beremiz) merge analysis

Reviewed 2026-08-28 against `beremiz/default` @ `7949c0b` (2026-05-03),
merge-base `97d311d` (2024-12-13). **Nothing was merged.**

Next review: `git log 7949c0b..beremiz/default` lists only what is new since
this one, so only those commits need classifying.

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
