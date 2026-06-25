# MT

Minimalistic translator. 60% of LLVM power in 5% of effort.

## Architecture

MT is a pipeline of stages that exchange one textual SSA form —
**MT IL**, specified in [docs/il.md](docs/il.md).

```
input.ssa ──> ATS3 front/middle ──(IL text)──> ATS2 backend ──> out.s
              parse, validate,                 isel, regalloc,
              SSA passes                       emission
              (XATS2JS → Node)                 (patscc → native C)
```

## Requirements

- [Node.js](https://nodejs.org) (recent; the ATS3 toolchain itself runs on Node)
- [ATS2/Postiats](http://www.ats-lang.org) 0.4.2 (`patscc`), e.g. `brew install ats2-postiats`
- [Zig](https://ziglang.org) 0.16.0 or newer

## Build

```sh
make vendor    # fetch the pinned ATS3 toolchain into vendor/XATSHOME
make           # build all stages
make smoke     # prove both ATS toolchains work on this machine
make test      # smoke tests + Zig unit tests
```

`scripts/mt` is the user-facing driver: `scripts/mt tests/il/add.ssa`.
It wires up whichever stages are currently built.

## Layout

- `docs/il.md` — **the IL spec; the contract between all stages**
- `ats/` — ATS3 sources (front/middle), built by `ats/Makefile` via XATS2JS
- `ats2/` — ATS2 sources (backend), built by `ats2/Makefile` via patscc
- `zig/` — Zig insurance stages (`zig build` from inside `zig/`) [not actually used much]
- `tests/il/` — shared IL corpus all sides must parse
- `scripts/mt` — pipeline driver
- `vendor/XATSHOME` — pinned ATS3 toolchain (gitignored; `make vendor`
  recreates it at the commit recorded in the top-level `Makefile`)

## Toolchain notes
ATS3.

- XATSHOME is pinned to one commit; upstream moves daily. Bump the
  `VENDOR_PIN` in `Makefile` deliberately and re-run `make test`.
- The ATS3→JS compiler runs under `node --stack-size=8801`-ish for a
  reason: the toolchain (and code it generates) recurses deeply.
  Generated user code gets **no tail-call elimination** from either
  compiler build (verified empirically): plain tail recursion is
  stack-bound. Deep loops must use the prelude's trec/stream
  combinators (`g_state$updts1x` et al.), which the JS target
  implements as native while-loops in the runtime — or MT-specific
  native loop drivers via the same `$extnam()` + `.cats` glue pattern
  the prelude itself uses.
- JS-side FFI glue (when needed) follows upstream's `.cats` convention
  and should stay isolated in dedicated modules.

ATS2. 

Backend stages compile with `-DATS_MEMALLOC_LIBC` so linear heap
allocation (`arrayptr`) is backed by malloc/free; the
typechecker enforces that every linear allocation is consumed
(`ats2/src/smoke.dats` demonstrates — deleting its `arrayptr_free`
makes compilation fail).
