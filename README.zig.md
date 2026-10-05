# README.zig.md — the utf8proc Zig package

A Zig 0.16 package that compiles the upstream C library utf8proc **2.12.0**
(Unicode 18.0.0) from source in this repository and publishes a Zig facade over
it. Nothing about the Unicode algorithm is reimplemented here: the shipped
`utf8proc.h`, `utf8proc.c` and `utf8proc_data.c` are upstream's bytes, and their
SHA-256 digests match the pinned commit `79cdd5ab40c79afa559f689ffc13b76812dee1ac`
— measured and recorded in [`UPSTREAM.md`](UPSTREAM.md) and
[`UPSTREAM.sha256`](UPSTREAM.sha256), and since checked twice by the driver on
2026-10-03: `sha256sum -c UPSTREAM.sha256` exited 0 on all 56 records, and the 53
pinned-tree paths compared against `git cat-file blob 79cdd5ab…:<path>` differed
in exactly the three files this fork edits in place. Both carry receipts below.
**Both were observed before this wave**, which added a fourth edited-in-place
file — `README.md`, whose upstream bytes now live at `README.upstream.md` — so
they are history for the tree as it stands. What re-running them should report
is stated as an expectation, not a result, in
[verification status](#verification-status).

> **How to read this document.** Every statement about the code is
> `SOURCE-CONFIRMED` — read out of a file in this repository. Behaviour that has
> actually been observed running is recorded in
> [verification status](#verification-status) with the driver's receipt for it;
> behaviour with no receipt there is `PENDING-VERIFICATION`. Nothing in this
> document is a result the driver did not record. One gate — the filtered-fetch
> consumer — is proved outside these documents, and
> [verification status](#verification-status) says where its result lives.
>
> The repository's README is [`README.md`](README.md), which follows this
> project's canonical order — native-source deviations, native-build deviations
> and the dated history link, the build/run/test matrix, then consumption. This
> document is the separate Zig interface documentation it points at: the calls,
> the owned preconditions, the error set, the fixtures, and the per-receipt
> detail behind its matrix rows.

## What this package is for

Unicode text processing that is missing from everything else in this workspace:
canonical and compatibility normalization (NFC, NFD, NFKC, NFKD), canonical
decomposition, full case folding including the non-trivial multi-codepoint
mappings, simple case mapping, UAX #29 extended grapheme cluster segmentation,
general category and East Asian width lookup. SheenBidi, its neighbour here,
implements UAX #9 bidi and none of these; HarfBuzz deliberately does not
normalize at all.

## Requirements

* **Zig 0.16.0**, the pinned toolchain. Nothing else.
* No network access at build or test time. The Unicode conformance corpora are
  committed under `testdata/`.
* No system utf8proc and no ICU. The archive is built from source in this
  repository. (The Nix output in this repository does install `pkg-config`
  metadata for a C consumer; that is a delivery detail, not a build dependency.
  See the consumption section of `README.md`.)
* `libc`. The one dependency, because upstream allocates with `malloc`/`realloc`
  and frees with `free`.

## Build steps

| Step | What it does |
|---|---|
| `zig build` | Installs `libutf8proc.a`, `include/utf8proc.h` and `LICENSE.md`, and **compiles** the smoke program and the API exercise. Neither executable is installed: they are proofs, not deliverables, and `zig-out/bin/` is not written |
| `zig build test` | The package's own behavioural tests: whole-corpus normalization conformance, whole-corpus grapheme conformance, the full case ranges, and the boundary cases — and then the API exercise. Real `addTest` / `addRunArtifact` work for the selected target, not a compile-only step |
| `zig build exercise` | Runs only the API exercise: a separate program with its own `main` that calls **every** public facade function unconditionally, each against a small expected answer written in that file. It reads no fixture and embeds none |
| `zig build smoke` | Runs the example in `smoke.zig` |
| `zig build upstream-test` | Builds and runs nine of upstream's own C test programs against this archive |
| `zig build check` | Compiles every public facade body, every test, the exercise, the smoke example and the upstream test programs for **all six** cross targets without running any of them |
| `zig build -Dtarget=<triple> check` | The same, for one selected triple |
| `zig build -Dlinkage=dynamic` | Installs the shared object under upstream's own ABI version `3.3.0` (`Makefile:25-27`, distinct from the API version, `utf8proc.h:66-68`): `libutf8proc.so.3.3.0` with soname `libutf8proc.so.3` and a `libutf8proc.so` link on ELF, `libutf8proc.3.3.0.dylib` with install name `libutf8proc.3.dylib` on Darwin, `utf8proc.dll` plus its import library on Windows |
| `zig build -Druntime=true` | Routes every native entry point through one process-lifetime table and links **no** native library into the module, neither the one this tree builds nor an installed one. The library is still built and installed, so a caller may name a provider this tree did not build. Orthogonal to `-Dlinkage`; a linked build is unchanged and `load` panics there with a message. **Partly observed:** eight runtime-loaded cells in epoch `20261004T232823091897Z-23133` carry a receipt for the successful path, against this tree's own provider; the failure, retry and provider-change contracts have none |

The six cross targets are `x86_64-linux-gnu`, `aarch64-linux-gnu`,
`aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu` and
`wasm32-wasi`. `-Dtarget=` narrows `check` to exactly that triple and nothing
else; the default is all six. A target that cannot be built here is a boundary
recorded in this document, never a dropped row.

## Importing

```zig
const utf8proc = @import("utf8proc");
```

The module name and the artefact name are both `utf8proc`. A consumer needs
`dep.module("utf8proc")` only — the module already carries its own link
dependencies and include paths, so adding `dep.artifact("utf8proc", .{})`
alongside it is redundant and this package does not ask for it.

In `build.zig.zon`:

```zig
.dependencies = .{
    .utf8proc = .{ .path = "../utf8proc" },
},
```

Package identity: `.utf8proc`, fingerprint `0xdcddf08d3f5ccfa0`. The consumer
package that exercises this one is `.utf8proc_consumer`, fingerprint
`0x99023fc438b383d5`.

The public header is installed at `zig-out/include/utf8proc.h`, so a C consumer
can `#include <utf8proc.h>` against the same archive with no Zig in between.

### What a fetched copy contains

`paths` is the closure, and the closure is the package: `utf8proc.c`,
upstream's own C suite, generator and build files, and **upstream's README under
its preserved path `README.upstream.md`**; the provenance and licence records,
including `FORK-LICENSE.md`; this wave's packaging files (`package.nix`,
`flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`) with the driver's
`flake.lock` beside them; and the `consumer/` package. Nothing needed to compile,
test, run the upstream suite or read a corpus is reachable only from a file left
out of it — and nothing a recipient needs in order to read the licence terms is
either.

That distinction matters because **a path dependency never reads `.paths`**. A
local `consumer/` resolves this package from the working tree, so a closure that
omitted the native core would still resolve and still build — which is exactly
what happened before the core was added back. A dependent who *fetches* the
package would have received a package with no library in it. The `consumer` job
in `.github/workflows/verify.yml` walks this repository and compares it against
`.paths` in both directions, and the seven files it permits to be absent —
upstream's six CI files and this fork's own workflow — are named in that step
and in [`UPSTREAM.md`](UPSTREAM.md#what-is-carried-but-is-not-part-of-the-package).

**Two closure requirements arrived with this wave**, and both are additions to
`.paths` rather than substitutions: upstream's README must travel under
`README.upstream.md`, and so must `FORK-LICENSE.md` together with the five
packaging files. A fetched copy without them loses upstream's own README, the
grant over the fork's files, and its standalone delivery. `build.zig.zon` is the
delivery role's file; this document states the requirement and asserts nothing
about whether the list already satisfies it.

**A third requirement arrived later the same day: `flake.lock`.** The driver wrote
it into this tree on 2026-10-04, after the delivery files it belongs to, and it is
listed in `.paths` beside `flake.nix`. It is the resolved form of the one input
`flake.nix:15` declares — the same
`c7def046b9a883d46974757852106483d741586f` — plus the `narHash` for those bytes,
so it is not a second answer to a question `flake.nix` leaves open. Listing it is
also what the closure demands: the `consumer` job in
`.github/workflows/verify.yml` walks the repository against `.paths` in both
directions, its carried-not-shipped list is for CI definitions rather than for a
lock, and `.gitignore:82-85` deliberately declines to ignore the locks because
they are real inputs. No `devenv.lock` is listed, because none exists:
`devenv.yaml:19-22` records that the lock is the driver's to write. `flake.lock`
is the driver's file; [`FORK-LICENSE.md`](FORK-LICENSE.md) excludes its terms and
[`NOTICE.md`](NOTICE.md) inventories it as the driver's.

## The two routes

### The raw C route — `utf8proc.c`

`pub const c` is the translated, **unmodified** `utf8proc.h` as shipped: every
option flag, every error macro, every Unicode enumeration, the
`utf8proc_property_t` record and every exported function. Its documentation is
upstream's own, in the file that is actually installed — read
`zig-out/include/utf8proc.h` rather than trusting a restatement here.

Use it for anything the facade does not wrap: `combining_class`, `bidi_class`,
`decomp_type`, `boundclass`, `ignorable`, `control_boundary` and the sequence
indices, all reachable through `c.utf8proc_get_property`.

### The consumer surface — the module's own declarations

The facade adds three things and nothing else: Zig types for the option word and
the error set, caller-buffer entry points that allocate nothing, and ownership
of the preconditions upstream leaves to the caller.

#### Types

| Type | What it is |
|---|---|
| `Status` | the C signed status word: a count on success, one of five negative codes on failure |
| `Option` | the C `unsigned int` option word |
| `Category`, `BidiClass`, `DecompType`, `BoundClass`, `IndicConjunctBreak` | the Unicode enumerations. The last four have **no** dedicated upstream accessor and are reachable only through the raw route |
| `Property` | `*const` opaque handle on one entry of upstream's static property table. **Opaque on purpose** — see [why](#why-property-is-opaque) |
| `CustomFunc` | `?*const fn (i32, ?*anyopaque) callconv(.c) i32`, passed to `decomposeCustom` and `mapCustom` |
| `Error` | the error set: **five** upstream statuses plus one this facade raises itself, `InputOutputOverlap`. See [the error set](#the-error-set-is-five-upstream-codes-and-two-refusals) |
| `Options` | `packed struct(u32)`: the fifteen option flags as independent booleans, every one defaulting to `false`, plus a `reserved: u17` that preserves option bits this version does not define, with `toBits()`/`fromBits()` and the `nlf2lf` constant |
| `Decoded` | `{ bytes_read: usize, codepoint: u21 }` |
| `Encoded` | `union(enum) { bytes: u3, rejected }` |
| `DecomposeResult` | `union(enum) { written: usize, needs_more: usize }` |
| `ReencodeError` | `Error` plus `WorkspaceTooSmall` |
| `OwnedString` | a UTF-8 string allocated by **upstream's** `malloc`, released only by `utf8proc_free` |
| `GraphemeIterator` | owns UAX #29 stateful-break state so the ordering requirement cannot be forgotten |

Which flag which entry point honours is upstream's property, not the type's, and
the per-flag table is in [`zig/root.zig`](zig/root.zig) beside the struct. Three of
those rows are worth repeating here, because each has a plausible-looking wrong
reading. **`stripcc` is read by `normalizeUtf32` and by nothing else.**
`UTF8PROC_STRIPCC` appears exactly three times in the core — `utf8proc.c:619`,
`:627` and `:641` — and all three are inside `utf8proc_normalize_utf32`, which
spans `:617-747`. `reencode` honours it only because it calls that function
first (`utf8proc.c:752`) and `map` only because it calls `reencode` (`:804`);
`decomposeChar` (`:445-531`), `decompose` and `decomposeCustom` never read it at
all, which agrees with the header listing it for `utf8proc_normalize_utf32` and
`utf8proc_reencode` (`utf8proc.h:601`, `:624`) and not for
`utf8proc_decompose_char` (`utf8proc.h:523-532`). The consequence for a caller is
exact: `decompose(str, dst, .{ .stripcc = true })` returns every control character
unchanged, and stripping or converting them needs `normalizeUtf32` or `reencode`
with the same word.

**`rejectna` is not about the letters N and A.** It means *return an error if the
codepoint is unassigned*, and it is read in exactly one place:
`UTF8PROC_REJECTNA` appears once in the core, at `utf8proc.c:468`, inside
`utf8proc_decompose_char` (`utf8proc.h:164`, `:228`, `:524`). So `decomposeChar`,
`decompose` and `map` reach it and `normalizeUtf32` and `reencode` do not, and
what it produces is `error.NotAssigned` (`utf8proc.c:468-470`) rather than a
silent drop. `stripna` is its opposite and sits six lines below it in the same
function (`utf8proc.c:474-476`): it returns `0`, dropping the unassigned
codepoint, and that is why one of the two raises and the other does not.

**`stripmark` without `compose` or `decompose` is refused by `decompose`,
`decomposeCustom`, `map` and `mapCustom`** — upstream's own check
(`utf8proc.c:549-551`) — while `decomposeChar` has no such check
(`utf8proc.c:503-506`) and strips the mark.

And **`stable` is accepted and forwarded but does nothing at this pin**:
`UTF8PROC_STABLE` is declared at `utf8proc.h:154` and the only five occurrences in
`utf8proc.c` are upstream's own
`utf8proc_NFD`/`NFC`/`NFKD`/`NFKC`/`NFKC_Casefold` passing it to
`utf8proc_map` (`utf8proc.c:820, 826, 832, 838, 844`); no code branches on it.
Setting it changes nothing here, and nothing in this package claims it does.

Beyond those rows, an option word a given entry point does not implement is
**silently ignored**. Upstream rejects exactly two illegal combinations, both
checked at the top of `utf8proc_decompose_custom` (`utf8proc.c:547-551`) — the
ones above — and validates nothing else, so a word this facade accepts, forwards
and this entry point does not read changes no result and raises no error.
`Options.reserved` is the same fact stated for undeclared bits: `utf8proc.h`
stops at `UTF8PROC_STRIPNA = 1<<14`, `fromBits` preserves everything above it, and
upstream ignores those bits too — which is what makes it safe to round-trip an
option word taken from a *newer* utf8proc.

#### Functions

| Function | Allocates | Returns |
|---|---|---|
| `version()` | no | `[:0]const u8` — upstream's API version, stringized from the shipped header's macros |
| `unicodeVersion()` | no | `[:0]const u8` — upstream's Unicode data version, from the literal in `utf8proc.c` |
| `errorMessage(status)` | no | `[:0]const u8` — upstream's own sentence, total over all inputs |
| `decode(bytes)` | no | `Error!?Decoded` — `null` for an empty slice |
| `codepointValid(cp)` | no | `bool` |
| `encodeChar(cp, *[4]u8)` | no | `Encoded` |
| `property(cp)` | no | `Property` |
| `category(cp)`, `categoryString(cp)` | no | `Category`, `[:0]const u8` |
| `charWidth(cp)`, `charWidthAmbiguous(cp)` | no | `i32`, `bool` |
| `toLower(cp)`, `toUpper(cp)`, `toTitle(cp)` | no | `i32` — **simple** mapping, not folding |
| `isLower(cp)`, `isUpper(cp)` | no | `bool` |
| `utf8Class(byte)` | no | `i8` — expected length for a sequence starting with `byte` |
| `decomposeChar(cp, dst, opts, last_boundclass)` | no | `Error!DecomposeResult` — **exactly one codepoint in, one decomposition out**; it never composes, whatever `opts.compose` says, because composition needs the *previous* codepoint. Refuses `error.InvalidOptions` when `opts.charbound` is set and `last_boundclass` is `null` |
| `decomposeCount(str, opts)` | no | `Error!usize` — upstream's own null-buffer sizing query |
| `decompose(str, dst, opts)` | no | `Error!DecomposeResult` — **the primary path**; refuses `error.InputOutputOverlap` |
| `decomposeCustom(str, dst, opts, custom, data)` | no | `Error!DecomposeResult`; refuses `error.InputOutputOverlap` |
| `normalizeUtf32(codepoints, opts)` | no | `Error!usize` — in place; `codepoints[0..returned]` is the result |
| `reencode(workspace, length, opts)` | no | `ReencodeError!usize` |
| `graphemeBreak(prev, cur)` | no | `bool` — **legacy, stateless, Unicode 8 semantics**: it omits GB10, GB12 and GB13, so it answers every RI/RI pair "no break" and has no way to count a run |
| `firstGraphemeBreak(codepoints)` | no | `?usize` |
| `map(str, opts)` | **yes, upstream `malloc`** | `Error!OwnedString` |
| `mapCustom(str, opts, custom, data)` | **yes, upstream `malloc`** | `Error!OwnedString` |
| `GraphemeIterator.reset()`, `.next(prev, cur)` | no | `void`, `bool` |

`decompose` + `reencode` is the allocation-free path and the one to reach for.
Upstream's own header says applications wanting control over memory allocation
should call `utf8proc_decompose` followed by `utf8proc_reencode` directly, and
`utf8proc_map` is built from exactly those two with a `malloc` in the middle.

`version()` and `unicodeVersion()` return what the shipped header's macros and
`utf8proc.c`'s literal say, stringized rather than restated. **The tests
deliberately do not pin those two strings** — a test that pins a version string
tests the version, not the behaviour. They are asserted only to be distinct,
NUL-terminated strings, which is a behavioural claim.

### The translation route is chosen per target

`zig translate-c` reads exactly one header, and it can only preprocess a target's
C library itself where that library's headers survive being preprocessed by Aro.
For most of the published matrix they do. For fifteen of the fifty-three they do
not, and those fifteen are named in `build.zig`'s `translationRoute` with the
header line and the mechanism that fails — nine NetBSD targets, five OpenBSD
targets and `x86-windows`. For exactly those, the build runs the target's own C
preprocessor first, `zig cc -E -dD` — the same pinned compiler that compiles
`utf8proc.c` — and hands the translator what it wrote. Every other target gets
Aro reading [`zig/translate.h`](zig/translate.h) directly.

**Both routes read this repository's own `utf8proc.h`**, with this repository's
root as the include path and the export macros supplied by `build.zig`, which is
the only authority for them: `libraryMacros(linkage)` goes on the C core's own
compile line and `consumerMacros(linkage)` goes on the translation line and on
every dependent's module, so the static delivery defines `UTF8PROC_STATIC` in all
three places and the shared delivery defines `UTF8PROC_EXPORTS` only on the core's
line. `zig/translate.h` defines neither and must not: a header that sets its own
export macro would describe a linkage the build did not choose. Nothing is stubbed,
narrowed, renamed or substituted on either route, and no predefine is invented
besides the compiler's own capability macro.

**The guarded 128-bit bridge.** `zig/translate.h` restates the compiler's own
`__int128_t` and `__uint128_t`, under `#if defined(__SIZEOF_INT128__)`. Nothing
about utf8proc's API, ABI or archive depends on them. They are there because
`generic-netbsd/arm/cdefs.h:62-63` defines `__ALIGNBYTES` as
`(sizeof(__int128_t) - 1)`, `-dD` keeps that definition beside the expanded text,
and `zig translate-c` emits no implicit typedef to stand in for it — so the
translation reached a bare `__int128_t` with nothing behind the name. That was
**observed**: `check -Dtarget=aarch64-netbsd` failed with `use of undeclared
identifier '__int128_t'` at `utf8proc-translate.zig:1191`
(`local://foundation-matrix-utf8proc-netbsd-preprocess-check.log`). The guard is
the compiler's own capability macro, so a target without `__int128` declares
neither, and both routes read the same lines.

**No target was dropped and no test was weakened to get there.** The five
OpenBSD targets are named by their own causes — the three ILP32 ones for Aro's
`size_t` disagreement, and `mips64-openbsd` **and** `mips64el-openbsd` for
`generic-openbsd/mips64/endian.h` refusing to define `BYTE_ORDER` without
`__MIPSEL__` or `__MIPSEB__`. Those last two are two architectures, not one:
separate libc directories and separate `std.Target.Cpu.Arch` members, `.mips64`
and `.mips64el`. There is no compatibility shim, no fake ABI and no
platform-conditional deletion of a required target; the current 53-platform run
builds all 53.

## The examples

Six examples. Each is a **complete `test` declaration** — or, in the first case, a
helper function together with the test that exercises it — not a fragment cut out
of a longer file. They belong in a test root carrying the three imports they
use:

```zig
const std = @import("std");
const testing = std.testing;
const utf8proc = @import("utf8proc");
```

The two `zig` blocks under [importing](#importing) are the opposite: labelled
fragments — a single `const`, and one field of a manifest — that stand in
context and are not declarations on their own.

Every assertion below is a value read out of the Unicode standard — UAX #15's
normalization and Hangul rules, `CaseFolding.txt`, UAX #29's well-formedness
rules and GB12/GB13 — and never a restatement of what this library happened to
return. Each block handles its own errors, with `try` or with `expectError`.
**No build step compiles this file.** `check` compiles the facade module
(`zig/root.zig`) and the `tests.zig`, `zig/api_exercise.zig` and `smoke.zig`
roots, plus the upstream C programs; it never reads a Markdown document.

**They have nonetheless been compiled and run, once, outside this package.** The
driver lifted these six blocks verbatim into a scratch package that depends on
this one by path and ran `zig build run`: **exit 0, 6/6 steps, 6/6 tests** —
`local://foundation-matrix-utf8proc-all-readme-examples-r3.log`, which records
`run test 6 pass (6 total)`. That is the only reason the three earlier attempts
exist, and they are worth keeping as history because each one found something
reading had not:

| Attempt | Exit | What it found |
|---|---|---|
| `…-all-readme-examples.log` | 1 | nothing in this document: the scratch package's own `build.zig.zon` used an absolute path, which Zig rejects — `expected path relative to build root; found absolute path`. A harness defect |
| `…-all-readme-examples-r1.log` | 1 | the NFC block wrote `allocator.alignedAlloc(u8, 4, …)`, and Zig 0.16's second parameter is `?mem.Alignment`, not an integer — `expected type '?mem.Alignment', found 'comptime_int'`. Corrected to `.@"4"` |
| `…-all-readme-examples-r2.log` | 1 | `5 pass, 1 fail (6 total)`: the case-folding block asserted the wrong *expected* value for `toUpper(0x00DF)` — `expected 223, found 7838`, that is `U+00DF` where upstream's own issue #130 regression requires `U+1E9E` (`test/case.c:57-63`). Corrected to `U+1E9E`, beside the `toLower(0x00DF) == U+00DF` half that was already right |
| `…-all-readme-examples-r3.log` | 0 | nothing further: `6 pass (6 total)` |

**The third correction has no receipt of its own, and saying so is the point.**
The NFC block's expected result was `U+00C9` and is now `U+00E9`: NFC of `e`
followed by U+0301 is the lowercase `é`, which is what the block's own title and
its `toNfc` comment already said. Attempt r1 failed at *compile* time on the
alignment argument, so no test ran and this value was never exercised; r2 then
reported only the sharp-s failure. The correction is part of the current text and
r3's 6/6 is what confirms it — not r2, which never looked at it.

So all three corrections are part of the current text, not proposals, and no
earlier form of these blocks is current. See
[verification status](#verification-status) for the gates that were run.

### Normalize to NFC with no allocation

```zig
fn toNfc(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    // U+00E9 LATIN SMALL LETTER E WITH ACUTE is canonically
    // decomposable to U+0065 U+0301 (é). If the input already
    // contains that sequence, NFC must compose it back to U+00E9.
    const needed = try utf8proc.decomposeCount(text, .{});
    const cps = try allocator.alloc(i32, needed);
    defer allocator.free(cps);

    const written = try utf8proc.decompose(text, cps, .{});
    const length = try utf8proc.normalizeUtf32(cps[0..written.written], .{ .compose = true });

    // `reencode` reads its workspace as UTF-32 on entry and writes UTF-8 back
    // into the same bytes, so the normalized codepoints have to be in there
    // first. An uninitialized workspace reencodes whatever bytes the allocator
    // happened to hand back.
    var workspace = try allocator.alignedAlloc(u8, .@"4", 4 * length + 1);
    defer allocator.free(workspace);
    @memcpy(workspace[0 .. 4 * length], std.mem.sliceAsBytes(cps[0..length]));

    const bytes = try utf8proc.reencode(workspace, length, .{});
    return try allocator.dupe(u8, workspace[0..bytes]);
}

test "NFC composes e + combining acute into U+00E9" {
    const out = try toNfc(testing.allocator, "e\u{0301}");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("\u{E9}", out);
}
```

The `4 * length + 1` workspace is not decoration — see
[the spare byte](#the-spare-byte-reencode-needs).

### Full case folding, which is not simple mapping

```zig
test "case folding expands U+00DF to two codepoints" {
    // CaseFolding.txt gives U+00DF LATIN SMALL LETTER SHARP S the
    // full mapping F 0073 0073 ("ss"). A simple tolower/toupper
    // cannot produce two codepoints, so this distinguishes folding
    // from mapping rather than merely re-asserting it.
    var out: [8]i32 = undefined;
    const r = try utf8proc.decompose("\u{df}", &out, .{ .casefold = true });
    try testing.expectEqual(@as(usize, 2), r.written);
    try testing.expectEqual(@as(i32, 0x73), out[0]);
    try testing.expectEqual(@as(i32, 0x73), out[1]);

    // Single-codepoint mapping cannot produce "ss". Upstream's issue #130
    // regression maps sharp s to capital sharp s (test/case.c:57-63).
    try testing.expectEqual(@as(i32, 0x00DF), utf8proc.toLower(0x00DF));
    try testing.expectEqual(@as(i32, 0x1E9E), utf8proc.toUpper(0x00DF));
}
```

### Algorithmic Hangul decomposition, and where composition actually happens

```zig
test "Hangul syllables decompose and recompose algorithmically" {
    // U+AC00 HANGUL SYLLABLE GA decomposes to the jamo L
    // U+1100 and V U+1161. Neither jamo is in UnicodeData.txt;
    // the pair is computed by UAX #15's Hangul syllable rule,
    // which is what makes this worth asserting.
    var out: [8]i32 = undefined;
    const r = try utf8proc.decomposeChar(0xAC00, &out, .{ .decompose = true }, null);
    try testing.expectEqual(@as(usize, 2), r.written);
    try testing.expectEqual(@as(i32, 0x1100), out[0]);
    try testing.expectEqual(@as(i32, 0x1161), out[1]);

    // Composing the jamo pair back is `normalizeUtf32`, and it needs
    // the *buffer* rather than one codepoint. `decomposeChar`
    // decomposes exactly the codepoint it is handed
    // (`utf8proc.c:445`): given U+1100 it has no predecessor to
    // compose with, and writes U+1100 straight back out.
    var pair = [_]i32{ 0x1100, 0x1161 };
    try testing.expectEqual(@as(usize, 1), try utf8proc.normalizeUtf32(pair[0..], .{ .compose = true }));
    try testing.expectEqual(@as(i32, 0xAC00), pair[0]);

    // The trailing jamo T U+11A8 rides on the same rule: the pair
    // composes to U+AC00 and the T advances it to U+AC01.
    var triple = [_]i32{ 0x1100, 0x1161, 0x11A8 };
    try testing.expectEqual(@as(usize, 1), try utf8proc.normalizeUtf32(triple[0..], .{ .compose = true }));
    try testing.expectEqual(@as(i32, 0xAC01), triple[0]);
}
```

`decomposeChar` is a one-codepoint entry point and is named for that: the
`compose` flag on it does not make it a composer, it selects which
decompositions are eligible. Composition reads the previous codepoint, so it is
`normalizeUtf32` — or `decompose` followed by `normalizeUtf32` — and nothing else.

### Regional indicators pair, and only the stateful test knows how many

```zig
test "regional indicators pair, and the stateless pair test loses count" {
    // UAX #29 GB12/GB13: regional indicators pair up two at a time,
    // so two of them are one cluster and a third starts a new one.
    try testing.expectEqual(@as(?usize, null), utf8proc.firstGraphemeBreak(&.{ 0x1F1E6, 0x1F1E8 }));
    try testing.expectEqual(@as(?usize, 2), utf8proc.firstGraphemeBreak(&.{ 0x1F1E6, 0x1F1E7, 0x1F1E8 }));

    // The legacy stateless pair test has no counter to keep, so it
    // reports "no break" for every RI/RI pair (`utf8proc.c:286-287`).
    // On the first pair that happens to be the right answer; on the
    // second pair of a run it is the wrong one, and GB12/GB13 says
    // there must be a break there.
    try testing.expect(!utf8proc.graphemeBreak(0x1F1E6, 0x1F1E8));
    try testing.expect(!utf8proc.graphemeBreak(0x1F1E7, 0x1F1E8)); // legacy: disagrees

    // The stateful iterator keeps the count and gets both right.
    var it = utf8proc.GraphemeIterator{};
    try testing.expect(!it.next(0x1F1E6, 0x1F1E7));
    try testing.expect(it.next(0x1F1E7, 0x1F1E8));
}
```

### Malformed UTF-8 is an error, not a guess

```zig
test "malformed UTF-8 is rejected" {
    // A lone continuation byte.
    try testing.expectError(error.InvalidUtf8, utf8proc.decode("\x80"));
    // 0xFF is what CHARBOUND emits; it is not valid UTF-8.
    try testing.expectError(error.InvalidUtf8, utf8proc.decode("\xFF"));
    // An over-long encoding of U+002F.
    try testing.expectError(error.InvalidUtf8, utf8proc.decode("\xC0\xAF"));
    // A surrogate half.
    try testing.expectError(error.InvalidUtf8, utf8proc.decode("\xED\xA0\x80"));
    // Above U+10FFFF.
    try testing.expectError(error.InvalidUtf8, utf8proc.decode("\xF5\x80\x80\x80"));
    // Empty input is not an error, it is simply nothing to decode.
    try testing.expectEqual(@as(?utf8proc.Decoded, null), try utf8proc.decode(""));
}
```

### An undersized reencode workspace is refused, not overrun

```zig
test "reencode refuses a workspace without the spare byte" {
    // The workspace holds the input as UTF-32 and receives the UTF-8
    // back in place, so it is filled before the call.
    const codepoints = [_]i32{'A'};

    var exact: [4]u8 align(4) = undefined; // 4 bytes per codepoint, and no spare
    @memcpy(exact[0..], std.mem.sliceAsBytes(codepoints[0..]));
    try testing.expectError(
        error.WorkspaceTooSmall,
        utf8proc.reencode(exact[0..], codepoints.len, .{}),
    );

    // One byte more is accepted, and the result is NUL-terminated
    // at workspace[result] as upstream does.
    var padded: [4 + 1]u8 align(4) = undefined;
    @memcpy(padded[0..4], std.mem.sliceAsBytes(codepoints[0..]));
    try testing.expectEqual(@as(usize, 1), try utf8proc.reencode(padded[0..], codepoints.len, .{}));
    try testing.expectEqualStrings("A", padded[0..1]);
    try testing.expectEqual(@as(u8, 0), padded[1]);
}
```

## What upstream does not guarantee, and this package therefore does not claim

These are the traps. Every one of them has a plausible-looking wrong answer and
none of them is an error return.

### `UTF8PROC_CHARBOUND` output is not valid UTF-8

Grapheme separators are `0xFF` bytes in UTF-8 output and `-1` sentinels in the
intermediate UTF-32 array. `decode` rejects `0xFF`, as it must. **CHARBOUND
output does not round-trip through this package's decoder**, and a caller that
feeds it back in is wrong, not merely unlucky.

### Invalid codepoints are passed through, not rejected

Codepoints outside `[0, 0x110000)` and the `-1` sentinel survive
`normalizeUtf32` unchanged, and composition never happens across one. Upstream
must do this: reading a property for an out-of-range codepoint would index
`utf8proc_stage1table` out of bounds. `normalizeUtf32` inherits that behaviour
and **is not input validation**. A following `reencode` then silently drops what
it cannot encode, so an out-of-range value in the middle of an input disappears
from the result rather than raising an error — which is why a caller that needs a
guarantee must validate first with `codepointValid`.

### `UTF8PROC_NULLTERM` is refused, not reinterpreted

Every entry point here takes an explicit slice. Upstream's rule is that with
`NULLTERM` the length argument is ignored, which is unsafe on an ordinary slice
— it may legitimately contain `0x00` bytes. Setting `Options.nullterm` returns
`error.InvalidOptions` rather than silently discarding the length the caller
passed. `encodeChar` does not validate its argument either: upstream encodes
surrogates `D800..DFFF` to three bytes that are not legal UTF-8, deliberately, so
the API does not change. `Encoded.bytes == 3` therefore does not imply validity.

`error.InvalidOptions` now has three sources, all named in
[the error set table](#the-error-set-is-five-upstream-codes-and-two-refusals):
upstream's own `UTF8PROC_ERROR_INVALIDOPTS`, this package refusing `nullterm`, and
this package refusing `charbound` with no `last_boundclass`.

The first is worth being precise about, because it does not reach every entry
point. Upstream checks both illegal combinations at the top of
`utf8proc_decompose_custom` (`utf8proc.c:547-551`) — `compose` together with
`decompose`, and `stripmark` with neither — so they surface through `decompose`,
`decomposeCustom`, `map` and `mapCustom`. `decomposeChar` has no such check and
accepts `stripmark` on its own (`utf8proc.c:503-506`), which is why the same option
word is an error on one entry point and a working transformation on another.

The third source exists because upstream's CHARBOUND output depends on the
`boundclass` of the previous codepoint (`utf8proc.h:533-537`): with `charbound`
set and `last_boundclass` null there is no previous state to carry, and what
upstream answers instead is the stateless rule — see
[CHARBOUND without a state pointer](#charbound-without-a-state-pointer-is-stateless-not-a-fault).

### CHARBOUND without a state pointer is stateless, not a fault

`decomposeChar` refuses `charbound` with a `null` `last_boundclass`, and the
reason is **not** that upstream would fault. Upstream's
`grapheme_break_extended` tests its state pointer at `utf8proc.c:293` and, for
`NULL`, takes its `else` branch at `utf8proc.c:334-335`, answering
`grapheme_break_simple(0, boundclass)` — the start-of-text rule against this
codepoint's own class. Nothing is dereferenced and nothing crashes. A probe of
the native call with a `NULL` state returned **two output units**, the `-1`
sentinel and the codepoint, which is the `boundary` branch at
`utf8proc.c:519-527` taken with the stateless answer.

What that answer gets wrong is exactly what UAX #29 cannot decide from one
codepoint: GB9c (Indic conjunct break), GB11 (emoji ZWJ) and GB12/GB13
(regional-indicator pairing) all need the previous codepoint's state, and the
stateless branch has none of it. So the result is not a crash to be prevented
but a plausible-looking wrong segmentation to be refused — a caller passing
`null` would get one cluster layout and no indication that the stateful one
differs.

### The spare byte `reencode` needs

Upstream requires "one spare byte of free space at the end" and checks nothing —
the requirement is a bare comment in `utf8proc.c`, repeated in the header as a
warning that the program *might crash*. A buffer of exactly `4 * length` bytes is
one byte short, and a stack array of `i32` always is. `reencode` computes
`4 * length + 1` with an ordinary comparison **before writing anything** and
returns `error.WorkspaceTooSmall`, so the overrun cannot originate here. This is
an ordinary runtime guard in every mode, never a `std.debug.assert`.

### The error set is five upstream codes and two refusals

`utf8proc_errmsg` maps exactly five negative codes —
`UTF8PROC_ERROR_NOMEM`, `OVERFLOW`, `INVALIDUTF8`, `NOTASSIGNED`, `INVALIDOPTS` —
and gives every other value one generic sentence, so the *upstream* set is closed
by upstream's own design and this package does not add a sixth code to it. What
it does add is refusals it owns outright, each with its source named:

| Error | Source |
|---|---|
| `OutOfMemory` | `UTF8PROC_ERROR_NOMEM`, only through `map`/`mapCustom` — the caller-buffer paths cannot fail this way |
| `Overflow` | `UTF8PROC_ERROR_OVERFLOW`, **plus** this facade refusing an input whose length does not fit the C signed length type (see [slice lengths](#slice-lengths-are-checked-before-they-become-a-c-length)) |
| `InvalidUtf8` | `UTF8PROC_ERROR_INVALIDUTF8` |
| `NotAssigned` | `UTF8PROC_ERROR_NOTASSIGNED` |
| `InvalidOptions` | `UTF8PROC_ERROR_INVALIDOPTS` (`compose` and `decompose` both set, or `stripmark` without either — checked in `utf8proc_decompose_custom`, so it reaches `decompose`/`decomposeCustom`/`map`/`mapCustom` and **not** `decomposeChar`), **plus** this facade refusing `Options.nullterm`, **plus** this facade refusing `Options.charbound` with a `null` `last_boundclass` |
| `InputOutputOverlap` | **this facade only**: `decompose`/`decomposeCustom` refuse an input slice that overlaps the output buffer, before writing anything |
| `WorkspaceTooSmall` | `reencode` only, and **not** in `Error` — it widens the set as `ReencodeError` |

So `Error` holds six members, five of them upstream's codes and one refusal of
this package's own; `reencode` answers with seven because `WorkspaceTooSmall` is
reached through `ReencodeError` alone. The three refusals exist because in each
case the alternative is a plausible-looking wrong answer rather than an error:
a flag that silently discards the caller's length, a segmentation that would be
answered from no state at all, and a C call that would read the input while
overwriting it.

### Overlapping input and output are refused before the first write

`decompose` and `decomposeCustom` refuse `error.InputOutputOverlap` when the
bytes of `str` and the bytes of `dst` overlap in memory. The check happens before
the native call, so **`dst` is untouched** when it fires.

It fires because upstream's contract does not cover the case: `utf8proc_decompose_custom`
reads its input and writes its output in a single forward pass with no documented
partial-output promise, so an overlapping pair would produce a result that
depends on the order in which upstream happens to consume and emit — a wrong
answer with no error. Refusing is the only honest option for a wrapper whose job
is to own the preconditions upstream leaves open.

This is deliberately **not** a blanket ban on overlap. `reencode` takes one
4-byte-aligned workspace that holds its input and receives its output in place;
that is upstream's own documented shape and it is safe because each codepoint is
read before its bytes are written. Decomposition's in-place equivalent is
`normalizeUtf32`, which likewise operates on the buffer it was given.

### Slice lengths are checked before they become a C length

Every entry point that hands a `slice.len` to upstream as a length checks that
value against the C signed length type first, and an input that does not fit is
refused with `error.Overflow` rather than converted. The refusal happens before
the native call, so no wrapped or sign-flipped length is ever passed down.

### Partial-work contracts

`DecomposeResult.needs_more` means upstream needed that many codepoints and the
buffer was too small. **`dst` now holds undefined data**: upstream promises no
partial output. Nothing further may be read from it. A caller sizing its buffer
with `decomposeCount` first cannot hit this, and that is the recommended order.
This is the opposite of `error.InputOutputOverlap` and of `WorkspaceTooSmall`,
where the buffer is left exactly as it was found.

### The `malloc`/`free` boundary

`map` and `mapCustom` allocate with the C library's `malloc` and release only
through `utf8proc_free`. `OwnedString.deinit` calls that function and nothing
else; **never** `std.mem.free`, never an allocator, never a raw `free` reached
any other way. `utf8proc_free` is safer precisely because the application may be
linked to a different C library than the one utf8proc was built against — and
`utf8proc_free` did not exist before 2.12.0, so an older installed utf8proc does
not export it.

Release exactly once: `OwnedString` is a value, and duplicating its `ptr` produces
a second handle for one allocation.

**Zig's test allocator cannot supply a leak oracle across this boundary.** A test
that leaks an `OwnedString` will not be reported by `std.testing`. That is a
property of the boundary, not a licence to leak, and it is stated here so no test
is written as though the oracle were working.

### What `CustomFunc` owes, and what it may assume

Three obligations it must meet, and two it may rely on. Each is upstream's
behaviour read out of `utf8proc.c`, not a promise this package adds.

**It runs on the caller's thread, and nothing happens after it returns.**
`utf8proc.c` and `utf8proc_data.c` contain no thread primitive of any kind,
nothing is deferred, and the callback is invoked from inside the decomposition
pass itself (`utf8proc.c:572`). A callback may therefore use state belonging to
the calling function — and must not hand out a pointer that outlives the call,
because nothing in the core would keep it alive.

**It runs more than once.** `utf8proc_map_custom` decomposes twice — once to size
the buffer (`utf8proc.c:787`) and once to fill it (`:791`) — so a custom mapping
must be a pure function of `(codepoint, data)`. One that answers differently on
the two passes makes upstream return `error.Overflow` (`utf8proc.c:800-803`)
rather than overflow the heap; upstream's own comment says why, at `:796-799`.
That is a real error path, not a silent wrong answer.

**Its return value must lie in `[0, 0x110000)`.** That is the codepoint then
decomposed (`utf8proc.c:572`, `:574-577`), and anything outside the range is
upstream's own `error.NotAssigned` from the check at `utf8proc.c:449`.

**`custom == null` means no custom mapping at all**, not a call through a null
pointer: the guard is `if (custom_func != NULL)` (`utf8proc.c:571`) and the header
says the argument is ignored when it is `NULL` (`utf8proc.h:583`, `:767`). `data`
may independently be `null`, and it reaches the callback unchanged, so a callback
must tolerate that instead of assuming its context is there.

**`data` is borrowed for exactly this call and nothing keeps it.** Upstream only
forwards it. `custom_data` appears five times in the core — as a parameter of
`utf8proc_decompose_custom` (`utf8proc.c:543`), as a parameter of
`utf8proc_map_custom` (`:781`), twice forwarded into `decompose_custom` (`:787`,
`:791`), and once as the second argument of the callback invocation (`:572`).
Nothing dereferences, copies or stores it, which is what makes it safe for
`data` to be the address of a local of the calling function: the borrow ends when
`decomposeCustom` or `mapCustom` returns.

It may also **reenter this module**, with one bound. There is no mutable global
state to collide over: every file-scope object in either core file is a function
or a `const` table — `utf8proc_utf8class[256]` (`utf8proc.c:56`) plus the six
`static const` tables in `utf8proc_data.c` — and none of them is mutable. A nested
call is therefore safe *unless* it is handed the `dst` the outer call is filling,
which the outer call resumes writing at `buffer + wpos` (`utf8proc.c:575`). A
callback cannot be running inside a `load` attempt either: a runtime-loading build
dispatches no call until the table is published, so a `load` reached from a
callback lands on `accept` rather than `ReentrantLoad`, and in a linked build
`load` stops the program. See [runtime loading](README.md#runtime-loading).

### Why `Property` is opaque

`utf8proc_property_t` is declared with C bit fields (`utf8proc.h:296-319`), and
the Zig C translator demotes any record containing a bit field to an opaque type.
That is the right outcome: the bit field layout is implementation-defined, and a
hand-mirrored Zig struct would be a plausible-looking lie that breaks under a
different compiler. So `Property` is `*const` opaque, and only the properties
upstream also exports through a dedicated function are reachable from Zig:
`category` / `categoryString`, `charWidth`, `charWidthAmbiguous`.
**The facade never re-derives a property value.**

Stated positively, because the alternative reading is a gap someone will try to
"fill": `combining_class`, `bidi_class`, `decomp_type`, `boundclass`, `ignorable`,
`control_boundary`, `indic_conjunct_break` and the five sequence indices have
**no exported upstream accessor at all**. They are unreachable from Zig whatever
the translator does with bit fields, and they stay available to a C consumer
through `c.utf8proc_get_property`. This is upstream's API surface, not an
omission here.

The returned pointer refers to a static table upstream never writes to, so it is
valid for the process lifetime. An unassigned or out-of-range codepoint yields
upstream's shared sentinel whose category is `0` (`UTF8PROC_CATEGORY_CN`).

### `charWidth` is not `wcwidth`

`utf8proc_charwidth` reports `0` for non-printable, where `wcwidth` reports `-1`,
and it reads utf8proc's own Unicode 18.0.0 table rather than the host C library's.
The two disagree wherever the system's tables are out of date. Upstream's own
`test/charwidth.c` calls its `wcwidth` mismatches informational and warns that
there are "lots of these errors for out-of-date system unicode tables" — which is
why this package does not build that test as an oracle. Its oracle-free
invariants are preserved instead, including that no combining mark has nonzero
width, that unassigned codepoints have width 1, that nothing is both
double-width and ambiguous, and the four pinned codepoints U+00AD, U+E000, U+00A1
and U+00A2.

## The conformance fixtures

`testdata/` carries the Unicode 18.0.0 corpora, committed so that verification
needs no network:

| File | Bytes | SHA-256 | Used for |
|---|---|---|---|
| `NormalizationTest.txt` | 2 863 708 | `25a50d816764b04abfb4a646d3eb2b2a803284c3873d9a06757b94fe4513dde3` | 20 171 conformance rows over six `@Part` sections |
| `GraphemeBreakTest.txt` | 137 090 | `b0cf047ee94485bbdc846de2b902f5f8a815f6b674f9d04223cddadd91c9df31` | 853 data rows |
| `DerivedCoreProperties.txt` | 1 159 889 | `09c928886a178fcafd93c29e4bd59073a058e5a100b716d425cb563ab50f68c9` | the source the two case files are extracted from |
| `Lowercase.txt` | 55 684 | `aca4346d0eb2601ccc18beb1eaedaf3269feb2f3df26f18e3970e45f16563e84` | 711 ranges, 2 740 code points, the whole `islower`/`tolower` space |
| `Uppercase.txt` | 53 245 | `c0823767d0fb71c7bf3f5cf38554748950bd9b95426f89859a706bf93d3a3921` | 678 ranges, 2 026 code points |
| `Unicode-License-V3.txt` | 1 995 | `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` | licence record, never a test input |

`Lowercase.txt` and `Uppercase.txt` are **derived** from
`DerivedCoreProperties.txt` by upstream's own recorded extraction rule, not
fetched and not hand-written; both end in a bare `# Total code points:` line with
no count and no trailing newline, which is upstream's output verbatim. The full
rule, the section line numbers, and the self-check that each derived file's summed
code-point count matches the section's own declared total are in
[`UPSTREAM.md`](UPSTREAM.md#lowercasetxt-and-uppercasetxt-are-derived-not-fetched--and-how).

**Consumption is whole-file, no sampling.** The scope `tests.zig` commits to, as
declared by the test source and observed running in all four optimize modes:

| Corpus | Rows consumed | Checks |
|---|---|---|
| `NormalizationTest.txt` | all 20 171, every `@Part` | 20 conformance checks each — **403 420** in total |
| `GraphemeBreakTest.txt` | all 853 | a stateful `GraphemeIterator` walk and `firstGraphemeBreak` on every row, plus the same segmentation as `UTF8PROC_CHARBOUND` `0xFF` markers compared byte for byte |
| `Lowercase.txt` + `Uppercase.txt` | every range, with the gaps between ranges walked too | `islower`/`tolower` and `isupper`/`toupper` over the whole codepoint space, matching upstream `test/iscase.c`'s shape |

The grapheme test prints its own coverage: `grapheme rows: 853, checked through
CHARBOUND: 853, surrogate-only: 0`. No row is skipped for surrogates in this
fixture, so all 853 are checked both ways.

`DerivedCoreProperties.txt` is **not** a test input. It is carried as the
provenance of the two derived case files and as the primary input their hashes
pin; the extraction rule, the section line numbers, the range counts and the
declared totals 2 740 and 2 026 are recorded in
[`UPSTREAM.md`](UPSTREAM.md#lowercasetxt-and-uppercasetxt-are-derived-not-fetched--and-how),
and the workflow's `derived case fixtures still match their sections` step
reproduces both files from it. A permanent Zig test that re-derived the two
sections and compared them against the committed copies was removed: it would
have compared a fixture with a copy of itself, which is a file-integrity check
and not a behavioural one.

### How the corpora reach the tests

**`tests.zig` embeds all four corpora in full.** Its accessor is one line —
`@embedFile("testdata/" ++ name)` — called with the corpus names, so
`NormalizationTest.txt` is a compile-time constant in the test binary rather
than run-time input. Nothing is read from the filesystem at run time, and there
is **no** options module, no `testdata_dir` and no per-file read limit anywhere
in this package.

**`zig/api_exercise.zig` carries no fixture data at all.** It is a separate
executable with its own `main` and its own small expected answers; it embeds no
corpus and re-exports nothing from the facade. `build.zig` gives it no fixture
module and no data, and `testdata/` is not an input to it.

**The consequence is a build-time dependency, not a run-time one.** About 3.1 MB
of conformance text is compiled into the test object, and `check` compiles that
object for each of the six targets, so the cost is paid at compile time on every
one. The benefit is that a test binary needs no source tree beside it to run —
which is what lets the same `test` step serve a foreign runner through
`cross-test`. Both properties come from the same decision, and `testdata/` is
one entry in `.paths` because `@embedFile` needs the bytes at build time.

## Upstream's own test suite

`zig build upstream-test` builds and runs nine of upstream's C test programs
against this archive: `normtest`, `graphemetest`, `valid`, `iterate`, `case`,
`iscase`, `custom`, `misc`, `maxdecomposition`.

Upstream compiles eleven in its `check` target and executes ten. The two this
package does not build are `charwidth` (its oracle is the host's `wcwidth`, which
is not an oracle — see [above](#charwidth-is-not-wcwidth)) and `printproperty`
(a property dumper upstream compiles and never runs). `bench/`, which links
ICU4C and libunistring, and the `test/install_uninstall.sh` installation script
are not run either. Every one of these exclusions, and `test/fuzzer.c`, is
recorded with its reason in [`UPSTREAM.md`](UPSTREAM.md#build-only-deviations-from-upstream).

One upstream detail worth keeping: `test/misc.c` asserts that
`utf8proc_unicode_version()` equals the Unicode version in `data/Makefile`, and
upstream supplies that value by shelling out to perl. The assertion is inside
`#ifdef UNICODE_VERSION`, so **a missing define does not fail the program — it
silently removes the check.** This build therefore scrapes the same value out of
the shipped `data/Makefile` and passes `-DUNICODE_VERSION` explicitly, so the
data version is cross-checked against upstream's own code and cannot drift into a
hand-written constant.

Upstream regression behaviour that survives into this package's own tests,
because it is behaviour and not version pinning: `CHARBOUND` combined with
`COMPOSE` and with `DECOMPOSE` (upstream issue 356), the Hangul jamo composition
of issue 317, issues 102, 128, 144 and 288, julia#37680, the five explicit GB9c
Indic conjunct-break cases new in Unicode 18, and the whole-space invariant that
`utf8proc_decompose_char` never returns more than four codepoints
(`test/maxdecomposition.c`).

What is deliberately **not** ported is `test/charwidth.c`'s system `wcwidth`
comparison, at `test/charwidth.c:73-86` — upstream's own source calls those
mismatches informational. Its oracle-free invariants and its four pinned
codepoints (U+00AD, U+E000, U+00A1, U+00A2) are ported.

## System-library mode: NOT APPLICABLE

There is no `b.systemIntegrationOption` in this build. Recorded as **not
applicable**, not as a gate that passed. The reasoning — including why linking an
installed older utf8proc against this header would compile and then fail to link,
and which 2.12.0 ABI changes a header/ABI identity check would have to catch — is
in [`UPSTREAM.md`](UPSTREAM.md#system-library-mode-not-applicable-in-this-wave).

**The same fact was then observed, not only argued.** The external-provider route
wave in epoch `20261004T232439Z` put this host's own utf8proc candidates through
the runtime loader and recorded `external_successes_observed: 0` with four
expected refusals and no route carrying `counts_as_external_coverage: true`. The
host's single library is 2.10.0 / Unicode 16.0.0, so it fails on the missing
`utf8proc_free` **and**, independently, on the Unicode axis. That is a boundary
for the runtime route; it is not a system-library mode, and it is not external
coverage. See [verification status](#verification-status).

## Runtime loading

`-Druntime=true` routes every native entry point through one process-lifetime
table and links no native library into the module. What the module publishes is
the same in both configurations, so a consumer can support both and tell them
apart at comptime: `runtime_loaded` is the switch, `LoadSource` is `.path` for an
explicit file or `.system` for an explicit name for the platform loader with no
path-to-system fallback, `LoadError` names every way `load` can decline, and
`load` / `loadedSource` are ordinary functions. Under the option, `c` is the
generated dispatch that `runtime/graph.zig` builds from **this** `TranslateC`
step's own output — which is why the dispatch re-exports the translated header's
types and constants from a module named for what it is, instead of restating them:
one type, not two nominally identical ones. In a linked build `load` stops the
program with a message instead of quietly succeeding.

The loader's own rules: the table is published once and atomically after every
symbol is bound; a failed attempt publishes nothing and a retry is explicit; the
same request again succeeds and changes nothing; a different request after a
success is `ProviderMismatch` and the library in use stays in use; a call from the
thread running the attempt is `ReentrantLoad` rather than a deadlock; the handle
and the loader's retained copy of the request live to process exit; and there is
no unload or reset. Eight runtime-loaded cells in epoch
`20261004T232823091897Z-23133` observed the successful path against this tree's
own provider; the failure, retry, provider-change, reentrancy and pre-load-panic
contracts have no receipt — see [verification status](#verification-status).

**What `validate` proves, and what it does not.** It resolves nothing and it does
not compare version numbers, which would prove nothing. It calls five resolved
entry points and reads the resolved data object through the exact field types the
translated header declares, and requires the answers the Unicode standard fixes;
a pointer whose calling convention, argument widths or data-object element width
differs cannot produce them. That is an ABI check. It is **not** a compatibility
claim, because of property 4 below.

Four properties of **this** library decide what the route has to do on the Zig
side, and they are not the loader's to guess:

1. **One exported data symbol.** `utf8proc_utf8class[256]`
   (`utf8proc.h:453`, defined at `utf8proc.c:56`) is the only exported data in
   the library. The six tables in `utf8proc_data.c`, including the
   `utf8proc_properties[]` that `utf8proc_get_property` returns pointers into,
   are `static const` and are not exported at all. A loaded raw route therefore
   reaches the exported table **by address in the loaded image**; a copied table
   would be a different array from the one the provider reads.
2. **Pointers into a provider's tables are per-image.** `Property` is opaque here
   by design, and under a loaded provider it is opaque for a stronger reason: two
   `Property` values from two images point into two different arrays, so
   comparing or caching them across a provider boundary is meaningless rather
   than merely discouraged.
3. **`OwnedString.deinit` has to keep crossing one image.** The wrapper frees
   through the library's own `utf8proc_free` because upstream allocated with that
   image's `malloc`; see [the `malloc`/`free` boundary](#the-mallocfree-boundary).
   A provider image's buffer must be released by that same image, which is why
   `deinit` routes through `c.utf8proc_free` instead of a Zig allocator — and why
   a loaded route cannot promise that a buffer is interchangeable between the
   host and an arbitrary provider.
4. **The provider's tables must be the same Unicode revision as this build's.**
   `utf8proc_get_property` indexes `utf8proc_stage1table` with the property's own
   `lower` and `upper` fields and with `codepoint >> 15` (`utf8proc.c:233-240`), so
   a provider built from a different Unicode revision resolves every symbol,
   passes every ABI check and still disagrees about codepoints this build never
   asked about. `utf8proc_property_t` is a bit-field record
   (`utf8proc.h:296-319`), so those indexes are read through field types that
   differ in width or signedness between providers. This is the one requirement
   that is not about the C ABI, and it is why `validate` requires the Unicode
   version to be **present** rather than equal to any particular value.

The platform-facing half — the same-allocator requirement across a `dlopen`ed
image or a Windows DLL, the fixed-width-but-not-universal scalars, and why symbol
presence is not ABI identity — is in the consumption section of `README.md`.
This package asserts nothing about Windows CRT interchangeability between a host
and a loaded provider.

## Nix and devenv

devenv is the canonical development interface; the flake is the portable
alternative, and both call the same single `package.nix` with `linkage`
selecting the variant. The commands, what each output installs, and why the SDK
is reachable through devenv's lazy `outputs.static` / `outputs.shared` rather
than the shell's `packages` are in the consumption section of `README.md`.

One of those is an interface property rather than a packaging one: static versus
shared is a property of the native artifact, not of dispatch, so both variants can
be linked or runtime-loaded. `static` in the Nix sense means a static library
artifact — never a promise of a wholly static executable.

**What each canonical entry actually runs.** `devenv.nix` gives all nine
scripts the same first line, a `cd` to this SDK's own directory resolved from
`builtins.toString ./.` in the module that declares them. That is what makes
`devenv shell -- sdk-consumer` and `devenv shell -- sdk-integrity` correct from
any working directory: devenv runs a script as a generated program in the
caller's directory, and this checkout's `build.zig`, `consumer/` and
`UPSTREAM.sha256` are not there. The path is a string and not a path literal on
purpose — a literal would give the generated program a store context and Nix
would copy this tree into the read-only store. Every `zig build` body then runs
one shared flag string, `--cache-dir "$ZIG_LOCAL_CACHE_DIR/utf8proc"
--global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" -j8 --summary all`, because Zig's own
default is `.zig-cache` inside this checkout. A cache variable the caller did
not export is filled from `XDG_CACHE_HOME` first and `TMPDIR` second; both still
empty is a refusal with a named remedy, before the compiler runs. `sdk-build`,
the one script whose step installs, adds `--prefix
"$ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out"` so the delivery never lands in the
checkout; the other eight install nothing and name no prefix of their own. No
gate in the tables below has observed this: it is read out of `devenv.nix` and
`build.zig`, not a result.

**What `zig build consumer` sends to the nested build.** `runConsumer` in
`build.zig` writes that command line itself. The sub-command is `run` when this
host can execute the resolved target and `install` when it cannot, chosen by
`hostCanExecute`; an `install` delivers the executable and asserts nothing about
its output. It passes `-Dtarget` and `-Dcpu` as the caller's *query*, then
`-Doptimize`, `-Dlinkage` and `-Druntime`, then the `-f…` executor switches and
`--libc-runtimes` when this graph has them, then `-j8` and `--summary all`. It
passes the local cache as
`--cache-dir <outer>/consumer` when `b.cache_root.path` is set, and the global
cache as `--global-cache-dir` followed by whatever
`b.graph.global_cache_root.path` resolves to, whole and unsuffixed, when that
is set. It passes `--prefix` with this invocation's own `b.install_prefix`,
made absolute, whenever the caller named one, and sends nothing when the
caller named none. The caller's own
arguments go last and behind `--`, and `consumer/build.zig` passes those same
arguments to its `run_exe`, so a program argument reaches the consumer
executable and not only the nested build. No gate in the tables below has
observed any of this: it is read out of `build.zig` and `consumer/build.zig`,
not a result.

## Verification status

The gates the driver has run, each with its receipt; then one gate whose result
lives outside this document. An unrun gate is never a pass, whatever this
document says about it.

**Everything in the first table below was observed on 2026-10-03, before this
wave's changes, and is history for the tree as it stood then.** This wave
relocated upstream's README, granted a licence over the fork's own files, added
five packaging files, and has since cut the runtime route over to
`runtime/graph.zig` (`CHANGELOG.md` entry 50, 2026-10-04) and taken up the
driver's `flake.lock`. A third table, dated 2026-10-05, carries the gates that
have since been run against the source as it stands now: the six-target `check`,
the 53-platform matrix and the two eight-cell host waves. The provenance,
packaging, C-consumer and nested-delivery receipts in the first table have **not**
been re-run and stay history for this wave; nothing in that table is restated as
if it were current. The gates this migration still has to observe are listed as
such, first, and none of them has a result.

### Not yet observed for this migration

`PENDING-VERIFICATION`. Every line below is a gate the driver runs that still has
no receipt against this wave's source; what it would establish is unchanged.

| Gate | What it would establish |
|---|---|
| an installed and a **fetched** consumer, typed and raw | that `.paths` carries the closure a fetched dependent needs, now including `README.upstream.md`, `FORK-LICENSE.md`, the five packaging files and the driver's `flake.lock`. Every 2026-10-05 installed prefix records `include/utf8proc.h` and `lib/pkgconfig/libutf8proc.pc`, and the nine nested-delivery cases resolved a **path** dependency; neither reads `.paths`, and the filtered-fetch proof is recorded outside this document |
| `sha256sum -c UPSTREAM.sha256` and the pinned-blob comparison, re-run | that the integrity anchor survived the README relocation. The expectation — 56 `OK` lines, and `README.md` as a **fourth** difference — is stated as an expectation and is **not** an observation |
| `-Druntime=true`: a failed attempt publishing nothing, an explicit retry, a different provider after a success, the atomic publication itself, and the panic before initialization in every mode | the negative half of the route in [runtime loading](#runtime-loading). The eight runtime-loaded cells in the 2026-10-05 table observed the successful path only |
| `nix build .#static` and `.#shared`, `devenv build outputs.static` and `outputs.shared`, and the devenv shell | that this wave's packaging files evaluate and build. They have never been evaluated: this role runs no `nix`, no `devenv`, no build and no gate |
| an installed C consumer built through the installed `libutf8proc.pc` | that the relocatable metadata names a library and a header that are really in the output, with `UTF8PROC_STATIC` in the static delivery and no `UTF8PROC_EXPORTS` in either. Both files are present in every observed prefix; no receipt compiled a consumer through them |

**Observed.**

| Gate | What it establishes | Result |
|---|---|---|
| `zig build install test smoke consumer upstream-test -j2 --summary all --prefix …/install-current` at `Debug` | the C core, the translation, the install, the 22 behavioural tests, the API exercise, the smoke program, the `consumer/` package **and** upstream's own nine C programs, in one command against the source as it stands | **PASS** — exit 0, **35/35 steps, 22/22 tests** — `local://foundation-matrix-utf8proc-current-debug-cpp.log`. It records `install success` (`install utf8proc success`, `install LICENSE.md to LICENSE.md success`), `smoke success`, `consumer success` and `upstream-test success` with all nine `run exe … success` (`normtest`, `graphemetest`, `iscase`, `valid`, `iterate`, `case`, `custom`, `misc`, `maxdecomposition`), plus the exercise's `all typed operations exercised` |
| the same at `-Doptimize=ReleaseSafe`, as `zig build test smoke consumer` | the same in an optimising mode, where a `std.debug.assert` would already be compiled away | **PASS** — exit 0, 13/13 steps, 22/22 tests — `local://foundation-matrix-utf8proc-releasesafe-native.log` |
| the same at `-Doptimize=ReleaseFast` | the same | **PASS** — exit 0, 13/13 steps, 22/22 tests — `local://foundation-matrix-utf8proc-releasefast-native.log` |
| the same at `-Doptimize=ReleaseSmall` | the same | **PASS** — exit 0, 13/13 steps, 22/22 tests — `local://foundation-matrix-utf8proc-releasesmall-native.log` |
| `zig build check -j2 --summary all` | every facade body, test, exercise, smoke example and upstream program compiles for **all six** cross targets, without running any of them | **PASS** — exit 0 — `local://foundation-matrix-utf8proc-six-baseline.log`, which ends on the `wasm32-wasi` upstream programs. `check` reads no Markdown, so the six examples in [the examples](#the-examples) are not covered by it; see their own row |
| `zig build check -Dtarget=aarch64-netbsd`, `-Dtarget=mips64el-openbsd`, `-Dtarget=x86-windows` | the three target families that need the extra preprocessor front end, one representative each | **PASS** — exit 0 on all three — `local://foundation-matrix-utf8proc-cpp-focus-aarch64-netbsd.log`, `…-cpp-focus-mips64el-openbsd.log`, `…-cpp-focus-x86-windows.log`. The same `aarch64-netbsd` check had exited 1 before the correction, with `use of undeclared identifier '__int128_t'` at `utf8proc-translate.zig:1191` — `local://foundation-matrix-utf8proc-netbsd-preprocess-check.log`. That failure is history, not the current state; the cause and the fix are in [the translation route](#the-translation-route-is-chosen-per-target) |
| `cross-test`, full published 53-platform matrix, no subset | that every one of the 53 platforms builds this package, and which of them can also run its tests | **PASS for every build; 20 of 53 also ran and passed; 33 build-only** — exit 0 — `local://foundation-matrix-utf8proc-cross-corrected-summary.json` (run `20261003-195739-62898-24523`, profile `cross-test.profile.sh`, `mode: zig-build`, Zig 0.16.0, `target_count: 53`). All 53 report `build.status: pass`; 20 report `run.status: pass` with 22 tests each (`x86_64-linux`, `aarch64-linux`, `aarch64_be-linux`, `arm-linux`, `armeb-linux`, `hexagon-linux`, `loongarch64-linux`, `mips-linux`, `mipsel-linux`, `mips64-linux`, `mips64el-linux`, `powerpc-linux`, `powerpc64-linux`, `powerpc64le-linux`, `riscv32-linux`, `riscv64-linux`, `s390x-linux`, `thumb-linux`, `thumbeb-linux`, `x86-linux`); the other 33 report `run.status: unavailable`, `reason: runtime_unavailable`, `status: build_only`, and are **not** passes. This run **supersedes** the earlier one in which fifteen targets failed to translate |
| `sha256sum -c UPSTREAM.sha256` | the 56 carried upstream and fixture files are byte-for-byte what this record pins | **PASS** — exit 0, 56 `OK` lines — `local://foundation-matrix-utf8proc-provenance-checksums.log` |
| every carried upstream path against `git cat-file blob 79cdd5ab…:<path>` | this downstream still carries **upstream's bytes at the pin**, which is a property of the files and not of where `HEAD` points | **PASS** — exit 0 — `local://foundation-matrix-source-integrity.json`: `utf8proc.files_checked: 53`, `differences: [".gitignore", "build.zig", "build.zig.zon"]`, exactly the three files `UPSTREAM.sha256`'s own header names as edited in place, and nothing else. The same record reports 10 429 protected files checked with **no** differences |
| an installed C consumer | `#include <utf8proc.h>` and link `libutf8proc.a` with no Zig in between | **PASS** — `zig cc -std=c99 -I …/install-current/include -DUTF8PROC_STATIC=1 … -l…` exits 0 (`local://foundation-matrix-utf8proc-installed-c-current-compile.log`) and the binary exits 0 after 23 printed checks ending `the installed C surface compiled, linked and ran` (`local://foundation-matrix-utf8proc-installed-c-current-run.log`) |
| the six examples in [the examples](#the-examples) | that each of them compiles, runs and passes against this package as published | **PASS** — exit 0, 6/6 steps, 6/6 tests — `local://foundation-matrix-utf8proc-all-readme-examples-r3.log`, run in a scratch package outside this repository. The three failures that preceded it are tabulated under the examples themselves |
| `zig fmt build.zig build.zig.zon tests.zig smoke.zig zig/root.zig zig/api_exercise.zig consumer/build.zig consumer/build.zig.zon consumer/src/main.zig` | formatting of the nine fork-authored Zig and ZON files | **PASS** — exit 0, over all nine files — `local://foundation-matrix-utf8proc-fork-zig-format.log`, which prints all nine paths. `zig fmt` prints a path only for a file it rewrites, so this run rewrote all nine. No upstream file was passed to it, and formatting changes layout only: no declaration, no macro and no upstream byte moves |
| `zig build consumer` over nine nested-delivery cases at `Debug`: default and explicit target, `static` and `dynamic`, linked and runtime-loaded, plus one deliberate no-provider refusal | that `runConsumer`'s nested `zig build run` really carries this graph's target query, CPU, optimize mode, linkage, runtime dispatch, both caches, `-j8`, `--summary all` and this invocation's `--prefix`, and that a provider named behind `--` reaches the consumer program | **PASS 9/9** — eight cases exit 0 with every expected pattern in the program's own output, and the ninth exits 1 with the named refusal it exists to prove — `nested-delivery-proof/evidence/20261004T220323250122Z-515d06adcbbf/index.json` (run `20261004T220323250122Z-515d06adcbbf`, under the approved scratch root). Every nested argv carried `-j8`, `--summary all`, `--cache-dir <outer>/consumer`, `--global-cache-dir` and `--prefix`, and no nested check failed in any case. The runtime-loaded cases carried `--provider <path>` behind `--` with every `*_TEST_PROVIDER` variable absent from the child, so the provider arrived on the command line and not through the environment. The source closure was 78 files under one stable hash, identical before and after |
| `zig build test smoke install -Doptimize=<mode> -Dlinkage=<linkage> -Druntime=false --cache-dir <cache> --global-cache-dir <global> --prefix <prefix> -j8 --summary all`, four optimize modes by `static` and `dynamic`, eight cells | that this wave's build graph still builds, runs its 23 tests, runs the smoke program and installs the whole closure in every mode, and that `-Dlinkage=dynamic` really delivers a shared object beside the static default | **PASS 8/8** — every cell `Build Summary: 28/28 steps succeeded; 23/23 tests passed`, `problems: []` — `native-final-evidence/contract-final-after-20261004/run.json` (run `contract-final-after-20261004`, driver `verify_native_final.py`, native mode only). The four `static` cells install 16 files carrying `lib/libutf8proc.a` and no shared object; the four `dynamic` cells install 18 files carrying `lib/libutf8proc.so`, `lib/libutf8proc.so.3` and `lib/libutf8proc.so.3.3.0` and no archive. Every cell installs `include/utf8proc.h`, `lib/pkgconfig/libutf8proc.pc` and eight licence records |

### Observed 2026-10-05, against the source as it stands now

| Gate | What it establishes | Result |
|---|---|---|
| `cross-test` over the full published 53-platform matrix, `--jobs 8 --build-jobs 8`, `cross-test.profile.sh`, `mode: zig-build`, Zig 0.16.0, `target_count: 53` | that the per-target translation route still resolves across all 53 platforms after this wave's build-graph changes, and which of them can also run its tests | **PASS for every build; 20 of 53 ran and passed; 33 build-only** — driver exit 0, `fail: 0`, `partial: 0`, `source_unchanged: true`, `jobs_honoured: true` — epoch `20261004T221720228710Z-45046`, receipt `utf8proc-53-target-8.json`. All 53 report `build.status: pass`; the 20 report `run.status: pass` with `tests: 23` and `reason: tests_complete`, and each of the other 33 reports `run.status: unavailable` with `reason: runtime_unavailable` — `build_only`, **not** a pass. This is a `test`-step matrix: no `install`, no `consumer` and no `upstream-test` in any cell |
| `zig build check`, the graph's own whole-matrix step, no `-Dtarget`, over the six baseline targets | that every facade body, test, exercise, smoke example and upstream program still compiles for all six baseline targets against this wave's source | **PASS, compile-only** — exit 0, `failed: false`, `Build Summary: 91/91 steps succeeded`, `targets_seen` naming all six of `declared_target_count: 6` — epoch `20261005T014547Z-797a73f2`, receipt `baseline-utf8proc-check-2026-10-05T01-46-01.794968+00-00.json`. The row carries **`runtime_pass_claimed: false`** and an empty test-count list: a compile-only row derives no runtime result under any exit code, so this is not a green `test` run |
| `zig build test smoke install -Doptimize=<mode> -Dlinkage=<linkage> -Druntime=false`, four optimize modes by `static` and `dynamic`, eight cells | that this wave's build graph still builds, runs its 23 tests, runs the smoke program and installs the whole closure in every mode on this host, and that `-Dlinkage=dynamic` really delivers a shared object beside the static default | **PASS 8/8** — every cell exit 0 with `test success` and `smoke success` and `problems: []`; the `Debug`/`static` cell reports `Build Summary: 28/28 steps succeeded; 23/23 tests passed` and a 16-file prefix carrying `lib/libutf8proc.a` with no shared object — epoch `20261004T233628757747Z-69351`, receipts `utf8proc-native-final-{static,dynamic}-<mode>.json` |
| the same eight cells at `-Druntime=true`, the provider named through `UTF8PROC_TEST_PROVIDER` and nothing read from the ambient environment | that the runtime route starts, binds the whole declared surface, passes `validate` and publishes, and that every test then answers through the dispatch rather than through a linked library | **PASS 8/8** — every cell exit 0; the `Debug`/`static` cell reports `Build Summary: 29/29 steps succeeded; 23/23 tests passed`. `tests.zig`'s `nativeReady()` is the only thing that loads, so the successful path is the one exercised — and **the provider is this tree's own source-built `libutf8proc.so.3.3.0`**, recorded `kind: "own"` — epoch `20261004T232823091897Z-23133`, receipts `utf8proc-loaded-final-{static,dynamic}-<mode>.json` |
| the external-provider route wave: this host's own utf8proc candidates by path and by loader name, plus the own-provider route | whether an independently supplied utf8proc is a legal provider for this SDK on this host | **NO INDEPENDENT EXTERNAL COVERAGE — a boundary, not a pass.** `status: pass`, `own_provider_route_passed: true`, **`external_successes_observed: 0`**, `refusals_observed: 4`, `own_routes_counted_as_external: []`, and **no route carries `counts_as_external_coverage: true`** — epoch `20261004T232439Z`, `utf8proc-index.json`. The host's only utf8proc is 2.10.0 / Unicode 16.0.0: it exports 30 of the 31 declared entry points, does not export `utf8proc_free` (`utf8proc.h:808`), and is out of family on the Unicode axis independently. Every external route was an expected refusal, and the only route that succeeded was this tree's own source-built provider |

**What these five rows do not establish.** 33 of the 53 rows compiled and ran
nothing, and `build_only` is never a runtime pass. The baseline row is
compile-only by construction. The two eight-cell waves are this host, this
toolchain and the `test`, `smoke` and `install` steps — and the loaded wave's
provider is this tree's own shared object, so it is the runtime route exercised
against itself, not against a foreign library. **No receipt in this section runs
the `consumer` step**, so the `install` branch of `CHANGELOG.md` entry 59 and
every `-f*` executor path remain unobserved; none of these receipts evaluates
`nix` or `devenv`, re-runs the integrity checks, or compiles a C consumer through
the installed `.pc`.

**What the two 2026-10-04 rows do not establish.** The nine-case nested run
covers the `consumer` step alone, and the eight-cell native run it sits beside
covers `test`, `smoke` and `install` on the host, with `-Druntime=false`.
Neither is a result for the
53-platform matrix or for `check`, and neither is a result for `devenv` or for
`nix`, which have never been evaluated. Neither is a result for any
cache-fallback guard: none is claimed here, and none carries a receipt in this
document. `-Druntime=true` keeps its own rows, and only the successful path of
that route is observed. All nine cases resolved to
`run`, because both of their targets resolve on this host, so the `install`
branch has no receipt anywhere in this document and is not a result for any
target here. Everything else in [not yet
observed](#not-yet-observed-for-this-migration) is still without one.

**The earlier 53-platform run is superseded, and its fifteen failures are
history.** `local://foundation-matrix-utf8proc-cross-original-summary.json`
(run `20261003-175929-14815-27659`) exited 1 with `counts: 20 pass, 15 fail, 18
build_only`. Its fifteen failures were all `build_failed`, all from the
translation rather than from this package's source: `aarch64-netbsd`,
`aarch64_be-netbsd`, `arm-netbsd`, `armeb-netbsd`, `mips-netbsd`,
`mipsel-netbsd`, `powerpc-netbsd`, `x86-netbsd`, `x86_64-netbsd`,
`arm-openbsd`, `mips64-openbsd`, `mips64el-openbsd`, `powerpc-openbsd`,
`x86-openbsd` and `x86-windows` — nine NetBSD, five OpenBSD and one Windows,
which is the set named in [the translation route](#the-translation-route-is-chosen-per-target).
The corrected run leaves the twenty that could run at twenty, moves those
fifteen from `fail` to `build_only` with `run.status: unavailable`, and exits 0.
**No platform was removed from the matrix and none was reported as passing on
the strength of a successful foreign compile.**

The API exercise is inside the `test` step rather than beside it: all four of the
native receipts above record `run exe utf8proc-api-exercise success` and
`all typed operations exercised`, so every public facade function has been
*called* and checked, not merely compiled, in every mode. The standalone
`zig build exercise` step still has no receipt of its own.

Two earlier receipts are kept here as history, because each explains a row above
and neither describes the current state. `local://foundation-matrix-utf8proc-unicode-r6.log`
is the pre-install Debug receipt for the source before the `install` step was
added to the command, and `local://foundation-matrix-utf8proc-unicode-r5.log`
recorded `upstream-test success` inside a command that exited 1 because a
`tests.zig` case was failing at the time. That case was corrected; the same
command now exits 0, as the first row records. No release-mode `upstream-test`
receipt exists, and none is claimed.

**Recorded outside this package.** One gate is not run from inside these
documents, and its state is deliberately not asserted here:

| Gate | What it establishes | Status |
|---|---|---|
| filtered-fetch consumer | that `.paths` really carries the closure a **fetched** dependent needs — the one property no in-repository gate can see, because a path dependency resolves from the working tree and never reads `.paths` | **Driver records this separately** in `local://foundation-matrix-final-package-proof.json`. Only that record's observed receipt establishes a pass; nothing above anticipates one |

**Error paths.** Five owned error answers are fired by the permanent tests, and
were fired in all four recorded modes. By the name of the test that fires each:
`UTF8PROC_NULLTERM is refused on every slice entry point` and
`CHARBOUND requires a live per-character state` for `InvalidOptions`,
`decomposition refuses aliased input before changing caller bytes` for
`InputOutputOverlap`, `reencode refuses a workspace that is one byte short` for
`WorkspaceTooSmall`, and `error mapping is checked against upstream's own return
values` for upstream's `InvalidUtf8` and `NotAssigned`. The slice-length check
that answers `error.Overflow` before a length becomes a C length has **no test
that fires it**: it stays a documented contract with no observed execution, and
nothing here claims it is covered.

A successful foreign compile is `build_only`, not a passing Zig API test, and a
cross target whose runner is unavailable is never a pass. The driver's own notes
record two `CacheCheckFailed`/`FileNotFound` symptoms from earlier waves with no
identified cause; if this package produces one, it stays a `SYMPTOM` until a cause
is established and is not attributed to the source, the cache or the volume.

### What is deliberately not tested

There is no test that pins a version string, checks `@hasDecl` or export
presence, compares a forwarding accessor against the raw member it forwards to,
checks copying, or asserts that a call does not throw. Version identity belongs
to the provenance and licence records, which is what `UPSTREAM.sha256` and
`NOTICE.md` are; `version()` and `unicodeVersion()` are asserted only to be
distinct NUL-terminated strings, which is a behavioural claim. The `smoke`
example may print the pinned version.

One test of that shape existed and was removed. It re-derived the `Lowercase`
and `Uppercase` sections out of the embedded `DerivedCoreProperties.txt` and
compared them, range for range, with the embedded `Lowercase.txt` and
`Uppercase.txt`. That is a fixture compared against a copy of itself: it could
only report that two committed files still agree, which is what
`UPSTREAM.sha256` and the workflow's derivation step already own. It exercised
no library behaviour, so it is gone; the derivation's provenance is recorded in
[`UPSTREAM.md`](UPSTREAM.md#lowercasetxt-and-uppercasetxt-are-derived-not-fetched--and-how)
and nothing behavioural was lost with it.

The same rule now holds for this package's own C-surface gate, which compared
`utf8proc_unicode_version()` against a literal until it was corrected. That
version claim is owned by `test/misc.c`'s `-DUNICODE_VERSION` cross-check against
upstream's `data/Makefile`, which `zig build upstream-test` runs and which fails
in its own right if the two disagree; the C gate prints both version strings —
a C consumer can read them — and asserts neither.

**One coverage boundary is real and is not going to be closed:** Zig's test
allocator cannot supply a leak oracle across upstream's `malloc`/`free` pair, so
a test that leaks an `OwnedString` will not be reported. That is a property of
the allocator boundary, not a licence to leak, and it is recorded here and in
[`FORK-NOTES.md`](FORK-NOTES.md) rather than papered over.

## Boundaries

* **Pinned toolchain only.** Zig 0.16.0. Bare `zig` is the `anyzig` dispatcher
  and must not gate a version-bearing project.
* **No build-time or test-time network.** The corpora are committed.
* **No system utf8proc mode.** Not applicable in this wave.
* **No publication.** This package is local and unpublished until the user
  authorises publication by name. No repository was created and no remote was
  touched.
* **The fork's own files are MIT, on the owner's authorization.** The library is
  under two MIT grants plus a separate Unicode data grant; the fixtures are under
  Unicode License V3; the files this fork wrote are under the grant in
  [`FORK-LICENSE.md`](FORK-LICENSE.md), recorded on 2026-10-04 and covering the
  fork's files only. [`NOTICE.md`](NOTICE.md) remains the per-file record, and no
  single label describes this tree.
* **The filtered-fetch consumer proof is recorded outside this package.** The
  closure a *fetched* dependent receives is proved by the driver's
  `local://foundation-matrix-final-package-proof.json`, not by any row above, and
  no statement here should be read as evidence that a fetched package builds
  until that record carries its receipt — see
  [verification status](#verification-status).
* **Cross-target results come from this workspace's own gates, never from
  upstream's CI.** Upstream's CI pins Zig 0.16.0 and asserts
  `zig-out/lib/libutf8proc.a`, but it runs only `ubuntu-latest` and
  `macOS-latest`; that is upstream's evidence on upstream's runners. The results
  that speak for this package are the six-target `check` and the full 53-platform
  run in [verification status](#verification-status), and of the 53 only the
  twenty with a runner are passes. Both now carry a 2026-10-05 receipt against
  this wave's source — `20261005T014547Z-797a73f2` for the compile-only baseline,
  `runtime_pass_claimed: false`, and `20261004T221720228710Z-45046` for the
  matrix, whose other 33 rows are `build_only` — and the 2026-10-03 receipts
  behind them remain history, as the note above the first table in
  [verification status](#verification-status) says.

## See also

* [`UPSTREAM.md`](UPSTREAM.md) — the pin, the archive receipt, the per-file
  anchor, the fixture provenance and derivation, and every build-only deviation.
* [`UPSTREAM.sha256`](UPSTREAM.sha256) — the integrity record.
* [`NOTICE.md`](NOTICE.md) — the per-file licence inventory and the four
  exceptions an auditor has to know about.
* [`CHANGELOG.md`](CHANGELOG.md) — numbered fork-only divergences.
* [`FORK-NOTES.md`](FORK-NOTES.md) — the problems met while preparing this
  package, and what was decided.
* [`zig/root.zig`](zig/root.zig) — the facade source, whose doc comments carry
  the per-function line references this document summarises.
* [`LICENSE.md`](LICENSE.md) — upstream's licence file, verbatim: two MIT grants
  and the Unicode data grant.
* [`README.md`](README.md) — the fork's README: native-source deviations,
  native-build deviations and the dated history link, the matrix, consumption.
* [`README.upstream.md`](README.upstream.md) — upstream's README, byte for byte.
* [`FORK-LICENSE.md`](FORK-LICENSE.md) — the MIT grant this fork asserts over
  its own files, its exact scope, and what it excludes.
* `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc` — this
  wave's standalone Nix and devenv delivery. None of them has been evaluated.
* `flake.lock` — the driver's lock for the one input `flake.nix:15` declares,
  written into this tree on 2026-10-04 and listed in `.paths`. What this document
  establishes about it is only that its `locked.rev` is the revision `flake.nix`
  declares; what it resolves to beyond that is the driver's receipt, not this
  document's.