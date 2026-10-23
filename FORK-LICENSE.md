# FORK-LICENSE.md

**MIT** — `SPDX-License-Identifier: MIT`

Copyright holder: `the utf8proc Zig SDK fork authors`. No upstream author is credited for fork work.

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

## Scope

This grant covers the fork-authored files and portions listed below.

| Paths |
|---|
| `zig/root.zig`, `zig/api_exercise.zig`, `zig/translate.h` |
| `tests.zig`, `smoke.zig` |
| `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig` |
| `README.md`, `README.zig.md` |
| `runtime/graph.zig`, `runtime/library.zig` |
| `NOTICE.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `FORK-NOTES.md`, `CHANGELOG.md`, `FORK-LICENSE.md` |
| `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc` |
| `build.zig`, `build.zig.zon`, `.gitignore` — fork-added build steps/options, `.paths` entries, and ten appended ignore lines only |
| `cross-test.profile.sh` |

The mixed files have no SPDX identifier; a file-level identifier would also cover upstream bytes. Wholly fork-authored files use `SPDX-License-Identifier: MIT`.

## Exclusions

- Upstream files and upstream bytes in `README.upstream.md`, `build.zig`, `build.zig.zon`, and `.gitignore` remain under the grants in `LICENSE.md` (two MIT grants and the Unicode data grant).
- `utf8proc_data.c` retains its Unicode data grant in `LICENSE.md`.
- The five `.txt` files in `testdata/` use Unicode License V3 in `testdata/Unicode-License-V3.txt`.
- `runtime/loader.zig`, `runtime/generate.zig`, `runtime/sync.c`, and `runtime/sync.h` are reusable loader files, not fork-authored; this grant states no terms for them.
- `flake.lock` is the dependency lock for `flake.nix`, listed in `build.zig.zon`, and is not fork-authored.
- Unicode trademarks remain subject to the Unicode Terms of Use and are not used as marks.
