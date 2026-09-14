# Per-variable `STRING[n]` — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `MY_STR : STRING[20];` compile in `KUSH2/matiec` to storage of 21 bytes instead of
the fixed 127, without changing anything about plain `STRING`.

**Architecture:** The declared width is a *storage* attribute, not a new datatype. Stage 3 gives a
`STRING[n]` variable the ordinary `STRING` datatype singleton, so every existing type check,
`is_ANY_STRING` test and overload resolution keeps working untouched. Stage 4 emits a per-width C
struct (`__STRING_20`) for the declaration only, and converts at the two crossings where a narrow
struct meets the canonical `STRING`: reads widen (`__string_widen_20()`), writes narrow with
truncation (`__string_narrow_20()`). Widths are emitted as implicit datatypes through the same
mechanism matiec already uses for inline `ARRAY[..] OF` declarations.

**Tech Stack:** C++98-ish matiec sources (bison/flex, visitor passes), GNU autotools, Docker for
both the native Linux build (fast iteration) and the mingw32 `iec2c.exe` cross build.

**Spec:** `kush2-sdk/docs/specs/X-37-string-ram-padding.md`

## Global Constraints

- **Phase 1 only.** No `kush2_iec_lib` ST retyping, no `KUSH-RTS3` firmware change, no `kush2-ide`
  change. Those are Phases 2–3 and ship as one ABI-coordinated release (spec C4).
- **R2 is the hard gate:** any program that declares no `STRING[n]` must produce byte-identical
  generated C. Every new code path is entered only after a `single_byte_limited_len_string_spec_c`
  is seen.
- **Narrowing rule (decided this session):** a statically-overlong literal is a build error; every
  other wider→narrower copy truncates at runtime at the declared width. Spec option (b) hardened
  with R3's static check. Option (a) is rejected — it would reject every existing program that
  assigns a plain `STRING` into what Phase 2 makes `DISPLAY4.Name`.
- **Two matiec trees (spec C5).** The compiler is `KUSH2/matiec`. The runtime headers that actually
  compile for the target are `kush2-sdk/matiec/lib/C/`. Header changes are additive macros only and
  must be applied to both trees, identically.
- `STR_MAX_LEN` (126) stays exactly as it is: it remains the width of the canonical `STRING` and of
  every widened temporary. It is no longer the width of declared bounded storage.
- **`WSTRING[n]` stays unimplemented.** `double_byte_string_var_declaration_c` keeps returning NULL
  in stage 4; no behaviour change, no new error.
- Comment style: minimal, only what the code cannot say itself; no ticket references.

---

## File Structure

**`KUSH2/matiec` (the compiler):**

| File | Responsibility |
|---|---|
| `docker/build-native.sh` (create) | Native Linux `iec2c` build inside the existing `matiec-mingw` image — the iteration loop. |
| `tests/string_widths/` (create) | ST fixtures + `run.sh` harness: compile each fixture, assert on generated C / exit status. |
| `absyntax_utils/search_base_type.cc/.hh` | Resolve `single_byte_string_spec_c` / `single_byte_limited_len_string_spec_c` to the `STRING` base type. |
| `stage3/fill_candidate_datatypes.cc/.hh` | Fill the candidate datatype for a `STRING[n]` declaration. |
| `stage3/narrow_candidate_datatypes.cc/.hh` | Narrow it, and raise the static overlong-literal error (R3). |
| `stage4/generate_c/generate_c_typedecl.cc` | Emit one `__DECLARE_STRING_TYPE(n)` per distinct width; annotate the AST node with its implicit type id. |
| `stage4/generate_c/generate_c_base.cc` | Print the implicit type id for a bounded string spec. |
| `stage4/generate_c/generate_c_vardecl.cc` | Declare/initialise bounded string variables. |
| `stage4/generate_c/generate_c.cc` | Return the spec from `print_function_parameter_data_types_c`; `string_bound_of()` helper. |
| `stage4/generate_c/generate_c_st.cc` | Widen on read (`print_getter`), narrow on write (`print_setter`). |
| `lib/C/iec_types_all.h`, `lib/C/accessor.h` | `__DECLARE_STRING_TYPE`, `__SET_STRVAR`. Mirrored into `kush2-sdk/matiec/lib/C/`. |

**Generated C, for a `VAR MY_STR : STRING[20] := 'hi'; END_VAR`:**

```c
/* in the POU header, once per distinct width */
__DECLARE_STRING_TYPE(20)

/* in the POU struct */
__DECLARE_VAR(__STRING_20,MY_STR)

/* init */
__INIT_VAR(data__->MY_STR,(__STRING_20){sizeof("hi")-1,"hi"},retain)

/* read  */ __string_widen_20(__GET_VAR(data__->MY_STR,))
/* write */ __SET_STRVAR(data__->,MY_STR,,20,<STRING expression>)
```

---

## Task 1: Build and test harness

**Files:**
- Create: `docker/build-native.sh`
- Create: `tests/string_widths/run.sh`
- Create: `tests/string_widths/plain_string.st`
- Modify: `README.build` (document the native docker build)

