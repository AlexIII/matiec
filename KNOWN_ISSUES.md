# Known issues

Unfixed defects in string literal C code generation, in
`stage4/generate_c/generate_c_base.cc`, `visit(single_byte_character_string_c)`.
Both need `$L`, `$N` or `$xx` escapes in a string literal to trigger.

## `$L` produces uncompilable C

The `$L` case appends a raw 0x0A byte instead of the two-character escape that
the neighbouring `$N` case emits. The newline lands inside the generated C
string literal, which then no longer compiles.

## `$xx` and `$N` are emitted as greedy C hex escapes

Both emit C `\xNN`, which has no length limit, so a hex digit following in the
ST source is absorbed into the escape and bytes are lost (`'A$Nb'` stores 2
bytes, not 3). gcc warns only when the absorbed value exceeds a byte, so some
cases are silent. Three-digit octal would bound the escape.
