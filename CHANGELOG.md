# CHANGELOG — fork-only divergences

Upstream's release history lives in its own repository, in `NEWS.md`, which this
package carries unmodified. This file records **only** what this fork changed
relative to utf8proc `2.12.0`
(`79cdd5ab40c79afa559f689ffc13b76812dee1ac`), written so a re-sync can replay it.
Numbers are stable identifiers; never renumber them.

Statuses below are the workspace's. **SOURCE-CONFIRMED** means the change was
read out of a file or measured by hashing bytes and involved no gate.
**PENDING-VERIFICATION** means the change has landed and no gate has looked at it
yet. **CONSTRAINT** means a binding design rule with no observation behind it.
**No entry here is a `VERIFIED` result** — the current state of every gate, green
or not, is the one table in [`README.zig.md`](README.zig.md#verification-status),
and it is not repeated here. That table's native, cross-target, full-matrix,
integrity and formatting rows all carry receipts. The filtered-fetch consumer is
named there by the location of its receipt rather than by a status, so no row in
these documents predicts a result nobody has observed yet.

**How to read a trailing status on an older entry.** It records the status *when
that entry was written*, not a claim about today. Most entries below therefore
still read `PENDING-VERIFICATION` from a point at which no gate had run; the
driver's gates have since observed most of those changes, and that table — not
these labels — is the current statement. Entries 33 through 36 are the ones this
distinction still bites hardest, and entry 37 records exactly how they were
resolved.

This package is local, uncommitted and unpublished: nothing in this file has been
published, and no publication is authorized in this expansion.

## 1. Added the Zig 0.16 package

`zig/root.zig`, `zig/api_exercise.zig`, `zig/translate.h`, `tests.zig`,
`smoke.zig`, `consumer/` and `.github/workflows/verify.yml` are new. Module:
`utf8proc`. Artifact: `libutf8proc.a` plus the installed `utf8proc.h`. The build
compiles upstream's `utf8proc.c` — which `#include`s `utf8proc_data.c`, so the
two must stay adjacent on disk — from this repository, with `-DUTF8PROC_STATIC`
on both the compile line and the translation line and `link_libc = true`.
Nothing is downloaded at build or test time, no upstream build system runs, and
`build.zig.zon` declares no dependencies. No upstream source file is touched.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 2. Kept upstream's `build.zig` and extended it, instead of relocating the tree

Upstream ships its own root-level `build.zig` and `build.zig.zon`, and Zig allows
one `build.zig` per package. The tree is **not** relocated into a
`libraries/` subdirectory and upstream is **not** duplicated; its build files are
extended in place. That is the contract's instruction, and it is also the smaller
diff: the alternative means moving a 2.4 MB generated table and 19 upstream test
files to new paths purely to avoid editing a build script.

Upstream's build behaviour is preserved verbatim: one source file, the
`-DUTF8PROC_STATIC` flag, `link_libc = true`, and the installed header. Added on
top: `test`, `smoke`, `exercise`, `check`, `upstream-test` and the consumer step.
There is **no options module for fixture paths**: `tests.zig` embeds its corpora
with `@embedFile`, so the build hands it nothing. Entry 19 recorded a
`utf8proc_paths` module that never existed; entry 31 supersedes it.

**Bound to** this package's layout. A library whose upstream build system claims
the `build.zig` name and whose layout is not fixed by a contract should re-open
this. See [`FORK-NOTES.md`](FORK-NOTES.md) § 1.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 3. Extended `build.zig.zon` in place

Upstream's `.name = .utf8proc` and `.version = "2.12.0"` are preserved, and so is
its `.fingerprint` field — with this manifest's own value in it. Added: the full
`.paths` closure, which is upstream's 7 entries (`build.zig`, `build.zig.zon`,
`utf8proc.h`, `utf8proc.c`, `utf8proc_data.c`, `README.md`, `LICENSE.md`) plus
`testdata/`, upstream's suite and tooling, the records and the consumer package.
Upstream's `.paths` is a strict subset of the new one. Entries 25 and 26 record
the two corrections made to this entry after it was written.

**Package identity:** `.utf8proc`, fingerprint `0xdcddf08d3f5ccfa0`. The consumer
package is `.utf8proc_consumer`, fingerprint `0x99023fc438b383d5`.

These three files — `build.zig`, `build.zig.zon` and `.gitignore` — are the only
upstream files this fork edits, and they are therefore **excluded** from
`UPSTREAM.sha256` with the reason written into that file's own header. Their
upstream-pristine digests, measured before the first edit, are in
[`NOTICE.md`](NOTICE.md).

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 4. Appended four ignore rules to upstream's `.gitignore`

Upstream's 44 lines are kept **verbatim**. Appended: `/.zig-cache/`, `/zig-out/`,
`/consumer/.zig-cache/`, `/consumer/zig-out/`. No upstream ignore pattern is
removed.

**No negation rule was added, and that was a decision rather than an oversight.**
Upstream's `*.new` pattern is unanchored, so it would ignore any fork file ending
in `.new`. Rather than add a negation, no fork file is named that way — in
particular `UPSTREAM.sha256` is written directly and `UPSTREAM.sha256.new` is
never created.

Upstream's `/data/*.txt` is root-anchored, so it **cannot** reach `testdata/`;
checked against the file's patterns, which is a reading of the file and not a
`git` run. `SOURCE-CONFIRMED`.

## 5. Committed the five Unicode conformance fixtures

New: `testdata/NormalizationTest.txt`, `testdata/GraphemeBreakTest.txt`,
`testdata/DerivedCoreProperties.txt`, `testdata/Lowercase.txt`,
`testdata/Uppercase.txt`, fetched from unicode.org on 2026-10-03 and stored byte
for byte.

**Upstream ships none of them.** `data/Makefile:59-63` deletes all four in its
`clean:` target and `data/download.sh` fetches them, so upstream's `check` is not
self-contained — it needs a network round trip. Committing them is what makes this
package's verification self-contained and what keeps the no-build-time-fetch rule
satisfied. Measured digests are in [`UPSTREAM.sha256`](UPSTREAM.sha256).

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 6. Derived `Lowercase.txt` and `Uppercase.txt` with upstream's own rule

