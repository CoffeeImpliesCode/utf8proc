# NOTICE

`LICENSE.md` retains upstream's two separate MIT/expat grants and its Unicode data grant. `testdata/Unicode-License-V3.txt` contains the current Unicode terms for the added data files.

## Licence by path

| Paths | Terms |
|---|---|
| Upstream library, headers, build files, tools, tests, and documentation, including `README.upstream.md` | The two MIT/expat grants in `LICENSE.md` |
| `test/**` (19 files), `data/**` (4), `bench/**` (6) | The MIT/expat grants; these 29 files have no per-file notice |
| `utf8proc_data.c` | Both MIT/expat grants and the separate Unicode data grant in `LICENSE.md` |
| `testdata/NormalizationTest.txt`, `GraphemeBreakTest.txt`, `DerivedCoreProperties.txt`, `Lowercase.txt`, `Uppercase.txt` | Unicode License V3 in `testdata/Unicode-License-V3.txt`; each data file carries its notice |
| Fork-authored paths listed below | MIT grant in `FORK-LICENSE.md` |
| Fork additions to `build.zig`, `build.zig.zon`, and `.gitignore` | MIT; upstream bytes in those files remain under upstream's grants |
| `runtime/loader.zig`, `runtime/generate.zig`, `runtime/sync.c`, `runtime/sync.h`, and `flake.lock` | Not fork-authored; this notice states no terms for them |

The upstream C library, headers, tables, tests, tools, and build files are covered by the package-level MIT grants. The second MIT grant is a separate copyright, not a replacement for the first.

- `LICENSE.md`: `Copyright © 2014-2021 by Steven G. Johnson, Jiahao Chen, Tony Kelman, Jonas Fonseca, and other contributors listed in the git history.`
- `LICENSE.md`: `Copyright (c) 2009, 2013 Public Software Group e. V., Berlin, Germany.`
- `LICENSE.md`: `Copyright (c) 1991-2007 Unicode, Inc. All rights reserved. Distributed under the Terms of Use in http://www.unicode.org/copyright.html.`

`utf8proc_data.c` has no copyright or licence notice of its own. The reference in `utf8proc.c` to a notice in that file is dangling; its Unicode terms are recorded in `LICENSE.md`. The data file remains unmodified, and its grant text is shipped unchanged.

The five Unicode data files are not upstream files and are not covered by upstream's grants. Their headers state:

> © 2026 Unicode®, Inc.  
> Unicode and the Unicode Logo are registered trademarks of Unicode, Inc. in the U.S. and other countries.  
> For terms of use and license, see https://www.unicode.org/terms_of_use.html

`testdata/Unicode-License-V3.txt` carries `Copyright © 1991-2026 Unicode, Inc.` Unicode License V3 and the older Unicode grant in `LICENSE.md` are different texts; the older grant covers `utf8proc_data.c`, and License V3 covers the five `testdata/` files. Unicode trademarks remain reserved and are not used as marks here.

## Fork-authored paths

The owner authorized MIT for the following fork-authored files. Copyright holder: `the utf8proc Zig SDK fork authors`; no upstream author is credited for fork work.

- `zig/root.zig`, `zig/api_exercise.zig`, `zig/translate.h`, `tests.zig`, `smoke.zig`
- `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig`
- `runtime/graph.zig`, `runtime/library.zig`
- `README.md`, `README.zig.md`, `NOTICE.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `FORK-NOTES.md`, `CHANGELOG.md`, `FORK-LICENSE.md`
- `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`, `cross-test.profile.sh`

`README.upstream.md` is upstream's README, preserved unchanged under upstream's terms. `README.md` is fork-authored. The fork grant covers only the fork-authored portions of `build.zig`, `build.zig.zon`, and `.gitignore`; it does not cover upstream bytes in those files, `utf8proc_data.c`, or the five Unicode data files. See `FORK-LICENSE.md` for the grant scope and exclusions.
