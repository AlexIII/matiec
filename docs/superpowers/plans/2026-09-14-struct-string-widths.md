# `STRING[n]` as a `TYPE ... STRUCT` Field — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a `TYPE ... STRUCT` element declare a bounded string (`F : STRING[10];`) that occupies 11 bytes instead of 127, closing X-37 constraint C8 — the gap that blocks 12 of `DISPLAY4`'s 14 `STRING` fields per instance, and with them the large majority of X-37's measured RAM win.

**Architecture:** One new grammar alternative routes `single_byte_string_spec` into the existing polymorphic `spec_init` slot of `structure_element_declaration`. Six already-verified mechanisms (spec/init separation, base-type resolution, member type lookup, `__STRING_n` type printing, implicit-typedecl ordering, and stage 3's non-involvement) then handle layout and the widen/narrow crossings with no change at all. Only four small additions remain: an initial value for the bounded spec node, width-typed literals inside struct initializers, an overlong-default diagnostic, and a signature-type override.

**Tech Stack:** C++ (matiec compiler, stages 1-4, GNU autotools), IEC 61131-3 Structured Text fixtures under `tests/string_widths/`, Docker toolchain (`docker/build-native.sh`) since this repo is worked on from Windows with no native Linux toolchain.

**Spec:** `../../../../kush2-sdk/docs/specs/X-37a-struct-string-widths.md` (i.e. `KUSH2/kush2-sdk/docs/specs/X-37a-struct-string-widths.md` — the spec lives in the sibling SDK repo, since that is where the X-37 spec family lives; the code lives here). Parent: `X-37-string-ram-padding.md`. Read both — this plan argues from the spec's requirement numbers (`R1`-`R9`) and constraints (`C1`-`C7`).

## Global Constraints

- **C6 — additive only. No rewriting or refactoring of existing compiler code.** Every change is a new method, a new grammar alternative, or a branch guarded on the declared width that falls through to the untouched original path. When a program declares no `STRING[n]`, the compiler must take the same code path it takes today, not an equivalent rewritten one. **No renames, no extractions, no reordering, no reformatting of existing lines.** Phase 1's idiom is the model: `stage4/generate_c/generate_c_vardecl.cc:2456` opens with `if (0 == current_string_bound) return generate_c_base_c::visit(symbol);`.
- **C7 — scope down rather than push through.** If any task proves materially harder than this plan predicts, **stop and report**; do not grow the change. The ladder, in order: (a) drop Task 3 (per-instance struct initializers), keeping member defaults; (b) drop member defaults too (Tasks 3 and 4), leaving bare `F : STRING[n];` — still everything `DISPLAY_DATA` needs, since it declares no defaults; (c) abandon this plan and fall back to X-37 Phase 2b alone. Each rung is independently shippable. Reaching for a rung is a reporting event, never a silent decision.
- **Bounded width range is `[1, 126]`**, already enforced at the single existing choke point `string_bound_of()` (`stage4/generate_c/generate_c.cc:245-257`). Do not add a second range check anywhere.
- **The declared width is storage, not a datatype** (spec C5). Stage 3 gives a bounded string the ordinary `STRING` datatype singleton. Do not touch `get_datatype_info.cc`, overload resolution, or `is_ANY_STRING`.
- **Stage 3 is not involved** (spec C3). `fill_candidate_datatypes.cc:1168` and `narrow_candidate_datatypes.cc:668` keep their `structure_element_declaration_c` visitors commented out. Do not enable them.
- **`WSTRING[n]` stays unsupported.** `double_byte_string_spec` is not touched by any task.
- **Do not run `git commit`.** The user has a standing instruction against committing in this work stream. Each task ends with a staged-and-reported diff; the user commits. If a task's final step shows a `git commit` command, treat it as "prepare this commit and ask", not as authorization.
- **Test fixtures live in `tests/string_widths/`**, following the existing convention exactly: `<name>.st` plus one of `<name>.expect` (substrings that must appear in the generated C, `.h`, or `VARIABLES.csv`) / `<name>.expect_fail` (compile must fail, substrings must appear on stderr), optionally `<name>.main.c` (compiled with gcc against the generated code and run; non-zero exit is a failure). Driven by `tests/string_widths/run.sh`.
- **Build/test commands** (run from the matiec repo root in Git Bash on Windows; the image must exist — `docker build -t matiec-mingw docker` once):
  - Build: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/docker/build-native.sh`
  - Whole fixture suite: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/tests/string_widths/run.sh`
  - One fixture: append its filename, e.g. `... /src/tests/string_widths/run.sh struct_bounded_decl.st`
  - R9 byte-identity gate: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/tests/string_widths/regress.sh /src/iec2c.ref` (see Task 6 for producing `iec2c.ref`)

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `stage1_2/iec_bison.yy` (modify) | Add one `structure_element_declaration` alternative routing to `single_byte_string_spec`, plus its missing-`:` error twin. The only grammar change in this plan. | 1 |
| `absyntax_utils/type_initial_value.hh` / `.cc` (modify) | Add `visit(single_byte_limited_len_string_spec_c*)` returning the shared empty-string literal, so a bounded member without an explicit default has an initial value instead of `NULL`. | 2 |
| `stage4/generate_c/generate_c_vardecl.cc` (modify) | In `generate_c_structure_initialization_c` only: add a `current_string_bound` field and a `single_byte_character_string_c` override so a member's literal is typed `__STRING_n` rather than `STRING`. | 2, 3 |
| `stage3/print_datatypes_error.cc` (modify) | Add a `structure_element_declaration_c` visitor enforcing R6 — an overlong member default is a build error. No such visitor exists today, so this is a pure addition. | 4 |
| `stage4/generate_c/generate_var_list.cc` (modify) | In `visit(structure_element_declaration_c)` only: guard on the declared width and export the member as type `STRING`, never `__STRING_n` (R7/C1). | 5 |
| `tests/string_widths/struct_*.st` + `.expect` / `.expect_fail` / `.main.c` (new) | Fixtures, one set per task. | 1-6 |

---

## Task 0: Baseline probe — does the existing struct initializer already work? (DONE)

Run before any source change, to establish whether a pre-existing defect had to be fixed first.
**Result: no pre-existing defect. Nothing to fix before Task 1.**

**Files:**
- Create: `tests/string_widths/struct_plain_init.st`
- Create: `tests/string_widths/struct_plain_init.main.c`

- [x] **Step 1: Fixture with a plain `STRING` member — default, no default, and per-instance override**

Deliberately contains no `STRING[n]`, so it measures only pre-existing behaviour. It is kept
permanently as the control fixture for Task 3: Task 3's `struct_bounded_init` is the same program
with widths added, so any difference between the two is attributable to this feature alone.

- [x] **Step 2: Run it against unmodified HEAD**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_plain_init.st
```

Observed: `PASS(compiled)` and `R1.F='abc' R1.G.len=0 R1.N=7 R2.F='xy' R2.N=9` — all assertions
hold.

**Three findings this locks in:**

1. **No pre-existing bug.** Member defaults, absent defaults and per-instance struct initializers
   all work today for plain `STRING` members. X-37a builds on a working foundation.
2. **The compound-literal concern is retired** (see Task 2, Step 5) — the generated
   `static const REC temp = {__STRING_LITERAL(3,"abc"),...}` puts a compound literal in exactly the
   position the bounded form will, and gcc accepts it.
3. **Task 2's diagnosis is confirmed from the same output.** `R1.G` has no default, so its
   `__STRING_LITERAL(0,"")` came from `type_initial_value_c::get()` — the precise call that returns
   `NULL` for a bounded spec node, aborting the compiler. That is the gap Task 2 closes.

---

## Task 1: Grammar — a struct element may be `STRING[n]`

Closes spec C8 and satisfies R1; R8 is its gate. After this task the declaration parses and the C
field type is correct, but a *variable of that struct type* will not yet compile — Task 2 fixes
that. This task's fixture therefore only asserts on the generated type declaration.

**Files:**
- Modify: `stage1_2/iec_bison.yy:3216-3251`
- Create: `tests/string_widths/struct_bounded_decl.st`
- Create: `tests/string_widths/struct_bounded_decl.expect`

**Interfaces:**
- Consumes: nothing.
- Produces: `TYPE ... STRUCT` elements may carry a `single_byte_string_spec_c` in their existing `spec_init` field. Every later task depends on this node reaching `structure_element_declaration_c::spec_init`.

- [ ] **Step 1: Record the baseline conflict count (R8 gate, before any edit)**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  -c 'cd /src && bison -Wall -o /tmp/base.cc stage1_2/iec_bison.yy 2>&1 | grep -Ei "conflict" || echo "NO CONFLICTS REPORTED"'
```

Write the exact output into the task notes. This is the number Step 6 must match. Do not skip this
step — once the grammar is edited the baseline is unrecoverable without a stash.

- [ ] **Step 2: Write the failing fixture**

`tests/string_widths/struct_bounded_decl.st`:

```st
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
```

`tests/string_widths/struct_bounded_decl.expect`:

```
__DECLARE_STRING_TYPE(10)
__STRING_10 F;
```

- [ ] **Step 3: Run it to confirm it fails for the right reason**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_bounded_decl.st
```

Expected: `FAIL(exit=1)` with `invalid structure element declaration.` on stderr. If it fails with
any *other* message, stop — the premise of this plan is wrong.

- [ ] **Step 4: Add the grammar alternative**

In `stage1_2/iec_bison.yy`, in the `structure_element_declaration:` rule, add this alternative
immediately after the existing `ref_spec_init` alternative and before the `/* ERROR_CHECK_BEGIN */`
marker:

```
| structure_element_name ':' single_byte_string_spec
	{$$ = new structure_element_declaration_c($1, $3, locloc(@$)); $$->token = $1->token;}
```

Then, inside the `/* ERROR_CHECK_BEGIN */` block of the same rule, immediately after the existing
`structure_element_name initialized_structure` alternative, add its error twin:

```
| structure_element_name single_byte_string_spec
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between structure element name and string specification."); yynerrs++;}
```

Use a literal tab for the action-line indentation, matching every surrounding alternative. Change
nothing else in this file.

- [ ] **Step 5: Rebuild and run the fixture**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/docker/build-native.sh
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_bounded_decl.st
```

Expected: `PASS(compiled) struct_bounded_decl` with no `MISSING:` lines.

If it instead fails inside codegen with a null-pointer crash or an `ERROR` abort, that is Task 2's
gap arriving early — record it and continue to Task 2 rather than patching here.

- [ ] **Step 6: Re-check the conflict count (R8 gate)**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  -c 'cd /src && bison -Wall -o /tmp/new.cc stage1_2/iec_bison.yy 2>&1 | grep -Ei "conflict" || echo "NO CONFLICTS REPORTED"'
```

Expected: **byte-identical to Step 1's output.** If the count increased, **stop and report** — this
is the spec's one acknowledged unknown (C2) and an explicit C7 abort signal. Do not attempt to
suppress the conflict with `%expect`, precedence declarations, or grammar restructuring; all three
violate C6.

- [ ] **Step 7: Stage and report (do not commit — see Global Constraints)**

```bash
git add stage1_2/iec_bison.yy tests/string_widths/struct_bounded_decl.st tests/string_widths/struct_bounded_decl.expect
git status --short
```

Report the staged diff and the two conflict counts.

---

## Task 2: A bounded member without an explicit default gets an initial value

`R : REC;` makes matiec emit a `static const REC temp = {...}` initializer. For each member it calls
`type_initial_value_c::get(current_element_type)` (`generate_c_vardecl.cc:652`). That class is a
`null_visitor_c` whose `get()` dispatches directly on the node with **no base-type resolution**
(`type_initial_value.cc:102-105`), and it has no visitor for `single_byte_limited_len_string_spec_c`
— so it returns `NULL` and the next line, `if (element_value == NULL) ERROR;`, aborts the compiler.

Two additions fix it: the missing initial value, and typing that value at the member's width.

**Files:**
- Modify: `absyntax_utils/type_initial_value.hh` (declaration)
- Modify: `absyntax_utils/type_initial_value.cc` (definition)
- Modify: `stage4/generate_c/generate_c_vardecl.cc` (class `generate_c_structure_initialization_c`)
- Create: `tests/string_widths/struct_bounded_var.st`
- Create: `tests/string_widths/struct_bounded_var.expect`
- Create: `tests/string_widths/struct_bounded_var.main.c`

**Interfaces:**
- Consumes: Task 1's grammar alternative.
- Produces: `generate_c_structure_initialization_c::current_string_bound` (an `int`, 0 when the member being emitted is not a bounded string), read by Task 3.

- [ ] **Step 1: Write the failing fixture**

`tests/string_widths/struct_bounded_var.st`:

```st
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
```

`tests/string_widths/struct_bounded_var.expect`:

```
__DECLARE_STRING_TYPE(10)
__STRING_10 F;
```

`tests/string_widths/struct_bounded_var.main.c` — this is the real gate. It proves the generated C
*compiles under gcc* and that the field is 11 bytes (R2, acceptance criterion 1):

```c
/* A bounded struct member is sized to its declared width and default-initialises empty. */
#include "iec_std_lib.h"
#include "accessor.h"
#include "POUS.h"
#include <assert.h>
#include <stdio.h>

TIME __CURRENT_TIME;
extern void config_init__(void);
extern PROG0 RES__INST0;

int main(void) {
    PROG0 *p = &RES__INST0;
    config_init__();
    PROG0_body__(p);

    printf("sizeof(REC.F)=%u REC.F.len=%u\n",
           (unsigned)sizeof(p->R.value.F), (unsigned)p->R.value.F.len);

    assert(sizeof(p->R.value.F) == 11);
    assert(p->R.value.F.len == 0);
    return 0;
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_bounded_var.st
```

Expected: a non-zero exit from `iec2c` (the `ERROR` abort described above), **or** a
`GENERATED C DOES NOT COMPILE` line. Either confirms the gap. Record which one you saw — it tells
you whether Step 3 alone or Steps 3 and 4 together are needed.

- [ ] **Step 3: Give the bounded spec node an initial value**

In `absyntax_utils/type_initial_value.hh`, immediately after the existing line
`void *visit(wstring_type_name_c *symbol);`, add:

```cpp
    /* STRING '[' integer ']' */
    void *visit(single_byte_limited_len_string_spec_c *symbol);
```

In `absyntax_utils/type_initial_value.cc`, immediately after the existing line
`void *type_initial_value_c::visit(wstring_type_name_c *symbol)      {return (void *)wstring_0;}`,
add:

```cpp
/* A bounded STRING's initial value is the empty string, exactly as a plain STRING's is;
 * the declared width types the storage, not the value.
 */
void *type_initial_value_c::visit(single_byte_limited_len_string_spec_c *symbol) {return (void *)string_0;}
```

- [ ] **Step 4: Type the emitted literal at the member's width**

All three edits are inside the class `generate_c_structure_initialization_c` in
`stage4/generate_c/generate_c_vardecl.cc` (the class opens at line 500). Touch no other class.

**4a.** In the class's private data, immediately after the existing line
`symbol_c* current_element_default_value;`, add:

```cpp
    int current_string_bound;
```

**4b.** In the constructor, change the body from `{}` to initialise the new field — this is the one
existing line the task modifies, and it only adds an initialisation:

```cpp
    generate_c_structure_initialization_c(stage4out_c *s4o_ptr): generate_c_base_and_typeid_c(s4o_ptr) {current_string_bound = 0;}
```

**4c.** In `visit(structure_element_initialization_list_c *symbol)`, in the `else` branch of the
`initialization_analyzer` test, replace the single line `element_value->accept(*this);` with:

```cpp
          current_string_bound = string_bound_of(current_element_type);
          element_value->accept(*this);
          current_string_bound = 0;
```

**4d.** Add the override as a new method in the same class, immediately before its closing `};`:

```cpp
    /* A bounded member's initial value must carry its own type: __STRING_LITERAL()
     * is typed STRING, which does not assign to a narrower struct field.
     */
    void *visit(single_byte_character_string_c *symbol) {
      if (0 == current_string_bound) return generate_c_base_and_typeid_c::visit(symbol);
      std::string str;
      unsigned int count = decode_string_literal(symbol, str);
      s4o.print(INITIAL_VALUE);
      s4o.print("((__STRING_");
      s4o.print(current_string_bound);
      s4o.print("){");
      s4o.print(count);
      s4o.print(",");
      s4o.print(str);
      s4o.print("})");
      return NULL;
    }
```

- [ ] **Step 5: Rebuild and run**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/docker/build-native.sh
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_bounded_var.st
```

Expected: `PASS(compiled)`, then the printed line `sizeof(REC.F)=11 REC.F.len=0`, and no assertion
failure.

**On the compound-literal question — settled empirically, no longer a risk.** An earlier draft of
this plan flagged that `(__STRING_10){2,"hi"}` is not a constant expression at static storage
duration and might be rejected by gcc. Task 0's probe disproves that concern: the existing compiler
already emits

```c
static const REC temp = {__STRING_LITERAL(3,"abc"),__STRING_LITERAL(0,""),7};
```

for a plain `STRING` member, and `__STRING_LITERAL(count,value)` expands to
`(STRING){sizeof(value)-1,value}` — a compound literal in exactly that position, which gcc compiles
and runs correctly (`tests/string_widths/struct_plain_init`). The bounded form is structurally
identical, so emit the cast form as written in 4d. If it nonetheless fails, that is a genuine
surprise: stop and report rather than improvising.

- [ ] **Step 6: Confirm no regression in the existing suite**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh
```

Expected: every pre-existing fixture still reports `PASS`, and no `MISSING:` lines.

- [ ] **Step 7: Stage and report (do not commit)**

```bash
git add absyntax_utils/type_initial_value.hh absyntax_utils/type_initial_value.cc \
        stage4/generate_c/generate_c_vardecl.cc tests/string_widths/struct_bounded_var.*
git status --short
```

---

## Task 3: Member defaults and per-instance struct initializers

R6's positive half and goal 3. The user scoped this explicitly: **a member default is a must**;
per-instance initializers only because the pipeline already exists (`spec_init_separator.cc:243`
splits them, `generate_c_vardecl.cc:429` routes them). If either turns out to need machinery beyond
what Task 2 added, that is C7 rung (a) — drop the per-instance form, keep the member default, and
report.

**Files:**
- Create: `tests/string_widths/struct_bounded_init.st`
- Create: `tests/string_widths/struct_bounded_init.expect`
- Create: `tests/string_widths/struct_bounded_init.main.c`

**Interfaces:**
- Consumes: Task 2's `current_string_bound` and the `single_byte_character_string_c` override.
- Produces: nothing new. This task is expected to require **no production code** — it verifies that Task 2's two additions already cover both initializer forms. If it passes with no source edit, that is the correct outcome, not a missing step.

- [ ] **Step 1: Write the fixture**

`tests/string_widths/struct_bounded_init.st` — exercises a member default (`F`), a member with no
default (`G`), and a per-instance initializer overriding one of them (`R2`):

```st
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
```

`tests/string_widths/struct_bounded_init.expect`:

```
__DECLARE_STRING_TYPE(10)
__STRING_10 F;
__STRING_10 G;
```

`tests/string_widths/struct_bounded_init.main.c`:

```c
/* Member defaults and per-instance struct initialisers both land at the declared width. */
#include "iec_std_lib.h"
#include "accessor.h"
#include "POUS.h"
#include <assert.h>
#include <stdio.h>

TIME __CURRENT_TIME;
extern void config_init__(void);
extern PROG0 RES__INST0;

int main(void) {
    PROG0 *p = &RES__INST0;
    config_init__();
    PROG0_body__(p);

    /* A struct member is a plain C field - no .value wrapper (that is only for
     * __DECLARE_VAR'd POU variables and FB fields). Verified against the
     * generated __DECLARE_STRUCT_TYPE(DISPLAY_DATA, STRING DESCRIPTION; ...).
     */
    printf("R1.F='%.*s' R1.G.len=%u R1.N=%d R2.F='%.*s' R2.N=%d\n",
           (int)p->R1.value.F.len, p->R1.value.F.body,
           (unsigned)p->R1.value.G.len, (int)p->R1.value.N,
           (int)p->R2.value.F.len, p->R2.value.F.body,
           (int)p->R2.value.N);

    assert(sizeof(p->R1.value.F) == 11);
    assert(p->R1.value.F.len == 3 && p->R1.value.F.body[0] == 'a');
    assert(p->R1.value.G.len == 0);
    assert(p->R1.value.N == 7);
    assert(p->R2.value.F.len == 2 && p->R2.value.F.body[0] == 'x');
    assert(p->R2.value.N == 9);
    return 0;
}
```

- [ ] **Step 2: Run it**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_bounded_init.st
```

Expected: `PASS(compiled)`, then `R1.F='abc' R1.G.len=0 R1.N=7 R2.F='xy' R2.N=9`, no assertion
failure.

- [ ] **Step 3: If it fails, triage before writing any code**

Read the failure and classify it:

- **`iec2c` aborts or emits a `STRING`-typed literal for `F`** — Task 2's 4c did not cover the
  default-value path (the branch that takes `current_element_default_value` rather than an explicit
  value). Setting `current_string_bound` earlier in the same loop, before the `element_value ==
  NULL` fallbacks, is still an additive guarded change and is in scope.
- **Only the `R2 : REC := (...)` form fails** — that is C7 rung (a). Delete the `R2` declaration and
  its two assertions from the fixture, note the limitation, and report. Do not build new machinery
  for it.
- **Both forms fail in a way that needs new machinery** — C7 rung (b). Stop and report.

- [ ] **Step 4: Re-run the whole suite**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh
```

Expected: all fixtures `PASS`.

- [ ] **Step 5: Stage and report (do not commit)**

```bash
git add tests/string_widths/struct_bounded_init.*
git status --short
```

State explicitly in the report whether any production code was needed, and whether a C7 rung was taken.

---

## Task 4: An overlong member default is a build error (R6)

`stage3/print_datatypes_error.cc:644` already implements this check for variable declarations. It is
bound to `single_byte_string_var_declaration_c` and never sees a struct element. There is **no**
`structure_element_declaration_c` visitor in that file today (verified), so this is a pure addition.

**Files:**
- Modify: `stage3/print_datatypes_error.cc`
- Modify: `stage3/print_datatypes_error.hh`
- Create: `tests/string_widths/struct_overlong_default.st`
- Create: `tests/string_widths/struct_overlong_default.expect_fail`

**Interfaces:**
- Consumes: Task 1's grammar alternative.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing fixture**

`tests/string_widths/struct_overlong_default.st` — an 11-character default in a 10-wide member:

```st
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
```

`tests/string_widths/struct_overlong_default.expect_fail`:

```
initial value is longer than the declared width of the string (11 > 10).
```

- [ ] **Step 2: Run it to verify it fails**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_overlong_default.st
```

Expected: `FAIL(compiled, expected an error)` — the overlong default is currently accepted and
silently truncated. That silent truncation is exactly what R6 forbids.

- [ ] **Step 3: Declare the new visitor**

In `stage3/print_datatypes_error.hh`, alongside the existing
`void *visit(single_byte_string_var_declaration_c *symbol);` declaration, add:

```cpp
    void *visit(structure_element_declaration_c *symbol);
```

- [ ] **Step 4: Implement it**

In `stage3/print_datatypes_error.cc`, immediately after the closing brace of the existing
`print_datatypes_error_c::visit(single_byte_string_var_declaration_c *symbol)` function (which ends
at line 659), add:

```cpp
/*  structure_element_name ':' spec_init */
// SYM_REF2(structure_element_declaration_c, structure_element_name, spec_init)
void *print_datatypes_error_c::visit(structure_element_declaration_c *symbol) {
	single_byte_string_spec_c *spec = dynamic_cast<single_byte_string_spec_c *>(symbol->spec_init);
	if (NULL == spec) return NULL;   /* not a bounded string member - nothing to check */
	if (NULL == spec->single_byte_character_string) return NULL;

	single_byte_limited_len_string_spec_c *limit = dynamic_cast<single_byte_limited_len_string_spec_c *>(spec->string_spec);
	token_c *bound   = (NULL == limit)? NULL : dynamic_cast<token_c *>(limit->character_string_len);
	token_c *literal = dynamic_cast<token_c *>(spec->single_byte_character_string);
	if ((NULL == bound) || (NULL == literal)) return NULL;

	long declared = parse_bounded_string_width(bound);
	int  length   = decode_string_literal(literal->value, NULL);
	if (length > declared)
		STAGE3_ERROR(0, spec->single_byte_character_string, spec->single_byte_character_string,
		             "initial value is longer than the declared width of the string (%d > %ld).", length, declared);
	return NULL;
}
```

Note the one deliberate difference from its variable-level sibling: that one does `if (NULL == spec)
ERROR;` because it can only ever be called on a string declaration. This one is called for **every**
struct element, so a non-string member must return quietly rather than abort the compiler. Use tabs
for indentation, matching the surrounding file.

- [ ] **Step 5: Rebuild and verify it now fails the build**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/docker/build-native.sh
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_overlong_default.st
```

Expected: `PASS(rejected, exit=1)` with no `MISSING:` line.

- [ ] **Step 6: Verify a legal default still compiles**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh
```

Expected: all fixtures `PASS` — in particular `struct_bounded_init` (whose `'abc'` fits in
`STRING[10]`) must not have started failing. A new visitor that rejects valid defaults is worse than
no visitor.

- [ ] **Step 7: Stage and report (do not commit)**

```bash
git add stage3/print_datatypes_error.cc stage3/print_datatypes_error.hh tests/string_widths/struct_overlong_default.*
git status --short
```

---

## Task 5: Keep `__STRING_n` out of the exported signature (R7 / C1)

`.prog_signature` has 32 bytes of headroom on the reference program. `generate_var_list.cc:885`
exports a struct member using `update_var_type_symbol(symbol->spec_init)`, which for a bounded
member would name the type `__STRING_10` and add a new string to every program's signature. Phase 1
already solved this for variables at `generate_var_list.cc:815`; struct members do not inherit it.

**Files:**
- Modify: `stage4/generate_c/generate_var_list.cc:885-901`
- Create: `tests/string_widths/struct_signature.st`
- Create: `tests/string_widths/struct_signature.expect`

**Interfaces:**
- Consumes: Task 1's grammar alternative.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing fixture**

`tests/string_widths/struct_signature.st`:

```st
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
```

`tests/string_widths/struct_signature.expect` — the member is exported with the `STRING` type name,
matching the column layout of the existing `bounded_decl.expect` line:

```
CONFIG.RES.INST0.R.F;STRING;STRING;
```

- [ ] **Step 2: Run it and inspect the actual exported row**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_signature.st
cat tests/string_widths/out/struct_signature/VARIABLES.csv | grep -i "R.F"
```

Expected: a `MISSING:` line, and the `grep` showing the row naming `__STRING_10` instead of
`STRING`. **Record the exact row** — the `.expect` substring in Step 1 was written from the
variable-level precedent and the real column layout for a nested member may differ. If it does,
correct the `.expect` file to the true layout with `STRING` substituted for `__STRING_10`, rather
than changing what the code emits beyond that substitution.

- [ ] **Step 3: Add the guard**

In `stage4/generate_c/generate_var_list.cc`, in `visit(structure_element_declaration_c *symbol)`,
replace the single line `update_var_type_symbol(symbol->spec_init);` with:

```cpp
      /* A bounded string member is exported as the STRING it is: the declared width is
       * storage, and naming a per-width type here would put one more string in
       * every program's signature.
       */
      if (string_bound_of(symbol->spec_init) > 0)
        update_var_type_symbol(&get_datatype_info_c::string_type_name);
      else
        update_var_type_symbol(symbol->spec_init);
```

This is the guarded-branch shape C6 requires: an unbounded member takes the original call, untouched.

- [ ] **Step 4: Rebuild and verify**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/docker/build-native.sh
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_signature.st
```

Expected: `PASS(compiled)` with no `MISSING:` line.

- [ ] **Step 5: Assert no per-width type name leaks into any exported list**

```bash
grep -rn "__STRING_" tests/string_widths/out/struct_signature/VARIABLES.csv && echo "LEAK - R7 VIOLATED" || echo "OK - no per-width type name exported"
```

Expected: `OK - no per-width type name exported`.

- [ ] **Step 6: Stage and report (do not commit)**

```bash
git add stage4/generate_c/generate_var_list.cc tests/string_widths/struct_signature.*
git status --short
```

---

## Task 6: Parity, rejection and byte-identity gates (R4, R9, C4)

The remaining acceptance criteria. Two of these are pure verification — the expectation is that they
pass with no production code, because the spec's "What already satisfies the contract" table says
member access reaches Phase 1's crossings through `search_varfb_instance_type_c:254` unchanged. **If
they do not pass, that is the spec's third listed risk materialising and a C7 reporting event**, not
a licence to widen the change.

**Files:**
- Create: `tests/string_widths/struct_nested_access.st`
- Create: `tests/string_widths/struct_nested_access.main.c`
- Create: `tests/string_widths/struct_bounded_out_param.st`
- Create: `tests/string_widths/struct_bounded_out_param.expect_fail`

**Interfaces:**
- Consumes: every preceding task.
- Produces: the final green suite.

- [ ] **Step 1: Write the member-access parity fixture (R4)**

`tests/string_widths/struct_nested_access.st` — covers all three shapes the spec names: a direct
member, a struct nested in a struct, and a struct as a `FUNCTION_BLOCK` input (the `DISPLAY4` shape):

```st
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
```

`tests/string_widths/struct_nested_access.main.c`:

```c
/* Narrowing writes and widening reads work through direct, nested and FB-input members. */
#include "iec_std_lib.h"
#include "accessor.h"
#include "POUS.h"
#include <assert.h>
#include <stdio.h>

TIME __CURRENT_TIME;
extern void config_init__(void);
extern PROG0 RES__INST0;

int main(void) {
    PROG0 *p = &RES__INST0;
    config_init__();
    PROG0_body__(p);

    printf("O.T.len=%u O.I.D.len=%u BACK.len=%u SEEN.len=%u\n",
           (unsigned)p->O.value.T.len, (unsigned)p->O.value.I.D.len,
           (unsigned)p->BACK.value.len, (unsigned)p->S.SEEN.value.len);

    /* R2: both members are sized to the declared width, not STR_MAX_LEN. */
    assert(sizeof(p->O.value.T) == 11);
    assert(sizeof(p->O.value.I.D) == 11);

    /* R4: a 30-character source truncates to the declared width on the way in ... */
    assert(p->O.value.T.len == 10);
    assert(p->O.value.T.body[9] == '0');
    assert(p->O.value.I.D.len == 10);

    /* ... and widens back out without corruption. */
    assert(p->BACK.value.len == 10);
    assert(p->BACK.value.body[9] == '0');
    assert(p->S.SEEN.value.len == 10);
    return 0;
}
```

- [ ] **Step 2: Run it**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_nested_access.st
```

Expected: `PASS(compiled)`, `O.T.len=10 O.I.D.len=10 BACK.len=10 SEEN.len=10`, no assertion failure.

If an assertion fires on a *length* the crossing is missing; if the process crashes or a neighbouring
field is corrupted, a full-width `STRING` was copied over an 11-byte field. Either is a stop-and-
report event under C7, not something to patch by widening scope.

- [ ] **Step 3: Write the rejection-parity fixture (C4)**

`tests/string_widths/struct_bounded_out_param.st` — a bounded member passed as an output parameter,
which Phase 1 forbids for bounded variables:

```st
TYPE
  REC : STRUCT
    F : STRING[10];
  END_STRUCT;
END_TYPE

FUNCTION_BLOCK SRC
VAR_OUTPUT
  O : STRING;
END_VAR
  O := 'x';
END_FUNCTION_BLOCK

PROGRAM prog0
  VAR
    R : REC;
    S : SRC;
  END_VAR
  S(O => R.F);
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
```

`tests/string_widths/struct_bounded_out_param.expect_fail`:

```
a bounded STRING cannot be passed as an output or in-out parameter.
```

- [ ] **Step 4: Run it**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh struct_bounded_out_param.st
```

Expected: `PASS(rejected, exit=1)` with no `MISSING:` line.

If it compiles instead, the C4 guard does not reach members. Report it; the additive fix is to apply
the same existing `STAGE4_ERROR` where the member path resolves its bound. Do not restructure the
guard.

- [ ] **Step 5: Build the reference compiler for the byte-identity gate (R9)**

From a clean checkout of the merge-base commit, build an unmodified `iec2c` and keep it as
`iec2c.ref` at the repo root:

```bash
git stash push -u -m "x37a-wip"
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/docker/build-native.sh
cp iec2c iec2c.ref
git stash pop
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw /src/docker/build-native.sh
```

`iec2c.ref` is a build artifact — confirm it is ignored (`git check-ignore -v iec2c.ref`) and do not
stage it.

- [ ] **Step 6: Run the byte-identity gate (R9, acceptance criterion 6)**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/regress.sh /src/iec2c.ref
```

Expected: every corpus entry reports `SAME`, and the trailing `N programs compared` is non-zero.
`regress.sh` skips any fixture declaring `STRING[`, so this measures exactly what R9 claims: programs
that use no bounded string are compiled identically.

Any `DIFFERS` line is a C6 violation — some existing code path changed behaviour. Report it with the
diff; do not proceed.

- [ ] **Step 7: Run the full suite one final time**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw \
  /src/tests/string_widths/run.sh
```

Expected: every fixture `PASS`, no `MISSING:` lines, no `GENERATED C DOES NOT COMPILE`, no
`BEHAVIOUR TEST FAILED`.

- [ ] **Step 8: Stage and report (do not commit)**

```bash
git add tests/string_widths/struct_nested_access.* tests/string_widths/struct_bounded_out_param.*
git status --short
git diff --cached --stat
```

Final report must state, against the spec's acceptance criteria: which of 1-9 passed, the two bison
conflict counts from Task 1, the `regress.sh` comparison count, and whether any C7 rung was taken.

---

## Outcome (2026-09-14)

All six tasks complete on branch `x37a-struct-string-widths`; 24/24 fixtures pass. Production code
landed in four files and totals ~45 lines, all additive. Three deviations from the plan, each
evidence-driven:

- **Task 5 was not implemented — deliberately.** The `generate_var_list.cc:885` guard would be dead
  code: struct members are never exported to `VARIABLES.csv`, bounded or plain, with no flags or
  with the SDK's `-l -e -p -i -b -r -R`. Even a struct passed as an FB input exports only `EN`,
  `ENO` and the FB's own outputs. R7 holds without code; adding an unreachable branch would have
  violated the spirit of C6. The redundant `struct_signature` fixture was removed.
- **Task 6's C4 fixture had the wrong premise.** The plan expected `S(O => R.F)` to be *rejected*.
  It is not, and should not be: the equivalent for a bounded *variable* (`bounded_out_param`) has
  always compiled, emitting a truncating `__SET_STRVAR`. The member does the same. The fixture was
  converted from `.expect_fail` to a positive truncation test, which is the real parity check.
- **Task 1's fixture was split, then removed.** As written it declared `R : REC;`, which cannot
  compile until Task 2, so it was reduced to the type declaration only to keep each commit green.
  Once Task 2 landed it was redundant with `struct_bounded_var` — same `.expect`, less coverage —
  and was deleted during cleanup.

**`regress.sh`'s SDK corpus was inert, and is now fixed.** It writes a program including
`../../kush2_iec_lib/PLC_LIB.ST`, but matiec resolves `{#include}` against the current directory
and the script `cd`s to the matiec root, so the include never resolved. Both compilers produced
nothing and the script reported the reassuring `SAME (but no code generated)`. Each program is now
compiled from its own directory (with `-I` and the compiler paths made absolute), and the skip
heuristic scans the library tree rather than just the wrapper — otherwise, once Phase 2b retypes
those POUs, a legitimate difference would read as a failure.

The payoff is the R9 evidence this unlocks: **the entire SDK IEC library — the whole
`DISPLAY4`/`DISPLAY_DATA` stack — now compiles byte-identically between the reference and feature
compilers.** That is the largest real program available and by far the strongest support for C6.
Second to it is `struct_plain_init` (a struct with plain `STRING` members, defaults and a
per-instance initializer), which exercises `generate_c_structure_initialization_c`, the one class
where an existing line was modified. Both matter more than the AnnexF corpus, most of which fails
to parse in either compiler.

## Acceptance criteria coverage

| Spec criterion | Covered by |
|---|---|
| 1 — struct member 11 B via DWARF/`sizeof` | `struct_bounded_var` |
| 2 — nested + FB-input round-trip, no overflow | Task 6, Steps 1-2 |
| 3 — overlong default rejected | Task 4 |
| 4 — fitting default and per-instance initializer emit correctly | Task 3 |
| 5 — bison conflict counts identical | Task 1, Steps 1 and 6 |
| 6 — plain-`STRING` struct byte-identical; existing suite passes | `regress.sh` (incl. the full SDK library) + `struct_plain_init` comparison |
| 7 — no `__STRING_` in the exported signature | met vacuously; struct members are not exported (see Outcome) |
| 8 — Phase 1's rejections reach members | Task 6, Steps 3-4 |
| 9 — diff is additive only, no pure refactors | Every task's stage-and-report step; reviewed on the staged diff |