**Interfaces:**
- Produces: `./docker/build-native.sh`-equivalent one-liner used by every later task to rebuild;
  `tests/string_widths/run.sh` — runs every `*.st` fixture through the freshly built `iec2c`,
  writing generated C to `tests/string_widths/out/<name>/` and printing PASS/FAIL per fixture.

- [ ] **Step 1: Write the native build script**

`docker/build-native.sh`:

```sh
#!/bin/sh
# Native Linux build of iec2c inside the matiec-mingw image, for fast iteration.
# Mounts /src = source tree; builds in place (the mingw build copies instead).
set -eu
cd /src
if [ ! -f Makefile ]; then
    autoreconf -i
    ./configure
fi
make -j"$(nproc)"
```

Run it with:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src \
    --entrypoint sh matiec-mingw /src/docker/build-native.sh
```

- [ ] **Step 2: Verify the baseline builds**

Run the command above. Expected: `iec2c` relinked, exit 0. If `configure` state from a previous
host is stale, `rm -f Makefile config.status && ` re-run.

- [ ] **Step 3: Write the first fixture — plain STRING, the R2 canary**

`tests/string_widths/plain_string.st`:

```
PROGRAM prog0
  VAR
    A : STRING;
    B : STRING := 'hello';
  END_VAR
  A := B;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
```

- [ ] **Step 4: Write the harness**

`tests/string_widths/run.sh`:

```sh
#!/bin/sh
# Compile every fixture with the freshly built iec2c and report per-fixture status.
# Usage: run.sh [fixture ...]   (default: all *.st)
set -u
cd "$(dirname "$0")"
IEC2C=../../iec2c
rc=0
for f in ${*:-*.st}; do
    name=$(basename "$f" .st)
    out="out/$name"
    rm -rf "$out"; mkdir -p "$out"
    if "$IEC2C" -I ../../lib -T "$out" "$f" > "$out/stdout.txt" 2> "$out/stderr.txt"; then
        echo "PASS(compiled) $name"
    else
        echo "FAIL(exit=$?)  $name"
        rc=1
    fi
done
exit $rc
```

- [ ] **Step 5: Run it and record the baseline**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src \
    --entrypoint sh matiec-mingw /src/tests/string_widths/run.sh
```

Expected: `PASS(compiled) plain_string`. Save `tests/string_widths/out/plain_string/*.c|h` aside as
the R2 reference (`git add` them is not required; Task 8 regenerates and diffs).

- [ ] **Step 6: Add `tests/string_widths/out/` to `.gitignore`, document the build, commit**

```bash
git add docker/build-native.sh tests/string_widths .gitignore README.build
git commit -m "test: harness for bounded STRING codegen"
```

---

## Task 2: Runtime support — per-width string type family

**Files:**
- Modify: `lib/C/iec_types_all.h` (after `__DECLARE_STRUCT_TYPE`)
- Modify: `lib/C/accessor.h` (next to `__SET_VAR`)
- Mirror both into: `../kush2-sdk/matiec/lib/C/iec_types_all.h`, `../kush2-sdk/matiec/lib/C/accessor.h`

**Interfaces:**
- Produces: `__DECLARE_STRING_TYPE(maxlen)` — defines type `__STRING_##maxlen`, its
  `__IEC___STRING_##maxlen##_t` accessor wrapper, and the two conversion functions
  `STRING __string_widen_##maxlen(__STRING_##maxlen s)` and
  `void __string_narrow_##maxlen(__STRING_##maxlen *d, STRING s)`.
- Produces: `__SET_STRVAR(prefix, name, suffix, w, new_value)`.

- [ ] **Step 1: Write the failing test fixture**

`tests/string_widths/runtime_header.c` — a host C file that uses the macro directly, so the runtime
contract is testable before any compiler change:

```c
#include "iec_std_lib.h"
#include <assert.h>

__DECLARE_STRING_TYPE(20)

int main(void) {
    __STRING_20 s;
    STRING wide = __STRING_LITERAL(5, "hello");
    STRING toolong = __STRING_LITERAL(30, "123456789012345678901234567890");

    assert(sizeof(__STRING_20) == 21);

    __string_narrow_20(&s, wide);
    assert(s.len == 5);
    assert(__string_widen_20(s).len == 5);
    assert(__string_widen_20(s).body[0] == 'h');

    __string_narrow_20(&s, toolong);
    assert(s.len == 20);
    assert(s.body[19] == '0');
    return 0;
}
```

- [ ] **Step 2: Run it, expect a compile failure**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw -c \
  "gcc -I lib/C -o /tmp/rt tests/string_widths/runtime_header.c && /tmp/rt"
