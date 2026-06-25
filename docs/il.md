# MT IL — v0 (draft)

The textual SSA form that MT pipeline stages exchange. It is both the
user-facing input language (like QBE's IL) and the interop contract
between the stages.

Rules of the road:

- This file is the contract. A stage that wants something the format
  cannot express changes this spec first, bumps the version, and
  updates both parsers in the same change.
- `tests/il/*.ssa` is the shared corpus. Every parser (ATS3 or Zig)
  must accept every file in it.

## Lexical

- Comments run from `#` to end of line.
- Temporaries are `%name`, globals (function symbols) are `$name`,
  block labels are `@name`.
- Whitespace is insignificant except as a token separator; one
  instruction per line.

## Types

| type | meaning        |
|------|----------------|
| `w`  | 32-bit integer |
| `l`  | 64-bit integer |

(Floats, memory types, and aggregates are deliberately out of scope
for v0.)

## Structure

```
module   := function*
function := "function" type "$" name "(" params ")" "{" block+ "}"
params   := [ type "%" name ("," type "%" name)* ]
block    := "@" label instr* terminator
```

Every block ends in exactly one terminator. The first block of a
function is its entry; entry blocks take no phi nodes in v0.

## Instructions

Three-address form, `%dst =type op operands`:

| instruction              | meaning                          |
|--------------------------|----------------------------------|
| `%d =t copy %a\|const`   | move                             |
| `%d =t add %a, %b`       | addition                         |
| `%d =t sub %a, %b`       | subtraction                      |
| `%d =t mul %a, %b`       | multiplication                   |
| `%d =t div %a, %b`       | signed division                  |
| `%d =t phi @b1 %a, @b2 %b` | SSA phi                        |

Terminators:

| instruction              | meaning                          |
|--------------------------|----------------------------------|
| `ret %a\|const`          | return a value                   |
| `jmp @b`                 | unconditional jump               |
| `jnz %a, @then, @else`   | branch on nonzero                |

Integer constants are decimal, optionally negative.

## Example

See `tests/il/add.ssa` for the canonical smallest module:

```
function w $add(w %a, w %b) {
@start
    %c =w add %a, %b
    ret %c
}
```

## Versioning

This is v0 while everything is in flux.
