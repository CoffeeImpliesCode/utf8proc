# utf8proc

A Zig facade and build package for the upstream utf8proc C library.
Upstream release: 2.12.0; Unicode data version: 18.0.0.

## Source deviations from upstream

- No upstream C implementation, public header, generated table, or test source is modified.
- The fork adds a typed facade in `zig/`, runtime loading in `runtime/`, and Zig tests and examples.
- Upstream's README is preserved as `README.upstream.md`.

## Build deviations from upstream

- `build.zig` adds the facade, tests, smoke program, API exercise, target checks, upstream C tests, and consumer steps to the single C translation unit. The core links libc.
- `zig translate-c` translates `utf8proc.h`. Aro handles most targets; nine NetBSD, five OpenBSD, and `x86-windows` use their target C preprocessor first.
- `upstream-test` builds nine upstream C tests. It excludes `charwidth` (host `wcwidth` comparison), `printproperty` (a property dumper), benchmarks, the Make-based installer, and fuzzers.
- The build generates `libutf8proc.pc` from upstream's template and selects consumer flags for the chosen linkage.
- There is no system-library link option. Runtime loading is separate.

## Support matrix

The build's six declared targets are:

| Target | Static archive | Shared artifact | Runtime loading |
|---|---|---|---|
| `x86_64-linux-gnu` | yes | yes | yes |
| `aarch64-linux-gnu` | yes | yes | yes |
| `aarch64-macos-none` | yes | yes | yes |
| `x86_64-windows-gnu` | yes | yes | yes |
| `riscv64-linux-gnu` | yes | yes | yes |
| `wasm32-wasi` | yes | no | no |

Runtime loading is unavailable on WASI, Emscripten, and freestanding targets.

## Consumption

### Zig

For a local checkout beside the consumer, add this to `build.zig.zon`:

```zig
.dependencies = .{
    .utf8proc = .{ .path = "../utf8proc" },
},
```

Import the module from `build.zig`:

```zig
const dep = b.dependency("utf8proc", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("utf8proc", dep.module("utf8proc"));
```

| Product | Build API name | Use |
|---|---|---|
| Zig module | `utf8proc` | Typed facade; includes its native link dependency. |
| Native library | `utf8proc` | `dep.artifact("utf8proc")`; static by default. |

The raw translated C declarations are exposed by the module as `c`.

### C

Use `include/utf8proc.h` and the `utf8proc` artifact. Define `UTF8PROC_STATIC` when linking the static archive. The installed `lib/pkgconfig/libutf8proc.pc` supplies the linkage-specific flags.

### Build options

- `-Dlinkage=static` is the default and installs `libutf8proc.a`.
- `-Dlinkage=dynamic` installs a shared library with upstream ABI version `3.3.0`; targets without a shared-library loader are rejected. A static library artifact does not make the final executable fully static.
- `-Druntime=true` defaults to `false` and is independent of linkage. The module links no native library and requires an explicit runtime provider.