```

Expected: `error: implicit declaration of ... __DECLARE_STRING_TYPE`.

- [ ] **Step 3: Add the macro to `lib/C/iec_types_all.h`**

```c
#define __DECLARE_STRING_TYPE(maxlen)\
typedef struct {\
  __strlen_t len;\
  uint8_t body[maxlen];\
} __STRING_##maxlen;\
__DECLARE_COMPLEX_STRUCT(__STRING_##maxlen)\
static inline STRING __string_widen_##maxlen(__STRING_##maxlen s) {\
  STRING r;\
  __strlen_t i;\
  r.len = s.len;\
  for (i = 0; i < s.len; i++) r.body[i] = s.body[i];\
  return r;\
}\
static inline void __string_narrow_##maxlen(__STRING_##maxlen *d, STRING s) {\
  __strlen_t i, n = (s.len > (maxlen)) ? (maxlen) : s.len;\
  for (i = 0; i < n; i++) d->body[i] = s.body[i];\
  d->len = n;\
}
```

Byte loops rather than `memcpy` — `lib/C` is compiled `-ffreestanding` for the target and this
header must not add a libc dependency. Both functions are `static inline` and unreferenced widths
cost nothing.

- [ ] **Step 4: Add the setter macro to `lib/C/accessor.h`**

Next to `__SET_VAR`, inside the same `MATIEC_LIB_DISABLE_FLAGS` split as its neighbour (in the
`KUSH2/matiec` copy there is no such split — add the single unguarded form there):

```c
#define __SET_STRVAR(prefix, name, suffix, w, new_value)\
	if (!(prefix name.flags & __IEC_FORCE_FLAG)) __string_narrow_##w(&(prefix name.value suffix), new_value)
```

and, in the `MATIEC_LIB_DISABLE_FLAGS` branch of the SDK copy:

```c
	#define __SET_STRVAR(prefix, name, suffix, w, new_value)\
		__string_narrow_##w(&(prefix name.value suffix), new_value)
```

- [ ] **Step 5: Run the test, expect pass**

Same command as Step 2. Expected: exit 0, no assertion fires.

- [ ] **Step 6: Mirror both headers into the SDK tree and confirm they are identical**

```bash
diff lib/C/iec_types_all.h ../kush2-sdk/matiec/lib/C/iec_types_all.h
```

Only the pre-existing 14-line divergence noted in `UPSTREAM_MERGE_NOTES.md` may remain; the new
macro block must be identical in both.

- [ ] **Step 7: Commit (both repos)**

```bash
git add lib/C/iec_types_all.h lib/C/accessor.h tests/string_widths/runtime_header.c
git commit -m "runtime: per-width IEC string type family"
```

In `kush2-sdk`, on its own branch: `git commit -m "matiec runtime: per-width IEC string type family"`.

---

## Task 3: Stage 3 — give `STRING[n]` declarations a datatype

**Files:**
- Modify: `absyntax_utils/search_base_type.cc`, `absyntax_utils/search_base_type.hh`
- Modify: `stage3/fill_candidate_datatypes.cc:1420`, `stage3/fill_candidate_datatypes.hh:256`
- Modify: `stage3/narrow_candidate_datatypes.cc:857`, `stage3/narrow_candidate_datatypes.hh:231`
- Test: `tests/string_widths/bounded_decl.st`

**Interfaces:**
- Consumes: the harness from Task 1.
- Produces: after this task, a `STRING[n]` variable's `datatype` annotation is
  `&get_datatype_info_c::string_type_name` — the same singleton a plain `STRING` gets. Stage 4 can
  rely on `symbol->datatype` being valid for such variables, and on `is_ANY_STRING()` being true.

**Note on the spec:** the two commented-out lines call `handle_var_declaration()`, which **does not
exist** anywhere in the tree — they cannot simply be uncommented. Write the bodies out.

- [ ] **Step 1: Write the failing test fixture**

`tests/string_widths/bounded_decl.st`:

```
PROGRAM prog0
  VAR
    A : STRING[20];
    B : STRING[20] := 'hi';
  END_VAR
  A := B;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
```

- [ ] **Step 2: Run it, record the current failure**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src \
    --entrypoint sh matiec-mingw /src/tests/string_widths/run.sh bounded_decl.st
```

Expected: `FAIL` — a segfault (exit 139) or a null-deref abort, per the spec's investigation.

- [ ] **Step 3: Teach `search_base_type_c` about the two spec nodes**

In `search_base_type.hh`, next to `visit(string_type_name_c *symbol)`:

```c
    void *visit(single_byte_string_spec_c *symbol);
    void *visit(single_byte_limited_len_string_spec_c *symbol);
```

In `search_base_type.cc`, next to the other string visitors:

```c
/* The declared width is a storage attribute, not a distinct datatype:
 * a STRING[n] is a STRING for every type check in stage 3.
 */
void *search_base_type_c::visit(single_byte_string_spec_c *symbol)
  {return symbol->string_spec->accept(*this);}

void *search_base_type_c::visit(single_byte_limited_len_string_spec_c *symbol)
  {return symbol->string_type_name->accept(*this);}
```

- [ ] **Step 4: Fill the candidate datatype**

`stage3/fill_candidate_datatypes.hh:256`, replacing the commented-out line:

```c
    void *visit(single_byte_string_var_declaration_c *symbol);
```

`stage3/fill_candidate_datatypes.cc:1420`, replacing the commented-out line:

```c
void *fill_candidate_datatypes_c::visit(single_byte_string_var_declaration_c *symbol) {
  symbol->single_byte_string_spec->accept(*this);
  add_datatype_to_candidate_list(symbol->single_byte_string_spec, &get_datatype_info_c::string_type_name);
  return NULL;
}
```

