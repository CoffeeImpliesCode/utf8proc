# UPSTREAM.md — what this fork is a fork of

## Upstream

| | |
|---|---|
| Project | utf8proc, a small C library for Unicode UTF-8, UTF-16 and UTF-32 processing: normalization, case folding, grapheme segmentation, general category and East Asian width |
| Canonical repository | `https://github.com/JuliaStrings/utf8proc.git` |
| Pinned ref | tag `v2.12.0` (lightweight; points directly at a commit) |
| Pinned commit | `79cdd5ab40c79afa559f689ffc13b76812dee1ac` |
| C library version built here | `2.12.0` |
| Unicode data the library carries | `18.0.0` |
| ABI version | `3.3.0` |
| Library licence | MIT / "expat" — **two separate grants**, see [`NOTICE.md`](NOTICE.md) |
| Data-file licence | a separate Unicode grant for `utf8proc_data.c`, and a third Unicode term for `testdata/` |

Where each of those comes from, read out of the carried tree:

* The version is `utf8proc.h:72,74,76` — `UTF8PROC_VERSION_MAJOR 2`,
  `UTF8PROC_VERSION_MINOR 12`, `UTF8PROC_VERSION_PATCH 0` — and
  `utf8proc_version()` returns that same triple by stringizing the macros
  (`utf8proc.c:99-101`). That is the version of the C library, not of anything
  this fork wrote.
* The Unicode data version is a **literal**, not a macro:
  `utf8proc.c:103-105` returns `"18.0.0"`. `data/Makefile:24` carries the
  matching `UNICODE_VERSION=18.0.0` and says at `data/Makefile:23` that whoever
  bumps it "must also update utf8proc_unicode_version function". The two agree,
  and `test/misc.c:96-99` exists to assert that they keep agreeing.
* The ABI version `3.3.0` is upstream's own, in `MANIFEST:5-7` as
  `libutf8proc.so.3 -> libutf8proc.so.3.3.0` and
  `lib/libutf8proc.so.3.3.0`. It is an ABI number, deliberately decoupled from
  the API version: `utf8proc.h:66-68` says the shared-library version may differ
  because it tracks ABI compatibility, not API compatibility.
* The compiled core is **three files and one translation unit**.
  `utf8proc.c` has exactly two `#include`s — `utf8proc.h` at line 44 and
  `utf8proc_data.c` at line 53 — and `utf8proc_data.c` has no `#include` of its
  own. The adjacent placement is load-bearing: the include at line 53 is
  quoted, so it resolves relative to the directory holding `utf8proc.c`, and
  `utf8proc_data.c` needs `UINT16_MAX` to be defined before it is reached,
  which `utf8proc.c:49-51` supplies itself when the platform headers do not.
* **No generated-at-build input exists.** There is no `config.h`, no
  `configure` output and no download. `utf8proc_data.c` is a 2.4 MB table
  already checked in, and upstream's own `build.zig:21-23` compiles exactly one
  source file.

### Upstream's own files name stale URLs. Recorded, not patched.

This matters because it is how a reader can end up looking at the wrong
repository, so it is written down rather than silently corrected:

* `utf8proc.h:33` points its `@mainpage` documentation at
  `https://github.com/JuliaLang/utf8proc`, and `utf8proc.h:31` at
  `http://julialang.org/utf8proc/`. The project now lives under the
  **JuliaStrings** organisation. Those are upstream's bytes and stay as they
  are.
* `README.upstream.md:2` badges a workflow under `NanoComp/meep`, another former
  name. `README.upstream.md:87` and `README.upstream.md:92` still link the issues
  list under `JuliaLang`.
* `README.upstream.md:9` and `README.upstream.md:11` link
  `public-software-group.org`, which is **correct** in context — those lines say
  the library was *originally* developed by Jan Behrens and the Public Software
  Group, which is history, not a current home. Only the JuliaLang and NanoComp
  names are stale.