These two are **not** Unicode publications. They are sections of
`DerivedCoreProperties.txt` extracted by the one-line regexes at
`data/Makefile:53-57`. The rule, the section line numbers, and a self-check on
the result are recorded in [`UPSTREAM.md`](UPSTREAM.md#lowercasetxt-and-uppercasetxt-are-derived-not-fetched--and-how).

Julia is not installed on this host, so the anchored substring match was
reimplemented with the same semantics — leftmost match, lazy `.*?`,
dot-matches-newline — over the same bytes, and the rule is recorded so a reader
can re-derive both files independently. Both files end in a bare
`# Total code points:` line with **no count and no trailing newline**, which is
upstream's `print(match(...))` output verbatim. **A parser must tolerate it, and
these files must never be tidied** — upstream's unanchored `*.new` pattern and any
newline-normalising tool are live hazards here.

Self-check, because a hash alone would not catch a wrong section out of the 20
`# Derived Property:` sections: `Lowercase.txt` holds 711 ranges covering exactly
2 740 code points against the section's declared 2 740; `Uppercase.txt` holds 678
ranges covering exactly 2 026 against a declared 2 026. The workflow's
`derived case fixtures still match their sections` step reproduces both files
from `DerivedCoreProperties.txt` and compares them byte for byte. A Zig test that
re-derived the same sections and compared them against the committed fixtures was
removed — it compared a fixture with a copy of itself — and entry 31 records the
removal.

**Bound to** Unicode 18.0.0. A UCD bump moves the section line numbers, the range
counts and the totals; all three are recorded in `UPSTREAM.md` and must move with
them.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 7. Added `testdata/Unicode-License-V3.txt` and shipped both Unicode texts

New: the current Unicode License V3 text, 1 995 bytes, measured and hashed.

Upstream's `LICENSE.md` §3 quotes the **1991-2007 three-condition** Unicode
grant and cites the retired `http://www.unicode.org/copyright.html` — as does
`README.upstream.md:27`. Unicode's **current** published licence for its Data Files is
Unicode License V3, whose single grant offers the notice in all copies **or** in
associated documentation, with no separate modification condition.

Both are shipped, unmodified, and neither is edited to match the other. Grant 3
governs the compiled `utf8proc_data.c`; Unicode License V3 governs the fetched
corpora. Reconciling them would mean choosing between two pieces of someone
else's legal text. Why the pinned file rather than the `terms_of_use.html` link
every fixture header carries: that URL is a navigation page whose content
changes, and a licence text that changes under a fetched package is not a licence
record.

`SOURCE-CONFIRMED`.

## 8. Recorded the dangling `utf8proc_data.c` cross-reference; patched nothing

`utf8proc.c:25-33` says *"Please notice the copyright statement in the file
`utf8proc_data.c`."* `utf8proc_data.c` line 1 is
`static const utf8proc_uint16_t utf8proc_sequences[] = {`. **There is no such
statement in that file**; the Unicode terms for the data table exist only in
`LICENSE.md` §3.

Recorded in [`NOTICE.md`](NOTICE.md) as a per-file exception, and
`NOTICE.md` explicitly declines to repeat upstream's claim. Nothing was added to
`utf8proc_data.c`, because its bytes are proved identical to upstream's committed
content twice over, an upstream source edit needs an observed failure to justify
it, and no owner authorisation covers this.

**Bound to** the byte-identity claim in `UPSTREAM.md`. If a notice is ever added,
the file becomes a fork edit and the identity claim must be restated honestly.

`SOURCE-CONFIRMED`.

## 9. Built and ran nine of upstream's eleven C test programs

Upstream's `Makefile:204` makes eleven `test/*` programs prerequisites of `check`
and executes ten of them (`Makefile:206-215`); `printproperty` is compiled and
never run. This fork builds and runs nine: `normtest`, `graphemetest`, `valid`,
`iterate`, `case`, `iscase`, `custom`, `misc`, `maxdecomposition`.

Two are not built, each for a recorded reason:

* **`test/charwidth.c`** — its oracle is the **host's** `wcwidth` through
  `<wchar.h>`, which needs `_XOPEN_SOURCE 700`, is not uniformly available across
  the six cross targets, and whose mismatches upstream's own source calls
  informational while warning of "lots of these errors for out-of-date system
  unicode tables" (`test/charwidth.c:73-86`). Building it would measure the host
  libc's Unicode vintage, not utf8proc. Its oracle-free invariants and its four
  pinned codepoints (U+00AD, U+E000, U+00A1, U+00A2) are ported to the Zig tests.
* **`test/printproperty.c`** — a property dumper upstream compiles and never
  executes.

Also not built or run: `bench/` (`Makefile:205` recurses into it, but
`bench/icu.c` links ICU4C and `bench/unistring.c` links libunistring, neither of
which is in scope or licensed here), `test_install_uninstall` (an installation
script, a prerequisite of upstream's `check` that its run lines never execute),
and `test/fuzzer.c` / `test/fuzz_main.c` (the OSS-Fuzz harness, which upstream's
`check` does not build either).

**Bound to** the six cross targets, and to upstream's current `check` recipe.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 10. Supplied `UNICODE_VERSION` to `test/misc.c` from upstream's own `data/Makefile`

`Makefile:181` shells out to perl to scrape `UNICODE_VERSION` out of
`data/Makefile` and passes it to `test/misc.c`, whose use site at
`test/misc.c:96-99` asserts `utf8proc_unicode_version()` agrees. **That use site
is inside `#ifdef UNICODE_VERSION`, so a missing define does not fail the
program** — it removes the assertion silently, and the program still prints
`Misc tests SUCCEEDED.` and exits 0.

The build scrapes the same value out of the **shipped** `data/Makefile` at build
time and passes `-DUNICODE_VERSION` explicitly. Not hand-copied and not
`julia`-generated: reading a committed upstream file means the data version
cannot drift into a hand-maintained constant anywhere in this fork.

For the record, `Makefile:184` passes the same define to
`test/maxdecomposition.c`, which never references the macro — a grep over `test/`
finds `UNICODE_VERSION` only in `misc.c`. That flag is a no-op upstream carries.

**Bound to** `test/misc.c`'s current source, and to `data/Makefile` remaining a
committed upstream file rather than a generated one.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 11. Pointed the native fixture arguments at `testdata/`

Upstream runs `test/normtest data/NormalizationTest.txt`,
`test/graphemetest data/GraphemeBreakTest.txt` and
`test/iscase data/Lowercase.txt data/Uppercase.txt` (`Makefile:206-213`). The
same four files ship here under `testdata/`, committed. `test/iscase.c:58`
requires exactly two arguments in the order Lowercase, Uppercase.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 12. Published the raw C route as `pub const c`, unchanged

`pub const c` is the translated, unmodified `utf8proc.h` as installed. Nothing
upstream's header documents was dropped, shortened or restated; readers are
pointed at `zig-out/include/utf8proc.h` for the authoritative text.

`utf8proc_property_t` is reached through it with its C bit field layout intact,
which is what lets a C consumer read `combining_class`, `bidi_class`,
`decomp_type`, `boundclass`, `ignorable`, `control_boundary`,
`indic_conjunct_break` and the five sequence indices.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 13. Kept `Property` opaque and mirrored no bit field

`utf8proc_property_t` uses C bit fields (`utf8proc.h:296-319`) and Zig 0.16's
`translate-c` demotes any record with a bit field to an opaque type. The layout is
implementation-defined, so a hand-mirrored Zig struct would be a plausible-looking
lie that breaks under a different compiler. `Property` is therefore `*const`
opaque, and the facade re-derives no property value.

Only the properties upstream also exports through a dedicated function are
reachable from Zig: `category` / `categoryString`, `charWidth`,
`charWidthAmbiguous`. The rest are unreachable **regardless of the translator**,
because upstream exports no accessor for them; that is recorded as upstream's API
surface and not as a gap to be filled.

**Bound to** Zig 0.16's translator behaviour and to upstream 2.12.0's API surface.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 14. Refused `UTF8PROC_NULLTERM` at every slice entry point

Every facade entry point takes an explicit slice. Upstream's rule is that with
`NULLTERM` the length argument is ignored (`utf8proc.c:545`), which is unsafe on
an ordinary slice — it may legitimately contain `0x00` bytes. Setting
`Options.nullterm` returns `error.InvalidOptions` rather than silently discarding
the length the caller passed.

`UTF8PROC_NULLTERM` still reaches Zig through the raw route, for a caller who
genuinely has a C string.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 15. Owned `utf8proc_reencode`'s spare byte with a runtime check

Upstream requires "one spare byte of free space at the end" and checks **nothing**:
it is a bare comment at `utf8proc.c:750-751`, repeated in the header as a warning
that the program *might crash* (`utf8proc.h:636-639`). A buffer of exactly
`4 * length` bytes is one byte short, and that is what `length` elements of `i32`
occupy — so every stack array of `i32` is short by one.

`reencode` computes `4 * length + 1` with an ordinary comparison **before writing
anything** and returns `error.WorkspaceTooSmall`. The check is an ordinary
comparison in every mode, **never** a `std.debug.assert`, which would compile away
in ReleaseFast and stop being a guarantee exactly where it matters.

**Bound to** upstream's stated bound, which a future upstream release could change.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 16. Kept the error set closed at five and named the second source (superseded by entry 29)

`utf8proc_errmsg` maps exactly five negative codes and gives every other value one
generic sentence (`utf8proc.c:107-122`), so the set is closed by upstream's own
design. No sixth error was invented for the facade's own rejection: entry 14's
`nullterm` refusal is folded into the existing `error.InvalidOptions` and
`README.zig.md` names both sources rather than leaving a reader to infer one.

`error.OutOfMemory` is reachable only through `map` and `mapCustom`; the
caller-buffer paths allocate nothing and cannot produce it.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 17. Wrapped `utf8proc_free` as `OwnedString.deinit` and stated the boundary

`map` and `mapCustom` allocate with the C library's `malloc` and release through
`utf8proc_free` (`utf8proc.c:789, 811, 849`). `OwnedString.deinit` calls that
function and nothing else — never `std.mem.free`, never an allocator, never a raw
`free` reached any other way — and the handle must be released exactly once.

`utf8proc_free` is new in 2.12.0 and is safer precisely because the application
may be linked to a different C library than the one utf8proc was built against.

**Zig's test allocator cannot supply a leak oracle across this boundary**, so a
test that leaks an `OwnedString` is not reported by `std.testing`. That is a
property of the allocator boundary and is recorded in `OwnedString`'s doc
comment, in `README.zig.md` and in [`FORK-NOTES.md`](FORK-NOTES.md) § 10 rather
than papered over. The bulk of the corpus tests use the allocation-free
`decompose` + `reencode` path, where the oracle does apply.

**Bound to** the allocator boundary. A facade-internal copy would have avoided the
problem and was rejected: copying is what the caller-buffer path already avoids.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 18. Owned the stateful grapheme-break ordering requirement

`utf8proc_grapheme_break_stateful` implements UAX #29 extended grapheme clusters,
including GB10/GB12/GB13 — emoji ZWJ sequences and regional-indicator pairing —
which cannot be decided from a pair of codepoints alone. Upstream requires the
call to be made **in order on every candidate break in the string**
(`utf8proc.h:649-658`), and a null state pointer silently degrades to the Unicode
8 rule set.

`GraphemeIterator` owns the state so the ordering requirement cannot be
forgotten, and `firstGraphemeBreak` walks every adjacent pair through one
iterator. The legacy stateless `graphemeBreak` is kept and documented as
Unicode 8.0.0 semantics that omits GB10/12/13, with the disagreement stated
rather than hidden — it is exactly the difference the regional-indicator example
in `README.zig.md` demonstrates. Entry 34 corrects where that disagreement
actually falls.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 19. Read the corpora at run time through `utf8proc_paths` (never implemented; superseded by entry 31)

This entry recorded a decision that never matched the source. It is kept
numbered so a re-sync reading it can see what was believed, and when.

**What it claimed.** `build.zig` creates a `utf8proc_paths` options module whose
single declaration is `pub const testdata_dir: []const u8`; `tests.zig` opens the
corpora by joined file name at run time under an 8 MiB per-file read limit; and
the API exercise is the exception, embedding them instead.

**What is true.** There is no `utf8proc_paths` module in this package, no
`testdata_dir`, and no run-time file read anywhere in it. `tests.zig` embeds all
four corpora in full with `@embedFile`, and `zig/api_exercise.zig` embeds nothing.
Entry 31 states the corrected decision.

**What survives here and is not superseded.** Corpus consumption is whole-file
with **no sampling**: all 20 171 normalization rows at 20 conformance checks
each — 403 420 — all 853 grapheme rows checked through both the stateful walk
and the `CHARBOUND` marker form, and every `Lowercase.txt` / `Uppercase.txt`
range with the gaps between ranges walked too.

**Bound to** the requirement that `testdata` be present in `.paths`, which now
holds for a stronger reason: `@embedFile` needs those bytes at build time.

`SOURCE-CONFIRMED` (as corrected by entry 31).

## 20. Ported upstream's regression behaviour; dropped only the `wcwidth` oracle

Kept as behaviour, not as version pinning: upstream issues 102, 128, 144, 288, 317
and 356; julia#37680; the five explicit GB9c Indic conjunct-break cases new in
Unicode 18; and `test/maxdecomposition.c`'s whole-space invariant that
`utf8proc_decompose_char` never returns more than four codepoints.

Dropped: `test/charwidth.c`'s system `wcwidth` comparison only, per entry 9.

**Not added deliberately:** no test that pins a version string, checks
`@hasDecl` or export presence, compares a forwarding accessor with the raw member
it forwards to, checks copying, or asserts that a call does not throw.
`version()` and `unicodeVersion()` are asserted only to be distinct NUL-terminated
strings, which is a behavioural claim; version identity belongs to the provenance
and licence records instead.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 21. Recorded system-library mode as NOT APPLICABLE, with the reason

There is no `b.systemIntegrationOption` in this build. Recorded as **not
applicable**, not as a gate that passed.

Debian does ship a compiled `libutf8proc`, so the W14 rule's precondition is
genuinely met here. The reason for omitting it is recorded rather than left as a
silent absence: `utf8proc_free` **did not exist before 2.12.0**, so bundling this
tree's 2.12.0 header against an installed 2.5.0–2.11.3 library would compile and
then fail to link; and 2.12.0 changed two declared types without changing the ABI
(`options` from `enum` to `unsigned int`, `decompose_char`'s `last_boundclass`
from `int *` to `utf8proc_int32_t *`), so any future system mode must verify
header/ABI identity **by version, not by width**.

**Bound to** this wave. A future wave may add a system mode with its own gate;
deciding to omit it is not the same as satisfying the rule, and nothing here claims
it does.

`CONSTRAINT`.

## 22. Kept upstream's CI, hashed and shipped to no one

`.github/workflows/{zig,make,cmake,ci-fuzz}.yml`, `.github/dependabot.yml` and
`appveyor.yml` are upstream's CI. They are kept byte for byte for provenance and
audit, are **not** retargeted at this fork's infrastructure, are **not**
referenced by `build.zig`, are **not** executed here, and are **not** in `.paths`.

They **are** hashed in `UPSTREAM.sha256`, so an auditor can confirm they arrived
unmodified. Hashed is not the same as shipped, and the record says so.

Upstream's `zig.yml` pins Zig 0.16.0 and asserts `zig-out/lib/libutf8proc.a`, but
it runs only `ubuntu-latest` and `macOS-latest`. That is upstream's evidence on
upstream's runners and it is **not** borrowed as evidence for any of this package's
six cross targets.

`SOURCE-CONFIRMED`.

## 23. Recorded the licence split per file instead of summarising the tree

New: `UPSTREAM.md`, `UPSTREAM.sha256`, `NOTICE.md`, `README.zig.md`,
`FORK-NOTES.md` and this file.

`NOTICE.md` is a per-file inventory, because a single label for this tree is
wrong: `LICENSE.md` carries **two** MIT grants with **two different
copyrights**, a third Unicode grant that names one file, `utf8proc_data.c`
carries no notice of its own, upstream's pointer to that notice is dangling, 29
upstream files under `test/`, `data/` and `bench/` carry no per-file header, the
six `testdata/` files are a third Unicode term, and every fork-authored file
asserts **no licence at all** at the time this entry was written — see the note
below for what changed on 2026-10-04.

**No line in this package claims one licence for the whole tree.** When this
entry was written the fork-authored files' status was *unassigned* pending the
owner's decision — the same open item the other fifteen forks carried. **The
owner answered it on 2026-10-04: those files are MIT**, on a direct
authorization recorded in `FORK-LICENSE.md`. That changed the licence over the
fork's files and nothing else: the two MIT grants, the Unicode data grant and
Unicode License V3 for the fixtures all stand as entry 23 describes them. See
entries 40 and 25 of [`FORK-NOTES.md`](FORK-NOTES.md).

`SOURCE-CONFIRMED`.

## 24. Recorded the measured integrity anchors

`UPSTREAM.sha256` holds 56 records computed from raw bytes on 2026-10-03, with no
shell hashing command and no `git` command.

Two independent anchors back them, and this is what makes "these are upstream's
bytes at the pin" a measurement rather than an assertion:

* All **53 of 53** upstream records match the driver's per-file SHA-256 map from
  `git archive --format=tar 79cdd5ab…` (`exit 0`, archive 2 775 040 bytes,
  `fcf2ba77881774208b17f57a0cbc8e6a70d07dcb51ec31bbf35c32ce58331e40`), with
  matching byte sizes and every blob `"kind": "regular"`. 0 mismatches. The 3
  blobs absent from `UPSTREAM.sha256` are exactly the 3 files entry 3 edits; the 6
  records absent from the pin tree are exactly the 6 `testdata/` files, which
  upstream does not commit.
* The **3 of 3** compiled files match the blob ids the pinned commit itself
  carries, read out of this clone with `git ls-tree -r 79cdd5ab…` and computed
  here independently as `sha1("blob " + len + "\0" + bytes)` over the file's
  contents.

`SOURCE-CONFIRMED`. **No `sha256sum -c` run is claimed** — the digests are
measured, the check is the driver's.

## 25. Put the native core back into `.paths`, and added the gate that checks it

`build.zig.zon`'s `.paths` listed 30 entries and none of the three files the
library is made of: `utf8proc.c`, `utf8proc.h`, `utf8proc_data.c`. They are now
listed, which restores upstream's own requirement — upstream's manifest at the
pinned tag already lists exactly those three — rather than adding a new one, and
upstream's 7-entry `.paths` is a strict subset of this one again.

Nothing in this repository could see the gap, because `consumer/` depends on
this package by relative path and a path dependency reads the working tree, not
`.paths`. Every local gate would have passed with an empty library; a *fetched*
dependent would have got a package with no C source, no header and no data
table. The `consumer` job of `.github/workflows/verify.yml` now walks the
repository and compares it against `.paths` in both directions, with the seven CI
files named as the complete permitted residue.

`PENDING-VERIFICATION`. See `FORK-NOTES.md` note 17.

## 26. Corrected what upstream's own manifest carries

This fork's records said upstream's `build.zig.zon` had a 7-entry `.paths` and
**no** `.fingerprint`, and that the fork "added" `.fingerprint`. Both were wrong.
Upstream ships `.fingerprint = 0xdcddf08dbb8954c4` alongside its 7-entry
`.paths`. The fork's value, `0xdcddf08d3f5ccfa0`, is a different number because
this manifest is not upstream's manifest, and neither value may be copied into
the other. Corrected in `build.zig.zon`, `UPSTREAM.md`, `NOTICE.md` and
`FORK-NOTES.md` note 1, with no licence consequence: the grant over upstream's
manifest text is unchanged either way.

`SOURCE-CONFIRMED` — read out of `git show 79cdd5ab…:build.zig.zon`.

## 27. Corrected the C-surface gate's oracle, and dropped its version pin

The installed-C-surface gate called
`utf8proc_decompose_char(0xFB01, out, 16, UTF8PROC_DECOMPOSE, NULL)` and
asserted the result was `U+0066 U+0069`. `utf8proc.c:513-518` requires
`UTF8PROC_COMPAT` for a compatibility mapping, so that call returns U+FB01
unchanged: the gate asserted NFKD through a call that asked for NFD. It now
asserts both halves — U+FB01 unchanged under `UTF8PROC_DECOMPOSE`, and
`U+0066 U+0069` under `UTF8PROC_DECOMPOSE | UTF8PROC_COMPAT`.

The same gate compared `utf8proc_unicode_version()` against the literal
`"18.0.0"`, which tests the pin rather than the library. That claim belongs to
`test/misc.c`'s `-DUNICODE_VERSION` cross-check against upstream's own
`data/Makefile`, which `zig build upstream-test` runs in the same job. Both
version strings are still printed; neither is asserted. In their place the gate
asserts the four codepoints upstream's own `test/charwidth.c:65-71` pins with no
`wcwidth` oracle: U+00AD and U+E000 one cell wide and East Asian Ambiguous,
U+00A1 Ambiguous, U+00A2 not. The unused `<string.h>` include went with the
`strcmp`.

`PENDING-VERIFICATION`. See `FORK-NOTES.md` note 18.

## 28. Replaced a vacuous provenance gate with one that reads the pinned tree

The verification table offered `git archive --format=tar 79cdd5ab… | sha256sum`
equals `fcf2ba77…` as the check that this tree still equals the pinned commit.
Re-running `git archive` over the pin re-derives the pin's own bytes and says
nothing about this working tree. The row is replaced, and the `integrity` job
now does the real thing: for each of the 53 paths in the pinned tree it compares
`git cat-file blob 79cdd5ab…:<path>`'s SHA-256 against `UPSTREAM.sha256`'s
record and the file on disk against the same digest, requires every pinned path
to have a record and every record outside the pin to be a `testdata/` fixture,
and requires the upstream files this fork edits in place to be exactly
`.gitignore`, `build.zig` and `build.zig.zon`.

**`HEAD` is never compared with the pin.** This repository is a downstream of
upstream's tag and carries its own commits on top of it; `HEAD` happens to be
`79cdd5ab…` today only because the fork's work is uncommitted, and such a check
would break on the first commit. The job checks out with `fetch-depth: 0`,
fails with a message when the pinned commit is absent, and is the only step
anywhere in this package that reads git history — `build.zig` never invokes
`git`, so a fetched source package still builds without any of it.

Two smaller corrections ride with it: `DerivedCoreProperties.txt` carries 20
`# Derived Property:` headers, not 23, and the licence sweep of `test/`, `data/`
and `bench/` finds 29 files with no per-file notice, not 28. Both were read out
of the files again while this entry was written.

`PENDING-VERIFICATION`. See `FORK-NOTES.md` note 19.

## 29. Widened the owned error set from five to six, and named every source

`Error` now holds six members: upstream's five codes — `OutOfMemory`, `Overflow`,
`InvalidUtf8`, `NotAssigned`, `InvalidOptions` — and one refusal this package
raises itself, `InputOutputOverlap`. Upstream's set is still closed at five;
nothing here adds a sixth upstream code. `reencode` answers with seven, because
`WorkspaceTooSmall` is reached only through `ReencodeError`.

`InvalidOptions` has three sources, all named: upstream's
`UTF8PROC_ERROR_INVALIDOPTS`, this package refusing `Options.nullterm`, and this
package refusing `Options.charbound` with a `null` `last_boundclass` — the third
because CHARBOUND output depends on the previous codepoint's bound class
(`utf8proc.h:533-537`) and, with no state to carry, upstream answers from the
stateless rule instead (`utf8proc.c:334-335`). **That answer is not a fault**:
nothing is dereferenced, and a probe of the native call returned two output
units. It is a segmentation decided without history, which is wrong wherever
UAX #29 needs history; entry 32 records the correction to the crash wording
this entry originally carried. `Overflow` has two: upstream's own, and this
package refusing a slice whose length does not fit the C signed length type
before it becomes a length argument.

`decompose` and `decomposeCustom` refuse `error.InputOutputOverlap` **before**
any write, so `dst` is untouched when it fires — the opposite of
`DecomposeResult.needs_more`, where upstream promises no partial output and
`dst` is undefined. Overlap is refused there and *not* banned everywhere:
`reencode` takes one buffer for input and output and `normalizeUtf32` works in
place, both upstream's own documented shapes.

Entries 7 and 16 recorded the earlier two-source, five-member version of this
decision; this entry supersedes their counts and keeps their reasoning.

**Observed since.** The driver's native receipts at `Debug`, `ReleaseSafe`,
`ReleaseFast` and `ReleaseSmall` each ran 22/22 tests, and those tests fire the
`nullterm` refusal, the CHARBOUND-without-state refusal and
`InputOutputOverlap`. The slice-length check that answers `error.Overflow` has no
test that fires it and stays documented-only.

## 30. Made the API exercise a real program (its fixture and install claims are superseded by entry 31)

`zig/api_exercise.zig` was added as a test artifact, where it was incidental: a
root whose test blocks are incidental can be built, linked and reported as a
pass without one public facade function ever being called. It is now an
executable with its own `main` that calls every public facade function
unconditionally — **compiled** by the default step, run at the end of
`zig build test`, selectable alone as `zig build exercise`, and compiled for all
six targets by `check`.

Two claims this entry used to make are wrong, and are corrected here. It is
**not installed**: `b.getInstallStep().dependOn(&exercise.step)` puts the compile
step in the install graph, and no `installArtifact` installs the binary, so
`zig-out/bin/` is never written and the installed prefix holds only `LICENSE.md`,
`include/utf8proc.h` and `lib/libutf8proc.a`. And it does **not** embed the
corpora: it embeds nothing at all, and `build.zig` passes it no fixture module
and no data. `tests.zig` is the root that embeds them, in full.

No upstream byte, fixture or test program is involved in either case.

**Observed.** `run exe utf8proc-api-exercise success` and `all typed operations
exercised` in all four native receipts.

## 31. Corrected how the corpora reach the tests, and dropped the fixture-copy test

Fixture access is **compile-time embedding, in one root**. `tests.zig`'s
accessor is `@embedFile("testdata/" ++ name)`, called with
`NormalizationTest.txt`, `GraphemeBreakTest.txt`, `Lowercase.txt` and
`Uppercase.txt`; all four are embedded in full. `zig/api_exercise.zig` embeds
nothing: it is a separate executable whose every expected answer is a literal
written in that file, with no fixture data and no re-export of the facade.

**No `utf8proc_paths` options module exists, and no run-time file read exists.**
Entries 2, 19 and 30, `FORK-NOTES.md` note 3 and `UPSTREAM.md` deviation 17 all
described a different mechanism; this entry supersedes them. The trade is now
stated honestly: about 3.1 MB of conformance text is compiled into the test
object and `check` compiles that object once per target; in exchange the test
binary carries its own oracle and runs anywhere, including on a foreign executor
where no source path into the build directory exists. `testdata/` is one entry in
`.paths` because `@embedFile` needs the bytes at build time.

**The derived-fixture copy test is gone.** `tests.zig` no longer embeds
`DerivedCoreProperties.txt` and no longer re-derives the `Lowercase` and
`Uppercase` sections to compare them, range for range, against the committed
fixtures. That test could report only that two committed files still agree —
which is what `UPSTREAM.sha256` and the workflow's `derived case fixtures still
match their sections` step already own — and it exercised no library behaviour.
The extraction provenance is unchanged and still recorded: upstream's rule at
`data/Makefile:53-57`, the section line numbers, 711 ranges / 2 740 code points
and 678 ranges / 2 026 code points against the declared totals, and the SHA-256
of all six fixtures, in `UPSTREAM.md` and `UPSTREAM.sha256`. Entry 6's stale "out
of 23" section count is corrected to 20 here too.

**Observed.** `zig build test smoke consumer` passes at `Debug`,
`ReleaseSafe`, `ReleaseFast` and `ReleaseSmall`, 22/22 tests in each, the
grapheme test printing `grapheme rows: 853, checked through CHARBOUND: 853,
surrogate-only: 0`.

`SOURCE-CONFIRMED` for the mechanism, observed for the runs named above.

## 32. Withdrew the crash claim about a null `last_boundclass`

`Options.charbound` with a `null` `last_boundclass` had been documented as
something upstream reads through, turning "a documented flag combination" into
a crash. **That was wrong.** `grapheme_break_extended` tests its state pointer at
`utf8proc.c:293` and, for `NULL`, takes the branch at `utf8proc.c:334-335` that
answers `grapheme_break_simple(0, boundclass)`. Nothing is dereferenced. A probe
of the native call returned two output units — the `-1` sentinel and the
codepoint — through the `boundary` branch at `utf8proc.c:519-527`.

The refusal stands, on better ground: the stateless answer decides GB9c, GB11
and GB12/GB13 with no history at all, so a caller passing `null` receives a
plausible wrong segmentation with nothing to indicate it. Entry 29 carried the
crash wording and is corrected here; `README.zig.md` and `FORK-NOTES.md` note 20
state the same correction.

**Observed.** The test `CHARBOUND requires a live per-character state` fires the
refusal, and passes in all four native receipts.

`SOURCE-CONFIRMED`.

## 33. Corrected the Hangul example: composition is `normalizeUtf32`, not `decomposeChar`

The Hangul example asserted

```zig
const composed = try utf8proc.decomposeChar(0x1100, &out, .{ .compose = true }, null);
try testing.expectEqual(@as(i32, 0xAC00), out[0]);
```

`utf8proc_decompose_char` decomposes **exactly the one codepoint it is handed**
(`utf8proc.c:445`). U+1100 is outside the Hangul syllable range checked at
`utf8proc.c:454-466` — the algorithmic rule at that branch runs in the other
direction — carries no `decomp_seqindex` entry, and falls past the CHARBOUND arm
to `if (bufsize >= 1) *dst = uc; return 1;` at `utf8proc.c:529-530`. The call
writes `0x1100` straight back out and returns `1`, so the `0xAC00` assertion was
false. `compose` on that entry point selects which decompositions are eligible;
it does not make the call a composer, because composition reads the *previous*
codepoint. L+V composition lives in `utf8proc_normalize_utf32`
(`utf8proc.c:650-745`) — the same path `tests.zig:503-506` already took.

The example now keeps the correct `U+AC00` → `U+1100 U+1161` decomposition, then
composes an initialised `[_]i32{ 0x1100, 0x1161 }` through `normalizeUtf32` and
asserts `U+AC00`, and adds `{ 0x1100, 0x1161, 0x11A8 }` → `U+AC01` so the
trailing-jamo step is covered too. `README.zig.md` now says in the same place
that `decomposeChar` is a one-codepoint entry point and that composition is
`normalizeUtf32`, or `decompose` followed by `normalizeUtf32`.

**Bound to** `utf8proc_decompose_char`'s one-codepoint contract, which is
upstream's and not this fork's.

`SOURCE-CONFIRMED`; the example now **compiles, runs and passes** —
`local://foundation-matrix-utf8proc-all-readme-examples-r3.log`, exit 0, 6/6.

## 34. Corrected the regional-indicator example: the legacy pair test is wrong on the *second* pair

The example asserted `testing.expect(utf8proc.graphemeBreak(0x1F1E6, 0x1F1E8))`.
`utf8proc_grapheme_break` is `utf8proc_grapheme_break_stateful(c1, c2, NULL)`
(`utf8proc.c:351-354`), and the NULL-state path lands in `grapheme_break_simple`
(`utf8proc.c:334-335`), whose GB12/GB13 arm returns **false** for RI+RI
(`utf8proc.c:286-287`). The call was therefore not wrong on the first pair — it is
right there — and wrong on the **second** pair of a run, where GB12/GB13 require a
break. The example had put the failure in the wrong place, and the wrong answer
would have been the one a reader copies.

The block now asserts `!graphemeBreak(0x1F1E6, 0x1F1E8)` **and**
`!graphemeBreak(0x1F1E7, 0x1F1E8)`, keeps the two `firstGraphemeBreak` results
that were already right (`null` for two indicators, `2` for three), and adds a
`GraphemeIterator` walk that does not break between the first two and does break
before the third. Every expected value is UAX #29's, not this library's output.
These are the same relationships `tests.zig:614-615` and `tests.zig:621-623`
already assert, so the example and the permanent tests now agree.

Entry 18's pointer at "the two regional-indicator examples" is corrected to the
one example that exists.

**Bound to** the stateless entry point's Unicode 8 rule set. The stateful
iterator is unaffected, and no upstream byte changed.

`SOURCE-CONFIRMED`; the example now **compiles, runs and passes** — the same
`-all-readme-examples-r3.log` receipt.

## 35. Fixed the NFC example's `reencode` workspace

`toNfc` allocated `4 * length + 1` bytes and handed them to `reencode` without
ever writing the normalized codepoints into them. `utf8proc_reencode` reads its
buffer as UTF-32 on entry and writes UTF-8 back into the same bytes
(`utf8proc.c:749-771`), so the example was reencoding whatever the allocator had
left there. The example now copies `std.mem.sliceAsBytes(cps[0..length])` into
the workspace before the call — the same shape `tests.zig:531`, `smoke.zig:62`
and `consumer/src/main.zig:59` already use.

**Bound to** the upstream in-place workspace shape; the size, `4 * length + 1`,
was already right and is unchanged.

`SOURCE-CONFIRMED`; the example now **compiles, runs and passes** — the same
`-all-readme-examples-r3.log` receipt. Entry 37 corrects a fourth defect in the
same block.

## 36. Scoped `UTF8PROC_ERROR_INVALIDOPTS`, kept `stable` honest, and labelled the examples

**Where upstream's own invalid-options answer reaches.** Upstream checks both
illegal combinations at the top of `utf8proc_decompose_custom`
(`utf8proc.c:547-551`) — `compose` with `decompose`, and `stripmark` with neither —
so they surface through `decompose`, `decomposeCustom`, `map` and `mapCustom`,
and **not** through `decomposeChar`, which has no such check and strips the mark
at `utf8proc.c:503-506`. `README.zig.md`'s error table and its NULLTERM section
named upstream's code as a source of `InvalidOptions` without saying which entry
points reach it, which reads as though every call refused the same option word.
Both now say which ones do, and the `Options` note records the `stripmark`
asymmetry directly.

**`Options.stable` does nothing at this pin, and nothing here says otherwise.**
`UTF8PROC_STABLE` is declared at `utf8proc.h:154`, and its only five occurrences
in `utf8proc.c` are upstream's own `utf8proc_NFD`, `utf8proc_NFC`, `utf8proc_NFKD`,
`utf8proc_NFKC` and `utf8proc_NFKC_Casefold` passing it to `utf8proc_map`
(`utf8proc.c:820, 826, 832, 838, 844`). No code branches on the bit, so the bit is
accepted, forwarded and inert. No per-entry-point honouring is claimed for it in
`README.zig.md`, in `zig/root.zig`'s flag table, or here.

**What the examples section is.** The six blocks are complete `test`
declarations — the first together with its helper function — intended for a test
root carrying `std`, `std.testing` and `utf8proc`; the two `zig` blocks in the
Importing section are labelled fragments. **No build step of this package
compiles this document**: `check` compiles the facade module and the `tests.zig`,
`zig/api_exercise.zig` and `smoke.zig` roots, plus the upstream C programs, and
reads no Markdown, and the `check` row of the gate table says the examples are
outside it.

**Superseded in part by entry 37.** This entry originally concluded that no
example carried an execution result *at all*. That was true of this package's
gates and false of the situation: the examples were later lifted verbatim into a
scratch package outside this repository and run there, and they pass. The
distinction is preserved rather than dropped — no step of `zig build` reaches
this file, and the run that observes it lives in another package's receipt.

**Bound to** this pin's `utf8proc.c`. A future release that branches on
`UTF8PROC_STABLE`, or that moves the invalid-options check, makes both statements
false and re-sync must correct them.

`SOURCE-CONFIRMED`. The source claims in this entry are read out of the files;
the two example blocks it scopes **compile, run and pass**
(`local://foundation-matrix-utf8proc-all-readme-examples-r3.log`).

## 37. Ran the examples, and corrected three more that reading had approved

Entries 33 through 36 corrected three example blocks by reading `utf8proc.c`.
That left the six blocks `PENDING-VERIFICATION`, because nothing in this package
compiles a Markdown file. The driver then lifted all six verbatim into a scratch
package depending on this one by path and ran them. Four attempts, each with a
receipt:

| Attempt | Exit | Outcome |
|---|---|---|
| `local://foundation-matrix-utf8proc-all-readme-examples.log` | 1 | a harness defect — an absolute path in the scratch `build.zig.zon`. Nothing in the document |
| `…-all-readme-examples-r1.log` | 1 | `expected type '?mem.Alignment', found 'comptime_int'` |
| `…-all-readme-examples-r2.log` | 1 | `5 pass, 1 fail (6 total)`: `expected 223, found 7838` |
| `…-all-readme-examples-r3.log` | 0 | `6/6 steps, 6/6 tests` |

**The three corrections.**

1. **`allocator.alignedAlloc(u8, 4, …)` → `allocator.alignedAlloc(u8, .@"4", …)`.**
   Zig 0.16's second parameter is `?mem.Alignment`, not an integer. This is a Zig
   API fact rather than a Unicode one, which is exactly why reading the Unicode
   sources did not catch it.
2. **NFC's expected result `U+00C9` → `U+00E9`.** NFC of `e` followed by U+0301 is
   the lowercase `é`; the block's own title and its `toNfc` comment already said
   so. **No failing receipt ever reported this one**: r1 died at compile time
   before any test ran, and r2 reported only the sharp-s failure. It is recorded
   because r3's 6/6 confirms the current text, not because a run caught it.
3. **`toUpper(0x00DF)` expected `U+00DF` → `U+1E9E`.** Upstream's issue #130
   regression at `test/case.c:57-63` requires
   `utf8proc_toupper(0x00df) == 0x1e9e` and
   `utf8proc_tolower(0x00df) == 0x00df`. The `toLower` half of the block was
   already right; the `toUpper` half was not.

`README.zig.md` now tabulates all four attempts under the examples, so the three
earlier failures are history rather than a claim that the current blocks were
once wrong in a way nobody checked. The section still says no build step of
*this package* compiles it — that is still true, and the run happened elsewhere.

**Bound to** the Zig 0.16 allocator signature and to this pin's case data. Note
21's bound is unchanged and is now backed by a counter-example: checking prose by
reading is not the same as checking it by running.

`SOURCE-CONFIRMED`, `OBSERVED` in `local://foundation-matrix-utf8proc-all-readme-examples-r3.log`.

## 38. Chose the translation front end per target, and restated one compiler typedef

`zig translate-c` preprocesses and parses with Aro, and Aro cannot read fifteen of
the fifty-three targets' C libraries. Fifteen `build.status: fail` rows in the
first full matrix run (`local://foundation-matrix-utf8proc-cross-original-summary.json`,
run `20261003-175929-14815-27659`, exit 1, `counts: {pass: 20, fail: 15,
build_only: 18}`) were all failures of that read, none of them a defect in
`utf8proc.c`, `utf8proc.h`, the facade or this package's source. They were nine
NetBSD targets, five OpenBSD targets and `x86-windows`, and the causes are three
different ones rather than one bug: NetBSD's `_Pragma("GCC visibility pop")`
inside `__END_DECLS`, OpenBSD's two conflicting `size_t` typedefs on ILP32, and
OpenBSD MIPS's `endian.h` refusing to define `BYTE_ORDER` without `__MIPSEL__` or
`__MIPSEB__` — with `mips64-openbsd` and `mips64el-openbsd` named separately,
because they are separate libc directories and separate `std.Target.Cpu.Arch`
members.

**The deviation is in `build.zig`'s `translationRoute` and `zig/translate.h`, and
is build-only.** For the fifteen, the build runs the target's own C preprocessor
first — `zig cc -E -dD`, the same pinned compiler that compiles `utf8proc.c` —
and Aro parses what it wrote; every other target keeps Aro reading
`zig/translate.h` as it stands. `zig/translate.h` also restates the compiler's own
`__int128_t` and `__uint128_t` under `#if defined(__SIZEOF_INT128__)`, because
`generic-netbsd/arm/cdefs.h:62-63` keeps `__ALIGNBYTES` as
`(sizeof(__int128_t) - 1)` and `zig translate-c` emits no implicit typedef to
stand in for it — the observed failure being `use of undeclared identifier
'__int128_t'` at `utf8proc-translate.zig:1191`.

**Nothing else moved.** Both routes read this repository's own `utf8proc.h`, with
this repository's root as the include path and `UTF8PROC_STATIC` defined from the
one `core_macros` list the C compile line uses. No predefine is invented — the
guard is the compiler's own capability macro. No shim, no fake ABI, no
platform-conditional deletion of a target, and no test weakened. The archive, its
ABI and utf8proc's own declarations are identical on both routes; the two
compiler typedefs are not utf8proc's and nothing about its API depends on them.

**Observed.** `local://foundation-matrix-utf8proc-cpp-focus-aarch64-netbsd.log`,
`…-cpp-focus-mips64el-openbsd.log` and `…-cpp-focus-x86-windows.log` each exit 0.
The six-target `check` exits 0. The corrected full matrix run
`20261003-195739-62898-24523`
(`local://foundation-matrix-utf8proc-cross-corrected-summary.json`) exits 0 with
all 53 `build.status: pass`, 20 `run.status: pass` and 33
`run.status: unavailable` / `build_only`. **The fifteen became build-only rows,
not passes**: each is a target with no runner on this host, and a successful
foreign compile is not a test result.

**Bound to** Zig 0.16.0's Aro front end and to the 53-platform matrix. A future
`translate-c` that preprocesses these headers itself would make the extra front
end unnecessary; the per-target conditions, not the target list, are what a
re-sync must re-check.

`SOURCE-CONFIRMED`, `OBSERVED`.

## 39. Rewrote `README.md` and preserved upstream's bytes as `README.upstream.md` — 2026-10-04

`README.md` was upstream's README, byte for byte, and this wave made it the fork's
README in the canonical order: current native-source deviations, current
native-build deviations with a dated history link, the build/run/test matrix,
then consumption. Upstream's file did not move into the fork README and was not
edited: it is now carried whole at `README.upstream.md`, 143 lines and 5839 bytes,
at the same SHA-256 `105b8cf2…` it had under the old name.

Every citation of upstream's prose in `NOTICE.md`, `UPSTREAM.md` and
`FORK-NOTES.md` was repointed at `README.upstream.md:<line>`, because those
quotations are of upstream's text and a citation into the fork's file would
become a claim about the wrong bytes. `UPSTREAM.sha256`'s README record moved to
`README.upstream.md` with the **same digest**, so the integrity anchor is a
rename and not a re-measurement, and the count stays 56 records.

**This makes `README.md` a fourth upstream file edited in place**, so it joins
`build.zig`, `build.zig.zon` and `.gitignore` in the record's exclusion list,
with its upstream-pristine digest recorded in `UPSTREAM.md` and `NOTICE.md`. It
is documentation-only: nothing in `build.zig` reads either file.

**Two requirements this wave placed on the delivery role. Both are met.** `.paths`
now carries `README.upstream.md`, `FORK-LICENSE.md` and the five packaging files,
and `FORK-LICENSE.md` earns its entry because `build.zig` installs it — a fetched
copy without it fails the install step. `runtime` is listed too, and is the one
entry whose content arrived with entry 50 rather than with this wave's
documentation: a `.paths` entry with no file behind it is itself a closure
failure, which is why the runtime route could not be listed before it existed.
`.github/workflows/verify.yml`'s `integrity` step now names all four edited-in-place
files, settles them before consulting `UPSTREAM.sha256`, and exempts
`README.upstream.md` beside the fixtures — entry 49 records why that was three
defects and not one. Both statements are readings of files; the driver runs the
checks.

`SOURCE-CONFIRMED`, `CONSTRAINT`.

## 40. Granted MIT over this fork's own files, on the owner's authorization — 2026-10-04

`FORK-LICENSE.md` records the grant, its exact scope and its exclusions, and
`NOTICE.md`'s section that said the fork's files assert no licence now states the
MIT grant, the SPDX identifier `MIT`, the collective copyright line
`the utf8proc Zig SDK fork authors`, and the three things the grant does **not**
reach: any upstream byte, `utf8proc_data.c` under its own Unicode data grant, and
the `testdata/` fixtures under Unicode License V3.

The basis is a direct owner authorization recorded on 2026-10-04 in the
foundation contract-migration wave, choosing this project's primary upstream term
so that a reader who accepts utf8proc's terms is not asked to accept a second
regime for its packaging. `LICENSE.md` is untouched: three upstream grants and
two Unicode texts remain three grants and two texts, and the per-file inventory
keeps all four exceptions.

No SPDX identifier, copyright holder or grant was inferred from a neighbouring
project, and no individual identity was invented — the holder is collective
precisely because no name was supplied.

`SOURCE-CONFIRMED`, `CONSTRAINT`.

## 41. Added a standalone Nix and devenv delivery — 2026-10-04 (its lock statement is superseded by entry 51)

Five new files: `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml` and
`.envrc`.

`package.nix` is a source-only derivation over this tree's **own** `build.zig`:
no fixed-output fetch, no build-time download, no C flags restated, and no host
path, store path or username anywhere in it. It adds nothing to the installed
closure: the build graph writes the library, the header, `LICENSE.md`,
`lib/pkgconfig/libutf8proc.pc`, the records under `share/licenses/utf8proc/` and
the fixtures under `share/utf8proc/testdata/`, and a derivation that reproduced
any of them would be a second writer for one output path. `flake.nix` exposes
`packages.<system>.static` and `.shared` from that one file, with `default` being
`static` because that is this
SDK's existing linkage policy, and a pinned nixpkgs revision. `devenv.nix` is the
canonical development shell, carries the Zig-version assertion, and sets no cache
or state variable of its own; it does **not** list the SDK package, because
entering a shell must not build the library.

**Both variants pass `-Dlinkage=<linkage>`, and `default` keeps the SDK's own
static policy** — upstream's. The derivation adds no C flags, one optimize
selection and `-Dcpu=baseline`, and both Zig caches point inside the Nix-provided
`TMPDIR` because the source tree is read-only in the sandbox. Entry 45 records the
interface normalisation this paragraph was rewritten for.

**No lock file was written.** `flake.lock` and `devenv.lock` are the driver's;
both consumers name their input revisions explicitly instead, and no hash was
invented to fill a lock this role is not allowed to write.

**That paragraph is true of the moment it was written and has been overtaken in
one half.** No lock existed then. The driver has since written `flake.lock` into
this tree on 2026-10-04 and `build.zig.zon` lists it beside the five delivery
files, so the pair `flake.lock`/`devenv.lock` no longer describes one state.
`devenv.lock` is still absent and `devenv.yaml:19-22` still says why. Entry 51
records the correction; this entry is kept numbered rather than rewritten.

**Nothing in any of the five files has been evaluated.** This role runs no `nix`,
no `devenv`, no build and no gate, so every statement about them is
`SOURCE-CONFIRMED` from `build.zig`, `utf8proc.h`, `libutf8proc.pc.in` and
`Makefile` in this repository, or `CONSTRAINT` from the delivery contract.

`SOURCE-CONFIRMED`, `CONSTRAINT`, `PENDING-VERIFICATION`.

## 42. Required variant-correct, relocatable pkg-config metadata — 2026-10-04

**Requirement on the build graph, which now owns the file.** `lib/pkgconfig/libutf8proc.pc`
is generated by `build.zig` from upstream's own `libutf8proc.pc.in`; `package.nix`
does not write it. Two properties were required, and both follow from upstream's
own material rather than from taste:

* **`Cflags` is variant-dependent.** Both upstream templates —
  `libutf8proc.pc.in` and `libutf8proc.pc.cmakein` — put `-DUTF8PROC_EXPORTS` in
  `Cflags`. Read `utf8proc.h:123-139` and that macro is a **build-side** switch:
  with `UTF8PROC_EXPORTS` defined, a Windows declaration becomes
  `__declspec(dllexport)` (`:130`) instead of `__declspec(dllimport)` (`:132`). It
  is correct while compiling the library; a consumer that defines it asks for its
  own translation unit to export those symbols. A consumer needs
  `-DUTF8PROC_STATIC` for the static delivery — `utf8proc.h:123-126` then leaves
  `UTF8PROC_DLLEXPORT` empty — and no macro at all for the shared one, where the
  empty define leaves `dllimport`, which is right. Upstream's own build systems
  make the same split: `CMakeLists.txt:34` marks `UTF8PROC_STATIC` `PUBLIC` on the
  static target and `:40` marks `UTF8PROC_EXPORTS` `PRIVATE` on the shared one.
* **`prefix` is `${pcfiledir}/../..`**, not an absolute path, so a staged, packed
  or moved tree still describes itself. An absolute prefix describes where the
  file was built, which is not the same question.

**Upstream's templates are not edited.** Both remain upstream's bytes and stay in
`UPSTREAM.sha256`; the difference lives only in what the build graph writes into
`$out`. An installed C consumer that compiled through upstream's own `.pc` on
Windows is unaffected and still gets upstream's line; this entry records the
difference rather than claiming upstream is wrong.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 43. Recorded what utf8proc's ABI requires of the runtime route — 2026-10-04

`-Druntime=true` selects runtime dispatch, orthogonally to `-Dlinkage`, and the
route itself belongs to the API role. What this role records is what utf8proc's
own declarations force on it, because three properties of the library are not
the loader's to guess: the library exports exactly **one** data symbol,
`utf8proc_utf8class[256]` (`utf8proc.h:453`), while all six tables in
`utf8proc_data.c` are `static const` and unexported, so an exported table is
reached by address in the loaded image and `utf8proc_get_property`'s pointers are
per-image; `utf8proc_map` allocates with the allocating image's `malloc` and
`utf8proc_free` calls that image's `free` (`utf8proc.c:789-811`, `:848-849`), so a
provider's buffer must be released by that provider and host memory must never be
freed through a provider; and symbol presence is not ABI identity, because 2.12.0
changed `options` from an `enum` to `unsigned int` and `last_boundclass` from
`int *` to `utf8proc_int32_t *` without a version string that would catch it.

**No Windows CRT interchangeability is claimed, anywhere.** A host and a loaded
DLL may resolve different C runtimes and therefore different heaps; the crossing
is safe only when both images really do resolve one allocator, this package
verifies and guarantees nothing about that, and establishing it is the loader
owner's job on that platform.

`SOURCE-CONFIRMED`, `CONSTRAINT`.

## 44. Re-anchored the integrity record after the README relocation — 2026-10-04

`UPSTREAM.sha256`'s header now names four excluded upstream files rather than
three and says why `README.md` is one of them. The record's README line moved to
`README.upstream.md` with the digest unchanged.

**Two receipts that were observed are not restated as if they still describe
this tree.** `sha256sum -c UPSTREAM.sha256` exiting 0 with 56 `OK` lines and the
pinned-blob comparison reporting differences exactly `.gitignore`, `build.zig`,
`build.zig.zon` were both observed on 2026-10-03, before the relocation. What
re-running them **should** report — 56 `OK` lines again, and `README.md` as a
fourth difference with the other ten thousand protected files unchanged — is
recorded in `UPSTREAM.md` and `README.zig.md` as an expectation, explicitly not
as an observation. No gate has been run since.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 45. Normalised the packaging interface — 2026-10-04

**One derivation, variants named only by the entry points.** `package.nix` is an
uncurried `{ lib, stdenv, zig, src, linkage }` function returning a single
derivation; `linkage` is `static` by default, upstream's own policy. `flake.nix`
calls it twice and publishes `packages.<system>.static` and `.shared`, with
`default` staying `static`, and nothing else — no prefixed aliases. `devenv.nix`
publishes the same two as lazy `outputs.static` / `outputs.shared`, so entering
the shell still builds nothing and `devenv build outputs.static` is the packaging
route.

**Build invocation.** One optimize selection, `-Dcpu=baseline`,
`-Dlinkage=${linkage}`, `--prefix "$out"`, and `-j"${NIX_BUILD_CORES:-1}"`; both
Zig caches exported under the Nix-provided `TMPDIR`, because the source tree is
read-only in the sandbox. `dontConfigure` and `dontBuild` keep the Zig setup
hook's own phases from building the package a second time; `dontInstall` is
deliberately **not** set, because `stdenv` decides whether the install phase runs
from `doInstall` and setting it would skip the real `installPhase` and produce an
empty output silently.

**No `builtins.getEnv`, no `builtins.currentSystem`, no host path** in any of the
five files, and no cross-compilation guard: the derivation builds natively and a
remote builder stays valid. `.envrc` no longer sources a storage policy or
overrides one; it names `XDG_RUNTIME_DIR` only when the caller has already named
an approved scratch root, because devenv otherwise defaults its runtime sockets
to `/tmp` even when `TMPDIR` is set. `TMPDIR`, `XDG_RUNTIME_DIR`, `DEVENV_HOME`
and both Zig caches are the caller's and are left untouched.

**Source filters** in both entry points drop VCS metadata, `.zig-cache`,
`zig-cache`, `zig-out`, `zig-pkg`, `.devenv`, `.devenv.flake.nix`,
`devenv.local.nix`, `.direnv` and `result*`, and keep every source, fixture, test
and licence file.

**Shell scripts** are real exec commands under namespaced names (`sdk-build`,
`sdk-test`, `sdk-smoke`, `sdk-exercise`, `sdk-check`, `sdk-upstream-test`,
`sdk-consumer`, `sdk-integrity`, `sdk-format`). The two scripts that shelled out
to `nix build` are gone: `outputs` is the packaging route.

`SOURCE-CONFIRMED`, `CONSTRAINT`, `PENDING-VERIFICATION`.

## 46. Native delivery: real `-Dlinkage`, the installed closure and the relocatable `.pc` — 2026-10-04

Recorded from the delivery role's source. **No gate has observed any of it**, and
nothing here is a result.

* **`-Dlinkage=static|dynamic`**, default `static`, upstream's own policy. The
  shared delivery carries upstream's ABI version `3.3.0` (`Makefile:25-27`, which
  `utf8proc.h:66-68` distinguishes from the API version `2.12.0`) and is installed
  as `libutf8proc.so.3.3.0` with soname `libutf8proc.so.3` and a `libutf8proc.so`
  link on ELF, `libutf8proc.3.3.0.dylib` with install name `libutf8proc.3.dylib` on
  Darwin, and `utf8proc.dll` with its import library on Windows. The shared
  compile line carries `-DUTF8PROC_EXPORTS`, so the DLL exports its functions and
  its `utf8proc_utf8class` data symbol; the static compile line keeps
  `-DUTF8PROC_STATIC`.
* **The installed closure is written entirely by the build graph**:
  `include/utf8proc.h`, the library, `LICENSE.md` at the root,
  `lib/pkgconfig/libutf8proc.pc`, `share/licenses/utf8proc/{LICENSE.md,
  FORK-LICENSE.md,NOTICE.md,UPSTREAM.md,CHANGELOG.md,Unicode-License-V3.txt}` and
  `share/utf8proc/testdata/` with the five Unicode corpora. `package.nix`'s
  duplicate `.pc`, licence-tree and fixture-tree writers are deleted: one writer
  per output path, and the graph is the writer.
* **The `.pc` is relocatable**, `prefix=${pcfiledir}/../..`, so a staged, packed or
  moved tree describes itself, and its `Cflags` is variant-dependent as entry 42
  requires.
* **`-Druntime=true` was, at the time of this entry, declared and refused** with a
  precise message while the API role's `runtime/graph.zig` did not exist. Entry 50
  records the cutover that replaced that refusal with the real route. The refusal
  itself was the honest state while it stood: an `@import` of a missing file is a
  compile error in every configuration, so a branch written before that file
  existed could not build at all.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 47. Corrected the export-macro split — 2026-10-04

Earlier records in this file and in `FORK-NOTES.md` describe `zig/translate.h`
defining `UTF8PROC_STATIC` itself, from a single `core_macros` list. **That is no
longer the shape of the build**, and the corrected statement is now the one in
`UPSTREAM.md` item 13, `README.zig.md` and the translation-route section:

* `build.zig` is the only authority for the export macros. `libraryMacros(linkage)`
  goes on the C core's own compile line; `consumerMacros(linkage)` goes on the
  translation line and on every dependent's module. Static defines
  `UTF8PROC_STATIC` in all three places; dynamic defines `UTF8PROC_EXPORTS` on the
  core's line alone and nothing on a consumer's.
* `zig/translate.h` now defines neither, and says so in its own header comment: a
  header that set its own export macro would describe a linkage the build did not
  choose.

The reason the earlier record said otherwise — that a build-script `-D` could not
reach the translation step in that Zig version — is retained as the history of the
deviation, not as its current description. Entries and notes that predate this one
are read with the dating convention in this file's header.

`SOURCE-CONFIRMED`.

## 48. Closed the package closure and applied the identifier — 2026-10-04

**`.paths` carries every file this wave added**: `README.upstream.md`,
`FORK-LICENSE.md`, `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml` and
`.envrc`, so a fetched package keeps upstream's README, the fork's grant and its
standalone delivery. `FORK-LICENSE.md` is in that list because `build.zig`
installs it into `share/licenses/utf8proc/` — a fetched copy without it fails the
install step, which is a stronger reason than tidiness. `runtime/` is
deliberately **not** listed while no `runtime/graph.zig` exists: a `.paths` entry
with no file behind it is itself a closure failure, and it is added when that
file lands.

**`.gitignore` gained six root-anchored entries** for this wave's tooling —
`/result`, `/result-*`, `/.devenv/`, `/.devenv.flake.nix`, `/.devenv.flakes/` and
`/devenv.local.nix` — alongside the four Zig entries. No upstream line was removed
or widened. `flake.lock` and `devenv.lock` are deliberately **not** ignored: they
are real inputs belonging to the driver, and ignoring a lock is the wrong way to
keep one out of a commit.

**`cross-test.profile.sh` now records MIT** with the SPDX identifier and the
2026-10-04 authorization, naming its earlier "none asserted" line as the state
before the identifier was supplied rather than as a different view of it.

**SPDX headers, and where they deliberately are not.** `MIT` was added to the
wholly fork-authored files: `zig/translate.h`, `consumer/build.zig`,
`consumer/build.zig.zon`, `cross-test.profile.sh` and
`.github/workflows/verify.yml`. It was **not** added to `build.zig`,
`build.zig.zon` or `.gitignore`, because those three carry upstream's bytes and
`FORK-LICENSE.md` scopes the grant to their fork-authored portions; an SPDX line
there would label upstream's grant as this fork's. That absence is a decision, and
it is recorded rather than left to look like an oversight.

The one item this entry left open — the workflow's `integrity` step — is closed
in entry 49 below. Everything above is a reading of files; no gate has observed any
of it.

`SOURCE-CONFIRMED`, `CONSTRAINT`, `PENDING-VERIFICATION`.

## 49. Corrected the integrity step for a record with four exclusions — 2026-10-04

Entry 19 turned `README.md` into a fourth file this fork edits in place, and
`UPSTREAM.sha256` says so in its own header: those four paths carry no digest,
because a digest for a file the fork edits would be false within hours. The
workflow's `integrity` step did not know that, and entry 19 broke it **three
independent ways**, any one of which would have failed the job:

1. `edited_in_place` still named three files, so `README.md` fell through to the
   divergence rule and was reported as differing from the pinned blob.
2. The step required a digest for every path in the pinned tree, so the four
   deliberately excluded paths failed as "upstream's tree carries it and
   `UPSTREAM.sha256` records nothing for it".
3. The remainder rule exempted only `testdata/`, so `README.upstream.md` — the file
   that exists precisely to carry upstream's README after its own path was
   replaced — failed as a recorded path the pinned tree does not contain.

**The correction, in that one step.** `edited_in_place` names all four with the
reason inline; those four are settled **before** the record is consulted, so no
digest is required of them and the requirement becomes the opposite one — that
their bytes *do* differ from the pinned blob, with a declared-but-unmodified file
still failing. `carried_outside_the_pin = {"README.upstream.md"}` exempts that file
from the remainder rule beside the fixtures, and the failure message now names
what is acceptable. The final count reads the declared set rather than the
divergences it happens to produce, so it still reports what it reported before. A
hardcoded upstream file count in the blob-id step and two "three"s in the prose
above the steps are gone, because that number moved when the exclusions did.

**Why this is recorded rather than just fixed.** The lesson is general and the
boundaries are named: a provenance gate with several rules over one record will
fail in several independent ways when the record changes shape, so every rule in
the gate — not only the one whose literal looks stale — has to be re-read against
the new shape. `UPSTREAM.sha256`'s header was the source of truth all along; the
step had four separate assumptions about it and only one of them was named.

**Unobserved.** The step has never run: it needs a checkout of this repository and
the upstream history. A reading of a file is not a pass, and nothing here is
recorded as one.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 50. Cut over the runtime route and the dynamic refusal — 2026-10-04

**The runtime refusal is gone and the route is real.** `-Druntime=true` is wired
against the API role's `runtime/graph.zig`, and the earlier "declared and refused"
state in entry 46 is history. What the option now does: under it the facade's `c`
import becomes the generated dispatch that `createModule` builds from **this**
`TranslateC` step's output — so the dispatch re-exports the translated header's
types and constants rather than restating them, and `c.utf8proc_map` in the facade
and `c_native.utf8proc_map` in the dispatch are one type — and **no native library
is linked into the module at all**, neither the one this tree builds nor an
installed one. The library is still built and installed, so a caller may name a
provider this tree did not build. `-Dlinkage` still decides which artifact is
delivered, so the two options are orthogonal in both directions. A linked build is
unchanged in every respect, `c` is the translated header itself, `load` there
stops the program with a message rather than quietly succeeding, and
`runtime_loaded` is the comptime switch that lets one consumer source support both.

**`runtime` is now in `.paths`,** with `runtime/graph.zig` the build half and
`runtime/library.zig` this SDK's descriptor. The loader core
(`runtime/loader.zig`, `runtime/generate.zig`, `runtime/sync.c`, `runtime/sync.h`)
belongs to the driver and is not authored here; `library.zig` names the
synchronization symbols `runtime/sync.h` provides under
`RT_SYNC_PREFIX=utf8proc_rt`, and `graph.zig` defines that macro, so a build where
the two spellings disagree fails to link rather than hiding behind a runtime path.

**A dynamic request a target cannot carry is refused, never substituted.** Where
`std.Target.DynamicLinker.kind` is `.none`, `-Dlinkage=dynamic` stops the build with
the triple, the OS tag and the reason rather than delivering a static archive in
its place. A substitution the caller did not ask for is a build that answered a
different question and reported success, and every gate run afterwards would
measure that archive. The static default is untouched: `wasm32-wasi` with no
linkage flag is an ordinary static archive.

**Provenance change in this pass.** `package.nix` no longer has a `/tmp` fallback
for either Zig cache. It fails with a message when `TMPDIR` is unset and resolves
`TMPDIR` through `readlink -f` before deriving the two cache paths from it, so the
caches are keyed by one canonical path rather than by whichever symlink the build
arrived through.

**Unobserved.** The route, the refusal and the packaging change are all
`SOURCE-CONFIRMED` from source. The driver's own gates — a real loaded smoke run,
the state edge tests, and the shared-artifact matrix where the refusal is itself
observable — are the records that would establish any of it, and none has run here.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 51. Scoped the closure claim to the shipped lock, and recorded two API reach corrections — 2026-10-04

**The complete-package claim was stale, and is now scoped to what it can
support.** `UPSTREAM.md` said this wave adds seven tree files, that `.paths` now
carries all of them, and that the workflow's two-directional comparison is
"complete in both directions". That was true when it was written and it stopped
being true as the wave went on: `.paths` also carries `zig`, `runtime`,
`tests.zig`, `smoke.zig`, the three named `consumer/` files and
`cross-test.profile.sh`, and the seven-file CI carve-out is still the only
residue in the tree. That is a reading of `build.zig.zon`,
`.github/workflows/verify.yml` and the tree — not a gate result. The check is the
driver's and no run is claimed here.

**One listed path is neither upstream's nor this fork's.** `flake.lock` is written
into this tree and listed in `.paths` beside the five delivery files. The driver
wrote it on 2026-10-04, after those files existed. Its `locked.rev` is the
revision `flake.nix:15` declares; the `narHash` is what the lock adds over that
declaration. `NOTICE.md` inventories it as the driver's and `FORK-LICENSE.md`
excludes its terms, so a fetched copy resolves that revision instead of choosing
one. **No `devenv.lock` exists and none is listed** — `devenv.yaml:19-22` records
that the lock is the driver's to write — and a `.paths` entry with no file behind
it is itself a closure failure. Entry 41's "no lock file was written" describes
the state before this one.

**Two completeness claims, and only one of them is anchored.** The pin record and
`UPSTREAM.sha256` are an inventory of *immutable upstream bytes*, and that is the
one measured twice. The closure claim is a statement about `build.zig.zon`
against this tree, and it covers three kinds of byte no upstream digest reaches:
the four upstream files this fork edits in place, this fork's own material, and
the driver's metadata — `flake.lock` beside the shared loader core under
`runtime/` (`loader.zig`, `generate.zig`, `sync.c`, `sync.h`), which the driver
authors and distributes across SDKs rather than this package. "Complete" is not a
claim that every byte in the package is pinned by something.

**`UTF8PROC_STRIPCC` is a third option bit whose reach is narrower than the header
suggests.** `UPSTREAM.md`'s section on those bits was a section on two; it is now
a section on three, and the re-sync step that re-checks them was updated with it.
The bit occurs exactly three times in the core — `utf8proc.c:619`, `utf8proc.c:627`
and `utf8proc.c:641` — and all three are inside `utf8proc_normalize_utf32`
(`utf8proc.c:617-747`). `reencode` honours it only by calling that function first
(`utf8proc.c:752`), and `map` and `map_custom` only by calling `reencode`
(`utf8proc.c:804`). `utf8proc_decompose_char` reads `UTF8PROC_STRIPMARK` at
`utf8proc.c:503-506` and never reads `STRIPCC`, and `utf8proc.h:523-532` does not
offer the bit there while `utf8proc.h:601` and `utf8proc.h:624` do offer it for
`utf8proc_normalize_utf32` and `utf8proc_reencode`. One behaviour is worth
restating with it: with no NLF option set, LF, CR, NEL, VT, FF and HT all become
U+0020 (`utf8proc.c:626-633`, `utf8proc.c:641-643`) rather than being removed.

**The custom callback runs synchronously on the calling thread, once per code
point, on every pass upstream makes.** The guard is `if (custom_func != NULL)` at
`utf8proc.c:571` and the call is `uc = custom_func(uc, custom_data)` at
`utf8proc.c:572`, between the decode and the `utf8proc_decompose_char` that
consumes the answer — so it runs inside the native call, with nothing deferred past
the return. `utf8proc_map_custom` runs it twice over the same input, once to size
the buffer (`utf8proc.c:787`) and once to fill it (`utf8proc.c:791`), so it must be
a pure function of `(codepoint, data)`; an answer that differs between the two
passes makes upstream free the buffer and return `UTF8PROC_ERROR_OVERFLOW`
(`utf8proc.c:800-803`) rather than write past the allocation. `custom == null`
means no custom mapping at all, and `data` is forwarded untouched and may itself
be `null`, so a callback has to tolerate a null context rather than assume one.

**What this entry does not claim.** The two API corrections above were made in
`README.zig.md` and `zig/root.zig` by the API role; this entry records them rather
than re-deriving them, and every line it cites was read out of `utf8proc.c` and
`utf8proc.h` in this tree. The parent's run `bg761` exited 0 after those two
landed; the command, mode and receipt behind that identifier are the parent's to
record, and this role ran nothing and inspected no output. No verification status
moves here on the strength of a run this role did not perform, and no gate in
`README.zig.md`'s table has observed any of it.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 52. Every canonical devenv entry locates this SDK, and `sdk-build` installs off the checkout — 2026-10-04

**The scripts ran in whatever directory the caller was in.** devenv
materialises each `scripts` entry as a generated program that inherits the
caller's working directory, and the canonical caller for this SDK is
`devenv shell -- <name>` from a devenv *project* directory that is not this
checkout. That directory has no `build.zig`, no `consumer/` and no
`UPSTREAM.sha256`, so the bodies that name a relative path had nothing to find.
All nine bodies now begin with `cd` to this SDK's own directory, resolved from
`builtins.toString ./.` inside `devenv.nix`: `./.` in an expression is relative
to the file that contains it, so it is this SDK and not the shell's directory.
The nine names are unchanged, and so is what each one runs after that line.

**`builtins.toString`, not `${./.}`.** Both evaluate to the same string; the
difference is what Nix does with it afterwards. A path literal interpolated into
the generated program carries a store context, so the whole tree is copied into
`/nix/store` and the script would `cd` into a read-only copy and build there.
The plain string carries no context and names the working tree. It is quoted
once, with `lib.escapeShellArg`.

**`sdk-build` now names an external prefix.** The default step is the install
step, so this is the one script that writes a delivery: `include/utf8proc.h`,
the library, the records and fixtures under `share/`, and
`lib/pkgconfig/libutf8proc.pc`. It passes
`--prefix "$ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out"` — beneath the cache directory
the caller exported, the same convention `package.nix` uses under the Nix
`TMPDIR` — and, with no cache directory exported, it says which variable is
missing and exits non-zero. It does not fall back to `zig-out/` inside this
tree, and this file still sets no cache variable and names no host path. The
other eight install nothing: `build.zig` deliberately keeps the smoke program
and the API exercise out of the installed prefix, and `consumer`'s `run` step
installs nothing, so none of them gained a flag that would change nothing. Every
`zig build` invocation carries the workspace's `-j8`.

**Superseded in part by entry 56.** This entry recorded that `devenv.nix` sets
no cache variable and that an unset one is refused outright. Both halves are now
false. A missing `ZIG_LOCAL_CACHE_DIR` or `ZIG_GLOBAL_CACHE_DIR` is filled from
`XDG_CACHE_HOME` first and `TMPDIR` second, and only a caller who named neither
of those either is refused. The `--prefix "$ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out"`
this entry introduced is unchanged, and so is the refusal to fall back to
`zig-out/` inside this tree.

**What this entry does not claim.** This role ran no `devenv`, no `nix`, no
build and no gate. The two failures the change addresses are the driver's
receipts from run `nix-acceptance-20261004T175328Z`, where
`utf8proc-devenv-consumer.log` ends `error: no build.zig file found, in the
current directory or any parent directories` and
`utf8proc-devenv-integrity.log` ends `sha256sum: UPSTREAM.sha256: No such file
or directory`, both with the scratch project directory as the working
directory. Those are observations of the old file. No gate has observed the new
one, and no row in `README.zig.md`'s tables moves on this entry.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 53. The consumer step forwards the target *query*, not the resolved target — 2026-10-04

**`zig build consumer` told the nested build a triple it could not have meant.**
`runConsumer` serialized `target.result.zigTriple`, which spells the *resolved*
target, so an unqualified run passed
`-Dtarget=x86_64-linux.6.12...6.12-gnu.2.42` down to `consumer/`'s own
`zig build`. The nested graph therefore read an explicitly named target,
resolved it against the ABI defaults rather than against this machine, and
compiled a consumer needing `/lib64/ld-linux-x86-64.so.2`; its `run` then
refused, correctly, because the host's real linker is
`/nix/store/lm3pknxi0ipypy3lxh1wmm8wvvavdwrn-glibc-2.42-84/lib/ld-linux-x86-64.so.2`
(`lib/std/Build/Step/Run.zig:1337-1348`). The SDK is not what failed: the
selection was.

**The change.** `runConsumer` now serializes `target.query` — `zigTriple` plus
`serializeCpuAlloc` — which is the pair `std.Build` itself uses when a
`ResolvedTarget` is handed to a dependency (`lib/std/Build.zig:454-459`), and
which writes the literal `native` for a selection that named nothing
(`lib/std/Target/Query.zig:421-423`). `-Dcpu` is forwarded alongside `-Dtarget`
for the first time, because a triple never carries the model or its feature set
(`lib/std/Target/Query.zig:488-528`). Both halves of the nested build now
resolve the host the way this graph did, through `b.graph.host`
(`lib/std/Build.zig:2704-2708`), so the consumer compiles against the linker
this machine actually has. An explicitly named cross target is still forwarded
explicitly, and still cross.

**What did not change.** `-Doptimize`, `-Dlinkage`, `-Druntime`, the executor
switches, `--libc-runtimes`, `--cache-dir <outer>/consumer` and the caller's own
arguments behind `--` are untouched, and the step still always requests a run
rather than falling back to an install. `consumer/build.zig` needed no change:
its own `standardTargetOptions` already registers the four standard target
options the pair is read back through.

**What this entry does not claim.** This role ran no `devenv`, no `nix`, no
build and no gate. The failure quoted above is
`utf8proc-devenv-consumer.log` from run `nix-acceptance-20261004T193710Z`, an
observation of the old file. No gate has observed the new one, and no row in
`README.md`'s or `README.zig.md`'s tables moves on this entry.
`skip_foreign_checks` is not set anywhere on this path, `patchRun` is not used
to ignore a host mismatch, no store path is written into this package, and no
other libc is substituted — the Nix linker is selected because the query selects
the host, not because anything here names it. `FORK-NOTES.md` entry 32 carries
the full causal map.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 54. The nested consumer build inherits the job width, the step list and the global cache — 2026-10-04

**`zig build consumer` ran a second build this graph had not selected.**
`runConsumer` writes the whole nested command line itself -- `zig build run`,
the target query and CPU, `-Doptimize`, `-Dlinkage`, `-Druntime`, the executor
switches, `--libc-runtimes`, `--cache-dir <outer>/consumer`, and the caller's own
arguments behind `--` -- and among the arguments it left out were the job width
and the step list `AGENTS.md:157-158` asks of every `zig build` entry in this
workspace, and the global cache the nested build then resolved on its own.

* **`-j8`.** Nothing can append a `-j` to a `Run` step's command after this
  helper has returned, so a nested build left to derive its own width takes
  `cpu_count - 1` (`lib/std/Io/Threaded.zig:1634-1639`). The consumer this step
  proves then compiles at a width neither this graph nor the gate asked for, and
  at a different width again on whichever machine runs the gate.
* **`--summary all`.** The nested build is a separate graph whose steps are
  named after the consumer package, so a failure inside it was otherwise one
  unnamed line in the outer graph's output.
* **`--global-cache-dir`.** The outer selection of the *global* cache was
  invisible to the nested build, which then resolved a global cache of its own.
  That store is a shared, content-addressed package cache rather than a
  per-graph manifest directory, so the correct forwarding is the caller's own
  path, unchanged: no `/consumer` suffix, unlike the local cache.
  The compiler emits that pair itself for every compile line it hands a graph
  (`lib/std/Build/Step/Compile.zig:1478-1479`), so a nested build that inherits
  the local cache but not the global one is the outlier here, not the rule.

**The change.** `runConsumer` writes `-j8`, `--summary`, `all`, and
`--global-cache-dir` followed by `b.graph.global_cache_root.path`, taken
from the graph the runner populated
before any script ran (`lib/compiler/build_runner.zig:73-76`, `:89`;
`lib/std/Build.zig:121-124`). No new option is declared and none is needed:
`--global-cache-dir [path]` is a documented build-runner option
(`lib/compiler/build_runner.zig:1675`), emitted as two tokens here for the same
reason `--cache-dir` above it is, and it is the compiler's own precedent --
`lib/std/Build/Step/Compile.zig:1478-1479` emits the identical pair from a build
script. Both new pairs sit ahead of the `--` that carries the caller's own
arguments, so a trailing `-- --provider <path>` still reaches the consumer
program unchanged.

**What did not change.** The native-query target and CPU of entry 53, the three
`-D` selections, the five executor switches and `--libc-runtimes`, the
`--cache-dir <outer>/consumer` pair, the `--`-forwarded `b.args`,
`run.has_side_effects` and the always-run policy are all untouched, and so is
the run-vs-install decision `runConsumer`'s own doc comment records: a
missing executor still stops the step instead of masquerading as a passing
consumer exchange. `runConsumer`'s signature is unchanged, so its single call
site needed no change. `consumer/build.zig`,
`consumer/build.zig.zon`, every source file, every upstream header, test,
fixture, licence text and integrity record in this package are untouched; this
entry changes one build script and nothing else.

**What this entry does not claim.** This role ran no `zig build`, no `devenv`,
no `nix` and no gate. Everything above is read out of the pinned 0.16.0
`lib/std` and `lib/compiler/build_runner.zig` and of this file; no build has
observed the new command line. The parent's own gate for it is
`zig build consumer -j8 --cache-dir <cache>/utf8proc/native --global-cache-dir <approved-global> --summary all`,
once for the default native selection and once for an explicitly named
`-Dtarget=`, and no row in `README.md`'s or `README.zig.md`'s tables moves on
this entry.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 55. The nested consumer build inherits this invocation's install prefix — 2026-10-04

**The nested build chose its own install prefix.** `runConsumer` writes the
whole nested command line, and the two caches this graph resolved were on it
while the install prefix was not. A caller who ran `zig build consumer
--prefix <somewhere>` got the caches it named and lost the one it named last.
The nested build fell back to its own default under the working directory the
same helper sets, which is `consumer/`, so its build output landed in
`consumer/zig-out`: an artefact inside a source package rather than the place
the caller asked for.

**The change.** `runConsumer` now writes `--prefix` and `b.install_prefix`
when the caller named one. It compares that value against
`b.build_root.join("zig-out")` first, so the comparison is against the value
the build system itself would have produced, and the pair is skipped when the
two are equal. A relative `b.install_prefix` is made absolute against
`b.graph.cache.cwd` before it is handed on: a relative `--prefix` on the
nested command line would resolve against `consumer/` and not against this
build's root. Two tokens, not `--prefix=…`, for the same reason the two cache
pairs are two tokens. The block sits after `--global-cache-dir` and before
the `--` that carries the caller's own arguments, so a trailing
`-- --provider <path>` is unaffected.

**Why the comparison rather than an unconditional forward.** With no prefix
named, `b.install_prefix` is `<build root>/zig-out`. The nested build's own
default is `consumer/zig-out`, because its root is the working directory.
Forwarding the outer default would therefore move the nested build's output
into the outer package's install layout for no caller request at all. The
nested command is `zig build run`, whose install step nothing depends on, so
this tree gains no `zig-out` either way.

**What did not change.** The target query and CPU of entry 53, the three `-D`
selections, the five executor switches and `--libc-runtimes`, the `-j8` and
`--summary all` pair of entry 54, the `--cache-dir <outer>/consumer` pair,
the `--global-cache-dir` pair, the `--`-forwarded `b.args`,
`run.has_side_effects` and the always-run policy are all untouched.
`runConsumer`'s signature is unchanged, so its single call site needed no
change. `consumer/build.zig` and `consumer/build.zig.zon` are untouched: that
package hands its own `b.args` to its `run_exe` already, so a program
argument reaches the consumer executable on the second hop without a change
here. Every source file, every upstream header, test, fixture, licence text
and integrity record in this package is untouched; this entry changes one
build script and nothing else.

**What this entry does not claim.** This role ran no `zig build`, no `devenv`,
no `nix` and no gate. Everything above is read out of this file. The parent's
gate for it is `zig build consumer -j8 --cache-dir <cache>/utf8proc/native
--global-cache-dir <approved-global> --prefix <prefix> --summary all`, once
for the default native selection and once for an explicitly named
`-Dtarget=`, and no row in `README.md`'s or `README.zig.md`'s tables moves on
this entry.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 56. Every canonical devenv build names both caches, and a missing one is filled — 2026-10-04

**Seven `zig build` bodies named no cache at all.** `devenv.nix` wrote `-j8` on
each of them and nothing else, so Zig's own default applied: `.zig-cache` inside
this checkout, which is the working tree `UPSTREAM.sha256` and the driver's
source digest cover. Entry 52 gave `sdk-build` a delivery prefix below
`$ZIG_LOCAL_CACHE_DIR` and refused when that variable was unset. No entry named
`ZIG_GLOBAL_CACHE_DIR` at all, and no entry named a `--cache-dir`, so a cache
outside this checkout was not something a caller could ask for.

**The change.** `devenv.nix` binds one shared flag string, `zigBuildFlags`, and
every `zig build` body uses it:

    --cache-dir "$ZIG_LOCAL_CACHE_DIR/utf8proc" --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" -j8 --summary all

Seven bodies use it — `sdk-build`, `sdk-test`, `sdk-smoke`, `sdk-exercise`,
`sdk-check`, `sdk-upstream-test` and `sdk-consumer` — so no two of them can
drift. `sdk-build` adds its own `--prefix
"$ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out"`, which entry 52 introduced and which is
unchanged. `sdk-integrity` and `sdk-format` run `sha256sum` and `zig fmt` and
carry no build flag.

**A missing cache variable is filled; an all-empty one is refused.** The old
rule was wrong about the common case, because the common case is a shell that
has never exported either variable. A non-empty `ZIG_LOCAL_CACHE_DIR` or
`ZIG_GLOBAL_CACHE_DIR` from the caller is used unchanged, which is what keeps
`FORK-NOTES.md` note 29's rule that a caller-supplied path is never overwritten.
A missing one is filled from `XDG_CACHE_HOME` first and `TMPDIR` second, as
`zig-local-cache` and `zig-global-cache`: the order and the directory names
`box2d`, `geographiclib-c` and `libunibreak` already use. When both are still
empty, the script names what is missing on stderr and exits non-zero, so the
compiler is never reached with `.zig-cache` as the only destination. No
fallback is a literal `/tmp`, a `/var/tmp`, an NFS mount or a path inside this
repository. None of it is a host fact written into a committed file either: the
fill reads variables the caller's environment already carries.

**Why the fill is in every body and not only in `enterShell`.** A devenv
`scripts` entry is materialised as a generated program that inherits the
caller's working directory and environment, not the shell hook's. Whatever
`enterShell` exported is therefore not guaranteed when a body starts, and
`devenv shell -- sdk-build` in a fresh process is exactly that case. The
refusal stands where the compiler would have been reached for the same reason.
`enterShell` still reports the same two states, and it does not stop.

**What this changes for the consumer step.** `runConsumer` in `build.zig` reads
`b.cache_root.path` and `b.graph.global_cache_root.path` as optional captures,
so the `--cache-dir <outer>/consumer` and `--global-cache-dir` relays of entry
54 happen only when this graph was given a path. Every canonical entry now gives
it one, so the nested build inherits this graph's cache instead of resolving
its own. `sdk-consumer` still names no `--prefix`: its step depends on the
consumer executable alone, so there is no delivery prefix to relay.

**What this entry does not claim.** This role ran no `devenv`, no `nix`, no
build and no gate. Everything above is read out of `devenv.nix`. The parent's
gate for it is `devenv shell -- sdk-build`, `devenv shell -- sdk-test`,
`devenv shell -- sdk-consumer` and `devenv shell -- sdk-check` from a project
directory with no cache variable exported, and then again with only `TMPDIR`
exported. No row in `README.md`'s or `README.zig.md`'s tables moves on this
entry.

`SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 57. Observed: the nested consumer delivery, nine cases at `Debug` — 2026-10-04

**Entries 54, 55 and 56 now have a bounded result.** The parent ran
`zig build consumer` over nine cases — `nested-default-linked-static`,
`nested-default-linked-dynamic`, `nested-default-loaded-static`,
`nested-default-loaded-dynamic`, `nested-explicit-linked-static`,
`nested-explicit-linked-dynamic`, `nested-explicit-loaded-static`,
`nested-explicit-loaded-dynamic` and `nested-no-provider` — and all nine
passed. This entry records that receipt. It changes no source.

**What the run observed.** Eight cases exited 0 with every expected pattern in
the consumer program's own output. The ninth exited 1, and that is what
`nested-no-provider` exists to prove: a runtime-loading build with no provider
named on the command line and none in the environment stops instead of reaching
an unresolved symbol. Every nested `zig build run` line carried `-j8`,
`--summary all`, `--cache-dir <outer>/consumer`, `--global-cache-dir` with the
caller's own path, and `--prefix` with the caller's own prefix, so entries 54,
55 and 56 describe what the nested build was actually given rather than what
the source intends. No nested check failed, and in every case the nested prefix
stayed outside this repository's tree instead of resolving to a `zig-out` inside
it. The four runtime-loaded cases carried `--provider <path>` behind `--` while
every `*_TEST_PROVIDER` variable was absent from the child environment, so the
provider arrived on the command line and the environment handoff is not what
made it work. The source closure was 78 files under one stable hash, identical
before and after.

**What this entry does not establish.** `Debug` only, one host, one toolchain,
and the `consumer` step only. It is not a result for the three release modes,
for the 53-platform matrix, for `devenv` or for `nix`. It is not a result for
any cache-fallback guard either: none is claimed here and none carries a
receipt. Every other row in `README.md`'s or `README.zig.md`'s tables is
untouched by this entry.

`OBSERVED`, `SOURCE-CONFIRMED`.

## 58. Observed: eight native cells, four modes by two linkages — 2026-10-04

**The four optimize modes and both linkages now have a result for this wave.**
The parent ran `zig build test smoke install` with `-Doptimize=<mode>` and
`-Dlinkage=<linkage>`, `-Druntime=false`, both caches named, an explicit
`--prefix`, `-j8` and `--summary all`, over four modes by two linkages. All
eight cells passed. This entry records that receipt. It changes no source.

**What the run observed.** Every cell reports `Build Summary: 28/28 steps
succeeded; 23/23 tests passed` with an empty `problems` list. The four `static`
cells install 16 files and carry `lib/libutf8proc.a` with no shared object. The
four `dynamic` cells install 18 files and carry `lib/libutf8proc.so`,
`lib/libutf8proc.so.3` and `lib/libutf8proc.so.3.3.0` with no archive, so the
two deliveries are disjoint and `-Dlinkage=dynamic` produces a real sonamed
shared object rather than a renamed archive. Every cell installs
`include/utf8proc.h`, `lib/pkgconfig/libutf8proc.pc` and eight licence records,
so the licence obligation travels with both deliveries.

**What this entry does not establish.** Native mode, one host, one toolchain,
`-Druntime=false`, and the `test`, `smoke` and `install` steps only. It is not a
result for `check` or for the 53-platform matrix, not a result for `devenv` or
for `nix`, not a result for `-Druntime=true`, which keeps its own pending row,
and not a result for any cache-fallback guard. The `22/22` figures in this
file's earlier receipts belong to the 2026-10-03 runs and are left as they are.
`23/23` is what this wave's source reports today, from this run alone.

`OBSERVED`, `SOURCE-CONFIRMED`.

## 59. The nested consumer sub-command is chosen, not assumed — 2026-10-05

**`zig build consumer` could not deliver a foreign consumer.** `runConsumer` wrote
`run` unconditionally, so on a target this host cannot execute the nested graph
reached its own `Step.Run`, which refused, and the step failed. It now sends
`install` when `hostCanExecute` says this host cannot execute the resolved
target. The sub-command is the only thing that changed: the target query, CPU,
optimize mode, linkage, runtime dispatch, both caches, `-j8`, `--summary all`,
`--prefix` and the `--`-forwarded arguments are byte-for-byte as entries 53 to 56
left them, and `consumer/build.zig` needed no change because it already installs
the executable.

**Supersedes** the always-run claim in entries 53, 54 and 55. Those entries are
dated history and are left as written.

**What this entry does not establish.** Nothing here has been run. There is no
receipt for the `install` branch, for a foreign `consumer`, or for any `-f*`
executor path. `SOURCE-CONFIRMED`, `PENDING-VERIFICATION`.

## 60. Observed: the 53-target cohort, the compile-only baseline and the runtime-loaded wave — 2026-10-05

**The cross-target and host gates now carry receipts against the source as it
stands.** Entries 57 and 58 recorded the nine nested-delivery cases and one
eight-cell native wave. Four further observations have since been run, and this
entry records them. It changes no source, no decision and no record of
provenance; it is an observation, and the per-cell detail is in
[`README.zig.md`](README.zig.md#verification-status).

**The full 53-platform cohort, epoch `20261004T221720228710Z-45046`, receipt
`utf8proc-53-target-8.json`.** `cross-test` with `--jobs 8 --build-jobs 8` over
`cross-test.profile.sh` in `mode: zig-build` on Zig 0.16.0: exit 0,
`target_count: 53`, `pass: 20`, `fail: 0`, `build_only: 33`, `partial: 0`,
`source_unchanged: true`, `jobs_honoured: true`. The 20 report
`run.status: pass` with `tests: 23` and `reason: tests_complete`; each of the other
33 reports `run.status: unavailable` with `reason: runtime_unavailable`. **A green
53-target build is not 53 runtime passes**: `build_only` is compiled and never run,
and it is not a pass in any document here. This is a `test`-step matrix — no
`install`, no `consumer` and no `upstream-test` in any cell.

**The compile-only baseline, epoch `20261005T014547Z-797a73f2`, receipt
`baseline-utf8proc-check-2026-10-05T01-46-01.794968+00-00.json`.** `zig build
check`, the graph's own whole-matrix step with no `-Dtarget`: exit 0, `failed:
false`, `Build Summary: 91/91 steps succeeded`, and `targets_seen` naming all six
of `declared_target_count: 6`. The row carries **`runtime_pass_claimed: false`**
and an empty test-count list: it proves compilation and says nothing about runtime
under any exit code.

**Two eight-cell host waves.** At `-Druntime=false`, epoch
`20261004T233628757747Z-69351`, receipts
`utf8proc-native-final-{static,dynamic}-<mode>.json`: **8/8 pass** over four
optimize modes by `static` and `dynamic`, every cell exit 0 with `test success`
and `smoke success`; the `Debug`/`static` cell reports `Build Summary: 28/28 steps
succeeded; 23/23 tests passed` and a 16-file prefix carrying `lib/libutf8proc.a`
and no shared object. At `-Druntime=true`, epoch `20261004T232823091897Z-23133`,
receipts `utf8proc-loaded-final-{static,dynamic}-<mode>.json`: **8/8 pass** through
the platform loader, the `Debug`/`static` cell reporting `Build Summary: 29/29
steps succeeded; 23/23 tests passed`. Every cell loaded the provider named by
`UTF8PROC_TEST_PROVIDER` — binding the whole declared surface, passing
`validate`, publishing once — and then ran the suite through the dispatch. **That
provider is this tree's own source-built `libutf8proc.so.3.3.0`**, recorded
`kind: "own"`, so the loaded wave is the runtime route exercised against itself.

**Independent external coverage: none, and that is a boundary rather than a pass.**
Epoch `20261004T232439Z`, `utf8proc-index.json`: `status: pass`,
`own_provider_route_passed: true`, **`external_successes_observed: 0`**,
`refusals_observed: 4`, `own_routes_counted_as_external: []`, and **no route
carries `counts_as_external_coverage: true`**. The host's only utf8proc is
2.10.0 / Unicode 16.0.0: it exports 30 of the 31 declared entry points, does not
export `utf8proc_free` (`utf8proc.h:808`), and is out of family on the Unicode
axis independently. Every external route was an expected refusal, and a refusal is
the result; none of them is coverage.

**What this entry does not establish.** **No receipt named here runs the
`consumer` step**, so entry 59's `install` branch and every `-f*` executor path
stay unobserved and entry 59 keeps its `PENDING-VERIFICATION` state. None of these
receipts evaluates `nix` or `devenv`, re-runs the integrity checks of entry 24, or
compiles a C consumer through the installed `libutf8proc.pc`. The runtime route's
negative contracts — a failed attempt, an explicit retry, a different provider
after a success, the atomic publication itself and the panic before initialization
— have no receipt and are not claimed here. `OBSERVED`, `SOURCE-CONFIRMED`.