If `add_datatype_to_candidate_list` is not visible at that point, use the same call the neighbouring
`visit(var1_init_decl_c)` uses — read it first and match it exactly.

- [ ] **Step 5: Narrow it**

`stage3/narrow_candidate_datatypes.hh:231` / `.cc:857`, replacing the commented-out lines:

```c
void *narrow_candidate_datatypes_c::visit(single_byte_string_var_declaration_c *symbol) {
  symbol->single_byte_string_spec->datatype = &get_datatype_info_c::string_type_name;
  return NULL;
}
```

- [ ] **Step 6: Rebuild and run both fixtures**

Expected: `bounded_decl` no longer segfaults. It may still emit no declaration for `A`/`B` (stage 4
is still stubbed) — that is Task 4. `plain_string` must still PASS.

- [ ] **Step 7: Commit**

```bash
git add absyntax_utils/search_base_type.* stage3/fill_candidate_datatypes.* stage3/narrow_candidate_datatypes.* tests/string_widths/bounded_decl.st
git commit -m "stage3: resolve STRING[n] declarations to the STRING datatype"
```

---

## Task 4: Stage 4 — emit the per-width type and the declaration

**Files:**
- Modify: `stage4/generate_c/generate_c_typedecl.cc` (`generate_c_implicit_typedecl_c`, near
  `visit(array_specification_c *)` at :1110)
- Modify: `stage4/generate_c/generate_c_base.cc` (near `visit(string_type_name_c *)` at :636)
- Modify: `stage4/generate_c/generate_c_vardecl.cc` (near `visit(var1_init_decl_c *)`)
- Modify: `stage4/generate_c/generate_c.cc:396`

**Interfaces:**
- Consumes: `__DECLARE_STRING_TYPE(n)` from Task 2; the datatype annotation from Task 3.
- Produces: `int string_bound_of(symbol_c *spec)` in `generate_c.cc`'s helper section — returns the
  declared width for a `single_byte_string_spec_c` or `single_byte_limited_len_string_spec_c`, and
  `0` for anything else (including plain `STRING`). Every later task uses it.

- [ ] **Step 1: Write the failing assertion into the harness**

Extend `tests/string_widths/run.sh` with an optional per-fixture expectation file: if
`<name>.expect` exists, every line in it must appear (as a substring) somewhere in the generated
`out/<name>/*.c` / `*.h`, else FAIL. Add:

`tests/string_widths/bounded_decl.expect`:

```
__DECLARE_STRING_TYPE(20)
__DECLARE_VAR(__STRING_20,A)
__DECLARE_VAR(__STRING_20,B)
```

Harness addition (after the compile succeeds):

```sh
    if [ -f "$name.expect" ]; then
        while IFS= read -r want; do
            [ -z "$want" ] && continue
            if ! grep -qF -- "$want" "$out"/*.c "$out"/*.h 2>/dev/null; then
                echo "  MISSING: $want"; rc=1
            fi
        done < "$name.expect"
    fi
```

- [ ] **Step 2: Run, expect the three MISSING lines**

- [ ] **Step 3: Add the width helper**

In `generate_c.cc`, next to the other file-scope helpers (before the visitor classes):

```c
/* Declared width of a bounded STRING specification, or 0 if unbounded. */
static int string_bound_of(symbol_c *spec) {
  single_byte_string_spec_c *s = dynamic_cast<single_byte_string_spec_c *>(spec);
  if (NULL != s) spec = s->string_spec;
  single_byte_limited_len_string_spec_c *l = dynamic_cast<single_byte_limited_len_string_spec_c *>(spec);
  if (NULL == l) return 0;
  integer_c *len = dynamic_cast<integer_c *>(l->character_string_len);
  if (NULL == len) return 0;
  return atoi(len->value);
}
```

Check how other passes read an `integer_c` token (`extract_integer_c` / `->value`) and match that
idiom rather than inventing one.

- [ ] **Step 4: Emit one type per distinct width**

In `generate_c_implicit_typedecl_c` (`generate_c_typedecl.cc`), mirroring
`visit(array_specification_c *)`:

```c
    /* STRING '[' integer ']' — an implicitly declared, width-bounded string type. */
    void *visit(single_byte_string_spec_c *symbol) {
      symbol->string_spec->accept(*this);
      return NULL;
    }

    void *visit(single_byte_limited_len_string_spec_c *symbol) {
      int bound = string_bound_of(symbol);
      if (bound <= 0) ERROR;
      if (declared_string_widths.find(bound) == declared_string_widths.end()) {
        declared_string_widths.insert(bound);
        s4o_incl.print("__DECLARE_STRING_TYPE(");
        s4o_incl.print_integer(bound);
        s4o_incl.print(")\n");
      }
      return NULL;
    }
```

with `std::set<int> declared_string_widths;` as a private member. Match the surrounding code's way
of writing to the include stream — read how `visit(array_specification_c *)` reaches `s4o_incl`
(it goes through `generate_c_typedecl_`), and if there is no direct `s4o_incl` in this class, add
the print inside `generate_c_typedecl_c` as a small public method
`void declare_string_type(int bound)` and call that instead.

