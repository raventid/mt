# MT

Minimalistic translator. 60% of LLVM power in 5% of effort.

## Requirements

[Zig](https://ziglang.org) 0.16.0 or newer.

## Build

```sh
zig build          # compile to zig-out/bin/mt
zig build run      # build and run
zig build test     # run unit tests
```

## Layout

- `src/main.zig` — CLI entry point (the `mt` executable)
- `src/root.zig` — library root, importable by other packages as `@import("mt")`
- `build.zig` / `build.zig.zon` — build script and package manifest
