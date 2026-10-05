# FORK-LICENSE.md — the licence this fork asserts over its own files

`LICENSE.md` is upstream's file, byte for byte, and holds three grants this fork
cannot rewrite. `NOTICE.md` is the per-file inventory. This file supplies the
third thing: the licence this fork asserts over the files this fork wrote.

## The grant

**MIT**, SPDX identifier `MIT`. Chosen by the owner of this working copy on
**2026-10-04** as this project's licence for fork-authored additions, matching its
primary upstream term — the MIT "expat" grant at `LICENSE.md:1-28`, restated in
prose at `README.upstream.md:23-28`. This is a direct owner authorization for this
repository, not an inference from the upstream terms and not a grant by any
upstream author.

```
MIT License

Copyright (c) 2026 the utf8proc Zig SDK fork authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`the utf8proc Zig SDK fork authors` is a collective holder: no individual
identity was supplied and none is invented, and no upstream author is credited
with fork work. A redistribution that needs a named holder gets one from the
owner.

Every other role was given this identifier: `MIT` is the SPDX identifier for
newly authored source and build files in this package.

## Scope

| Path | Covers |
|---|---|
| `zig/root.zig`, `zig/api_exercise.zig`, `zig/translate.h` | the typed facade, the API exercise, the translation aggregate header |
| `tests.zig`, `smoke.zig` | the behavioural tests and the smoke program |
| `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig` | the independent path-dependent consumer package |
| `README.md`, `README.zig.md` | the fork's own documentation |
| `runtime/graph.zig`, `runtime/library.zig` | this fork's half of the runtime route: the build wiring and the SDK's descriptor |
| `NOTICE.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `FORK-NOTES.md`, `CHANGELOG.md`, `FORK-LICENSE.md` | this fork's own records, this file included |
| `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc` | the standalone Nix and devenv delivery this fork wrote; `flake.lock` travels beside them and is excluded below |
| `build.zig`, `build.zig.zon`, `.gitignore` | **the fork-authored portions only**: the added steps and options, the `.paths` additions, the ten appended ignore lines. Upstream's bytes inside them keep upstream's terms |
| `cross-test.profile.sh`, `.github/workflows/verify.yml` | this fork's cross-test profile and its own CI wiring. Upstream's `.github/**` workflows are upstream's |

The three mixed files carry **no** SPDX identifier, and that is what this scope
implies: a single-file identifier there would describe upstream's bytes as this
fork's. Every wholly fork-authored file carries `SPDX-License-Identifier: MIT`.

## Exclusions

* Every upstream file, and the upstream bytes inside `README.upstream.md`,
  `build.zig`, `build.zig.zon` and `.gitignore`: the two MIT grants and the
  Unicode data grant in `LICENSE.md`.
* `utf8proc_data.c`, which `LICENSE.md:52-93` names and which therefore keeps its
  own Unicode data grant.
* The five `.txt` files in `testdata/`, under **Unicode License V3**, whose text
  ships beside them in `testdata/Unicode-License-V3.txt`. This fork does not
  restate, paraphrase, relicense or strip their notices.
* `runtime/loader.zig`, `runtime/generate.zig`, `runtime/sync.c` and
  `runtime/sync.h`, which are the driver's reusable loader core rather than this
  fork's files. The driver authors and distributes them; this grant says nothing
  about their terms.
* `flake.lock`, which is the driver's lock for the one input `flake.nix:15`
  declares, not a file this fork wrote. The driver wrote it into this tree on
  2026-10-04, after the delivery files beside it, and `build.zig.zon` lists it
  so a fetched copy resolves that revision rather than choosing one for itself.
  Shipping a file and asserting a licence over it are separate acts, and only
  the first happened here.
* Unicode trademarks, reserved by the Unicode Terms of Use and used here by
  nobody as a mark.

## Obligations

MIT requires the copyright notice and the permission notice above to travel with
every copy of the fork-authored material. Both are in this file, which the Nix
output installs beside the library under `share/licenses/utf8proc/`. MIT requires
no `NOTICE` file, no change statement, no attribution list and no patent grant,
and none is invented here.

## Status

`SOURCE-CONFIRMED` for the terms quoted from `LICENSE.md` and for the owner's
authorization of 2026-10-04. No gate has observed this grant: whether the SPDX
headers this identifier was supplied for are present and correct in every
fork-authored file is a driver check, and this package's verification table
carries no result for it.