- [ ] **Step 5: Print the C type name**

In `generate_c_base.cc`, next to `visit(string_type_name_c *)`:

```c
    void *visit(single_byte_string_spec_c *symbol) {return symbol->string_spec->accept(*this);}
    void *visit(single_byte_limited_len_string_spec_c *symbol) {
      s4o.print("__STRING_");
      s4o.print_integer(string_bound_of(symbol));
      return NULL;
    }
```

(Use whatever integer-printing helper `s4o` actually has — check `stage4.hh`; if there is none,
`char buf[16]; snprintf(...)` in the same style as neighbouring code.)

- [ ] **Step 6: Declare the variables**

In `generate_c_vardecl.cc`, replacing nothing (this visitor does not exist yet), next to
`visit(var1_init_decl_c *)`:

```c
/*  var1_list ':' single_byte_string_spec */
void *visit(single_byte_string_var_declaration_c *symbol) {
  if ((current_vartype & wanted_vartype) == 0) return NULL;
  current_string_bound = string_bound_of(symbol->single_byte_string_spec);
  this->current_var_type_symbol = symbol->single_byte_string_spec->string_spec;
  this->current_var_init_symbol = symbol->single_byte_string_spec->single_byte_character_string;
  declare_variables(symbol->var1_list);
  this->current_var_type_symbol = NULL;
  this->current_var_init_symbol = NULL;
  current_string_bound = 0;
  return NULL;
}
```

Read `visit(var1_init_decl_c *)` immediately above and copy its vartype-guard and prologue exactly —
the guard shown here is a sketch, the real one is whatever that visitor does.

`current_string_bound` is a new `int` member initialised to 0 in the constructor.

- [ ] **Step 7: Initialiser literal with the bounded type**

In the same class, override the string literal visitor so a bounded declaration gets a compound
literal of its own type instead of `__STRING_LITERAL` (which is typed `STRING`):

```c
void *visit(single_byte_character_string_c *symbol) {
  if (0 == current_string_bound) return generate_c_base_and_typeid_c::visit(symbol);
  s4o.print("(__STRING_");
  s4o.print_integer(current_string_bound);
  s4o.print("){sizeof(");
  /* print the C string literal exactly as the base visitor does */
  ...
  s4o.print(")-1,");
  ...
  s4o.print("}");
  return NULL;
}
```

Read `generate_c_base.cc:484`'s `__STRING_LITERAL(` emission first and factor the literal-body
printing out of it into a small protected method so both call sites share it — do not duplicate the
escape handling.

When there is no initialiser, `declare_variables` falls back to `type_initial_value_c::get()`, which
returns the shared empty-string node `string_0`; with `current_string_bound` set, the override above
turns that into `(__STRING_20){sizeof("")-1,""}`. Confirm that in the generated output.

- [ ] **Step 8: Unstub the function-parameter type printer**

`generate_c.cc:396`:

```c
    void *visit(single_byte_string_var_declaration_c *symbol) {
      print_list(symbol->var1_list, symbol->single_byte_string_spec->string_spec);
      return NULL;
    }
```

Match the shape of the neighbouring `visit(var1_init_decl_c *)`.

- [ ] **Step 9: Rebuild, run the fixtures**

Expected: `bounded_decl` PASSes with no MISSING lines; `plain_string` still PASSes.

- [ ] **Step 10: Verify the storage is really 21 bytes**

Compile the generated C in the container and read the size back with DWARF, the same way the
original investigation measured `PLC1_1_ram`:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw -c \
 "gcc -g -c -I lib/C -I tests/string_widths/out/bounded_decl \
      tests/string_widths/out/bounded_decl/*.c -o /tmp/p.o && \
  objdump --dwarf=info /tmp/p.o | grep -A4 '__STRING_20'"
```

Expected: `DW_AT_byte_size : 21`. Record the observed value in the commit message.

- [ ] **Step 11: Commit**

```bash
git add stage4/generate_c/ tests/string_widths/
git commit -m "stage4: emit per-width storage for STRING[n] declarations"
```

---

## Task 5: Static overlong-literal diagnostic (R3)

**Files:**
- Modify: `stage3/narrow_candidate_datatypes.cc` (the visitor added in Task 3)
- Test: `tests/string_widths/overlong_literal.st`, `.expect_fail`

**Interfaces:**
- Consumes: `string_bound_of` semantics (re-derive locally in stage 3 — do not include a stage 4
  header; read the `integer_c` the same way stage 3 reads other integer tokens).

- [ ] **Step 1: Write the failing test**

`tests/string_widths/overlong_literal.st` — a 30-character literal into a `STRING[20]`:

```
PROGRAM prog0
  VAR
    A : STRING[20] := '123456789012345678901234567890';
  END_VAR
  A := A;
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
```

Mark it as a must-fail fixture: `tests/string_widths/overlong_literal.expect_fail` containing the
expected diagnostic substring:

```
initial value is longer than the declared width
```

Harness: when `<name>.expect_fail` exists, a *successful* compile is a FAIL, and the file's contents
must appear in `stderr.txt`.

- [ ] **Step 2: Run, expect FAIL — it compiles today (silent truncation)**

- [ ] **Step 3: Add the check**

In `narrow_candidate_datatypes_c::visit(single_byte_string_var_declaration_c *)`:

```c
  single_byte_string_spec_c *spec = symbol->single_byte_string_spec;
  if (NULL != spec->single_byte_character_string) {
    int bound = /* declared width */;
    int len   = /* decoded length of the literal, escapes resolved */;
    if (len > bound)
      STAGE3_ERROR(0, spec->single_byte_character_string, spec->single_byte_character_string,
                   "initial value is longer than the declared width of the string (%d > %d).",
                   len, bound);
  }
