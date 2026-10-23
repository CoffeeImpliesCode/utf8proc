# Changelog

Fork changes relative to utf8proc 2.12.0 (`79cdd5ab40c79afa559f689ffc13b76812dee1ac`); Unicode data 18.0.0.

- Nested consumer builds forward the target query, CPU, optimize mode, linkage, runtime mode, caches, install prefix, and job width; non-runnable targets install instead of run.
- Devenv build commands locate this SDK and use `ZIG_LOCAL_CACHE_DIR` and `ZIG_GLOBAL_CACHE_DIR`, filling missing values from `XDG_CACHE_HOME` or `TMPDIR`.
- Added Nix `static` and `shared` outputs with `default` set to `static`.
- Installed `libutf8proc.pc` uses a relocatable prefix and linkage-specific consumer flags.
- Added static/shared builds with `-Dlinkage` and runtime dispatch with `-Druntime`; the options are independent, and unsupported dynamic targets fail rather than substitute a static library.
- Runtime mode requires an explicit `LoadSource`; the smoke and consumer programs accept `--provider` or `UTF8PROC_TEST_PROVIDER`.
- Runtime loading retries failed requests, treats repeated successful requests as idempotent, rejects a different provider after success, and keeps the provider loaded until process exit.
- Cross-target translation uses the target C preprocessor where Aro cannot parse system headers; other targets use Aro directly.
- Build steps include `test`, `smoke`, `exercise`, `check`, `upstream-test`, and `consumer`; install provides the header, selected library, license records, test data, and pkg-config metadata.
- Conformance data is committed under `testdata/` and embedded in tests, so test runs need no source-tree path or download.
- The upstream-test step builds and runs nine C test programs; the host-dependent `wcwidth` comparison and property dumper are not run.
- Added a Zig facade over the translated C API and exposed the complete translated header through `pub const c`.
- Kept `utf8proc_property_t` opaque; Zig callers use upstream's exported property accessors rather than a mirrored C bit-field layout.
- Mapping results use `OwnedString.deinit`, which releases them through `utf8proc_free`; callers must release runtime-loaded results through their allocating provider.
- `GraphemeIterator` carries state across ordered break checks for current extended grapheme clusters; stateless `graphemeBreak` retains upstream's Unicode 8 behavior.
- Slice APIs reject `NULLTERM`; `CHARBOUND` requires a non-null `last_boundclass`, while the raw C route remains available for C-string callers.
- `reencode` checks for its required trailing byte before writing and returns `WorkspaceTooSmall` for a short buffer.
- `decompose` and `decomposeCustom` reject overlapping input and output before writing; `normalizeUtf32` and `reencode` retain upstream's in-place use.
- The facade reports length overflow and input/output overlap as typed errors before passing invalid slices to C.
- At this upstream version, `UTF8PROC_STABLE` is forwarded but has no effect; `UTF8PROC_STRIPCC` applies through normalization and functions that call it, not through `decomposeChar`.
- Custom mapping callbacks run synchronously once per code point on each pass; `mapCustom` makes two passes, so callbacks must return consistent results.
- Fork-authored files now carry the authorized MIT grant; upstream grants and Unicode License V3 continue to govern their respective files.
- Corrected the examples for Hangul composition, regional-indicator segmentation, normalization workspace contents, and case-conversion results.
- The build compiles bundled upstream sources; it offers no system-library mode because `utf8proc_free` is new in 2.12.0 and older libraries do not provide it.