* `README.upstream.md:27` points the Unicode data licence at
  `http://www.unicode.org/copyright.html#Exhibit1`, which is the pre-2015 URL.
  See [the data-file licence](#the-data-file-licence-and-a-dangling-cross-reference)
  for what that costs.

No URL was corrected, because no upstream byte was edited, and this fork edits
none: the file these lines are quoted from is upstream's README preserved whole as
`README.upstream.md` (see entry 19 below), and the fork's own `README.md` quotes
it rather than restating it.

## Import mechanism, and what anchors the bytes

### The archive receipt, and a per-file cross-check against it

The driver measured a `git archive` stream of the pinned commit in this
directory and recorded it in the workspace record
`local://foundation-project-matrix-source-pins.json`. Read out of that record,
verbatim:

| Field | Value |
|---|---|
| Pin | `79cdd5ab40c79afa559f689ffc13b76812dee1ac` |
| Command | `git archive --format=tar 79cdd5ab40c79afa559f689ffc13b76812dee1ac` |
| Working directory | `/vol/fob-vol7/mi19/gertullj/foundation-libs/utf8proc` |
| Exit code | `0` |
| Archive size | `2 775 040` bytes |
| Archive SHA-256 | `fcf2ba77881774208b17f57a0cbc8e6a70d07dcb51ec31bbf35c32ce58331e40` |
| Blobs recorded | 53, every one `"kind": "regular"` — no symlink, no submodule, no directory entry |

That record also carries a per-file SHA-256 and byte size for each of those 53
blobs. **This fork re-measured all 56 of its own records and compared them.**
The result is exact:

| Comparison | Result |
|---|---|
| The 53 blobs in the pin record vs this fork's measured digests | **53 of 53 identical, 0 mismatches** |
| The 3 pin blobs absent from `UPSTREAM.sha256` | exactly `.gitignore`, `build.zig`, `build.zig.zon` — the three files this fork edits in place, excluded for that reason and named in the record's own header |
| The 6 records in `UPSTREAM.sha256` absent from the pin tree | exactly the six `testdata/` files, which upstream does not commit — `data/Makefile`'s `clean:` target deletes them, which is the whole reason this fork has to carry them |

So the answer to "are these upstream's bytes at `v2.12.0`?" is measured rather
than assumed: **every one of the 53 files upstream committed at the pinned
commit is present here with an identical SHA-256 and an identical byte size, and
the tree contains nothing else from upstream.** There is no unverified remainder
to disclose.

The earlier delivery records `local://foundation-expansion-sources.json` and
`local://foundation-expansion-source-archives.json` contain no utf8proc entry;
`…-source-pins.json` is the record that does, and it is the one quoted above.

### A second, independent anchor on the compiled core

For each of the three files the build compiles, this fork also computed the git
object id of the file as it sits on disk —
`sha1("blob " + <byte length> + "\0" + <file bytes>)`, computed directly over the
bytes, no `git` command involved — and compared it with the blob id the pinned
commit itself carries, read out of this repository with
`git ls-tree -r 79cdd5ab40c79afa559f689ffc13b76812dee1ac`:

| File | Bytes | git blob SHA-1 on disk | Pinned commit's blob id |
|---|---|---|---|
| `utf8proc.h` | 34 834 | `d842f6bcdf3a2e4a70de82fda94371851cfd5567` | `d842f6bcdf3a2e4a70de82fda94371851cfd5567` |
| `utf8proc.c` | 33 831 | `0e277e0c27ed0d9cc3d1b254b24d6a4bfc8c9019` | `0e277e0c27ed0d9cc3d1b254b24d6a4bfc8c9019` |
| `utf8proc_data.c` | 2 409 012 | `5d6bcc2fd81c335f4dabcca5f3242f29d440cdd8` | `5d6bcc2fd81c335f4dabcca5f3242f29d440cdd8` |

All three match, and all three byte counts match. This is a different
computation from the SHA-256 comparison above — a different hash, over a
different framing of the same bytes, against a source inside this clone rather
than a recorded archive map — and it agrees: **the C sources and the 2.4 MB
generated data table this fork compiles are byte-identical to the blobs the
pinned commit carries.** The `integrity` job in `.github/workflows/verify.yml`
re-derives exactly these three ids on every run, from the pin and from the
working tree, so the table is reproducible rather than only asserted here.

### What is *not* anchored

**Tag signature: not verified.** No signing key was consulted and no claim is
made about whether the tag `v2.12.0` is signed. The content anchors above are
content checks, not signature checks.

**The `testdata/` fixtures are not covered by either anchor**, and cannot be:
upstream does not commit them, so no `git archive` of upstream can attest to
them. They are anchored instead by the URLs they were fetched from, the
revision and date each names in its own first two lines, and the SHA-256 this
fork measured — see [the fixtures](#the-conformance-fixtures-in-testdata).

## What this fork is

A Zig package that compiles upstream's own C library from the root of this
repository and publishes a Zig facade over the translated `utf8proc.h`. No part
of the Unicode algorithm is reimplemented, re-derived, retuned or patched: no
table is regenerated, no upstream source file is modified, and nothing is
downloaded at build or test time. The only bytes this fork authors are new
files in new roles, plus three upstream files it edits for build purposes only —
see [build-only deviations](#build-only-deviations-from-upstream).

## What is compiled, and with which switches

One translation unit: **`utf8proc.c` only.** `utf8proc_data.c` is not compiled
separately; it is `#include`d at `utf8proc.c:53`, which is why the two must stay
adjacent on disk.

| Switch | Value | Why, from the source |
|---|---|---|
| `UTF8PROC_STATIC` | **defined**, on the compile line and on the translation line | `utf8proc.h:123-125` makes `UTF8PROC_DLLEXPORT` empty when it is defined. Without it, `utf8proc.h:128-132` gives `__declspec(dllimport)` under `_WIN32`, so every declaration on the Windows target would be an import and the static archive would not link. This is the one switch whose absence fails loudly, and only on `x86_64-windows-gnu`. |
| `link_libc` | **true** | `utf8proc.c` calls `malloc`, `realloc` and `free` (`utf8proc.c:789, 811, 849`). Upstream's own `build.zig:10` sets `link_libc = true`. |
| C standard | C99, and the header is additionally C++-compatible | Upstream's `Makefile` `UCFLAGS` builds `-std=c99 -pedantic -Wsign-conversion -Wall -Wextra -Wc++-compat`. |
| Everything else | upstream's defaults, unmodified | The only conditional compilation in the core is the pre-2013 MSVC fallback in `utf8proc.h:81-120` and the `DLLEXPORT` / `STATIC` / `EXPORTS` logic. There is no platform-conditional code in `utf8proc.c` at all. |

No libc string function is called: a sweep of `utf8proc.c` for
`memcpy`/`memset`/`strcmp`/`strlen` finds only parameters *named* `strlen`, never
a call. Nothing beyond libc's allocator is linked, so there is no dependency to
satisfy on any of the six cross targets.

### Three option bits whose reach is narrower than the header suggests

All three are properties of the pinned upstream bytes and are recorded here so a
re-sync re-checks them rather than inheriting them.

**`UTF8PROC_STABLE` has no branch anywhere in the core.** It is declared at
`utf8proc.h:154` and documented at `utf8proc.h:604, 627, 779`, and it occurs
exactly five times in `utf8proc.c` — `utf8proc.c:820, 826, 832, 838, 844` — in
which upstream's own `utf8proc_NFD`, `NFC`, `NFKD`, `NFKC` and `NFKC_Casefold`
pass it *to* `utf8proc_map`. No code tests the bit. A caller that sets it gets it
forwarded and nothing else, so this package accepts and forwards it and claims no
per-entry-point behaviour for it.

**`UTF8PROC_ERROR_INVALIDOPTS` is raised in one function only.** Both illegal
combinations — `compose` with `decompose`, and `stripmark` with neither — are
checked at the top of `utf8proc_decompose_custom` (`utf8proc.c:547-551`), so they
reach `utf8proc_decompose`, `utf8proc_decompose_custom` and everything built on
them (`utf8proc_map`, `utf8proc_map_custom`) and reach **not**
`utf8proc_decompose_char`, whose own `UTF8PROC_STRIPMARK` arm
(`utf8proc.c:503-506`) strips the mark without any such precondition. The header's
per-function flag lists do not say this; the source does.

**`UTF8PROC_STRIPCC` is read by one function only, and it is not the one the
header's summary implies.** The bit is declared at `utf8proc.h:186` and
described there as stripping control characters, and `utf8proc.h:42` lists it
beside `UTF8PROC_IGNORE` and `UTF8PROC_STRIPMARK` as a general facility. It
occurs exactly three times in `utf8proc.c` — `utf8proc.c:619`, `utf8proc.c:627`
and `utf8proc.c:641` — and all three are inside `utf8proc_normalize_utf32`, which
spans `utf8proc.c:617-747`. `utf8proc_decompose_char` reads
`UTF8PROC_STRIPMARK` at `utf8proc.c:503-506` and never looks at `STRIPCC`, and
the per-function list at `utf8proc.h:523-532` does not offer it either, while
`utf8proc.h:601` and `utf8proc.h:624` do offer it for
`utf8proc_normalize_utf32` and `utf8proc_reencode`. `utf8proc_reencode` honours
it only because it calls that function first (`utf8proc.c:752`), and
`utf8proc_map` and `utf8proc_map_custom` only because they call `reencode`
(`utf8proc.c:804`). A caller who sets the bit on `decompose`,
`decompose_custom` or `decompose_char` gets every control character back
unchanged, and the header does not say so. One behaviour is worth restating with
it: with no NLF option set, LF, CR, NEL, VT, FF and HT all become U+0020
(`utf8proc.c:626-633`, `utf8proc.c:641-643`) rather than being removed, so
"strip" in the declaration comment at `utf8proc.h:179-185` is a conversion for
that group and a removal only for the remaining control characters.

## The data-file licence, and a dangling cross-reference

`LICENSE.md` is upstream's single licence file — there is no `COPYING`, no
per-file `LICENSE`, and **no SPDX identifier anywhere in the tree** (swept: zero
matches outside `testdata/`, which this fork added and which carries none
either). It has three sections, and they are three different things:

1. **`LICENSE.md:1-28`, the utf8proc grant.** MIT / "expat",
   `Copyright © 2014-2021 by Steven G. Johnson, Jiahao Chen, Tony Kelman, Jonas
   Fonseca, and other contributors listed in the git history.`
2. **`LICENSE.md:30-50`, the original grant.** MIT / "expat",
   `Copyright (c) 2009, 2013 Public Software Group e. V., Berlin, Germany`.
   This is a **second copyright with its own grant**, not a duplicate of the
   first, and it has to be kept verbatim.
3. **`LICENSE.md:52-93`, the Unicode data grant.** It names
   `utf8proc_data.c` specifically, quotes
   `Copyright (c) 1991-2007 Unicode, Inc. All rights reserved. Distributed under
   the Terms of Use in http://www.unicode.org/copyright.html.`, and carries the
   three-condition grant including condition (c): clear notice in each modified
   Data File or in the Software as well as in the documentation that the data or
   software has been modified.

**`utf8proc_data.c` carries no notice of its own, and upstream's pointer to it
is dangling.** Line 1 of that file is
`static const utf8proc_uint16_t utf8proc_sequences[] = {` — no copyright, no
licence line, no SPDX. Yet `utf8proc.c:26-32` says *"This library contains
derived data from a modified version of the Unicode data files"* and *"Please
notice the copyright statement in the file `utf8proc_data.c`."* **There is no
such statement in that file.** The Unicode terms for the data table exist only in
`LICENSE.md` §3.

This is recorded, not patched. `utf8proc_data.c` is 2.4 MB of upstream-generated
tables and its bytes are proved identical to upstream's committed blob by the
check above; inserting a notice would break that proof, change upstream source
without an observed failure to justify it, and fall outside the owner
authorisation this workspace has given for portability fixes. Nothing in this
package repeats upstream's claim as though the data file carried the notice.

**The terms in `LICENSE.md` §3 and the terms that currently govern the fixtures
are not the same text.** `LICENSE.md:59-60` quotes the 1991-2007 three-condition
grant, conditioned on (a) the notice appearing with all copies, (b) appearing in
associated documentation, and (c) clear notice of modification. The Unicode
Consortium's **current** published licence for its Data Files is Unicode License
V3, whose single grant offers (a) *or* (b) — either the notice in all copies, or
the notice in associated documentation — and drops the separate modification
condition. `README.upstream.md:27` still cites the retired
`copyright.html#Exhibit1`. Both texts are shipped unmodified: `LICENSE.md`
carries the historical one for the compiled data table, and
`testdata/Unicode-License-V3.txt` carries the current one for the fixtures. This
package does not choose between them and does not assert which governs whom.

**Everything else upstream ships is unlicensed per file.** A sweep of `test/`,
`data/` and `bench/` for `Copyright`, `Permission is hereby`, `MIT` or `SPDX`
returns nothing — 29 files, including all of upstream's own C test suite, the
Julia generator and every benchmark. Those files fall under the package-level
MIT grants in `LICENSE.md` §1 and §2 and nothing else.

## The conformance fixtures in `testdata/`

**Upstream ships no Unicode conformance data at all.** `data/Makefile:59-63`
deletes `NormalizationTest.txt`, `GraphemeBreakTest.txt`, `Lowercase.txt` and
`Uppercase.txt` in its `clean:` target, and `data/download.sh` is the script that
fetches them. So upstream's `check` is *not* self-contained: it needs a network
round trip to run at all. Committing the corpora is what makes this fork's
verification self-contained, and it is the reason `data/` is never entered by
this build.

Five files were fetched by this fork from the Unicode Consortium on **2026-10-03**
and stored byte for byte. The three primary files each name their own revision
and date in line 1 and line 2, which is what establishes that they are 18.0.0
rather than whatever a URL might serve today.

| Fixture | Origin | Bytes | SHA-256 | Names its own revision |
|---|---|---|---|---|
| `testdata/NormalizationTest.txt` | `https://www.unicode.org/Public/18.0.0/ucd/NormalizationTest.txt` | 2 863 708 | `25a50d816764b04abfb4a646d3eb2b2a803284c3873d9a06757b94fe4513dde3` | `# NormalizationTest-18.0.0.txt`, `# Date: 2026-06-24` |
| `testdata/GraphemeBreakTest.txt` | `https://www.unicode.org/Public/18.0.0/ucd/auxiliary/GraphemeBreakTest.txt` | 137 090 | `b0cf047ee94485bbdc846de2b902f5f8a815f6b674f9d04223cddadd91c9df31` | `# GraphemeBreakTest-18.0.0.txt`, `# Date: 2026-06-12` |
| `testdata/DerivedCoreProperties.txt` | `https://www.unicode.org/Public/18.0.0/ucd/DerivedCoreProperties.txt` | 1 159 889 | `09c928886a178fcafd93c29e4bd59073a058e5a100b716d425cb563ab50f68c9` | `# DerivedCoreProperties-18.0.0.txt`, `# Date: 2026-08-07` |
| `testdata/Unicode-License-V3.txt` | `https://www.unicode.org/license.txt` | 1 995 | `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` | `UNICODE LICENSE V3`, `Copyright © 1991-2026 Unicode, Inc.` |

All five are plain LF text with no byte-order mark. Each of the three data files
carries, in its own lines 3-5, the notice that governs it:

```
# © 2026 Unicode®, Inc.
# Unicode and the Unicode Logo are registered trademarks of Unicode, Inc. in the U.S. and other countries.
# For terms of use and license, see https://www.unicode.org/terms_of_use.html
```

### `Lowercase.txt` and `Uppercase.txt` are derived, not fetched — and how

These two are **not** Unicode publications. They are sections of
`DerivedCoreProperties.txt`, extracted by upstream's own recorded rule at
`data/Makefile:53-57`:

```make
Uppercase.txt: DerivedCoreProperties.txt
	$(JULIA) -e 'print(match(r"# Derived Property: Uppercase.*?# Total code points:"s, read("DerivedCoreProperties.txt", String)).match)' > $@

Lowercase.txt: DerivedCoreProperties.txt
	$(JULIA) -e 'print(match(r"# Derived Property: Lowercase.*?# Total code points:"s, read("DerivedCoreProperties.txt", String)).match)' > $@
```

Read the rule exactly: take the substring beginning at the first
`# Derived Property: Lowercase` (or `Uppercase`) and ending at the end of the
**first** `# Total code points:` that follows it. Nothing is filtered, reordered,
normalised or reformatted, and **nothing is written that upstream's own command
would not have written** — which is why both files end in a bare
`# Total code points:` line with no count and no trailing newline. That is
upstream's `print(match(...))` output verbatim. A parser must tolerate it. Do not
"tidy" these files.

This fork reimplemented that regex rather than running Julia: no Julia toolchain
is present on this host, and installing one for a two-line anchored substring
match would have been a heavier dependency than the extraction warrants. The
reimplementation is the same pattern with the same semantics — a leftmost match,
a lazy `.*?`, and dot-matches-newline — applied to the same bytes, and it is
recorded here so a reader can re-derive both files without trusting the prose.

| Derived fixture | Section header | Section closes at | Bytes | SHA-256 |
|---|---|---|---|---|
| `testdata/Lowercase.txt` | `DerivedCoreProperties.txt:1495` | `:2210` `# Total code points: 2740` | 55 684 | `aca4346d0eb2601ccc18beb1eaedaf3269feb2f3df26f18e3970e45f16563e84` |
| `testdata/Uppercase.txt` | `DerivedCoreProperties.txt:2214` | `:2896` `# Total code points: 2026` | 53 245 | `c0823767d0fb71c7bf3f5cf38554748950bd9b95426f89859a706bf93d3a3921` |

**A self-check on the derivation, not just a hash.** Each derived file was
re-parsed and its ranges summed. `Lowercase.txt` holds 711 ranges covering
exactly **2 740** code points, from U+0061 to U+1E943, and the section's own
declared total is 2 740. `Uppercase.txt` holds 678 ranges covering exactly
**2 026** code points, from U+0041 to U+1F189, against a declared 2 026. Both
agree, which is evidence the extraction took the intended section rather than a
neighbouring one — `DerivedCoreProperties.txt` carries 20 `# Derived Property:`
headers and a wrong anchor
would still have produced a well-formed file.

### How the fixtures are read

**One mechanism, and it is compile-time embedding.** `tests.zig`'s accessor is
`@embedFile("testdata/" ++ name)`, called with four names —
`NormalizationTest.txt`, `GraphemeBreakTest.txt`, `Lowercase.txt` and
`Uppercase.txt` — and each is embedded in full. There is no options module, no
`testdata_dir`, no path joining and no run-time file read anywhere in this
package. `DerivedCoreProperties.txt` is **not** embedded and is **not** a test
input: it is carried as the provenance of the two derived case files, which is
recorded below and hashed in `UPSTREAM.sha256`.

`zig/api_exercise.zig` embeds nothing. It is a separate executable with its own
`main` that calls every public facade function once, each against a small
expected answer written as a literal in that file — no corpus, no fixture data,
and no re-export of the facade.

**What embedding costs and buys.** About 3.1 MB of conformance text becomes a
compile-time constant in the test object, and `check` compiles that object for
each of its six targets, so the cost is paid at compile time on every one of
them. What it buys is that the test binary carries its own oracle: it runs
anywhere, including on a foreign executor under the QEMU, Wine or wasmtime
runners `cross-test` selects from its 53 platforms, where no source path into the
build directory exists at all. `testdata/` is one entry in `.paths` because
`@embedFile` needs the bytes at build time.

Corpus consumption is **whole-file, no sampling**: all 20 171 conformance rows of
`NormalizationTest.txt` (spread over six `@Part` sections — Specific cases 46,
Character by character 17 154, Canonical Order 2 004, PRI #29 194, Canonical
closures 735, Chained primary composites 38) at 20 checks each — 403 420 in
total; all 853 data rows of `GraphemeBreakTest.txt`, each through both the
stateful walk and the `CHARBOUND` marker form; and every range of
`Lowercase.txt` and `Uppercase.txt`, with the gaps between ranges walked too.

`testdata/Unicode-License-V3.txt` is a licence record. It is hashed, it is
shipped, and it is never an input to a test.

## System-library mode: NOT APPLICABLE in this wave

There is no `b.systemIntegrationOption` in this build, and the source pins and
bounded contracts are therefore identical in every mode that exists — which is
one mode. Recording this as *not applicable* rather than as a gate that passed.

The rule it would otherwise have to satisfy is `WISDOM.md` W14, and it is worth
recording why omitting it here is a decision rather than an oversight. Debian
does ship a compiled `libutf8proc`, so the rule's precondition is genuinely met.
But `utf8proc_free` **is new in 2.12.0** (`utf8proc.h:808`, `utf8proc.c:848`) and
the installed versions run 2.5.0 through 2.11.3, so bundling this tree's 2.12.0
header against an older installed library would compile and then fail at link
time; and 2.12.0 changed two declared types without changing the ABI — `options`
went from an `enum` to `unsigned int`, and `utf8proc_decompose_char`'s
`last_boundclass` went from `int *` to `utf8proc_int32_t *`. Any system mode
would have to translate the *installed* header and verify header/ABI identity,
not just link something called `libutf8proc`. That is a decision for a future
wave, with its own gate.

## Build-only deviations from upstream

Everything in this section is a build decision. **No upstream C source, header,
data table, test source, fixture or licence text is modified** — the blob check
above and `UPSTREAM.sha256` are what say so.

| # | Deviation | Scope | Why |
|---|---|---|---|
| 1 | `build.zig` extended in place | build-only | Upstream's `build.zig` is 26 lines that compile `utf8proc.c` and install the header, with no `test`, `smoke`, `check`, `consumer` or `upstream-test` step. Zig allows one `build.zig` per package, and upstream ships its own, so the fork's build definition lives there rather than in a second file or a relocated tree. Upstream's `UTF8PROC_STATIC` flag, its single source file and its `link_libc` are all preserved. |
| 2 | `build.zig.zon` extended in place | build-only | Upstream's manifest carries `.fingerprint = 0xdcddf08dbb8954c4` and a 7-entry `.paths`: `build.zig`, `build.zig.zon`, `utf8proc.h`, `utf8proc.c`, `utf8proc_data.c`, `README.md`, `LICENSE.md` — read out of `git show 79cdd5ab…:build.zig.zon`. All seven upstream entries are still listed by name; the fork adds the corpora, upstream's suite and tooling, the records, the consumer package, this wave's `README.upstream.md`, `FORK-LICENSE.md` and five packaging files, and the `runtime` directory, the `zig` facade directory, the two package roots and `cross-test.profile.sh`. One further listed path belongs to neither upstream nor this fork: `flake.lock` is the driver's lock, written into this tree after those five delivery files existed, and `NOTICE.md` and `FORK-LICENSE.md` both take its terms out of this fork's own material. `FORK-LICENSE.md` is not optional documentation: `build.zig` installs it into `share/licenses/utf8proc/`, so a fetched copy without it fails the install step. `runtime` could not be listed before it existed — a `.paths` entry with no file behind it is itself a closure failure — and is listed now that entry 21's files are there. The `.fingerprint` differs, `0xdcddf08d3f5ccfa0` against upstream's `0xdcddf08dbb8954c4`, because the two manifests are not the same file; the value here belongs to this manifest and is re-derived by the compiler that reads it. Upstream's `.name = .utf8proc` and `.version = "2.12.0"` are preserved verbatim. |
| 3 | `.gitignore` appended to | build-only | Upstream's 44 lines are kept verbatim. The fork appends root-anchored entries only: four for Zig (`/.zig-cache/`, `/zig-out/`, `/consumer/.zig-cache/`, `/consumer/zig-out/`) and six for this wave's tooling (`/result`, `/result-*`, `/.devenv/`, `/.devenv.flake.nix`, `/.devenv.flakes/`, `/devenv.local.nix`). No negation rule is needed because no fork file ends in `.new`, and `flake.lock` and `devenv.lock` are deliberately **not** ignored: they are real inputs belonging to the driver, and ignoring them would be the wrong way to keep one out of a commit. Note upstream's unanchored `*.new`, `*.out` and `/build/` patterns and that `/data/*.txt` is root-anchored, so it **cannot** swallow `testdata/` — checked against the file's patterns, which is a reading of the file and not a `git` run. |
| 4 | Nine of upstream's eleven C test programs are built and run | build-only | Upstream's `Makefile:204` makes eleven `test/*` programs prerequisites of `check` and executes ten of them (`Makefile:206-215`); `printproperty` is compiled and never run. This fork builds and runs nine: `normtest`, `graphemetest`, `valid`, `iterate`, `case`, `iscase`, `custom`, `misc`, `maxdecomposition`. |
| 5 | `test/charwidth.c` not built | build-only, with reason | Its oracle is the **host's** `wcwidth` through `<wchar.h>`, which needs `_XOPEN_SOURCE 700` and is not uniformly available across the six cross targets, and its own source calls its mismatches informational and warns of "lots of these errors for out-of-date system unicode tables". Building it would compare this library against whatever Unicode version the host libc has, which is not an oracle. Its oracle-free invariants and its four pinned code points (U+00AD, U+E000, U+00A1, U+00A2) are ported to the Zig tests. |
| 6 | `test/printproperty.c` not built | build-only | Upstream compiles it and never executes it; it is a property dumper. |
| 7 | `bench/` not built | build-only | `Makefile:205` has `check` recurse into `bench/`, but `bench/icu.c` links ICU4C and `bench/unistring.c` links libunistring. Neither is in scope, and neither licence is granted by anything in this tree. The files stay in the repository for provenance. |
| 8 | `test_install_uninstall` not run | build-only | `test/install_uninstall.sh` is an installation smoke script. `Makefile:204` makes it a prerequisite of `check`, but the run lines never execute it. It also installs into a prefix, which this build does not do. |
| 9 | `test/fuzzer.c`, `test/fuzz_main.c` not built | build-only | The OSS-Fuzz harness, driven by `test/ossfuzz.sh`. Upstream's `check` does not build it either. |
| 10 | `UNICODE_VERSION` supplied to `test/misc.c` from the shipped `data/Makefile`, not by a hand-copied literal | build-only | `Makefile:181` shells out to perl to scrape `UNICODE_VERSION` out of `data/Makefile` and passes it to `test/misc.c`, where `test/misc.c:96-99` uses it to assert `utf8proc_unicode_version()` agrees. That block is inside `#ifdef UNICODE_VERSION`, so a missing define **does not fail the program** — it silently removes the assertion, and the program still prints `Misc tests SUCCEEDED.` and exits 0. The build scrapes the same value out of the committed `data/Makefile` itself, so the data version cannot drift into a hand-maintained constant in this fork. `Makefile:184` passes the same define to `maxdecomposition.c`, which never references the macro; that one is a no-op upstream carries. |
| 11 | Fixture paths point at `testdata/` | build-only | Upstream passes `data/NormalizationTest.txt`, `data/GraphemeBreakTest.txt`, `data/Lowercase.txt`, `data/Uppercase.txt` (`Makefile:206-213`). The same four files ship here under `testdata/`, committed. `test/iscase.c:58` requires exactly two arguments in the order Lowercase, Uppercase. |
| 12 | `testdata/Unicode-License-V3.txt` added | new file | See [the data-file licence](#the-data-file-licence-and-a-dangling-cross-reference). |
| 13 | The export macros are supplied per linkage by `build.zig`, and `zig/translate.h` defines neither | build-only | Upstream puts `-DUTF8PROC_STATIC` on the archive's compile line (`build.zig:21-23`) and `-DUTF8PROC_EXPORTS` on the shared object's (`Makefile`), so the choice is upstream's and the fork keeps it. `utf8proc.h:123-139` then makes `UTF8PROC_DLLEXPORT` empty for `UTF8PROC_STATIC` and `__declspec(dllimport)` for a `_WIN32` consumer that defines neither, so a consumer needs `UTF8PROC_STATIC` for a static link and nothing for a shared one. `build.zig` owns all three placements — `libraryMacros(linkage)` on the core's compile line, `consumerMacros(linkage)` on the translation line and on every dependent's module — and `zig/translate.h` deliberately defines nothing: a header that set its own export macro would describe a linkage the build did not choose. An earlier revision of this row said the opposite, because a build-script `-D` could not reach the translation step in that Zig version; `CHANGELOG.md` entry 47 records the correction. |
| 14 | The translated module is exposed only as the `c` import of the published module | build-only | It is not registered as a top-level module named `c`, so `dep.module("c")` cannot resolve declarations with no library behind them. |
| 15 | `.version` is checked against the pin at build time | build-only | `build.zig` panics if `build.zig.zon`'s `.version` drifts from the pinned `2.12.0`, so a version bump is a decision someone makes rather than a side effect. No `-DUTF8PROC_VERSION*` override exists anywhere, so `utf8proc_version()` reports what the shipped header's own macros say, stringized at `utf8proc.c:97-101`. |
| 16 | `zig/api_exercise.zig` is an executable **compiled** by the default step, run by `test` and by `exercise`, compiled by `check` — and **not installed** | build-only | It used to be added as a test artifact, where it was *incidental*: a root whose test blocks are incidental can be built, linked and reported as a pass without any public function ever being called. It is now a real program with its own `main` that calls every public facade function unconditionally. The default install step depends on its **compile** step (`b.getInstallStep().dependOn(&exercise.step)`), which is not installation: there is no `installArtifact` call for it, so `zig-out/bin/` is never written and the installed prefix holds only `LICENSE.md`, `include/utf8proc.h` and `lib/libutf8proc.a`. `zig build test` runs it, `zig build exercise` runs it on its own, and `check` compiles it for all six targets. One body is now one result: a facade function that does not compile is reported by the build, and one that misbehaves at run time is reported by a program that ran. |
| 17 | The test root embeds the corpora; the exercise carries no fixture data | build-only | The corpora have to reach `tests.zig` somehow, and `@embedFile` is what makes the test binary self-contained: it runs on a foreign executor under QEMU, Wine or wasmtime, where neither an absolute nor a relative source path into the build directory exists, and all four corpora are compiled in in full. `zig/api_exercise.zig` gets no data at all — every expected answer in it is a literal in that file. The committed files are the same in both cases, and neither root downloads anything. |
| 18 | The translation front end is chosen per target, and `zig/translate.h` restates the compiler's own 128-bit typedefs | build-only | `zig translate-c` preprocesses and parses with Aro, and Aro cannot read fifteen of the fifty-three targets' C libraries: nine NetBSD targets (`__END_DECLS` ends in `_Pragma("GCC visibility pop")`, which Aro leaves in the token stream), three ILP32 OpenBSD targets (two conflicting `size_t` typedefs), both OpenBSD MIPS targets (`endian.h` refuses to define `BYTE_ORDER` without `__MIPSEL__` or `__MIPSEB__`), and `x86-windows` (`_ALLOCA_S_MARKER_SIZE` is derived from architecture macros Aro's Windows table lacks). `build.zig`'s `translationRoute` picks the route from the property each cause turns on — not from a target list — and for those fifteen runs the target's own C preprocessor, `zig cc -E -dD`, first; every other target keeps Aro reading `zig/translate.h` as it stands. `zig/translate.h` additionally restates `__int128_t` and `__uint128_t` under `#if defined(__SIZEOF_INT128__)`, because `generic-netbsd/arm/cdefs.h:62-63` keeps `__ALIGNBYTES` as `(sizeof(__int128_t) - 1)` and `zig translate-c` emits no implicit typedef to stand in for it. Both routes read this repository's own `utf8proc.h`, with this repository's root on the include path and the export macros coming from `build.zig`'s one macro source, so the route cannot describe a different library or a different linkage. Nothing is stubbed, narrowed, renamed or substituted, no predefine is invented — `__SIZEOF_INT128__` is the compiler's own capability macro — and the archive, its ABI and utf8proc's own declarations are identical on both routes. The two typedefs are the compiler's, not utf8proc's, and nothing about its API, ABI or compiled output depends on them. |
| 19 | `README.md` replaced in place by the fork's README; upstream's bytes preserved as `README.upstream.md` | documentation-only, no build effect | The one deviation here that is documentation rather than build. Upstream's README — 143 lines, 5839 bytes, SHA-256 `105b8cf2…` — is kept whole at `README.upstream.md`; the file now at `README.md` is new. No upstream byte was edited, moved or paraphrased: every quotation of upstream's prose cites `README.upstream.md:<line>`, and `UPSTREAM.sha256`'s record moved from `README.md` to `README.upstream.md` with the **same digest**, so the integrity anchor is a rename, not a re-measurement. Nothing in `build.zig` reads either file, and no gate in this repository parses Markdown. |
| 20 | A standalone Nix and devenv delivery: `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc` | new files, no upstream effect | Five files upstream has no counterpart for. `package.nix` is one uncurried derivation over this tree's **own** `build.zig`, with `lib`/`stdenv`/`zig` injected and `linkage` selecting the artifact: it fetches nothing, downloads nothing at build time, adds no C flags, and writes nothing into the installed closure, because `build.zig` already installs the library, the header, `LICENSE.md`, `lib/pkgconfig/libutf8proc.pc`, the licence and provenance records and the Unicode fixtures. `flake.nix` names the variants (`packages.<system>.static` and `.shared`, `default` keeping upstream's static policy) from that one file; `devenv.nix` exposes the same two as lazy `outputs`, so entering the shell builds nothing. Upstream's `Makefile`, `CMakeLists.txt` and `build.zig` still describe their own projects exactly as before; nothing here replaces them. |
| 21 | A runtime-dispatch route: `runtime/graph.zig`, `runtime/library.zig`, and `-Druntime=true` | build-only, new files | `-Druntime=true` routes every native entry point through one process-lifetime table and links no native library into the module, while `-Dlinkage` still decides which artifact is built and installed — the two options are orthogonal, and a linked build is unchanged. `graph.zig` is the build half: `createModule(b, translate, target, optimize)` replaces `translate.createModule()` as the module bound to the facade's `c` import, and `createCoreModule(b, target, optimize)` supplies the `rt` import both configurations share. `library.zig` is the SDK's descriptor and the file another SDK replaces. Upstream has no equivalent; the loader core (`runtime/loader.zig`, `runtime/generate.zig`, `runtime/sync.c`, `runtime/sync.h`) is the driver's and is not authored here. Nothing about upstream's source, ABI, headers or data changes to make this work, and the linked route remains the default. |

Entries 16 and 17 were rewritten against the source. An earlier revision of this
table described a `utf8proc_paths` options module handing `tests.zig` a fixture
directory, and an embedded copy of the corpora inside the exercise; neither
exists in this package, and no such module is created by `build.zig`. The
correction is recorded in [`CHANGELOG.md`](CHANGELOG.md) entries 31 and 32.

**Entry 19 is the only documentation-only row in this table.**

**Entry 18 is the only deviation here that exists because of a target rather
than of upstream's build**, and it is recorded with its observed outcome: the
fifteen targets failed to translate before it
(`local://foundation-matrix-utf8proc-cross-original-summary.json`, run
`20261003-175929-14815-27659`, exit 1, `counts: {pass: 20, fail: 15, build_only:
18}`) and build after it
(`local://foundation-matrix-utf8proc-cross-corrected-summary.json`, run
`20261003-195739-62898-24523`, exit 0, all 53 `build.status: pass`). None of the
fifteen is a pass: each is a target with no runner here, so it is a
`build_only` row. The full record is `CHANGELOG.md` entry 38 and
[`FORK-NOTES.md`](FORK-NOTES.md) note 23.

The upstream tree is kept whole otherwise: `test/` (19 files), `bench/` (6),
`data/` (4), `cmake/`, `utils.cmake`, `Doxyfile`, `lump.md`, `MANIFEST`,
`NEWS.md`, `Makefile`, `CMakeLists.txt`, `libutf8proc.pc.in`,
`libutf8proc.pc.cmakein`, `appveyor.yml` and `.github/` all stay, so a re-sync
has something to diff against.

## What is carried but is not part of the package

`.github/workflows/zig.yml`, `make.yml`, `cmake.yml`, `ci-fuzz.yml`,
`.github/dependabot.yml` and `appveyor.yml` are **upstream's CI**, kept verbatim
for provenance and audit. They build upstream's CMake and Make projects and
upload to upstream's AppVeyor account; they are not retargeted at this fork's
infrastructure, not referenced by `build.zig`, not executed here, and not in
`.paths`. Upstream's own `zig.yml` pins Zig 0.16.0 and asserts
`zig-out/lib/libutf8proc.a`; that is upstream's evidence about upstream's CI on
upstream's runners (`ubuntu-latest`, `macOS-latest` only), and it is not a result
for this fork on any of its six cross targets.

These files **are** hashed in `UPSTREAM.sha256`, so an auditor can confirm they
arrived unmodified. Hashed is not the same as shipped.

This fork's own workflow is `.github/workflows/verify.yml`, which is a new file
and is also not in `.paths`.

The `consumer` job of that same workflow walks this repository and compares it
with `build.zig.zon`'s `.paths` in both directions, and the seven files above —
six of them upstream's CI, one this fork's own — are the complete, named list of
what it permits to be in the tree and absent from `.paths`. A file that is in the
tree and in no `.paths` entry fails it; so does a `.paths` entry with no file
behind it. The reason that check exists rather than being left to a reader is
that a *path* dependency cannot detect it: `consumer/` resolves this package by
relative path and therefore reads the working tree, so a package whose `.paths`
omitted `utf8proc.c`, `utf8proc.h` and `utf8proc_data.c` still resolved and still
built — and a dependent who *fetched* it would have received a package with no
library in it. That is fixed in `build.zig.zon`; this step is what keeps it
fixed.

**`.paths` is a closure over the tree, and it has outgrown "the seven files this
wave added".** `README.upstream.md`, `FORK-LICENSE.md`, `package.nix`, `flake.nix`,
`devenv.nix`, `devenv.yaml` and `.envrc` are still listed in `build.zig.zon`, and
they are no longer the whole of what the fork adds: `zig`, `runtime`, `tests.zig`,
`smoke.zig`, the three named `consumer/` files and `cross-test.profile.sh` are
listed beside them, so the workflow's two-directional comparison still has the
same seven-file CI carve-out and nothing else. That is a reading of
`build.zig.zon`, `.github/workflows/verify.yml` and the tree, not a gate result:
the check itself is the driver's, and no run has been made here.
`FORK-LICENSE.md` earns its entry rather than tidying the list, because
`build.zig` installs it — a fetched package without it fails at install time.

**One shipped path is neither upstream's nor the fork's, and the completeness
claim does not cover it.** `flake.lock` is listed in `.paths` beside the five
delivery files, and the driver wrote it into this tree on 2026-10-04. It is the
resolved form of the one input `flake.nix:15` declares — the same
`c7def046b9a883d46974757852106483d741586f` — plus the `narHash` for those bytes;
`FORK-LICENSE.md` excludes its terms and `NOTICE.md` inventories it as the
driver's, beside the reusable loader core under `runtime/`. **No `devenv.lock`
exists**, `devenv.yaml:19-22` records why, and none is listed, because a `.paths`
entry with no file behind it is itself a closure failure.

**Two completeness claims live in this file, and only one of them is measured.**
The claim about the pin — that every file upstream committed at `79cdd5ab…` is
present here with an identical digest and that the tree carries nothing else from
upstream — is an inventory of **immutable upstream bytes**, and it is the one
anchored twice, by the driver's 53-blob map and by the three git blob ids. The
package claim is a different statement, over bytes no upstream digest reaches: the
four upstream files this fork edits in place, the material this fork authored, and
the driver's metadata — `flake.lock`, and `runtime/loader.zig`,
`runtime/generate.zig`, `runtime/sync.c` and `runtime/sync.h`, which are shared
across SDKs rather than written here. "The closure is complete" is therefore a
statement about `build.zig.zon` against this tree; it is not a statement that
every byte in the package is pinned by something.

## Integrity

`UPSTREAM.sha256` holds **56** records — one `<hex>  <path>` line each, in
`sha256sum` format — covering every byte this fork carries that it did not
author. Check it with:

```
sha256sum -c UPSTREAM.sha256
```

50 records are utf8proc upstream bytes; 6 are Unicode files fetched by this fork.
Four upstream files are excluded with the reason stated in the record's own
header (`build.zig`, `build.zig.zon`, `.gitignore`, all edited in place, and
`README.md`, whose upstream bytes live on in `README.upstream.md`), and
their **upstream-pristine** digests, measured before the first edit, are:

| File | Upstream bytes | SHA-256 as imported |
|---|---|---|
| `build.zig` | 649 | `e5c3f68a41ed7462` (full value in [`NOTICE.md`](NOTICE.md)) |
| `build.zig.zon` | 275 | `84c041c2725795a7` (full value in [`NOTICE.md`](NOTICE.md)) |
| `.gitignore` | 490 | `40274c6530f9c9fd` (full value in [`NOTICE.md`](NOTICE.md)) |
| `README.md` | 5839 | `105b8cf218f3e149` (full value in [`NOTICE.md`](NOTICE.md)) |

I measured and recorded the full 64-hex values for those four while writing this
package and quote only the prefixes here, to keep a digest from being copied out
of this document and into a build script that never needed it.

**How the digests were produced.** Each file was read as raw bytes and hashed
with SHA-256 in a single pass over the byte string, with no encoding step and no
shell hashing command, on 2026-10-03; the same method for every record. No `git`
command produced any line of the record. A walk of the tree reported no symlinks
and no non-regular entries, so each record is the digest of that file's own bytes
rather than of a link target. No receipt in this package reports a version of the
hashing tool, so this states the method and claims no version of it.

**What the record establishes.** The bytes the build compiles, the headers it
installs, the upstream suite it runs, the fixtures its tests read and the licence
text it ships are the bytes this record pins, and any later edit to any of those
56 files fails the check loudly.

**What it does not establish.** It is not a signature, not a Git object id, and
not itself a re-derivation from commit `79cdd5ab…`. It establishes that
identity by *agreement* with two independent measurements recorded elsewhere in
this package: the driver's 53-blob per-file SHA-256 map from
`git archive --format=tar 79cdd5ab…`, against which all 53 upstream records
match, and the git blob SHA-1 table for the three compiled files. The
`testdata/` records have no such second measurement and cannot have one — see
[the fixtures](#the-conformance-fixtures-in-testdata) for what anchors them
instead.
**Status: OBSERVED.** These digests were first measured and not validated by a
gate; the driver has since run the check. `sha256sum -c UPSTREAM.sha256` exits 0
with 56 `OK` lines — `local://foundation-matrix-utf8proc-provenance-checksums.log`
— and [`README.zig.md`](README.zig.md#verification-status) records it. The
second measurement above is no longer only a measurement: the pinned-blob
comparison has been run too, and `local://foundation-matrix-source-integrity.json`
records `utf8proc.files_checked: 53` with
`differences: [".gitignore", "build.zig", "build.zig.zon"]` — exactly the three
files excluded from the record, and nothing else. Same record: 10 429 protected
files checked, no differences.

**Those receipts predate entry 19 and this is stated rather than left to be
re-discovered.** They were observed on 2026-10-03 against the tree as it stood
then, when the differences were exactly `.gitignore`, `build.zig` and
`build.zig.zon` and `README.md` was still upstream's bytes. Entry 19 replaced the
contents of `README.md` afterwards, so the expectation — **not an observation, and
no run has been made** — is that re-running the same pinned-blob comparison now
reports `README.md` as a fourth difference and still 10 429 protected files with
no differences, and that `sha256sum -c UPSTREAM.sha256` still prints 56 `OK`
lines, since the record follows the bytes to their new path. Until the driver runs
both again, the receipts above stand as evidence for the tree that existed when
they were taken and for nothing after it.

**This is the driver's gate, not this repository's workflow job, and the two are
not the same thing.** The `integrity` job in `.github/workflows/verify.yml`
re-derives every upstream record from the pinned commit's own blob —
`git cat-file blob 79cdd5ab…:<path>` — compares that digest to the record, and
compares the file on disk to the same digest. Three rules run over the tree: a
record's digest must equal the pinned blob's; a recorded file must have those
bytes on disk; and neither the pinned tree nor the record may have an unaccounted
remainder. The four files this fork edits in place
(`build.zig`, `build.zig.zon`, `.gitignore`, `README.md`) are the declared
exception to the first two rules, and they are **settled before the record is
consulted**: no digest is required of them, and the requirement is the opposite
one, that their bytes do differ from the pinned blob. A file declared edited
whose bytes are still upstream's fails there. Two carried paths sit outside the
pinned tree by design — the `testdata/` fixtures and `README.upstream.md` — and
only those two are exempt from the remainder rule. **That CI job has not run**:
it needs a checkout of this repository on a CI runner, which has not happened.
What has run is the equivalent check outside it, whose result is recorded above.
The job remains written so the check is reproducible by anyone with a clone; its
existence is not evidence that it passed.

**The requirement entry 19 placed on that job is met, and it was three defects
rather than one.** Replacing `README.md`'s contents broke the step in three
independent ways at once, and any one of them would have failed the job, so the
fix was not the one-liner this section first recorded:

1. the declared edited-in-place set still named three files, so `README.md` fell
   through to the divergence rule and was flagged as changed from the pinned blob;
2. the step required a digest for every path in the pinned tree, while
   `UPSTREAM.sha256`'s header deliberately excludes exactly those four — so the
   excluded paths failed as "upstream's tree carries it and `UPSTREAM.sha256`
   records nothing for it";
3. the remainder rule exempted only `testdata/`, so `README.upstream.md` — which
   exists precisely to carry upstream's README after its own path was replaced —
   failed as a recorded path the pinned tree does not contain.

The step now names all four, settles them before the record is consulted, exempts
`README.upstream.md` beside the fixtures, and counts the edited set from the
declaration rather than from the divergences it happens to produce. All of that is
a reading of the file; the step is unobserved, and if it ever fails the reason
should now be a real divergence rather than this bookkeeping.

**It is also the only step anywhere in this package that reads git history**, and
it needs it: it checks out with `fetch-depth: 0` and fails with a message rather
than passing quietly when the pinned commit is absent. A source tarball, a
vendored copy and a shallow clone therefore cannot run it. Nothing in
`build.zig` invokes `git`, so a fetched package with no `.git` still builds, and
every other gate in that workflow works without history. That split is
deliberate and is the same one `htscodecs` makes with its `provenance-history`
step.

## Synchronising with a new upstream release

1. Check out the new tag upstream and read `UTF8PROC_VERSION_MAJOR/MINOR/PATCH`
   in `utf8proc.h` and the literal returned by `utf8proc_unicode_version()` in
   `utf8proc.c`. Those two strings are the facts; the tag spelling is not.
2. Re-fetch the five `testdata/` files from the new Unicode revision and
   re-derive `Lowercase.txt` and `Uppercase.txt` with the **same** extraction
   rule from `data/Makefile`. A UCD bump moves the section line numbers, the
   range counts and the code-point totals recorded above.
3. Confirm `data/Makefile`'s `UNICODE_VERSION` and `utf8proc.c`'s literal still
   agree, and update the build's `-DUNICODE_VERSION` with them. Their
   disagreement is a real upstream bug that `test/misc.c` is written to catch.
4. Have the driver re-measure `git archive --format=tar <new-pin> | sha256sum`
   and its per-file blob map, then re-compare it against `UPSTREAM.sha256` the
   way [the archive receipt](#the-archive-receipt-and-a-per-file-cross-check-against-it)
   describes. That comparison is cheap, it is what proves a re-sync landed the
   intended tree, and it caught nothing only because the current tree is already
   exact.
5. Regenerate `UPSTREAM.sha256` over the same path set with the same method, and
   update the record count and the exclusions in its header.
6. Re-read the licence: a new release could add or reword a grant in
   `LICENSE.md`, and a new generated table could acquire a notice that
   `utf8proc_data.c` does not have today.
7. Bump `.version` in `build.zig.zon`, update the pin in this file and in
   `README.zig.md`, and add one numbered `CHANGELOG.md` entry.
8. Re-run every gate. Nothing in this package carries a result forward across a
   version bump.

9. Re-check the three option bits whose reach is narrower than the header suggests
   — [above](#three-option-bits-whose-reach-is-narrower-than-the-header-suggests).
   A release that branches on `UTF8PROC_STABLE`, that moves the invalid-options
   check out of `utf8proc_decompose_custom`, or that reads `UTF8PROC_STRIPCC`
   anywhere but `utf8proc_normalize_utf32`, makes the matching statement false,
   and `README.zig.md`, `zig/root.zig` and `CHANGELOG.md` entries 36 and 51 have
   to be corrected with them.

## See also

* [`NOTICE.md`](NOTICE.md) — the per-file licence inventory: which of the three
  grants reaches which file, which fork-owned files are under the fork's own MIT
  grant in [`FORK-LICENSE.md`](FORK-LICENSE.md) and which are not under any
  grant, and every file this fork adds or edits.
* [`FORK-LICENSE.md`](FORK-LICENSE.md) — the MIT grant this fork asserts over its
  own files, its scope, and the three things it excludes: upstream's bytes,
  `utf8proc_data.c`, and the fixtures.
* [`UPSTREAM.sha256`](UPSTREAM.sha256) — the integrity record itself.
* [`README.zig.md`](README.zig.md) — how to build, import and call the package,
  and where the gate matrix lives.
* [`CHANGELOG.md`](CHANGELOG.md) — numbered fork-only divergences.
* [`FORK-NOTES.md`](FORK-NOTES.md) — the problems met while preparing this
  package, and what was decided.