```

Use the same `STAGE3_ERROR` arity and formatting as its neighbours in the file. For the literal
length, reuse whatever helper already decodes `$xx`/`$N` escapes; if none exists in stage 3, count
the source characters and note in a comment that escapes make this an upper bound — a conservative
over-count would reject valid programs, so if no decoder exists, count decoded length with a small
local loop over the same escape rules `generate_c_base.cc`'s literal visitor implements.

- [ ] **Step 4: Rebuild, run all fixtures**

Expected: `overlong_literal` FAILs to compile with the new message; the other fixtures unchanged.

- [ ] **Step 5: Commit**

```bash
git commit -am "stage3: reject a string initializer wider than its declared bound"
```

---

## Task 6: Read and write crossings

**Files:**
- Modify: `stage4/generate_c/generate_c_st.cc` (`print_getter` :122, `print_setter` :165)
- Test: `tests/string_widths/assign_narrow.st`, `.expect`

**Interfaces:**
- Consumes: `string_bound_of`, `__SET_STRVAR`, `__string_widen_##n`.
- Produces: `int string_bound_of_var(symbol_c *var_ref)` — resolves a variable reference to its
  declaration via `search_varfb_instance_type_c` / `search_var_instance_decl_c` and returns its
  declared width, or 0.

- [ ] **Step 1: Write the failing test**

`tests/string_widths/assign_narrow.st`:

```
PROGRAM prog0
  VAR
    WIDE   : STRING;
    NARROW : STRING[10];
    OUT    : STRING;
  END_VAR
  NARROW := WIDE;
  OUT := NARROW;
  OUT := CONCAT(NARROW, WIDE);
END_PROGRAM

CONFIGURATION config
  RESOURCE res ON PLC
    TASK tsk(INTERVAL := T#100ms, PRIORITY := 0);
    PROGRAM inst0 WITH tsk : prog0;
  END_RESOURCE
END_CONFIGURATION
```

`assign_narrow.expect`:

```
__SET_STRVAR(data__->,NARROW,,10,
__string_widen_10(__GET_VAR(data__->NARROW,))
```

- [ ] **Step 2: Run, expect MISSING for both lines**

- [ ] **Step 3: Resolve a variable reference to its declared width**

In `generate_c_st.cc`, near the top of the class:

```c
/* Declared width of the string a variable reference resolves to, or 0. */
int string_bound_of_var(symbol_c *symbol) {
  if (!get_datatype_info_c::is_ANY_STRING(symbol->datatype)) return 0;
  return string_bound_of(search_varfb_instance_type->get_decl(symbol));
}
```

`search_varfb_instance_type` is already a member of this class (constructed in the ctor). Read its
public API first — if the accessor that returns the declaration is named differently, use that; if
it only returns a *datatype*, fall back to `search_var_instance_decl->get_decl()` for the simple
(non-structured) case and return 0 for anything structured, with a `STAGE4_ERROR` in `print_setter`
so a bounded struct field cannot be miscompiled silently. Structured bounded fields are Phase 2's
requirement, not Phase 1's — but they must fail loudly, never wrongly.

- [ ] **Step 4: Widen on read**

At the end of `print_getter`, wrap the emitted expression:

```c
  int bound = string_bound_of_var(symbol);
  if (bound > 0 && wanted_variablegeneration != fparam_output_vg) {
    /* prefix printed before the GET_* macro name, suffix after the closing ')' */
  }
```

Concretely: compute `bound` at the top of `print_getter`; if `bound > 0` and the generation mode is
not `fparam_output_vg` (a by-reference output parameter must not be widened — see Step 6), print
`__string_widen_<bound>(` before the `GET_*` macro name and `)` after the final `s4o.print(")")`.

- [ ] **Step 5: Narrow on write**

In `print_setter`, when `fb_symbol == NULL` and `string_bound_of_var(symbol) > 0`, print
`__SET_STRVAR` instead of `SET_VAR`, and print the width plus a comma immediately before
`print_check_function(type, value, fb_value)`. Leave the `SET_EXTERNAL` / `SET_LOCATED` paths alone:
if a bounded string turns up as external or located, `STAGE4_ERROR` with
`"bounded STRING is not supported for external or located variables"`.

- [ ] **Step 6: Reject the cases that cannot be right yet**

