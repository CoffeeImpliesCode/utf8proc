# FORK-NOTES.md — what was decided while preparing this fork, and why

Written by the provenance role. **The provenance role ran no build, test, smoke
run, cross-target compile or formatter, and this repository was not committed
to, pushed or otherwise mutated.** Read-only `git` *was* used — `git ls-tree -r`,
`git cat-file blob`, `git show`, `git log`, `git remote -v`, `git status` — to
read the pinned tree, the pinned blob ids, upstream's own `build.zig.zon` and
this clone's history state; note 15 lists exactly which. Every statement here is
`SOURCE-CONFIRMED` — read out of a file, measured by hashing bytes, or read out
of the pinned commit — or `CONSTRAINT`, a binding design rule with no
observation behind it. Gate results belong to the driver and are recorded in
[`README.zig.md`](README.zig.md#verification-status) with their receipts; note 15
says which of them have since been observed. Where a decision needed a fact
nobody in this role could read, that is said instead of being filled in with a
guess.

Each note is written in the shape the workspace horizon mandate asks for:
**condition, what it would look like, decision, and the boundary it is bound to.**

---

## 1. The `build.zig` collision, and why the tree was not relocated

**Condition.** Upstream ships its own root-level `build.zig` and `build.zig.zon`
(added in 2.12.0). Zig allows one `build.zig` per package, and this package's
root *is* upstream's root.

**The two shapes on the table.** Either nest the upstream tree under a
subdirectory — the `libraries/liblmdb/` shape — leaving the package root to the
fork; or keep upstream at the root and extend its `build.zig` in place.

**Decision: keep upstream at the root and extend `build.zig` in place.** The
contract for this wave states it directly: no tree relocation, no duplicate
upstream copy. That is also the smaller diff, which matters when the alternative
means moving a 2.4 MB generated table and 19 upstream test files to new paths
purely to avoid editing a build script.

**What it costs, recorded rather than discovered later.** Upstream's manifest
already carries a `.fingerprint` (`0xdcddf08dbb8954c4`) and a 7-entry `.paths`,
and this fork's manifest differs from it in both: its `.fingerprint` belongs to
this manifest, and its `.paths` is a superset that adds the corpora, upstream's
suite and tooling, the records and the consumer package. Three upstream files —
`build.zig`, `build.zig.zon`, `.gitignore` — are therefore fork-edited and
excluded from `UPSTREAM.sha256`, each with the reason written into that file's
own header. See [`NOTICE.md`](NOTICE.md) for the full diff and the pristine
digests that survive the edit.

**Bound to.** This package's layout only. A library whose upstream build system
claims the `build.zig` name *and* that the contract does not fix the layout for
should re-open this.

---

## 2. `Lowercase.txt` and `Uppercase.txt`: derive them, and record the rule

**Condition.** Upstream's `make check` needs four fixture files that upstream
does not ship. `data/Makefile:59-63` deletes `NormalizationTest.txt`,
`GraphemeBreakTest.txt`, `Lowercase.txt` and `Uppercase.txt` in `clean:`, and
`data/download.sh` is the script that fetches them. Two of those four are not
Unicode publications at all: they are sections of `DerivedCoreProperties.txt`,
produced by `data/Makefile:53-57`.

**Decision: commit the five files, and derive the two case files with upstream's
own recorded rule rather than fetching or hand-writing them.** The rule is a
one-line anchored regex per property: take the substring from
`# Derived Property: Lowercase` to the end of the first following
`# Total code points:`. Both the rule and the section line numbers are recorded
in [`UPSTREAM.md`](UPSTREAM.md), so a reader can re-derive both files without
trusting this sentence.

**The trap in that rule, and it is a real one.** `.match` returns the matched
span only, so upstream's output ends in a bare `# Total code points:` line with
**no count and no trailing newline**. A well-meaning formatter, a `.gitattributes`
newline rule, or an editor that "adds a final newline" silently changes both
files. Upstream's own `test/iscase.c` stops at the first `#` line, so the
missing count costs nothing — but the parser must not require a trailing `\n`,
and the files must never be tidied. `.gitignore`'s unanchored `*.new` pattern
means `UPSTREAM.sha256.new` must also never be created.

**A self-check was added because a hash alone would not catch a wrong section.**
`DerivedCoreProperties.txt` carries 20 `# Derived Property:` sections, and a wrong
anchor still produces a well-formed file. So each derived file's ranges were
summarised and compared with the section's own declared total: `Lowercase.txt` =
711 ranges covering exactly 2 740 code points against a declared 2 740;
`Uppercase.txt` = 678 ranges covering
exactly 2 026 against a declared 2 026. Both match. The reproduction is owned by
the workflow's `derived case fixtures still match their sections` step, which
re-derives both files from `testdata/DerivedCoreProperties.txt` and compares them
byte for byte. A Zig test that re-derived the same two sections and compared
them against the committed fixtures once existed and was **removed**: it compared
a fixture with a copy of itself, which says nothing about behaviour, and keeping
it would have left a permanent test asserting that a file still equals itself.
What survives is the measurement above and that workflow step.

**Boundary.** Tied to Unicode 18.0.0. A UCD bump moves the section line numbers,
the range counts and the totals; all of them are recorded in `UPSTREAM.md` and
must move with it. No gate has confirmed this — it is a source-level property of
the fixture bytes.

---

## 3. The corpora are embedded, and the exercise carries no data at all

**Condition.** The conformance corpora are large — `NormalizationTest.txt` alone
is 2.86 MB — and the test root has to run wherever `cross-test` decides to run
it, including under the QEMU, Wine and wasmtime executors its 53 platforms
select. On such a machine neither an absolute nor a relative source path into
the build directory exists, so a test that read its corpora from disk could not
execute there at all.

**Decision, in two parts.** `tests.zig` embeds all four corpora in full, through
one accessor, `@embedFile("testdata/" ++ name)`. There is no options module, no
`testdata_dir` and no run-time file read anywhere in this package.
`zig/api_exercise.zig` embeds nothing: every expected answer in it is a literal
written in that file, so it does not need `testdata/` at all.

**What was traded.** About 3.1 MB of text becomes a compile-time constant in the
test object, and `check` compiles that object once per target, so the size is
paid at compile time on each of the six. What is bought is a test binary that
carries its own oracle and runs anywhere without a source tree beside it.

**What this note corrects.** An earlier version of this decision had the
opposite shape in both halves: `build.zig` created a `utf8proc_paths` options
module handing the test root a fixture directory to read at run time, and the
exercise carried its own embedded copy of the corpora. Neither matched the
source. There is no such module in this package, and the exercise embeds
nothing.

**Boundary.** `testdata/` is required at **build** time now rather than at run
time, because `@embedFile` reads it while compiling. That makes `testdata` one
entry in `build.zig.zon`'s `.paths` — which the closure gate in
`.github/workflows/verify.yml` then covers in both directions — and it makes a
trimmed checkout fail at compile time rather than at run time, which is the
better of the two failures.

---

## 4. The dangling `utf8proc_data.c` cross-reference: record, do not patch

**Condition.** `utf8proc.c:25-33` tells the reader: *"Please notice the copyright
statement in the file `utf8proc_data.c`."* `utf8proc_data.c` line 1 is
`static const utf8proc_uint16_t utf8proc_sequences[] = {`. There is no copyright
statement in it. The Unicode terms exist only in `LICENSE.md` §3.

**Decision: record it in `NOTICE.md` and change nothing.** Three reasons, and the
first is decisive:

1. `utf8proc_data.c`'s bytes are proved identical to upstream's committed content
   twice over — a SHA-256 match against the driver's 53-blob archive map and a git
   blob SHA-1 match against upstream's own tree listing. Inserting a notice would
   destroy that proof.
2. It would be an upstream source edit with **no observed failure to justify
   it**. The workspace authorises bounded portability fixes; a missing comment is
   not a portability fix.
3. `NOTICE.md` records the truth where an auditor will actually look, and
   explicitly declines to repeat upstream's claim.

**Boundary.** Any future decision to add the notice is the owner's, and it would
require regenerating `UPSTREAM.sha256` and restating the identity claim honestly
— the file would then be a fork edit, not an upstream byte.

---

## 5. Two Unicode texts, neither edited to match the other

**Condition.** `LICENSE.md` §3 quotes the 1991-2007 three-condition Unicode
grant — (a) notice with all copies, (b) notice in associated documentation, (c)
clear notice of modification — and cites the retired
`http://www.unicode.org/copyright.html`. `README.upstream.md:27` cites the same retired
URL. Unicode's **current** published licence for its Data Files is Unicode
License V3, whose single grant offers the notice in all copies **or** in
associated documentation, with no separate modification condition.

**Decision: ship both, unmodified, and say plainly that they differ.** Grant 3
governs `utf8proc_data.c`, the compiled table; `testdata/Unicode-License-V3.txt`
governs the fetched corpora. Reconciling them would mean choosing between two
pieces of someone else's legal text, which is not this role's call and is not
needed to comply with either. Both are in `.paths`; the full text of the current
licence travels with the data it governs.

**Why `testdata/Unicode-License-V3.txt` exists at all** rather than relying on
the `terms_of_use.html` link every fixture header carries: that URL is a
navigation page whose content changes. A licence text that changes under a
fetched package is not a licence record. The pinned file is 1 995 bytes with a
measured SHA-256 and cannot shift under the reader.

**Boundary.** `testdata/Unicode-License-V3.txt` is anchored by its measured
SHA-256 and the URL it came from. It is **not** covered by the `git archive`
anchor, because upstream does not commit it — and neither can any `git archive`
of upstream. That is the one place in this package where the integrity record
rests on a single measurement, and it is stated as such in `UPSTREAM.md`.

---

## 6. "The tree is MIT" is false, and three counts had to be corrected

**Condition.** The natural summary of this package is "MIT". It is wrong, and
the wrongness is not subtle — but the *specific* counts were wrong twice while
drafting, which is exactly the kind of detail that gets carried forward
unchecked.

Recorded so the next reader starts from the corrected figures:

| Claim | First written | Correct | How it was established |
|---|---|---|---|
| Files under `test/` | 18 | **19** | directory walk |
| Files with no per-file notice under `test/`, `data/`, `bench/` | 28 | **29** | sweep for `Copyright`, `Permission is hereby`, `MIT`, `SPDX` over all three directories |
| `.c` files under `test/` | — | **15** (plus `tests.h`, `ossfuzz.sh`, `install_uninstall.sh`, `app/CMakeLists.txt`) | directory walk |

**Decision: `NOTICE.md` itemises the four per-file exceptions instead of
summarising the tree.** Grant 1 covers the library; grant 2 is a *different
copyright* with its own grant that must be kept; grant 3 names one file;
`utf8proc_data.c` carries no notice of its own; upstream's pointer to that
notice is dangling; 29 files carry no per-file header; the six `testdata/`
files are a third Unicode term; and the fork's own files asserted **no licence at
all** when this note was written — the owner granted them MIT on 2026-10-04, and
note 25 carries that grant and its limits. No line in this package says "the tree
is MIT", then or now: the last clause changed the licence over the fork's own
files and left the three upstream grants and the fixtures' Unicode terms exactly
as itemised here.

**Boundary.** The counts are properties of this pinned tree and move with a
re-sync. They are not properties of the licence.

---

## 7. `Error` is closed at five, and `InvalidOptions` has a second source (count superseded by note 20)

**Condition.** `utf8proc_errmsg` maps exactly five negative codes and gives every
other value one generic sentence (`utf8proc.c:107-122`). The natural temptation
is to add a sixth error for whatever the facade itself rejects.

**Decision: the set stays at five, and the one facade-specific rejection is
folded into an existing member with the extra source named.**
`error.InvalidOptions` therefore has exactly two origins — upstream's
`UTF8PROC_ERROR_INVALIDOPTS`, and this facade refusing `Options.nullterm` — and
`README.zig.md` says so instead of leaving a reader to discover it from a
behaviour difference.

**Why `nullterm` is refused rather than honoured.** Every entry point here takes
an explicit slice. Upstream's rule is that with `NULLTERM` the length argument
is ignored (`utf8proc.c:545`). An ordinary Zig slice may legitimately contain
`0x00` bytes, so honouring the flag would mean silently truncating at a NUL the
caller never asked about. `UTF8PROC_NULLTERM` still reaches Zig, through
`c.utf8proc_reencode` and friends, for a caller who genuinely has a C string.

**Boundary.** The set can grow only if upstream's own error surface grows. A
facade-invented code would be a sixth error with no upstream counterpart, which
the W11 rule forbids.

---

## 8. `reencode`'s spare byte: owned here, checked in every mode

**Condition.** Upstream's `utf8proc_reencode` requires "one spare byte of free
space at the end" and checks **nothing**. The requirement is a bare comment at
`utf8proc.c:750-751`; the header repeats it as a warning that the program *might
crash* (`utf8proc.h:636-639`). A buffer of exactly `4 * length` bytes is one byte
short — and that is exactly what `length` elements of `i32` occupy, so every
stack array of `i32` is short by one.

**Decision: `reencode` computes `4 * length + 1` with an ordinary comparison
before writing anything and returns `error.WorkspaceTooSmall` if the workspace is
too small.** The documented crash cannot originate in this package. The check is
an ordinary comparison in Debug, ReleaseSafe and every cross target — **not** a
`std.debug.assert`, which would compile away in ReleaseFast and stop being a
guarantee exactly where it matters.

**Boundary.** The bound is upstream's, not this package's. A future upstream that
allocates the spare byte itself would make the wrapper's check redundant but not
wrong.

---

## 9. `Property` stays opaque, and the consequence is stated positively

**Condition.** `utf8proc_property_t` is declared with C bit fields
(`utf8proc.h:296-319`). Zig 0.16's `translate-c` demotes any record containing a
bit field to an opaque type. The bit field layout is implementation-defined, and
the property record is a `struct` array — one TU, no ABI risk inside the archive,
but a hand-mirrored Zig struct would be a plausible-looking lie that breaks under
a different compiler.

**Decision: `Property` is `*const` opaque; no field is mirrored.** Only the
properties upstream exports through a dedicated function are reachable from Zig:
`category` / `categoryString`, `charWidth`, `charWidthAmbiguous`.

**The part that needed deciding was how to phrase the rest.** The remaining
fields — `combining_class`, `bidi_class`, `decomp_type`, `boundclass`,
`ignorable`, `control_boundary`, `indic_conjunct_break`, and the five sequence
indices — are unreachable from Zig **regardless of the translator**, because
upstream exports no accessor for any of them. Writing that up as "the translator
hides these" would be a half-truth pointing at a fixable cause; writing it up as
"a gap to be filled" would invite someone to fill it by re-deriving values, which
is the thing this decision exists to prevent. `README.zig.md` therefore states it
as upstream's API surface and says plainly that they remain available to a C
consumer through `c.utf8proc_get_property`.

**Boundary.** Bound to Zig 0.16's translator behaviour and to upstream 2.12.0's
API surface. A compiler change would not make those fields reachable either,
because upstream does not expose them.

---

## 10. The test-coverage boundary that cannot be closed

**Condition.** `utf8proc_map` and `utf8proc_map_custom` allocate with the C
library's `malloc` and release through `utf8proc_free`. Memory that crosses into
a third-party allocator has no leak oracle from Zig's test allocator: a test that
leaks an `OwnedString` is not reported.

**Decision: state it, do not work around it.** `OwnedString`'s doc comment, this
note and `README.zig.md` all say it in the same words. The wrapper does not paper
over it by routing upstream's allocation through a Zig allocator — that would
mean copying, and copying is what the caller-buffer path already avoids.

**Consequence recorded.** Tests of `map`/`mapCustom` assert behaviour — the
mapping result, the `CustomFunc` two-pass `error.Overflow` path, the free path
completing — but cannot assert "no leak". `decompose` + `reencode`, the
allocation-free primary path, is what the corpus tests use, so the leak oracle
does apply to the bulk of the verification.

**Boundary.** This is a property of the allocator boundary, not of this fork.
It would only change if upstream grew an allocator-taking entry point.

---

## 11. `test/charwidth.c` is not an oracle, and upstream says so itself

**Condition.** `test/charwidth.c` compares `utf8proc_charwidth` against the
**host's** `wcwidth` through `<wchar.h>`, needs `_XOPEN_SOURCE 700`, and its own
source calls the mismatches informational, warning of "lots of these errors for
out-of-date system unicode tables" (`test/charwidth.c:73-86`).

**Decision: do not build it as an oracle.** Its oracle-free invariants are ported
— no combining mark has nonzero width, unassigned codepoints have width 1,
nothing is both double-width and ambiguous, and the four pinned codepoints
U+00AD, U+E000, U+00A1 and U+00A2. What is dropped is only the `wcwidth`
comparison.

**Why this is not a weakened test dressed up as a principle.** Comparing against
the host's Unicode tables measures the host libc's vintage, not utf8proc. On a
host with out-of-date tables the test fails for a reason that has nothing to do
with the code under test, and on a host with current tables it is a second, worse
copy of the same data. The real oracle is Unicode's own
`DerivedCoreProperties.txt`-derived corpora, already committed.

**Boundary.** Bound to hosts with differing Unicode versions, which is most of
them. On a host whose `wcwidth` matches Unicode 18.0.0 exactly it would be
redundant rather than wrong — still not an oracle worth a cross-target gate.

---

## 12. `UNICODE_VERSION` — a check that disappears instead of failing

**Condition.** `Makefile:181` scrapes `UNICODE_VERSION` out of `data/Makefile`
with perl and passes `-DUNICODE_VERSION='"18.0.0"'` to `test/misc.c`, whose use
site at `test/misc.c:96-99` asserts `utf8proc_unicode_version()` agrees. The use
site is inside `#ifdef UNICODE_VERSION`.

**Decision: the build scrapes the same value out of the shipped
`data/Makefile` at build time and passes `-DUNICODE_VERSION` to `test/misc.c`.**
Not hand-copied, and not `julia`-generated: the value is read from a committed
upstream file by the build, so the define and the assertion are driven by one
source and cannot drift apart.

**Why the sourcing matters as much as the define.** If the value were a literal
in `build.zig`, the assertion would compare `utf8proc_unicode_version()` against
a hand-written constant — it would still catch upstream disagreeing with itself,
but it would not catch someone editing that constant. Reading `data/Makefile`
means the data version cannot drift into a hand-maintained number anywhere in
this fork.

**Why it is worth its own note anyway.** If the define is missing, the program
does not fail — the `#ifdef` skips the whole block, the program still prints
`Misc tests SUCCEEDED.` and still exits 0. **A missing define cannot be detected
from the exit status**; it silently removes the assertion that the compiled-in
Unicode version matches the one upstream's generator used. This is the same
failure shape as `UTF8PROC_STATIC`: a switch whose absence is invisible until
something much later breaks.

**Bonus, for the record:** `Makefile:184` passes the same define to
`test/maxdecomposition.c`, which never references the macro — a grep over `test/`
finds `UNICODE_VERSION` only in `misc.c`. That flag is a no-op upstream carries.

**Boundary.** Bound to `test/misc.c`'s current source, and to `data/Makefile`
remaining a committed upstream file rather than a generated one.

---

## 13. Upstream's CI stays, and this fork does not pretend to it

**Condition.** The tree carries `.github/workflows/{zig,make,cmake,ci-fuzz}.yml`,
`.github/dependabot.yml` and `appveyor.yml`. They build upstream's CMake and Make
projects and upload to upstream's AppVeyor account. Upstream's `zig.yml` pins Zig
0.16.0 and asserts `zig-out/lib/libutf8proc.a`.

**Decision: keep them byte for byte, for provenance and audit. Do not retarget
them, do not reference them from `build.zig`, do not put them in `.paths`, and do
not run them here.** This fork's own workflow is `.github/workflows/verify.yml`,
a new file that is also not in `.paths`.

**Two distinctions kept sharp.** *Carried but not shipped* is not *not carried*:
the six upstream CI files **are** hashed in `UPSTREAM.sha256`, so an auditor can
confirm they arrived unmodified — hashed is not the same as shipped, and saying
otherwise would leave an unverified hole in the tree. And upstream's `zig.yml`
pinning Zig 0.16.0 is upstream's evidence about upstream's CI on upstream's
runners, `ubuntu-latest` and `macOS-latest` only; it says **nothing** about this
package on any of its six cross targets, and `README.zig.md` says so rather than
borrowing the corroboration.

**Boundary.** Any change to upstream's CI files requires a deliberate re-sync and
a `UPSTREAM.sha256` regeneration.

---

## 14. System-library mode: recorded as NOT APPLICABLE, with the reason

**Condition.** Debian ships a real compiled `libutf8proc`, so the W14 rule's
precondition is genuinely met here — unlike a library with no installed
counterpart, where the rule is vacuous.

**Decision: no `b.systemIntegrationOption` in this wave. Recorded as NOT
APPLICABLE, not as a gate that passed.** The contract fixes the source pins and
bounded contracts as identical across every mode, and there is one mode.

**The reason is recorded so it is not re-litigated as an oversight:**

* `utf8proc_free` **did not exist before 2.12.0** (`utf8proc.h:808`). Installed
  Debian versions run 2.5.0 through 2.11.3, so bundling this tree's 2.12.0 header
  against an installed library would compile and then **fail to link** — and would
  fail silently at the W14 level right up until it did.
* 2.12.0 changed two declared types without changing the ABI: `options` went from
  an `enum` to `unsigned int`, and `utf8proc_decompose_char`'s `last_boundclass`
  went from `int *` to `utf8proc_int32_t *`. Same widths, different declared
  types, so a header/ABI identity check must compare **versions**, not widths.
* `utf8proc_properties[]` is a `struct` array with implementation-defined bit
  fields. Inside the archive that is harmless — one translation unit. A C
  consumer compiled with a different compiler's bit field layout could misread
  `utf8proc_get_property()` results, which is part of why the soname is 3.3.0.

**Boundary.** A future wave may add a system mode, but it must translate the
**installed** header and verify header/ABI identity by version. Deciding to omit
it is not the same as satisfying the rule, and this note does not claim it does.

---

## 15. What was measured, and what was not

**Measured, by reading or hashing bytes:**

* 56 SHA-256 digests in `UPSTREAM.sha256`, computed from raw bytes with no shell
  hashing command and no `git` command.
* The comparison of all 53 upstream records against the driver's per-file blob
  map from `git archive --format=tar 79cdd5ab…`: **53 of 53 identical, 0
  mismatches**, with matching byte sizes and every blob `"kind": "regular"`.
* Git blob SHA-1 for the three compiled files, matching upstream's own tree
  listing: 3 of 3.
* The derivation self-check: 711 ranges / 2 740 code points and 678 ranges /
  2 026 code points, each against its section's declared total.
* The pinned tree read out of this clone with `git ls-tree -r 79cdd5ab…`: 53
  paths, the blob ids of the three compiled files, and upstream's own
  `build.zig.zon` with its 7-entry `.paths` and `.fingerprint = 0xdcddf08dbb8954c4`.
* That comparison run over all 53 records: the pinned commit's blob for every
  recorded upstream path hashes to the recorded SHA-256, the three pin paths
  absent from the record are exactly `.gitignore`, `build.zig` and
  `build.zig.zon`, and the six records outside the pin are exactly the
  `testdata/` fixtures. The workflow step that automates this is written but
  unrun.
* Corpus row counts: 20 171 normalization rows over six `@Part` sections, 853
  grapheme data rows.
* The `.paths` closure: 33 entries covering 68 files against 75 files in the
  tree, with exactly the seven CI files outside `.paths`.
* `DerivedCoreProperties.txt` section headers: 20 `# Derived Property:` lines.
* Line anchors cited throughout these documents, checked against the files.

**Observed since, by the driver, and recorded with receipts:**

* `zig build install test smoke consumer upstream-test -j2 --summary all
  --prefix …/install-current` at `Debug`, against the source as it stands:
  **exit 0, 35/35 steps, 22/22 tests** — `local://foundation-matrix-utf8proc-current-debug-cpp.log`.
  It records `install success` (`install utf8proc success`, `install LICENSE.md
  to LICENSE.md success`), `smoke success`, `consumer success`, and
  `upstream-test success` with all nine of upstream's own programs reported
  `success` (`normtest`, `graphemetest`, `iscase`, `valid`, `iterate`, `case`,
  `custom`, `misc`, `maxdecomposition`), plus the exercise's
  `all typed operations exercised`. **One command now covers install, tests,
  exercise, smoke, consumer and the upstream suite**, which is what closed the
  gap the previous revision of this note had to apologise for.
* `zig build test smoke consumer` at `ReleaseSafe`, `ReleaseFast` and
  `ReleaseSmall`: exit 0, 13/13 steps and 22/22 tests in each, with the smoke
  program, the API exercise and the `consumer/` package all running. Receipts
  `local://foundation-matrix-utf8proc-releasesafe-native.log`,
  `local://foundation-matrix-utf8proc-releasefast-native.log`,
  `local://foundation-matrix-utf8proc-releasesmall-native.log`. Those three name
  their steps, so `install` is not among them and is not claimed for them; no
  release-mode `upstream-test` receipt exists, and none is claimed.
* `zig build check -j2 --summary all`: **exit 0** for all six cross targets —
  `local://foundation-matrix-utf8proc-six-baseline.log`.
* `zig build check -Dtarget=aarch64-netbsd`, `-Dtarget=mips64el-openbsd` and
  `-Dtarget=x86-windows`: exit 0 on each, one representative per family that
  needs the extra front end —
  `local://foundation-matrix-utf8proc-cpp-focus-aarch64-netbsd.log`,
  `…-cpp-focus-mips64el-openbsd.log`, `…-cpp-focus-x86-windows.log`.
* `cross-test` over the **full published 53-platform matrix**, no subset:
  `local://foundation-matrix-utf8proc-cross-corrected-summary.json`, run
  `20261003-195739-62898-24523`, exit 0. All 53 `build.status: pass`; 20
  `run.status: pass` with 22 tests each; 33 `run.status: unavailable`,
  `reason: runtime_unavailable`, `status: build_only`, and **not** passes.
* `sha256sum -c UPSTREAM.sha256`: exit 0, 56 `OK` —
  `local://foundation-matrix-utf8proc-provenance-checksums.log`. The digests are
  no longer merely measured; the check has run.
* The pinned-blob comparison: `local://foundation-matrix-source-integrity.json`
  reports `utf8proc.files_checked: 53` and
  `differences: [".gitignore", "build.zig", "build.zig.zon"]` — exactly the three
  files note 19's `integrity` job names, and nothing else. The same record
  reports 10 429 protected files checked with no differences.
* `local://foundation-matrix-ledger-integrity.json`: 19 forks, 19 unique ids, 15
  protected old rows, `differences: []`. Every existing fork row and its
  consume/excluded disposition are intact.
* An installed C consumer: `zig cc -std=c99 -I …/install-current/include
  -DUTF8PROC_STATIC=1 …` exits 0
  (`local://foundation-matrix-utf8proc-installed-c-current-compile.log`) and the
  binary exits 0 after 23 printed checks ending
  `the installed C surface compiled, linked and ran`
  (`local://foundation-matrix-utf8proc-installed-c-current-run.log`).
* The six README examples, lifted verbatim into a scratch package depending on
  this one by path and run with `zig build run`: **exit 0, 6/6 steps, 6/6 tests**
  — `local://foundation-matrix-utf8proc-all-readme-examples-r3.log`. See note 22
  for what the three earlier attempts found.
* `zig fmt` over the nine fork-authored Zig and ZON files: **exit 0, all nine
  rewritten** — `local://foundation-matrix-utf8proc-fork-zig-format.log` prints
  all nine paths, and `zig fmt` prints a path only for a file it rewrites. No
  upstream file was passed to it. Formatting changes layout only: no declaration,
  no macro and no upstream byte moves, so this is not a change of behaviour and
  it re-opens no gate.

**Two receipts are kept as history, because each explains a current row and
neither describes the current state.** `…-utf8proc-unicode-r6.log` is the Debug
receipt from before `install` was added to the command, and
`…-utf8proc-unicode-r5.log` recorded `upstream-test success` inside a command
that exited 1 on a `tests.zig` case since corrected.

**Not measured here, and deliberately not asserted here:**

* The filtered-fetch consumer — a filtered `zig fetch`, a materialised package
  and a fetched dependent. The `.paths` closure argument of note 17 stands on a
  path dependency's blindness to `.paths`, which is exactly why only a fetched
  dependent can test it, and nothing else in this wave substitutes for that.
  **The driver records it separately**, in
  `local://foundation-matrix-final-package-proof.json`, outside this repository;
  only that record's observed receipt establishes a pass. `README.zig.md` names
  that record rather than a status, so these documents freeze without predicting
  a result nobody has observed yet.

**Still not claimed, and not gates:**

* No tag-signature check.
* No performance claim of any kind.
* No system-library result, because there is no system-library mode.
* No commit, no push, no other mutation of this repository by this role. Nothing
  here has been published, and no publication is authorized in this wave.
* Read-only `git` was used, and this is corrected rather than glossed: `git log`,
  `git ls-tree -r`, `git cat-file blob`, `git show`, `git remote -v` and
  `git status` were run to read the pinned tree, the pinned blob ids, upstream's
  own manifest and this clone's history state. They read; they changed nothing.

**Boundary.** `README.zig.md`'s verification table is the authoritative list of
gates. Its native, cross-target, full-matrix, integrity and formatting rows all
carry receipts. The filtered-fetch consumer is deliberately **not** in that table
as a status: it is named there by its receipt's location instead, and no row in
these documents states whether it passed.

---

## 16. Open questions for the driver and the owner

These are genuinely unresolved and none of them was invented away:

1. **Licence for the fork's own files — answered on 2026-10-04.** When this note
   was written every fork-authored file in this package asserted **no licence**,
   and `NOTICE.md` recorded the status as *unassigned* pending the owner's
   decision. The owner has now authorized a per-project licence for those files,
   matching this project's primary upstream term: they are **MIT**, recorded with
   that basis in `FORK-LICENSE.md` and in `NOTICE.md`. Note 25 carries the scope
   and the three things the grant does not reach. **This question is closed;**
   nothing else in this list changed with it.
2. **`.paths` closure — the listing is complete; the proving record is
   external.** The three native files were missing and are now listed, and the
   `consumer` job of the workflow compares the repository against `.paths` in both
   directions. The paths that must be in `.paths` for the package to build and for
   its tests to read their corpora are listed in `UPSTREAM.sha256`'s own header:
   the three native files, `LICENSE.md`, `README.md`, all six `testdata/` files,
   `build.zig` and `build.zig.zon`. All of them are there.
   **What these documents deliberately do not say is whether a fetched package
   builds.** The one gate that can answer that is recorded by the driver outside
   this repository, in `local://foundation-matrix-final-package-proof.json`, and
   only its observed receipt settles the question. The earlier wording of this
   item called the closure "closed" with no such distinction, which claimed a
   result rather than pointing at where it is recorded.
3. **Cross-target outcomes — now observed, and only partly as passes.** The six
   baseline targets compile: `zig build check` exits 0 for all six
   (`local://foundation-matrix-utf8proc-six-baseline.log`). The full 53-platform
   run builds all 53 and *runs* 20; the other 33 have no runner here and are
   `build_only`, which is not a pass. The source-level constraints read out of
   `utf8proc.h:123-137` and the `malloc` call sites — `UTF8PROC_STATIC` is the one
   switch whose absence fails loudly and only on `x86_64-windows-gnu`, and
   `link_libc` is required for `wasm32-wasi` and `aarch64-macos-none` — held:
   none of those four targets failed. `aarch64-macos-none`, `x86_64-macos`,
   `aarch64-maccatalyst` and `x86_64-maccatalyst` and `wasm32-wasi` all appear
   among the 33 build-only rows, which is the accurate reading: they compiled,
   and nothing here ran them.

   **Re-observed on 2026-10-05 against this wave's source**, which is what makes
   this item current rather than historical. Epoch `20261005T014547Z-797a73f2`,
   row `baseline-utf8proc-check`: `zig build check` over the same six baseline
   targets, exit 0, `failed: false`, `91/91 steps`, all six seen — and
   `runtime_pass_claimed: false`, so it is compile evidence and nothing else under
   any exit code. Epoch `20261004T221720228710Z-45046`, receipt
   `utf8proc-53-target-8.json`: the full 53 again, exit 0, **20 rows with
   `run.status: pass` and 23 tests each, 33 `build_only`, 0 fail**,
   `source_unchanged: true`, `jobs_honoured: true`. The count is unchanged from
   2026-10-03, and the reading is unchanged too: a green 53-target build is not 53
   runtime passes. Two eight-cell host waves now sit behind it —
   `20261004T233628757747Z-69351` at `-Druntime=false` and
   `20261004T232823091897Z-23133` at `-Druntime=true`, 8/8 pass each, the loaded
   one against this tree's own `libutf8proc.so.3.3.0`.

   **No independent external provider was exercised, and none was available.**
   Epoch `20261004T232439Z` put this host's own utf8proc candidates through the
   runtime loader and recorded `external_successes_observed: 0`, four expected
   refusals, and no route carrying `counts_as_external_coverage: true`: the host's
   single library is 2.10.0 / Unicode 16.0.0 and does not export `utf8proc_free`.
   That is the observed form of note 14's argument, and it is a **boundary**, not
   coverage.
4. **Whether to keep `bench/` at all.** It is carried, hashed and never
   compiled. `bench/icu.c` links ICU4C and `bench/unistring.c` links libunistring,
   neither of which is in scope or licensed here. Keeping them is the current
   decision because the workspace rule says not to delete retained upstream
   material; dropping them is the driver's call and would be a recorded
   deviation.
5. **A version bump.** `utf8proc.c:103-105` returns the literal `"18.0.0"` and
   `data/Makefile:24` says whoever bumps one must bump the other.
   `test/misc.c` is written to catch the disagreement — provided the define is
   passed, which is note 12.

---

## 17. `.paths` did not carry the library, and a path dependency could not see it

**Condition.** `build.zig.zon`'s `.paths` listed 30 entries. Every one of this
package's own files was there, and the three that make up the library were not:
`utf8proc.c`, `utf8proc.h` and `utf8proc_data.c`.

**Symptom, and why nothing caught it.** `build.zig` compiles `utf8proc.c` and
installs `utf8proc.h`, `tests.zig` and `zig/api_exercise.zig` include
`<utf8proc.h>`, and `consumer/` depends on this package **by relative path**.
A path dependency never reads `.paths`: it resolves files from the working
tree. So every gate that runs in this repository — build, test, smoke,
`upstream-test`, `check`, consumer — passed and would have kept passing with an
empty library in the package. Only a *fetched* dependent sees the difference,
and a fetched dependent would have received a package with no C source, no
header and no data table in it.

**Decision: put the three files back, and add the gate that could have found
it.** Upstream's own manifest already lists exactly those three
(`git show 79cdd5ab…:build.zig.zon`), so this restores an upstream requirement
that was dropped rather than adding a new one; upstream's 7-entry list is a
strict subset of the fork's again, which is what `NOTICE.md` and
`CHANGELOG.md` now say. The `consumer` job of the workflow walks the repository
and compares it with `.paths` **in both directions** — a listed path with no
file fails, and a file with no listed path fails — with the seven CI files named
as the complete permitted residue.

**Bound to.** Any package whose own gate resolves it by path. A closure check
that only the fetch path exercises must not be left to the fetch path. This is
the same shape as note 12, where a check that disappears silently instead of
failing was the defect.

---

## 18. The C gate asked for NFD and asserted NFKD

**Condition.** The installed-C-surface gate in `.github/workflows/verify.yml`
called
`utf8proc_decompose_char(0xFB01, out, 16, UTF8PROC_DECOMPOSE, NULL)` and
asserted the result was `U+0066 U+0069`.

**Symptom.** That assertion could never hold. `utf8proc.c:513-518` takes a
character's decomposition entry only when its mapping type is canonical **or**
`UTF8PROC_COMPAT` is set; U+FB01's mapping is a compatibility mapping, so the
call returns U+FB01 unchanged. The call asks for NFD and the assertion states
NFKD, and neither the comment above it nor the option word said so. It was an
option-word defect written as a Unicode claim, which is why reading the
expected value — `U+0066 U+0069` is correct for NFKD — does not catch it.

**Decision: assert both halves, and say which is which.** With
`UTF8PROC_DECOMPOSE` alone, U+FB01 comes back unchanged; with
`UTF8PROC_DECOMPOSE | UTF8PROC_COMPAT` it is `U+0066 U+0069`. The boundary
between canonical and compatibility decomposition is behaviour worth asserting
from C, and asserting only the passing half would leave the defect in place for
the next reader.

**Also removed, in the same pass: a version pin.** The gate compared
`utf8proc_unicode_version()` against `"18.0.0"`. The workspace rule puts version
identity in the provenance record, and this job already runs a stronger owner of
that claim — `test/misc.c` cross-checks the archive's Unicode version against
upstream's own `data/Makefile` through `-DUNICODE_VERSION`, and it fails if the
two disagree. Both version strings are still printed by the gate, because a C
consumer can read them. In their place the gate now asserts the four codepoints
upstream's own `test/charwidth.c:65-71` pins with no `wcwidth` oracle:
U+00AD and U+E000 one cell wide and East Asian Ambiguous, U+00A1 Ambiguous and
U+00A2 not.

**Bound to.** Any assertion written from an expected *value* without checking
the *call* that produces it. An expected value that is right for the wrong
option word, buffer size or normalisation form is the failure mode this note is
for; `test/charwidth.c`'s host `wcwidth` comparison is the same shape of trap
and is why it is not an oracle (note 11).

---

## 19. Prove the files are upstream's, not that `HEAD` is the pin

**Condition.** A downstream carries its own commits on top of the upstream tag.
As of this writing `HEAD` in this clone still *is* `79cdd5ab…`, because the
fork's work is uncommitted — which is exactly why a `HEAD`-equality check looks
reasonable while it is being written and breaks the moment the fork commits
anything. The previous verification row offered for it, re-running
`git archive --format=tar 79cdd5ab…`, was worse than useless: it re-derives the
pin's own bytes and says nothing at all about this working tree.

**Decision.** Two gates, both written into `.github/workflows/verify.yml`:

1. **`integrity` — the carried upstream files are the pinned commit's own
   bytes.** For each of the 53 paths in the pinned tree: the SHA-256 of
   `git cat-file blob 79cdd5ab…:<path>` must equal `UPSTREAM.sha256`'s record,
   and the file on disk must equal that. Every pinned path must have a record;
   every record outside the pinned tree must be a `testdata/` fixture; and the
   set of upstream files this fork edits in place must be exactly
   `.gitignore`, `build.zig`, `build.zig.zon` — the three `UPSTREAM.sha256`'s
   own header already names.
2. **`consumer` — `.paths` is a complete closure**, which is note 17.

The first job checks out with `fetch-depth: 0` and **fails with a message** when
the pinned commit is absent. It is the only step in this package that reads git
history: `build.zig` never invokes `git`, so a fetched source package with no
`.git` still builds, and every other gate works without history. That is a
deliberate split, not an inconsistency — `htscodecs` makes it with a separate
`provenance-history` step for the same reason.

**Bound to.** A repository whose upstream has git history. For an archive-only
import — GMP, predicates — the equivalent anchor is the recorded archive digest
and the pristine-import diff, and this gate has no meaning there.

---

## 20. Three new refusals, and why the error set moved from five to six

**Condition.** The API role added three preconditions this package now owns, and
the provenance documents that described the error set had to follow.

**The three, and the wrong answer each one replaces:**

1. **`error.InputOutputOverlap` on `decompose` / `decomposeCustom`.** Upstream
   reads its input and writes its output in one forward pass with no documented
   partial-output contract, so an overlapping pair yields whatever the pass
   order happens to produce — a wrong answer, not an error. The check runs before
   the native call, so `dst` is untouched when it fires.
2. **A slice-length range check answering `error.Overflow`.** Every entry point
   that passes a `slice.len` down checks it against the C signed length type
   first. Without it an over-long slice is converted rather than refused, and the
   C library sees a length that is not the caller's.
3. **`error.InvalidOptions` when `Options.charbound` is set with a `null`
   `last_boundclass`.** CHARBOUND output depends on the previous codepoint's
   bound class (`utf8proc.h:533-537`); with no state pointer there is nothing to
   carry, and upstream answers from the stateless rule instead
   (`utf8proc.c:334-335`). **This is not a crash.** The state pointer is tested at
   `utf8proc.c:293`, the `NULL` case falls to the branch that compares the
   start-of-text rule with this codepoint's own class, nothing is dereferenced,
   and a probe of the native call returned two output units — the `-1` sentinel
   and the codepoint. What that produces is a segmentation decided without
   history, which is wrong exactly where UAX #29 needs history: GB9c, GB11 and
   GB12/GB13. Refusing turns a silently wrong answer into an error.

**Consequence for the records.** `Error` now holds six members — upstream's five
codes plus `InputOutputOverlap` — and `reencode` answers with seven, because
`WorkspaceTooSmall` lives in `ReencodeError`. `InvalidOptions` has three named
sources. Upstream's set is still closed at five: nothing here adds a sixth
*upstream* code, and the two documents that said "closed at five" now say which
five and which refusals sit on top. Note 7 recorded the two-source version of
that statement; this note supersedes its count.

**Not a blanket ban on overlap.** `reencode` takes one buffer for its input and
its output and `normalizeUtf32` normalises in place; both are upstream's own
documented shapes, and each reads an element before writing its bytes. Only the
decomposition pair is refused, because only there upstream promises nothing
about the result of an overlap.

**The exercise became a program, and that is the same class of defect.** An
`addTest` artifact whose bodies are incidental can be built, linked and reported
as a pass without one public function ever being called. `zig/api_exercise.zig`
is now a real executable with its own `main` that calls every public facade
function: **compiled** by the default step — which is not installation, because
no `installArtifact` installs it and `zig-out/bin/` is never written — run at
the end of `zig build test`, selectable alone as `zig build exercise`, and
compiled for all six targets by `check`. It needs no fixture data at all: every
expected answer in it is a literal in that file, which is a stronger form of the
foreign-executor property note 3 buys the test root by embedding.

**Status.** The contracts are documented here, in `README.zig.md` and in
`CHANGELOG.md`, and they have since been observed: the driver's four native
receipts (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall) each ran the 22 tests
that fire the `nullterm` refusal, the CHARBOUND-without-state refusal,
`InputOutputOverlap` and `WorkspaceTooSmall`, and each ran the exercise to
completion. The slice-length check that answers `error.Overflow` before a length
becomes a C length has no test that fires it and stays documented-only. The
provenance role itself ran no build, test or compiler probe, and quotes the
driver's receipts rather than implying otherwise.

**Bound to.** This package's Zig surface, and to a foreign runner that executes
a binary without the build directory. The refusals themselves are not
target-bound: they are ordinary runtime checks in every optimize mode, never
`std.debug.assert`.

---

## 21. Three examples asserted the wrong thing, and no gate could have said so

**Condition.** `README.zig.md` carries six example blocks. They are prose, not
code: no build step reads Markdown, so `check` never instantiated them and the
four native receipts count tests in `tests.zig` and `smoke.zig`. A block could
assert anything at all and every recorded gate would still read the same.

**What was wrong, and how it looked.** All three defects were one shape: an
expected value that was a guess about what a call would return rather than a fact
from the Unicode standard — which is exactly the promise that section made about
itself.

1. **`decomposeChar(0x1100, …, .{ .compose = true })` does not compose.** The call
   decomposes exactly the codepoint it is given (`utf8proc.c:445`). U+1100 is
   outside the Hangul syllable range that branch checks, carries no
   `decomp_seqindex`, and is written straight back out (`utf8proc.c:529-530`), so
   the example's `U+AC00` assertion was false. Composition reads the *previous*
   codepoint and lives in `utf8proc_normalize_utf32` (`utf8proc.c:650-745`), the
   path `tests.zig:503-506` already took.
2. **`graphemeBreak(RI, RI)` answers `false`, not `true`.** The legacy stateless
   pair test keeps no state, so it reports "no break" for every regional-indicator
   pair (`utf8proc.c:286-287`, reached through the NULL-state branch at
   `utf8proc.c:334-335`). It is *right* about the first pair of a run and wrong
   about the second, where GB12/GB13 require a break. The example asserted `true`
   and placed the disagreement on the first pair — the one placement that would
   have taught a reader the opposite of the real limitation.
   `tests.zig:614-615` already had it right, which is why the permanent tests
   never noticed and the documentation was the only place it was wrong.
3. **`reencode`'s workspace was never filled.** `utf8proc_reencode` reads its
   buffer as UTF-32 on entry and writes UTF-8 back into the same bytes
   (`utf8proc.c:749-771`); the NFC example handed it freshly allocated,
   uninitialised memory and asserted the composition result.

**Decision.** Each example asserts a value readable from UAX #15,
`CaseFolding.txt` or UAX #29 and from nowhere else. Where the honest fact is that
a call is wrong — the stateless pair test — the example asserts the wrong answer
explicitly and names which pair it is wrong about, rather than dropping the
assertion or inverting it. The section now says what it is: six complete `test`
declarations for a test root carrying `std`, `std.testing` and `utf8proc`, with
the two `zig` blocks under Importing labelled as fragments, and **no build step
compiles that document**. The `check` row of the gate table says so as well.

Two adjacent claims were tightened in the same pass, because both invited the
same kind of over-reading. `InvalidOptions`'s upstream source is the check at the
top of `utf8proc_decompose_custom` (`utf8proc.c:547-551`), so it reaches
`decompose`, `decomposeCustom`, `map` and `mapCustom` and **not** `decomposeChar`,
which strips the mark without it (`utf8proc.c:503-506`). And `Options.stable` is
declared at `utf8proc.h:154` but branched on nowhere in this pin's `utf8proc.c`:
its five occurrences are upstream's own `utf8proc_NFC`, `NFD`, `NFKD`, `NFKC` and
`NFKC_Casefold` passing it to `utf8proc_map` (`utf8proc.c:820, 826, 832, 838,
844`). It is accepted, forwarded and inert, and no record in this package claims
per-entry-point honouring for it.

**Status.** `SOURCE-CONFIRMED` against `utf8proc.c`, `utf8proc.h` and
`zig/root.zig`. The examples themselves were `PENDING-VERIFICATION` while no
gate in this package could see them; they no longer are, and note 22 records how.
The provenance role ran no build, test or compiler probe while making these
corrections. `CHANGELOG.md` entries 33 through 36 record them individually.

**Bound to.** Prose that no gate compiles — in this package, and in any package
whose examples live in a Markdown file. An example is only as strong as its
expected values; outside a compiled test root the expected value has to be
checked against the source by reading, and the document has to say that this is
what happened rather than implying a run. Note 22 is the case where reading was
not enough, and it is the reason the bound says *checked by reading* rather than
*verified*.

---

## 22. The examples were run after all, and reading them was not enough

**Condition.** Note 21 recorded that `README.zig.md`'s six example blocks are
prose: no step in this package reads Markdown, so every claim about them was
`PENDING-VERIFICATION` and reading the source was the only check available.

**What changed.** The driver lifted the six blocks verbatim into a scratch package
outside this repository, depending on this one by path, and ran them. Four
attempts, each recorded:

| Attempt | Exit | Outcome |
|---|---|---|
| `local://foundation-matrix-utf8proc-all-readme-examples.log` | 1 | a harness defect — an absolute path in the scratch `build.zig.zon`, rejected by Zig. Nothing in the document |
| `…-all-readme-examples-r1.log` | 1 | `allocator.alignedAlloc(u8, 4, …)`: Zig 0.16's second parameter is `?mem.Alignment`, so the integer `4` was a type error. Corrected to `.@"4"` |
| `…-all-readme-examples-r2.log` | 1 | `5 pass, 1 fail (6 total)`. The case-folding block asserted `toUpper(0x00DF) == 0x00DF`; upstream's issue #130 regression at `test/case.c:57-63` requires `0x1e9e`, and the failure printed `expected 223, found 7838`. Corrected to `U+1E9E` |
| `…-all-readme-examples-r3.log` | 0 | `6/6 steps, 6/6 tests` |

**Three corrections, and one of them has no receipt.** The alignment argument and
the sharp-s expected value were each reported by a failing run. **The third
correction — the NFC block's expected result, `U+00C9` to `U+00E9` — was never
reported by anything.** Attempt r1 died at compile time, before any test ran, so
the value was never exercised; r2 then reported only the sharp-s failure. It is
recorded here as a correction that the passing run confirms and no failing run
ever caught, because a claim of "the compiler found this" would be false.

**Why it matters beyond this package.** A block of documentation prose is only as
strong as its weakest expected value, and *checking by reading* is not the same as
*checking by running*. Reading found three of the four defects in note 21 and none
of these three: the `?mem.Alignment` parameter is a Zig 0.16 API fact, not a
Unicode fact, and `U+00DF` versus `U+1E9E` is a `toUpper` claim that had to be
compared with `test/case.c:57-63` line by line. The generalisable rule is that a
package whose examples are its primary user-facing documentation should treat
"run the examples" as a gate in its own right — in a scratch package, if the
document's own build steps do not reach it.

**Bound to.** Packages that keep runnable examples in a Markdown file. It is not
bound to Zig 0.16: the specific errors are, the rule is not. What is *not*
claimed: the six blocks are the current text and they pass; the earlier forms did
not, and no receipt exists for the third correction.

---

## 23. Fifteen targets failed to translate, and the fix was a second front end

**Condition.** This package compiles one translation unit and hands it to
`zig translate-c`, which preprocesses *and* parses with Aro. On 38 targets that
worked. On fifteen it did not, all of them a failure of Aro's own read of that
target's C library rather than of anything in `utf8proc.c`, `utf8proc.h` or this
package's facade.

**Symptom, observed.** `local://foundation-matrix-utf8proc-netbsd-preprocess-check.log`
— `zig build check -Dtarget=aarch64-netbsd` exits 1,
`utf8proc-translate.zig:1191:43: error: use of undeclared identifier '__int128_t'`.
On the full matrix, `local://foundation-matrix-utf8proc-cross-original-summary.json`
(run `20261003-175929-14815-27659`) exited 1 with
`counts: {pass: 20, fail: 15, build_only: 18}`, and all fifteen failures were
`build_failed`: `aarch64-netbsd`, `aarch64_be-netbsd`, `arm-netbsd`,
`armeb-netbsd`, `mips-netbsd`, `mipsel-netbsd`, `powerpc-netbsd`, `x86-netbsd`,
`x86_64-netbsd`, `arm-openbsd`, `mips64-openbsd`, `mips64el-openbsd`,
`powerpc-openbsd`, `x86-openbsd`, `x86-windows`.

**The three causes, kept separate.** They are not one bug with one fix:

1. **NetBSD (9).** `__END_DECLS` is `__END_PUBLIC_DECLS`
   (`generic-netbsd/sys/cdefs.h:431-432`), whose body ends in
   `_Pragma("GCC visibility pop")` (`:413`). Aro 0.16 leaves the pragma in the
   token stream instead of executing it, so the trailing `__END_DECLS` of
   `sys/types.h`, `sys/endian.h:74`, `sys/bswap.h`,
   `x86_64-netbsd-none/machine/byte_swap.h:72` and `<stdlib.h>` each stop the
   parse — twenty-one of them on `x86_64-netbsd`.
2. **OpenBSD ILP32 (3: `arm`, `powerpc`, `x86`).** Aro's own `<stddef.h>`
   typedefs `size_t` as `__SIZE_TYPE__`, which is `unsigned int` on a 32-bit
   target, while `generic-openbsd/sys/types.h:171-174` typedefs it as
   `__size_t` under a `_SIZE_T_DEFINED_` guard Aro's header never sets, and
   `__size_t` is `unsigned long` there. Two typedefs, two widths, one name.
3. **OpenBSD MIPS (2: `mips64-openbsd`, `mips64el-openbsd`).**
   `generic-openbsd/mips64/endian.h:32-41` refuses to define `BYTE_ORDER` unless
   `__MIPSEL__` or `__MIPSEB__` is defined, and Aro's MIPS predefined table
   defines neither. **These two are two architectures, not one**: separate libc
   directories, and `std.Target.Cpu.Arch` gives them separate members, `.mips64`
   and `.mips64el` (`std/Target.zig:1350-1353`). A fix that named only
   "OpenBSD", or only one of the two, would have left the other failing.

`x86-windows` is a fourth, separate one:
`any-windows-any/malloc.h:183-187` derives `_ALLOCA_S_MARKER_SIZE` from `_ARM_`,
`_X86_`, `__ia64__`, `__x86_64` or `__aarch64__`, and Aro's Windows predefined
table defines none of them for 32-bit — which is why `aarch64-windows`,
`thumb-windows` and `x86_64-windows` built and `x86-windows` did not.

**Fix: choose the front end per target, and restate one compiler typedef.**
`build.zig`'s `translationRoute` picks, from the property each cause turns on
rather than from a list of target names: every NetBSD target, every ILP32 OpenBSD
target, both OpenBSD MIPS targets, and `x86-windows` get the **target's own C
preprocessor first** — `zig cc -E -dD`, the same pinned compiler that compiles
`utf8proc.c` — and Aro parses what it wrote. Every other target gets Aro reading
`zig/translate.h` as it stands. Separately, `zig/translate.h` restates the
compiler's own `__int128_t` and `__uint128_t` under
`#if defined(__SIZEOF_INT128__)`, because `generic-netbsd/arm/cdefs.h:62-63`
defines `__ALIGNBYTES` as `(sizeof(__int128_t) - 1)` and `-dD` keeps that
definition beside the expanded text while `zig translate-c` emits no implicit
typedef (`translate-c/Translator.zig:420-422`).

**No compensation, no shim, no dropped target.** Both routes read this
repository's own `utf8proc.h`, with this repository's root on the include path and
`UTF8PROC_STATIC` defined from the single `core_macros` list the C compile line
uses, so the route cannot describe a different library or a different linkage.
(That macro source is the shape this note found on 2026-10-03; corrected
2026-10-04 — the lists are `libraryMacros(linkage)` and `consumerMacros(linkage)`
and `zig/translate.h` defines neither. The correction is `CHANGELOG.md` entry 47
and `UPSTREAM.md` item 13; nothing else in this note changed.)

Nothing is stubbed, narrowed, renamed or substituted, no predefine is invented —
`__SIZEOF_INT128__` is the compiler's own capability macro, defined under the same
`hasInt128Type()` test Clang and Aro both use — and the archive, its ABI and
utf8proc's own declarations are identical on both routes.

**Observed after the fix.**
`local://foundation-matrix-utf8proc-cpp-focus-aarch64-netbsd.log`,
`…-cpp-focus-mips64el-openbsd.log` and `…-cpp-focus-x86-windows.log` each exit 0
— one representative per family, including both MIPS names. The six-target
`check` exits 0 (`local://foundation-matrix-utf8proc-six-baseline.log`). The full
matrix, run `20261003-195739-62898-24523`
(`local://foundation-matrix-utf8proc-cross-corrected-summary.json`), exits 0 with
**all 53 `build.status: pass`**, 20 `run.status: pass` and 33
`run.status: unavailable` / `build_only`.

**The fifteen did not become passes; they became build-only rows.** Every one of
them is a target with no runner on this host, so a successful foreign compile is
`build_only` and is recorded as such. What the correction changed is
`build.status`, from `fail` to `pass`; what it did not change is whether anything
executed there, and nothing in this package's records claims otherwise.

**Bound to.** Zig 0.16.0 with Aro as `translate-c`'s front end, and to the
platform set of the 53-platform matrix. The *shape* generalises: when a
translator cannot read a target's headers, running the target's own preprocessor
first is a bounded, honest fix — whereas inventing a predefine to satisfy the
translator, or special-casing a target out of the matrix, is not.

---

## 24. The README was upstream's, and three records cited it as though it were the fork's

**Condition.** The contract-migration wave requires the fork README to carry
native-source deviations, native-build deviations with a dated history link, the
matrix, and consumption — in that order. `README.md` was upstream's README,
byte for byte, and its bytes were already pinned in `UPSTREAM.sha256`. Three
records quoted it by line number: `NOTICE.md` cites `README.md:8-12`, `:23-28`
and `:27`; `UPSTREAM.md` cites `:2`, `:9`, `:11`, `:27`, `:87`, `:92`;
`FORK-NOTES.md` and `CHANGELOG.md` cite `:27`.

**Symptom, had it been done the other way round.** Any of those citations would
have silently changed meaning, because the lines they quote are statements about
*upstream's* licence, its stale `JuliaLang` and `NanoComp/meep` URLs and the
Public Software Group's history. After a rewrite they would point at this fork's
prose and would read as upstream having said something it never said. That is the
failure mode this note is about: not a broken build, but a provenance record that
quietly stops being true.

**Decision.** `README.md` becomes the fork's README. Upstream's bytes move to
`README.upstream.md` unchanged — same 5839 bytes, same SHA-256, so the integrity
anchor is a rename — and every citation of upstream's prose was repointed at
`README.upstream.md:<line>`. Upstream's text is never quoted *into* the fork
README: the fork README links to the file instead. `UPSTREAM.sha256`'s record
moved with the file, and `README.md` joined the four files excluded from that
record because it is no longer byte-identical to upstream.

**Bound to.** This package's records. The generalisation: when a document that is
itself upstream bytes is replaced in place, every `path:line` citation of it
becomes a claim about the wrong file, and the citation list is part of the
migration, not a follow-up.

**Two requirements this created for other roles, one now met and one open.**
`build.zig.zon`'s `.paths` carries `README.upstream.md`, `FORK-LICENSE.md` and the
five packaging files, so a fetched package keeps upstream's README, the fork's
grant and its delivery; `FORK-LICENSE.md` is load-bearing rather than tidy,
because `build.zig` installs it and the install step would fail without it. Still
open: `.github/workflows/verify.yml`'s `integrity` job declares three
edited-in-place files where this note made it four. Both are readings of files, not
gate results — the driver runs the checks, and this role ran none.

## 25. The fork's own files had no licence, and the owner chose one

**Condition.** `NOTICE.md` recorded, correctly, that every file this fork wrote
asserted **no** licence: the build graph, the facade, the tests, the records. That
was true and it was deliberate — a grant needs a basis, and there was none.

**Decision.** The owner of this working copy authorized a per-project licence
for the fork-authored additions, matching the project's primary upstream term.
That term is MIT, stated twice in `LICENSE.md` (`:1-28` and `:30-50`), so the
grant is MIT, SPDX identifier `MIT`, and it is recorded with its basis in
`FORK-LICENSE.md` and summarised in `NOTICE.md`.

Three boundaries were written down rather than assumed:

* **The holder line is collective** — `the utf8proc Zig SDK fork authors` —
  because no individual identity was supplied and inventing one would be a
  fabrication. No upstream author is credited with fork work, which is upstream's
  copyright over upstream's bytes and nothing else.
* **The grant reaches no upstream byte**, including the upstream bytes still
  inside `build.zig`, `build.zig.zon` and `.gitignore`, and it does not reach
  `utf8proc_data.c`, which `LICENSE.md:52-93` names and which therefore keeps its
  own Unicode data grant.
* **It does not reach the fixtures.** The five `.txt` files in `testdata/` stay
  under Unicode License V3. That was true before the authorization and is true
  after it; only the licence over the fork's *own* files changed.

**Bound to.** This tree's authorship split. The generalisation: a per-file
inventory and a per-project grant answer different questions, and a grant over
"our files" is worthless if it does not say which files those are — which is why
`FORK-LICENSE.md` enumerates them rather than saying "everything not upstream".

## 26. One derivation, two named variants

**Condition.** The contract asks for static and shared Nix packages with the
default preserving the SDK's existing linkage policy. This SDK's policy is
upstream's, and upstream's is a static archive: the `-Dlinkage` option in
`build.zig`'s `build` ends in `orelse .static`, so `-Dlinkage` defaults to
`static` here.

**Decision.** `package.nix` is one uncurried `{ lib, stdenv, zig, src, linkage }`
function returning one derivation, and the entry points name the variants:
`flake.nix` publishes `packages.<system>.static` and `.shared` with `default`
staying `static`; `devenv.nix` publishes the same two as lazy `outputs`. Neither
entry point invents a second convention, and neither returns a variant set from
`package.nix` itself.

**The build invocation, and why each flag is there.** One optimize selection and
`-Dcpu=baseline` so the artifact is a package artifact rather than a host-shaped
one; `-Dlinkage=${linkage}` so the variant is the build graph's choice;
`--prefix "$out"`; and `-j"${NIX_BUILD_CORES:-1}"`, because a derivation that
ignores the builder's core count is a local build that happens to run remotely.
No C flags: `build.zig` owns those.

**Phases.** `dontConfigure` and `dontBuild` keep the Zig setup hook's own phases
from building the package a second time with default flags. `dontInstall` is
deliberately not set: `stdenv` decides whether the install phase runs from
`doInstall`, not from the presence of an `installPhase` attribute, so setting it
would skip the real phase and produce an empty output with no error at all.

**Why the install phase is the only one that runs.** The SDK's default build step
*is* its install step, and it executes nothing: `build.zig`'s `build` hangs the
install step off the smoke executable's own `addExecutable` step, not off any
run. So `zig build --prefix $out` installs and runs nothing of this package's
own.

**Caches.** Both Zig caches are exported under the Nix-provided `TMPDIR` in
`preInstall`, because `src` is read-only in the sandbox and `.zig-cache/` cannot
be created beside `build.zig`. Leaving that to the toolchain's default would make
the build fail in a way that looks like a source problem.

**Bound to.** This package's build graph and nixpkgs' `zig_0_16`. If a future
build graph makes the smoke program part of the install step's *run*, the
run-phase-free derivation has to be revisited.

## 27. Upstream's `pkg-config` metadata carries a build-side macro in `Cflags`

**Condition.** A consumer needs link metadata, and upstream ships it: both
`libutf8proc.pc.in` and `libutf8proc.pc.cmakein` put `-DUTF8PROC_EXPORTS` in
`Cflags`, and `Makefile:100-106` generates the former with four `sed`
substitutions.

**Observation.** `utf8proc.h:123-139` reads that macro as what it is. Without
`UTF8PROC_STATIC`, on `_WIN32` a declaration is `__declspec(dllexport)` when
`UTF8PROC_EXPORTS` is defined (`:130`) and `__declspec(dllimport)` when it is not
(`:132`). So `-DUTF8PROC_EXPORTS` is the macro for *building* the DLL, and a
consumer that defines it asks for its own translation unit to export those
symbols — the opposite of consuming them. What a consumer needs is
`-DUTF8PROC_STATIC` for the static variant, where `:123-126` then leaves
`UTF8PROC_DLLEXPORT` empty, and nothing for the shared one, where the empty define
leaves `dllimport`.

**Decision, recorded as a requirement on whoever writes the file.** The metadata
must be variant-dependent in exactly that way, derived from the header rather than
from taste, and it must be **relocatable**: `prefix` becomes
`${pcfiledir}/../..` rather than an absolute path, so a staged, packed or moved
tree still describes itself. `build.zig` generates the file, because the build
graph owns where the library lands and a second generator would be a second place
for that answer to be wrong; `package.nix` therefore writes nothing into `$out`
beyond what the graph installs. Upstream's two templates are **not edited**: they
are upstream's bytes and stay in `UPSTREAM.sha256`, and a consumer who installs
upstream's own `.pc` still gets upstream's line. Recorded in `NOTICE.md`,
`UPSTREAM.md` and `CHANGELOG.md` entry 42.

**Boundary, and it is not a platform boundary.** This is a metadata correction,
not a claim that upstream is broken on every platform: a non-Windows consumer
compiling through `-DUTF8PROC_EXPORTS` gets
`__attribute__((visibility("default")))` declarations, which is harmless. The
correction matters on Windows, and it is derivable from the header on every
platform.

## 28. utf8proc's ABI constrains the runtime route

**Condition.** `-Druntime=true` routes every native entry point through one
process-lifetime table and links no native library into the module; `-Dlinkage`
still decides which artifact is delivered. What this role owns is the record of
what utf8proc's declarations force on that route.

**Decision.** Record those four facts, and describe no capability the package does
not have: no stub route, no fallback that silently links the static archive, no
"runtime mode" that is the linked mode under another name. Now that the route has
landed, the same facts are recorded as what the implementation honours — the
exported table is reached by address in the loaded image, `OwnedString.deinit`
still routes through the library's own `utf8proc_free`, and the Unicode-version
requirement below is the one thing no symbol check can enforce.

**The ownership split first, because it decides the licence record.**
`runtime/graph.zig` is the build half and `runtime/library.zig` this SDK's
descriptor; `runtime/loader.zig`, `runtime/generate.zig`, `runtime/sync.c` and
`runtime/sync.h` are the reusable core the driver authors and distributes. That
split is why `FORK-LICENSE.md` scopes this fork's grant to the first two and says
nothing about the other four: they are not this fork's files to grant.

The four facts about utf8proc itself, each read out of the source:
1. **Exported data is one array.** `utf8proc_utf8class[256]`
   (`utf8proc.h:453`, defined at `utf8proc.c:56`) is the library's only exported
   data symbol. All six tables in `utf8proc_data.c` — including
   `utf8proc_properties[]`, which `utf8proc_get_property` returns pointers into —
   are `static const` and unexported. So a loaded raw route reaches the exported
   table by address in the loaded image, and property pointers are per-image by
   construction.
2. **The allocator belongs to the allocating image.** `utf8proc_map` allocates
   with the library image's `malloc`/`realloc` (`utf8proc.c:789-811`) and
   `utf8proc_free` calls that image's `free` (`:848-849`). A provider's buffer is
   released by that provider; host memory is never freed through a provider. This
   is why the facade's `OwnedString.deinit` routes through `c.utf8proc_free`
   rather than a Zig allocator, and it is why a loaded route cannot promise that
   a buffer is interchangeable between host and provider.
3. **Symbol presence is not ABI identity.** 2.12.0 changed `options` from an
   `enum` to `unsigned int` and `utf8proc_decompose_char`'s `last_boundclass` from
   `int *` to `utf8proc_int32_t *`, with no version string that would catch it.
   `utf8proc_version()` is the cheap half of a provider check; the header/ABI
   identity work is already written down in `UPSTREAM.md`'s system-library
   section, which explains why W14 is *not applicable* here rather than satisfied.
4. **A provider's tables must be the same Unicode revision as this build's.**
   `utf8proc_get_property` indexes `utf8proc_stage1table` with the property's own
   `lower` and `upper` fields and with `codepoint >> 15` (`utf8proc.c:233-240`),
   and `utf8proc_property_t` is a bit-field record (`utf8proc.h:296-319`), so a
   provider built from a different Unicode revision resolves every symbol, passes
   every ABI check and still disagrees about codepoints this build never asked
   about. This is the one requirement that is not about the C ABI, which is why
   `validate` requires the Unicode version to be **present** rather than equal to
   any particular value.

**No Windows CRT interchangeability is claimed.** A host executable and a loaded
DLL may resolve different C runtimes and therefore different heaps. The crossing
is safe only when both images really do resolve one allocator; this package
verifies nothing about that, guarantees nothing about it, and says so in
`README.md` and `README.zig.md` in the same words. On ELF targets the same
discipline applies across a `dlopen`-ed image, where the bound symbols are the
ones that image resolved.

**Bound to.** utf8proc 2.12.0's declarations and its compiled tables, and to this
migration's loader contract. A future utf8proc that exports its tables, or a
loader that copies them out of the image, would relax fact 1; fact 2 would only
relax if a future upstream grew an allocator hook, which it has not; and fact 4 is
not relaxable by any loader at all, because the Unicode revision is a property of
the compiled tables rather than of the declarations. Closing that gap would mean
comparing `utf8proc_unicode_version()` against the revision this build was
compiled for, which is a compatibility judgement rather than an ABI check — which
is why `validate` stops at "present".

## 29. A committed file names no storage location, and a missing cache variable is filled

**Condition.** The workspace's storage policy requires that Nix, devenv and Zig
caches land on approved local scratch, never in a repository, never in `/tmp` or
`/var/tmp`, and never on the `/vol` mount. A committed file may not name any of
those locations, and this role does not know which mount the next host will pick.

**Decision.** The packaging files name no storage location at all. `devenv.nix`
sets no `TMPDIR`, no `XDG_RUNTIME_DIR` and no `DEVENV_HOME`, and it never
overwrites a cache variable the caller exported: a `ZIG_LOCAL_CACHE_DIR` or
`ZIG_GLOBAL_CACHE_DIR` that is already non-empty is used exactly as it arrives.
`.envrc` names exactly one thing, `XDG_RUNTIME_DIR`, and only when the caller has
already named an approved scratch root — because devenv defaults its runtime
sockets to `/tmp` even when `TMPDIR` is set, and that is the one default this
package can fix without inventing a host fact. `DEVENV_ROOT`, `DOTFILE` and
`STATE` are read-only to devenv and are not touched.

**Why there is no evaluation-time lookup either.** An earlier revision of this
note had `devenv.nix` read `HOST_SCRATCH_ROOT` with `builtins.getEnv` and export
the cache paths when it was set. That was removed: impure evaluation in a
committed file makes the shell's result depend on the evaluator's environment
in a way no lock can capture, and the caller already knows where its scratch is.

**Why a missing cache variable is filled rather than guessed at evaluation time.**
An earlier rule refused an unset cache variable outright. That was right about
the rule and wrong about the common case, because a shell that has never
exported either variable is ordinary, and refusing it told the caller nothing
they could act on short of inventing a mount. `devenv.nix` fills a missing one
from `XDG_CACHE_HOME` first and `TMPDIR` second, as `zig-local-cache` and
`zig-global-cache`, and refuses only when the caller named neither of those
either. Both fallbacks are read out of variables the caller's environment
already carries, so a committed file still names no location. Setting a literal
`/tmp` cache instead would look like working support while violating the storage
rule, and a `default:` path in a Nix expression would be a lie about a host
property. The fill is in each script body as well as in `enterShell`, because a
devenv `scripts` entry is a generated program that inherits the caller's
environment and not the shell hook's; note 31 carries the same reasoning for the
working directory.

**Second decision: the SDK is not in the development shell's `packages`.** Adding
it would make entering the shell build the library. `outputs.static` and
`outputs.shared` carry it instead, and `packages` is tools only.

**Two later additions, both consistent with the rest.** `CHANGELOG.md` entry 52
gave the `sdk-build` script an install prefix beneath the caller's
`ZIG_LOCAL_CACHE_DIR`. Entry 56 gave all seven `zig build` bodies one shared
flag string naming both cache directories, and turned that refusal into a fill
from `XDG_CACHE_HOME` and `TMPDIR`. Both read variables the caller already
exported and never overwrite one, and both name no mount, no host and no policy
in a committed file: this note's rule is unchanged, and note 31 carries why those
scripts needed a location at all.

---

## 30. One record, several rules, and a gate that breaks three ways at once

**Condition.** `UPSTREAM.sha256` states in its own header which upstream files are
deliberately excluded from it, and why: this fork edits those paths in place, so a
digest for them would be false within hours. Entry 19 added a fourth to that list
when it replaced `README.md`'s contents and moved upstream's bytes to
`README.upstream.md`.

**Symptom, by reading rather than by running.** The workflow's `integrity` step had
four separate assumptions about that record, and entry 19 invalidated three of
them: the declared edited-in-place set still named three files, so `README.md`
fell through to the divergence rule; the step demanded a digest for every path in
the pinned tree, so the four excluded paths failed as unrecorded; and the
remainder rule exempted only `testdata/`, so `README.upstream.md` failed as a
record with nothing to anchor it to. Any one of the three fails the job, and only
the first is visible in the step's own source — the other two are assumptions
about a file this repository's records describe.

**Fix.** Settle the excluded paths *before* the record is consulted: no digest
required, and the requirement inverted so that a declared-but-unmodified file
fails. Exempt `README.upstream.md` beside the fixtures. Count the declared set
rather than the divergences it happens to produce. Delete the hardcoded upstream
file count and the "three"s in the prose above the steps, because they moved with
the exclusions.

**Bound to.** This gate's three rules over one record, and to a record whose shape
is described in prose its header rather than in a machine-readable field.

**The generalisation, which is the part worth carrying.** When a provenance record
changes shape — a new exclusion, a renamed path, a new origin — the file that
*checks* it has to be re-read rule by rule against the new shape. Reading only the
literal that looks stale finds one of the three failures here. The source of truth
was the record's own header the whole time; what was missing was reading every
consumer of it, not a rule in it. The same shape shows up wherever a header
documents a machine-readable list that other files interpret by convention:
`.paths` against the two-directional closure check, and the export-macro split
that note 23 recorded against the correction in `CHANGELOG.md` entry 47.

---

## 31. A devenv script has no working directory of its own

**Condition.** Any SDK whose canonical devenv entries are `scripts` — which
devenv materialises as generated programs rather than running them in place —
or `tasks` whose `exec` names a relative path such as `build.zig`,
`consumer/` or `UPSTREAM.sha256`, and which is driven from outside its own
checkout. That last part is deliberate rather than accidental: the driver runs
`devenv shell -- <name>` from a scratch *project* directory that holds
`.devenv/` and `devenv.lock` and nothing else, so devenv's autolock and its
cache stay off a repository that lives on a network mount.

**Symptom, read out of the driver's receipts and the sources they name.** Two
unrelated errors from one cause. The consumer entry printed `error: no build.zig
file found, in the current directory or any parent directories`: the consumer
step is declared in *this* build graph, and `runConsumer` sets the nested
build's working directory to `b.path("consumer")`, which is relative to this
build root, so the command belongs here and not in `consumer/`. The integrity
entry printed `sha256sum:
UPSTREAM.sha256: No such file or directory`: the record's 56 paths are relative
to this SDK, and `sha256sum -c` resolves each name against the current
directory and has no option to root itself elsewhere. Neither error names the
cause; both are what a relative path says when the process starts somewhere
else.

**Fix.** Every exec body starts with a `cd` to the SDK's own directory,
computed in the module that declares the entry. `./.` in an expression is
relative to the file that contains it, so `builtins.toString ./.` is the SDK
and not the caller's directory. Two details decide whether that works.
`builtins.toString`, not `${./.}`: a path literal interpolated into the
generated program carries a store context, Nix copies the whole tree into the
read-only store, and a build that wrote there could not — the string names the
working tree and the literal names a copy of it. And
`lib.escapeShellArg` around the result, because a checkout path with a space in
it is not a hypothetical.

**Bound to.** Entries whose exec body names a relative path; a devenv version
that materialises scripts and tasks as generated programs that inherit the
caller's working directory; and a driver that invokes them from a project
directory on purpose. A `cwd` option on a task covers the task half only, never
the script half. Self-location costs nothing when the SDK is evaluated from
somewhere else, because `./.` is whatever directory the module file itself is
in.

**The generalisation, which is the part worth carrying.** A build entry point
is a command *and* a working directory, and the directory is the half nobody
writes down. Every relative path inside an exec body is a claim about where the
process starts, and that claim is false exactly when the entry is invoked the
way a package manager, a task runner or a harness invokes it — from outside the
tree. Naming the directory explicitly, derived from the file that owns the
entry, makes the entry callable from anywhere. Any checker that re-roots itself
with `cd "$(dirname "$0")/.."` is making the same statement one layer down, in
shell rather than in Nix.

## 32. The nested consumer build was told a resolved target, and a triple cannot carry a dynamic linker

**Condition.** Any step that re-enters `zig build` as a *separate* build graph
and has to state the target on the command line for it. Here that is
`runConsumer`, which runs `consumer/` as its own build so that a dependent
which writes only `b.dependency("utf8proc", ...)` and `dep.module("utf8proc")`
is proved against the real package rather than a manifest dependency that would
close a cycle.

**Symptom, read out of the driver's receipt.** `utf8proc-devenv-consumer.log`
from run `nix-acceptance-20261004T193710Z` ends with

> error: the host system is unable to execute binaries from the target
> because the host dynamic linker is
> '/nix/store/lm3pknxi0ipypy3lxh1wmm8wvvavdwrn-glibc-2.42-84/lib/ld-linux-x86-64.so.2',
> while the target dynamic linker is '/lib64/ld-linux-x86-64.so.2'.

and the nested command it quotes is
`zig build run -Dtarget=x86_64-linux.6.12...6.12-gnu.2.42`. Nothing about this
SDK is wrong in that message. The refusal is `Step.Run`'s own
`lib/std/Build/Step/Run.zig:1337-1348`, comparing
`b.graph.host.result.dynamic_linker` with the target's own, and it is right:
the nested build was never given this host, it was given a triple.

**Why.** `runConsumer` serialized `target.result.zigTriple`. That is
`Query.fromTarget(target).zigTriple(...)`
(`lib/std/Target.zig:2099-2101`), and `fromTarget`
(`lib/std/Target/Query.zig:107-136`) converts a resolved target back into a
*query* by filling in everything it can spell: `cpu_arch`, `os_tag`, `abi`,
the GNU libc version and the CPU as `.{ .explicit = … }` with its full feature
add and subtract sets. That last part is the `6.12...6.12` in the receipt. What
it cannot spell is `dynamic_linker` — the field is never assigned there, or in
either `zigTriple` — so a resolved host comes back as an explicitly named
cross target. The nested `standardTargetOptions` read it as one, resolved it
against the ABI's defaults instead of against this machine, and asked for
`/lib64/ld-linux-x86-64.so.2`. Same architecture, same OS, same glibc version —
and still not native, because `Query.fromTarget(host)` is not a native query
(`isNativeTriple()` demands `cpu_arch`, `os_tag` and `abi` all null,
`lib/std/Target/Query.zig:377-394`). Nothing in the graph can express that
difference once it has been flattened into a string, which is why the same
source fails on this host and would have passed on a glibc-default one.

**Fix.** Serialize the **query** instead: `target.query.zigTriple`, which writes
the literal `native` when nothing was named (`lib/std/Target/Query.zig:421-423`
— `isNativeTriple()` is true exactly for a query that names nothing, `:392-394`)
and the caller's own spelling otherwise, plus
`target.query.serializeCpuAlloc` as `-Dcpu`, because the triple never carries
the model or its feature set (`:488-528`; the four standard options are
registered at `lib/std/Build.zig:1474-1493`). That pair is not a house
invention: it is the pair `std.Build` itself uses when a `ResolvedTarget` is
handed to a dependency (`lib/std/Build.zig:454-459`). A query that names nothing
*is* `b.graph.host` (`lib/std/Build.zig:2704-2708`), so both halves of the
nested build compile against the linker this machine really has, while
`-Dtarget=aarch64-linux-gnu` still resolves to `aarch64-linux-gnu` on the other
side.

**Bound to.** Any step that shells out to a nested `zig build` and states a
target for it. Not bound to: `std.Build`'s own dependency forwarding, which
already used the query, and the refusal itself, which stays exactly as it is.
`skip_foreign_checks` is not set, `patchRun` is not used to ignore a mismatch,
no store path is written down anywhere in this package, and no other libc is
substituted — the host's real linker is selected because the query selects the
host, not because anything here names it.

**The generalisation.** A resolved target and a target *query* serialize
differently, and only one of them round-trips. `std.Target` records what the
machine turned out to be — a detected CPU, a discovered dynamic linker, an
installed sysroot — and none of that survives being spelled as a triple, because
a triple is a portable name for a configuration rather than a description of one.
Anything that hands a selection to another build must hand the question.

## 33. The nested consumer build was given the caches but not the prefix

**Condition.** Any step that re-enters `zig build` as a *separate* build graph
and forwards state to it. Here that is `runConsumer`, which writes the whole
nested command line for `consumer/`'s own build. A caller who names a cache
directory, a global cache directory or a program argument got all three, and a
caller who named `--prefix` got nothing: the nested build resolved its own.

**Symptom, read out of the sources rather than from a receipt.** The nested
command was `zig build run`, the helper set its working directory to
`consumer/`, and no `--prefix` was on the line.
`std.Build.determineAndApplyInstallPrefix` gives a build that was passed none
`<build root>/zig-out`, and that root is the working directory the same helper
set. So the nested build's own install prefix was `consumer/zig-out`, a build
artefact inside a source package, and the caller's `--prefix` stopped at the
outer graph. Nothing failed and nothing printed, because the nested command is
`zig build run` and its install step nothing depends on. The difference is
where an artefact would land, not an error.

**Fix.** Forward `--prefix` and `b.install_prefix` when the caller named one,
and make a relative value absolute against `b.graph.cache.cwd` first. The
helper compares `b.install_prefix` against `b.build_root.join("zig-out")` and
skips the pair when the two are equal, because that comparison is the build
system's own answer to "did the caller name a prefix?" rather than a second
opinion about it. Two tokens, not `--prefix=…`, for the reason the two cache
pairs are two tokens. `DESTDIR` is not forwarded: a nested build inherits the
environment the outer one ran with.

**Bound to.** Steps that re-enter `zig build` as a separate graph. Not bound
to this package's `consumer`, whose own `run` step depends on its run artifact
and not on its install step, and not bound to `std.Build`'s own dependency
forwarding, which carries a prefix to no child at all — `createChild` chooses
`<cache>/i/<hash>` for every one.

**The generalisation.** A nested build inherits its environment for free,
because a run step does not clear it, and inherits nothing else, because the
helper wrote the command line. Every value the outer graph resolved and the
caller named has to be handed on one at a time, and the value that goes
missing is the one that looks obvious, because the default is a real answer to
a question nobody asked. Forwarding the outer default unconditionally is worse
than forwarding nothing: the inner default was already right for the inner
build, and the outer one would have moved it out from under that.

## 34. An optional capture is a silent no-op, and only the nested command line says so

**Condition.** Any step that re-enters `zig build` as a separate graph and
forwards state to it. Note 32 covered the target query, note 33 the install
prefix, and this note records what the relays look like from outside.

**Observation, not a symptom.** Nothing failed. The parent ran
`zig build consumer` over nine cases at `Debug` — four routes, a default and an
explicit target, `static` and `dynamic`, linked and runtime-loaded, plus one
deliberate refusal with no provider named — and all nine passed. Eight exited 0
with every expected pattern in the consumer program's own output; the ninth
exited 1, which is what it exists to prove. Every nested `zig build run` line
carried `-j8`, `--summary all`, `--cache-dir <outer>/consumer`,
`--global-cache-dir` and `--prefix`. The four runtime-loaded cases carried
`--provider <path>` behind `--` while every `*_TEST_PROVIDER` variable was
absent from the child, so the provider arrived on the command line.

A second, separate run covers the modes this one does not. `zig build test
smoke install` was run over eight native cells, four optimize modes by `static`
and `dynamic`, and all eight passed with `28/28 steps succeeded; 23/23 tests
passed`. The four `static` cells install `lib/libutf8proc.a` and no shared
object. The four `dynamic` cells install `lib/libutf8proc.so`,
`lib/libutf8proc.so.3` and `lib/libutf8proc.so.3.3.0` and no archive.

**Why that is worth recording.** Each relay in notes 32, 33 and 54 sits on an
optional capture: `b.cache_root.path`, `b.graph.global_cache_root.path` and
`b.install_prefix` can each hold a default. A default is a real answer to a
question the caller never asked, and a relay written on top of one is a silent
no-op for every caller who passed nothing. Nothing downstream can tell the two
states apart except the printed nested command line, which is why the argument
for each relay had to be made from the source first and confirmed afterwards.

**Bound to.** One SDK, one host, one toolchain, native mode, `-Druntime=false`.
The 53-platform matrix and `check` have no result here, and neither has
`devenv`, `nix` or `-Druntime=true`. No cache-fallback guard has a receipt at
all.

**The generalisation.** A fix that depends on a value the caller may not have
set needs a place where its absence is visible. Printing the nested command is
cheaper than a flag, and it is the only record that distinguishes "the relay
fired" from "the relay had nothing to forward" after the fact.

## 35. The nested consumer build was told to `run` a target this host cannot execute

**Condition.** Any step that re-enters `zig build` as a separate graph and picks a
sub-command for it. Notes 32, 33 and 34 recorded what the nested command line
carries; none recorded which sub-command it was.

**Observation, not a symptom.** `runConsumer` wrote `run` unconditionally. On a
target this host cannot execute, the nested graph reaches its own
`b.addRunArtifact(exe)` and `Step.Run` refuses, so `zig build consumer -Dtarget=`
with a foreign target failed rather than delivered. A foreign consumer was not
install-only before this change; it was a failing step.

**Decision.** The sub-command is `run` when `hostCanExecute` — which asks
`std.zig.system.getExternalExecutor`, the question `Step.Run` asks, carrying this
graph's own executor switches — says this host can execute the resolved target,
and `install` when it cannot. `install` delivers the same executable through
`b.installArtifact` and is compile-and-deliver evidence, not a consumer
exchange. A GNU libc target under `-fqemu` with no `--libc-runtimes` also installs,
because `Step.Run` fails that case rather than skipping it.

**Supersedes.** The always-run claim in CHANGELOG entries 53, 54 and 55. Those
entries are dated history and stand as written; entry 59 records the change.

**Bound to.** Nothing here has been run. No receipt exists for the `install`
branch, for a foreign `consumer`, or for any `-f*` executor path. `PENDING-VERIFICATION`.
