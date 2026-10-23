# Fork notes

Upstream: utf8proc 2.12.0. Unicode data: 18.0.0.

## Source additions

The upstream C implementation, public header, generated data table, and test sources are unchanged.

| File | Change and reason |
|---|---|
| `zig/root.zig` | Adds typed Zig operations and ownership helpers so callers avoid raw option words and direct C-buffer management. |
| `zig/translate.h` | Translates upstream's header and adds compiler 128-bit typedefs needed by Aro on some targets. |
| `zig/api_exercise.zig` | Calls every public facade function so compile steps analyze the full API. |
| `tests.zig` | Embeds Unicode corpora and tests conformance, regressions, and facade contracts without runtime file reads. |
| `smoke.zig` | Exercises deterministic facade results in a real executable without a test harness. |
| `runtime/graph.zig` | Wires generated dispatch to translated declarations for runtime-loaded builds. |
| `runtime/library.zig` | Defines utf8proc's symbol set and provider checks outside the reusable loader. |
| `runtime/loader.zig` | Workspace-provided loader state machine and platform calls keep generic loading code reusable across SDKs. |
| `runtime/generate.zig` | Workspace-provided generator derives dispatch wrappers from translated declarations instead of handwritten signatures. |
| `runtime/sync.c` | Workspace-provided platform locks, condition variables, and thread identities synchronize load attempts. |
| `runtime/sync.h` | Declares the prefixed synchronization interface so SDK loader symbols do not collide. |
| `consumer/build.zig` | Builds a standalone executable through `dep.module("utf8proc")`; forwards linkage, runtime mode, and program arguments. |
| `consumer/build.zig.zon` | Declares the consumer's identity and local `.path = ".."` dependency. |
| `consumer/src/main.zig` | Checks independent facade expectations in linked and runtime-loaded builds. |

`utf8proc.c` points to a copyright notice absent from `utf8proc_data.c`. `NOTICE.md` records the mismatch and leaves upstream bytes unchanged. `LICENSE.md` carries the compiled table's Unicode terms. `testdata/Unicode-License-V3.txt` accompanies the conformance data.

## Upstream files edited in place

| File | Change and reason |
|---|---|
| `build.zig` | Extends upstream's root build script so one Zig graph can build and package the facade without relocating the C tree. |
| `build.zig.zon` | Sets this package's fingerprint and expands `.paths` so fetched copies include sources, fixtures, tests, records, and packaging. |
| `.gitignore` | Appends root-anchored ignores for Zig outputs and local devenv state without removing upstream rules. |
| `README.md` | Replaces upstream's text with the fork README. `README.upstream.md` preserves the original. |

## Build graph

- The root script extends upstream's one-source C build with the Zig facade, runtime dispatch, tests, smoke program, API exercise, target checks, upstream C tests, and a standalone consumer package.
- On Zig 0.17, the nested consumer build uses `--build-file`, `ZIG_GLOBAL_CACHE_DIR`, and `ZIG_LIB_DIR`; it keeps the caller's cwd and uses a separate local cache.
- The library build defines `UTF8PROC_STATIC` for static linkage and `UTF8PROC_EXPORTS` for the shared library. The translation header defines neither macro.
- Runtime dispatch generation consumes actual translation output, so the function signatures stay derived from the translated header.
- `zig/api_exercise.zig` is compiled by the default step and `check`. It runs from `test` or `exercise` and is not installed.
- Tests embed all four conformance corpora. `testdata/Lowercase.txt` and `Uppercase.txt` follow upstream's extraction from `DerivedCoreProperties.txt`. Keep the bare final `# Total code points:` marker without a count or trailing newline.
- The build reads `UNICODE_VERSION` from `data/Makefile` for `test/misc.c`. Without that define, upstream silently skips its Unicode-version assertion.
- `check` compiles the declared target configurations and does not run code. An explicit `-Dtarget` checks only that target.
- There is no system-library mode. Libraries before 2.12.0 lack `utf8proc_free`, and 2.12.0 changed declared types without changing widths.
- `package.nix` wraps the Zig build and selects linkage. The flake exposes static and shared outputs with static as default. The devenv shell provides tools and keeps task outputs and caches outside the checkout.
- The pinned Nixpkgs revision predates Zig 0.17.0; flake and devenv extend its Zig recipe with the 0.17.0 release metadata.

## Platform boundaries

The target support matrix is in `README.md`.

- Target libc headers that use unsupported `_Pragma`, conflicting `size_t` declarations, MIPS byte-order macros, or `_ALLOCA_S_MARKER_SIZE` need preprocessing before Aro translation.
- A runtime provider must export all 31 declared functions and the `utf8proc_utf8class` data object. ABI checks require a Unicode version string but do not compare it with 18.0.0, so provider tables must match this build.
- The provider owns memory returned by its allocation functions. `OwnedString.deinit` calls that provider's `utf8proc_free`. The loader does not check whether a Windows host and DLL use the same C runtime.