A bounded string passed as an output/in-out parameter (`fparam_output_vg`, `GET_VAR_BY_REF`) hands a
`__STRING_20 *` where a `STRING *` is expected. Emit
`STAGE4_ERROR(symbol, symbol, "a bounded STRING cannot be passed as an output or in-out parameter")`
rather than generating code that will not compile. Add a fixture proving it errors:
`tests/string_widths/bounded_out_param.st` + `.expect_fail`.

- [ ] **Step 7: Rebuild, run all fixtures, then compile the generated C**

The generated C for `assign_narrow` must compile clean with `-Wall -Werror`:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -w /src --entrypoint sh matiec-mingw -c \
 "gcc -Wall -Werror -c -I lib/C -I tests/string_widths/out/assign_narrow \
      tests/string_widths/out/assign_narrow/*.c -o /tmp/a.o"
```

This is the real gate for this task: the widen/narrow calls must type-check against the generated
struct types.

- [ ] **Step 8: Commit**

```bash
git commit -am "stage4: widen bounded strings on read, truncate on write"
```

---

## Task 7: Behaviour test — truncation actually happens at runtime

**Files:**
- Create: `tests/string_widths/runtime_behaviour.st`, `tests/string_widths/runtime_main.c`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the ST fixture**

A program that assigns a 30-character literal into `STRING[10]` *through a variable* (so the static
check of Task 5 does not fire) and copies the result back out to an unbounded `STRING`:

```
PROGRAM prog0
  VAR
    SRC : STRING := '123456789012345678901234567890';
    NARROW : STRING[10];
    RESULT : STRING;
  END_VAR
  NARROW := SRC;
  RESULT := NARROW;
END_PROGRAM
```

plus the same `CONFIGURATION` block as the other fixtures.

- [ ] **Step 2: Write a host driver that runs one scan and asserts**

`tests/string_widths/runtime_main.c` — include the generated POU, call `config_init__()` then
`PROG0_body__()` on the instance, and assert `RESULT.len == 10` and
`RESULT.body[9] == '0'`. Model it on `tests/main.c`, which already does this for the existing test
programs — read it and follow its structure rather than inventing a driver.

- [ ] **Step 3: Run it**

Expected: exit 0. A `len` of 30 means the narrow copy was skipped; a crash means the widen read the
wrong width.

- [ ] **Step 4: Commit**

```bash
git commit -am "test: bounded string truncation at runtime"
```

---

## Task 8: R2 regression gate

**Files:**
- Create: `tests/string_widths/regress.sh`

**Interfaces:**
- Consumes: the pre-change `iec2c`. Produces a pass/fail answer to "is generated C byte-identical
  for programs with no `STRING[n]`?".

- [ ] **Step 1: Build the reference compiler from `main`**

```bash
git stash -u
git worktree add /tmp/matiec-main main   # or: git -C .. clone
```

Build it in the container the same way, and keep the resulting `iec2c` as `/tmp/iec2c.ref`.
(If a worktree is awkward under Docker on Windows, build from a `git archive main` tarball extracted
into a scratch directory instead — the point is a reference binary, not the mechanism.)

- [ ] **Step 2: Assemble the corpus**

Every `.st` under `tests/` plus every generated ST the SDK ships:
`../kush2-sdk/test-projects/**/*.st` (or whatever the IDE emits — locate it, do not guess). Skip any
file containing `STRING[`.

- [ ] **Step 3: Write `regress.sh`**

For each corpus file: run both compilers into separate output dirs and `diff -r` them. Any
difference is a FAIL, printed with the file and the diff.

- [ ] **Step 4: Run it**

Expected: every corpus file identical. If a diff appears, it is a real R2 violation — fix it before
going further; do not accept a "harmless" difference.

- [ ] **Step 5: Commit**

```bash
git add tests/string_widths/regress.sh
git commit -m "test: R2 regression gate against the pre-change compiler"
```

---

## Task 9: Rebuild and re-vendor `iec2c.exe`

**Files:**
- Modify: `dist-win/iec2c.exe` (build artifact, gitignored here)
- Modify: `../kush2-sdk/bin_windows/iec2c.exe`

- [ ] **Step 1: Cross-build**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/src" -v "$(pwd -W)/dist-win:/out" matiec-mingw
```

Expected: `--- built ---` and a PE32 executable.

- [ ] **Step 2: Smoke-test the Windows binary on a bounded fixture**

Run `dist-win/iec2c.exe` from PowerShell against `tests/string_widths/bounded_decl.st` and confirm
the same generated C as the Linux build produced.

- [ ] **Step 3: Vendor it and rebuild a real project**

Copy over `../kush2-sdk/bin_windows/iec2c.exe`, then build `PLC1_1` end-to-end with the SDK's normal
build path. Expected: builds, and `.prog_signature` / static RAM are unchanged — no program declares
`STRING[n]` yet, so Phase 1 must move neither number (spec C7, AC5).

- [ ] **Step 4: Commit in `kush2-sdk` on its own branch**

```
feat(matiec): iec2c with per-variable STRING[n] support
```

Record in the commit body: the DWARF-verified 21-byte size, the R2 result from Task 8, and that
`PLC1_1`'s RAM and signature are unchanged.

---

## Out of scope, recorded for Phase 2

- **Struct members.** `structure_element_declaration_c` is `structure_element_name ':' spec_init`,
  and `spec_init` does not reach `single_byte_string_spec`. Whether `DISPLAY_DATA`'s fields can be
  declared `STRING[20]` at all therefore needs checking before Phase 2 is scheduled — if the grammar
  rejects it, Phase 2 needs a grammar change this plan does not contain. Check it early; it is the
  cheapest thing that could invalidate the Phase 2 table.
- **IL and SFC codegen** (`generate_c_il.cc`, `generate_c_sfc.cc`) get no bounded-string handling.
  The SDK's IDE emits ST, so this is unexercised — but it means an IL program using a bounded string
  generates C that will not compile, rather than a diagnostic.
- **Variadic widening at `CONCAT`-family call sites (spec C1).** Handled implicitly: a bounded
  string is widened by `print_getter` before it ever reaches the call, so `va_arg(ap, STRING)` sees
  the canonical type. No dedicated call-site work is needed, but confirm it against the generated C
  in Task 6's fixture — that is what `OUT := CONCAT(NARROW, WIDE);` is there to prove.
- **`.prog_signature` export descriptors.** `export_var_descriptor_t.ulSize` should carry the real
  per-variable width once bounded strings exist in a real program; nothing in Phase 1 changes what
  is exported, so this stays with Phase 3's IDE work.

---

## Implementation notes (what the plan got wrong)

Recorded after Phase 1 was built, so the next session reads the tree as it is,
not as this plan predicted it.

- **Stage 3 needed one change, not three.** The two commented-out visitors in
  `fill_candidate_datatypes.cc` / `narrow_candidate_datatypes.cc` call
  `handle_var_declaration()`, which does not exist anywhere in the tree — they
  cannot be uncommented, and they are not what was missing. The real gap was
  `search_base_type_c`, which had no visitor for `single_byte_string_spec_c` or
  `single_byte_limited_len_string_spec_c`, so a `STRING[n]` variable resolved to
  no datatype at all and every reference to it was reported as "Variable not
  declared in this scope". Six lines there fixed the whole of stage 3; the two
  commented-out lines were left as they were.
- **The `#if 0` block in `generate_c_vardecl.cc:2301` is not a stale
  implementation.** It is a copy of the AST definitions, the same comment block
  that appears in several other files. There was nothing there to revive.
- **`function_param_iterator_c` also had no visitor** for the declaration, so a
  function block with a `STRING[n]` input rejected the parameter
  ("Invalid parameter 'NAME' when invoking FB 'F'") before codegen was reached.
- **`generate_c_inlinefcall.cc` has its own `print_getter`/`print_setter`** and
  needed the same widen/narrow treatment as `generate_c_st.cc`'s. With it, a
  bounded variable bound to a *function's* output parameter works (the call
  writes through a canonical `STRING` temporary), so the planned STAGE4_ERROR
  for that case is not reachable from a function call; it remains as a guard.
  `VAR_IN_OUT` on a function block is copy-in/copy-out and works the same way.
- **The R3 diagnostic lives in `print_datatypes_error.cc`**, not in
  `narrow_candidate_datatypes.cc`: in matiec the narrow pass annotates and the
  print pass reports, and only the latter defines `STAGE3_ERROR`.
- **Compound literals must be wrapped in `__INITIAL_VALUE(...)`.** The bounded
  initial value contains a comma, which otherwise splits `__INIT_VAR`'s
  arguments.
- **Two AnnexF examples make matiec loop forever** after a parse error
  (`gravel_st.txt`, and one other), in both the reference and the new compiler.
  `regress.sh` gives every run a 60s timeout and compares the exit codes.

- **`STRING[n]` is rejected outside a POU variable declaration.** A `VAR_GLOBAL`,
  `VAR_EXTERNAL` or located declaration reached `update_type_init()` with no
  datatype and aborted with an internal compiler error; it now fails with
  "a bounded STRING is only supported for a variable declared inside a POU".
  Supporting globals means widening `__DECLARE_GLOBAL`/`__DECLARE_EXTERNAL` and
  deciding what a `VAR_EXTERNAL STRING` that refers to a `VAR_GLOBAL STRING[12]`
  should mean — neither is needed by Phase 2.
- **Phase 2 is blocked on the grammar, as suspected.** `TYPE REC : STRUCT F :
  STRING[10]; END_STRUCT; END_TYPE` does not parse ("';' missing at end of
  structure element declaration"), because `structure_element_declaration` takes
  a `spec_init`, which never reaches `single_byte_string_spec`. `DISPLAY_DATA`'s
  three fields in the Phase 2 table are struct elements, so Phase 2 needs a
  grammar production for them first. Function block variables are fine — those
  go through `var_init_decl` and work today.
- **The exported variable list needed its own visitor** in `generate_var_list.cc`,
  which otherwise wrote a malformed `VARIABLES.csv` line. Bounded variables are
  exported as `STRING`, so `.prog_signature` gains no new type name (C7).
