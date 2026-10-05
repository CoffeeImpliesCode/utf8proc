//! Build for the `utf8proc` package: upstream's C core compiled from this
//! repository, plus a Zig facade over the translated public header.
//!
//! Run `zig build --help` for the steps and options. The shape is:
//!
//!   zig build               install the library, `include/utf8proc.h`, the
//!                           licence and data-term records, the Unicode
//!                           fixtures and `lib/pkgconfig/libutf8proc.pc`, and
//!                           compile the smoke program (not run). The library
//!                           is `libutf8proc.a` unless `-Dlinkage=dynamic`
//!                           says otherwise
//!   zig build test          run the behavioural tests for the selected target
//!   zig build smoke         run the smoke program
//!   zig build upstream-test build and run upstream's own C test programs
//!   zig build consumer      build the `consumer/` package against
//!                           `dep.module("utf8proc")`, and run it when this
//!                           host can execute the selected target
//!   zig build check         compile everything for the six required cross
//!                           targets, running nothing
//!
//!   cross-test              the same `test` step, for the published
//!                           53-platform Zig 0.16.0 Tier 1/2 table rather than
//!                           the host alone. `cross-test` discovers
//!                           `cross-test.profile.sh` from the package root,
//!                           runs `zig build test -Dtarget=TARGET` for each of
//!                           them, and executes the binary where a runner
//!                           exists and records explicit `build_only` coverage
//!                           where one does not. `test` is what the harness
//!                           reaches for, and it builds the same graph and the
//!                           same test binary for whatever `-Dtarget` says:
//!                           nothing in `build()` narrows it to the host, and
//!                           the `check` matrix below is compile-only and is
//!                           not a substitute for it.
//!
//! Options:
//!
//!   -Doptimize=...          standard; the gates use Debug and ReleaseSafe
//!   -Dtarget=...            standard; when one is named, `check` checks that
//!                           single target instead of the six
//!   -Dlinkage=static        a static archive, `libutf8proc.a`. This is the
//!   -Dlinkage=dynamic       default and is exactly what this package produced
//!                           before the option existed, so passing nothing
//!                           changes nothing. `dynamic` builds a real shared
//!                           object carrying upstream's ABI soname, with the
//!                           core compiled PIC and with upstream's own export
//!                           macro on the library's compile line and off every
//!                           consumer's. A target with no dynamic linker is
//!                           refused rather than answered with an archive
//!   -Druntime=true          the facade dispatches native calls through one
//!                           process-lifetime table an explicit `load` fills,
//!                           and the module links no native library at all.
//!                           Default false, and orthogonal to `-Dlinkage`,
//!                           which still decides which artifact is built and
//!                           installed -- so the library this build produces is
//!                           still available to point a provider at
//!
//! Nothing is downloaded and nothing is installed behind the caller's back.
//! There is no CMake, autotools, meson, Make or download step anywhere in this
//! file, and the only compiled library source is the one translation unit
//! named in `core_sources`.
//!
//! ## Upstream's own `build.zig`, and what this file adds
//!
//! Upstream 2.12.0 ships a `build.zig` at the repository root (#351) and this
//! file replaces it in place rather than relocating the tree or adding a
//! second copy of upstream. Upstream's version is 26 lines: one module, one
//! static library, one `installHeader`, one source file and one flag. What is
//! kept here is upstream's shape and upstream's names -- the library is called
//! `utf8proc`, `zig-out/lib/libutf8proc.a` is what upstream's own CI asserts
//! (`.github/workflows/zig.yml:29`), and the single compile flag is upstream's
//! `-DUTF8PROC_STATIC` (its `build.zig:23`). What is added is the closure a
//! package needs and upstream's script does not have: the module a dependent
//! imports, the translation, the test and smoke and exercise roots, the nine
//! upstream C test programs, the consumer step and the six-target `check`. Each
//! of those is a step below; none of them changes a byte of `utf8proc.c`,
//! `utf8proc_data.c` or `utf8proc.h`.
//!
//! `FORK-NOTES.md` records this as a build-only deviation from upstream's
//! script, item by item; `UPSTREAM.md` records the pin.
//!
//! ## What is compiled
//!
//! The core is three files and one translation unit. `utf8proc.c` has exactly
//! two `#include`s: `utf8proc.h` (`:44`) and `utf8proc_data.c` (`:53`). The
//! data file is a quoted include, so it resolves relative to the directory of
//! `utf8proc.c`; keeping the two adjacent, which upstream already does, is what
//! makes that resolution correct, and `core_sources` therefore names
//! `utf8proc.c` alone. There is no `config.h`, no `configure` output and no
//! generated header: the generated tables are committed, so there is nothing to
//! generate per target.
//!
//! `test/`, `bench/`, `data/` and the three upstream build systems travel in the
//! package and none of them is executed. `bench/icu.c` links ICU4C and
//! `bench/unistring.c` links libunistring, neither of which is in scope;
//! `data/data_generator.jl` needs `julia`; `test/install_uninstall.sh` drives
//! `make install`. What `upstream-test` does build is named in `upstream_tests`.
//!
//! ## What this package registers, and what it installs
//!
//! Two routes are published, and they are different kinds of thing:
//!
//!   * `dep.module("utf8proc")`: the Zig facade, `zig/root.zig`. This is the one
//!     registered module. It carries `link_libc`, the translated header as the
//!     `c` import, the package root on its own include path, and the compiled
//!     archive, so a dependent that adds this module needs nothing further --
//!     no second `dep.artifact("utf8proc")`, no `-I`, no `-DUTF8PROC_STATIC` --
//!     to call the facade or to reach `utf8proc.c`.
//!   * `dep.artifact("utf8proc")`: the compiled library, in whichever
//!     `-Dlinkage` selected, for a dependent that links it into its own C or
//!     Zig build. Nothing in this package's own consumer asks for it, which is
//!     what makes the module route's self-containment a fact rather than an
//!     assertion.
//!
//! The translated header is imported, never registered as a module of its own.
//! `translate.createModule()` rather than `translate.addModule("c")` is
//! deliberate: registering `c` would make `dep.module("c")` resolve and hand a
//! dependent the same declarations with no library behind them, which is a
//! reachability a dependent cannot tell from support. `c` on the facade is the
//! supported way in, and it carries the facade's own linkage.
//!
//! `b.installArtifact` publishes the compiled library -- `zig-out/lib/libutf8proc.a`
//! by default, and under `-Dlinkage=dynamic` the shared object with the soname
//! and version symlinks -- together with `zig-out/include/utf8proc.h`, which
//! `installHeader` marks as travelling with the artifact so a dependent that
//! links the library finds the header without reaching into this repository.
//! `LICENSE.md` is installed beside them: `utf8proc_data.c` is compiled into
//! the archive and carries the separate Unicode data terms, so the licence text
//! belongs next to the binary.
//!
//! ## What `-Dlinkage` changes, and what it does not
//!
//! Two options, one default, and the default is the only change-free one:
//!
//!   * `static` (default) compiles `libutf8proc.a` with the compile line this
//!     package has always used: `-std=gnu11`, `-D UTF8PROC_STATIC=1`,
//!     `link_libc`, and no PIC decision of its own. `Module.pic` is `null`
//!     here rather than `false` on purpose -- `null` emits no `-fPIC` or
//!     `-fno-PIC` at all (`std/Build/Module.zig:554`, `addFlag(zig_args, m.pic,
//!     "-fPIC", "-fno-PIC")`, which emits nothing for a null flag), so
//!     the static command line is byte-for-byte the one that existed before the
//!     option, and `-Dlinkage=static` is a no-op rather than a change.
//!   * `dynamic` compiles every object `-fPIC` and links a shared object
//!     carrying upstream's own ABI version, `Makefile:25-27`'s `MAJOR 3`,
//!     `MINOR 3`, `PATCH 0`: `libutf8proc.so.3.3.0` with the soname
//!     `libutf8proc.so.3` and a `libutf8proc.so` link beside it on ELF, which
//!     is exactly what upstream's own `SHLIB_VERS_EXT = so.$(MAJOR).$(MINOR).
//!     $(PATCH)` and its `libutf8proc.so.$(MAJOR)` clean rule name
//!     (`Makefile:35,57-61`); `libutf8proc.3.3.0.dylib` carrying the install
//!     name `libutf8proc.3.dylib` on Darwin, with `libutf8proc.dylib` beside it,
//!     where the major-versioned name upstream's `SHLIB_VERS_EXT = $(MAJOR).dylib`
//!     produces is the link rather than the file; and `utf8proc.dll` with its
//!     `utf8proc.lib` import library on Windows, where a DLL has no soname.
//!
//! The three numbers are upstream's *ABI* version and answer a different
//! question from the API version 2.12.0 above; `utf8proc.h:56-68` says so and
//! `MANIFEST` carries the same 3/3/0.
//!
//! Nothing else differs. The same three core sources, the same header, the
//! same `-std=gnu11`, the same translation, the same facade, the same tests,
//! the same smoke program, the same nine upstream C test programs and the same
//! installed header are built for both linkages; the artifact's *kind* is the
//! only thing `-Dlinkage` selects. In particular no source is compiled out for
//! the shared object and no header is substituted for it.
//!
//! **A dynamic request a target cannot carry is refused, not substituted.**
//! `sharedObjectRefusal` is the whole of that rule and `deliveredLinkage` is
//! where it is applied. WASI has no dynamic linker at all --
//! `std.Target.DynamicLinker.kind` is `.none` for it -- so
//! `-Dlinkage=dynamic -Dtarget=wasm32-wasi` stops the build with the target's
//! name and the reason instead of handing back an archive, and every gate run
//! afterwards then measures the library the caller asked for rather than one
//! this build chose for them. With no `-Dlinkage` at all the default is
//! `static`, so the same target is an ordinary static archive and nothing is
//! refused: that is the difference between a default and a substitution. A
//! default is what the caller asked for by saying nothing; a substitution is a
//! different answer to a question that was answered.
//!
//! **Which targets are in that class is read from two facts, not one.**
//! `targetCarriesSharedObject` treats a Windows target as able to carry a shared
//! object even though `std.Target.DynamicLinker.kind` answers `.none` for it
//! (`lib/std/Target.zig:2380`): a PE/COFF image has no interpreter path
//! because its imports are resolved by the loader inside the OS, not because
//! Windows cannot load a DLL. Collapsing the two facts into one predicate would
//! refuse `-Dlinkage=dynamic` on this package's own `x86_64-windows-gnu` matrix
//! cell, a target that delivers `utf8proc.dll` plus its import library as a
//! matter of course. WASI gets no such pass: a `.wasm` module has no loader to
//! resolve its imports at load time, so a shared object there is still a file
//! nothing can load.
//!
//! **The refusal is immediate for a target the caller named, and a failing
//! step for a row nobody named.** `-Dtarget=wasm32-wasi -Dlinkage=dynamic` is
//! refused inside the published graph, before any step runs. Inside
//! `zig build check -Dlinkage=dynamic` the WASI row is one the caller did not
//! name, and it becomes an explicit `addFail` step carrying the same reason
//! while the other five rows are still compiled; nothing at all is built for
//! that row, and it is not dropped either, so it cannot pass by omission. A
//! native `zig build install` does not depend on `check` and is never poisoned
//! by a row it never compiles.
//!
//! ## `-Druntime=true`: the dispatch, and what it is not
//!
//! Orthogonal to `-Dlinkage`. What changes is what the facade's `c` import is
//! bound to and what the module links, not what this build produces:
//!
//!   * linked, the default: `c` is `translate.createModule()` and the module
//!     links the compiled library. `rt` is added beside it from the graph's
//!     `createCoreModule`, because a linked build has no dispatch to carry
//!     `LoadSource` and `LoadError` and `zig/root.zig:136,142` takes those two
//!     public types from the core module directly.
//!   * `-Druntime=true`: `c` is the generated dispatch, built by the graph's
//!     `createModule` from *this* `TranslateC` step -- so the types and
//!     constants behind `pub const c` are the translated ones rather than a
//!     second, nominally distinct set -- and nothing at all is linked into the
//!     module, neither this tree's library nor an installed one, because the
//!     symbols are meant to arrive through the platform loader when the caller
//!     names a provider with an explicit `load`. Linking the archive as well
//!     would make the linker demand every entry point before `load` is ever
//!     called, and the runtime route would quietly be a linked one.
//!
//! The library is still built and installed under `-Druntime=true`, so the
//! provider a caller names need not be the one this build produced.
//!
//! `runtime/graph.zig` is the API role's file and the only one this script
//! imports; beside it are this SDK's descriptor `runtime/library.zig` and the
//! reusable loader core -- `runtime/loader.zig`, `runtime/sync.c`,
//! `runtime/sync.h` and `runtime/generate.zig`. All of them travel in one
//! `.paths` entry, because a fetched copy that has the graph without the core
//! is a route it cannot take.
//!
//! ## The export macro is a build-side switch, and it splits
//!
//! `utf8proc.h:123-139` resolves `UTF8PROC_DLLEXPORT` from two macros:
//! `UTF8PROC_STATIC` makes it empty, and without it a `_WIN32` declaration
//! becomes `__declspec(dllexport)` when `UTF8PROC_EXPORTS` is defined and
//! `__declspec(dllimport)` when it is not. That makes the correct value a
//! function of what is being compiled, not of the platform alone, so this file
//! carries two lists and one rule -- upstream's own split, the one
//! `CMakeLists.txt:34,40` draws between a `PUBLIC` and a `PRIVATE`
//! definition:
//!
//!   * `libraryMacros` goes on the C core's own compile line. Static defines
//!     `UTF8PROC_STATIC`, so the archive's declarations are unqualified;
//!     dynamic defines `UTF8PROC_EXPORTS`, so under `_WIN32` the functions
//!     *and* the exported data symbol `utf8proc_utf8class` (`utf8proc.c:56`)
//!     carry `__declspec(dllexport)` and the DLL exports them, while on ELF and
//!     Darwin the same macro is `__attribute__((visibility("default")))`
//!     (`utf8proc.h:135`), which is upstream's own answer for a shared build.
//!   * `consumerMacros` goes on every line that *consumes* the library: the
//!     translation (`TranslateC.defineCMacro`), the preprocessing line on the
//!     `preprocessed` route, and the nine upstream C test programs, which
//!     include `utf8proc.h` and link the artifact. Static defines
//!     `UTF8PROC_STATIC` there too, because `utf8proc.h:123-126` is what leaves
//!     a Windows consumer's declarations unqualified. Dynamic defines
//!     *neither*, because the empty define is the correct answer there:
//!     `dllimport` on Windows, and the default-visibility attribute everywhere
//!     else.
//!
//! `UTF8PROC_EXPORTS` is never on a consumer's line. A C consumer that defines
//! it asks for its own translation unit to export those symbols, which is the
//! opposite of consuming them -- upstream's `libutf8proc.pc.in` and
//! `libutf8proc.pc.cmakein` both put it in `Cflags`, and `installPkgConfig` below
//! corrects exactly that one line, per linkage, from the header's own logic.
//!
//! ## What is installed, and the pkg-config file
//!
//! The install closure is the whole one, not the header and the archive:
//!
//!   * `include/utf8proc.h`, the entire public API, marked as travelling with
//!     the artifact by `installHeader`.
//!   * `lib/` -- `libutf8proc.a`, or the shared object with its soname and
//!     version links under `-Dlinkage=dynamic`.
//!   * `lib/pkgconfig/libutf8proc.pc`, generated here from upstream's own
//!     `libutf8proc.pc.in` template, because the build graph owns where the
//!     library lands and metadata that restated it would be a second place for
//!     it to be wrong. It is *relocatable*: `prefix` is `${pcfiledir}/../..`, so
//!     the installed tree can be moved and the file still describes the copy it
//!     travels with. Its `Cflags` is variant-dependent, as the two sections
//!     above derive.
//!   * `LICENSE.md` at the root, and under `share/licenses/utf8proc/`: that
//!     same `LICENSE.md` (upstream's two MIT grants and the separate Unicode
//!     Terms of Use in its section 3), this fork's `FORK-LICENSE.md`, `NOTICE.md`,
//!     `UPSTREAM.md` and `CHANGELOG.md`, and `testdata/Unicode-License-V3.txt`,
//!     which governs the fixtures installed beside it.
//!   * `share/utf8proc/testdata/`, the five committed Unicode corpora, named one
//!     by one in `fixtures` and installed from this tree rather than fetched --
//!     `data/Makefile:44-48` downloads them with curl and deletes them on
//!     `clean` (`:58-60`), which is the rule this package does not follow.
//!
//! This graph owns all of it, and a packaging script that installs its own copy
//! of any of it is installing a second, differently-derived answer to the same
//! question. `package.nix` presently writes its own `libutf8proc.pc` and its own
//! licence and fixture trees with `sed` and `install`; that is exactly the
//! duplication this graph removes, and the packaging side has to drop it in the
//! same change or the two would both write `$out`.
//!
//! ## Who preprocesses `zig/translate.h`
//!
//! `zig translate-c` reads C with Aro, and Aro preprocesses as well as parses,
//! so the translation unit can be read either way round: Aro can do both jobs,
//! or the target's own C preprocessor -- the compiler this build script is
//! running -- can do the first and Aro the second. `translationRoute` says
//! which target gets which, and `preprocessedHeader` is the extra front end.
//! Both routes read this repository's own `utf8proc.h`, with this repository's
//! root as the include path and the linkage's own consumer macros defined from
//! the one `consumerMacros` list the translation and every C consumer of this
//! package's library read, so the route decides *which preprocessor has to
//! understand the target's C library* and nothing else about the translation.
//!
//! It is a real per-target decision and not a uniform one. Aro translates the
//! header for most of the published 53-platform matrix with no step in front
//! of it -- `OBSERVED`: 20 runtime passes and 18 build-only cells in run
//! `20261003-175929-14815-27659` of `cross-test` -- and the target's own
//! preprocessor is the front end that cannot read glibc's output *for this
//! header*: `utf8proc.h:79` includes `<stdlib.h>`, `stdlib.h:60` includes
//! `<bits/floatn.h>`, and `bits/floatn-common.h:213-215`, `:250-252`,
//! `:267-269` and `:284-286` typedef `_Float32`, `_Float64`, `_Float32x` and
//! `_Float64x` under `!__GNUC_PREREQ (7, 0)`, a guard that holds for Zig's
//! Clang because it defines `__GNUC__` as 4. Aro holds those names as builtin
//! type specifiers of its own, so on a GNU-libc target the preprocessed
//! translation would stop on each of them instead of succeeding. `pcre2`'s
//! `aggregateRoute` records the same observation for `<inttypes.h>`; this is
//! that rule, for the same reason.
//!
//! `zig/translate.h` includes `<utf8proc.h>` with this repository's root on the
//! include path, so the translated declarations are the ones this graph
//! compiles rather than whatever `utf8proc.h` happens to be installed on the
//! build machine (`WISDOM.md` W14). On the `preprocessed` route that include
//! path belongs to the preprocessing step instead -- by the time the translator
//! reads the file there is no `#include` left in it -- and on the `aro` route it
//! belongs to the translation. Both steps are given it anyway, so the two
//! routes cannot drift into resolving different headers.
//!
//! ## Why there is no `b.systemIntegrationOption`
//!
//! This wave adds no system-library mode, so the rule is recorded as **NOT
//! APPLICABLE** rather than claimed as satisfied. The reason is a specific
//! version fact rather than a preference. Debian and its derivatives ship a
//! real compiled `libutf8proc`, at 2.5.0 through 2.11.3 depending on the suite,
//! and `utf8proc_free` -- the only correct way to release the memory
//! `utf8proc_map` and the `utf8proc_NF*` family return -- **does not exist
//! before 2.12.0**. `utf8proc.h:802-808` documents it as the deallocator and
//! `utf8proc.c:845` implements it as `free`; on an installed 2.11.3 the symbol
//! is absent. A mode that translated this package's bundled 2.12.0 header and
//! linked an installed 2.11.3 library would therefore compile and then fail to
//! link, or -- with a shim -- would compile and free through the wrong C
//! runtime. Both are the `WISDOM.md` W14 failure, so no such mode is offered
//! here. A caller who wants an installed utf8proc links it directly; a caller
//! who wants `utf8proc_free` needs this tree. Source pins and the bounded
//! contracts above are identical in the bundled mode this file implements,
//! because there is no second mode to drift.
//!
//! ## How `check` proves the facade
//!
//! Zig analyses a function body only when something calls it, so compiling a C
//! archive proves nothing about the facade, and `std.testing.refAllDecls`
//! proves nothing either -- a declaration it only reflects over is never
//! instantiated. `check` therefore compiles three Zig roots that *call* the
//! public surface -- `zig/api_exercise.zig` as an executable, `tests.zig`,
//! and `smoke.zig` as an executable -- for every target in the matrix, plus the
//! C core, the translation and the nine upstream C test programs. That is a
//! standing obligation on those files, not on this script: every public
//! declaration in `zig/root.zig` must be called from one of them, or `check`
//! stops covering it. Nothing runs for a cross target, so a passing `check` is
//! compile evidence and never a claim that a foreign binary ran.

const std = @import("std");

const manifest = @import("build.zig.zon");

/// The upstream release this fork is pinned to, in the one form this file
/// needs it: a version to hold `build.zig.zon` to and the API version the
/// generated `libutf8proc.pc` reports.
///
/// 2.12.0 ships `utf8proc.h:72-76` with `UTF8PROC_VERSION_MAJOR 2`,
/// `_MINOR 12`, `_PATCH 0`, and `utf8proc.c:99-101` stringizes exactly those
/// three macros, so the C library this package builds reports `2.12.0` from
/// its own archive. Upstream's *ABI* version is a different number and is not
/// here: it is `abi_version` below.
///
/// The repository, the tag, the commit and the per-file digests are **not**
/// restated here. They live in `UPSTREAM.md` and `UPSTREAM.sha256`, written by
/// this fork's provenance owner from the imported tree, and nothing in a build
/// may depend on Git being present; a SHA copied into a build script is a
/// second place for it to be wrong.
const upstream = struct {
    const version: std.SemanticVersion = .{ .major = 2, .minor = 12, .patch = 0 };
};

/// Upstream's shared-library version, which is an ABI statement and not the
/// API version above.
///
/// `Makefile:25-27` carries `MAJOR=3`, `MINOR=3`, `PATCH=0` for exactly this
/// and `MANIFEST` carries the same 3/3/0; `CMakeLists.txt:44-45` sets the same
/// three numbers as `VERSION` with `SOVERSION ${SO_MAJOR}`. `utf8proc.h:66-68`
/// says in upstream's own words that the shared-library version may differ
/// from the API version because it indicates ABI compatibility, and
/// `Makefile:19-24` says the same beside the numbers.
///
/// Zig spells those three numbers as a `SemanticVersion` and installs
/// `libutf8proc.so.3.3.0` with the soname `libutf8proc.so.3` and a
/// `libutf8proc.so` link beside it, which is upstream's own `SHLIB_VERS_EXT`
/// and its `libutf8proc.so.$(MAJOR)` (`Makefile:38,57-61`). A static archive
/// carries no version, so this value is only ever given to a shared object.
const abi_version: std.SemanticVersion = .{ .major = 3, .minor = 3, .patch = 0 };

/// The one registered module, and the artifact a C consumer links.
///
/// Both are `utf8proc`, in separate namespaces: `dep.module("utf8proc")` and
/// `dep.artifact("utf8proc")` are different calls on the same name, and the
/// installed library is `libutf8proc.a` or `libutf8proc.so` because of it.
const module_name = "utf8proc";
const lib_name = "utf8proc";

/// The import name `zig/root.zig` reaches the translated header by.
const c_import_name = "c";

/// The import name `zig/root.zig` reaches the loader core by.
///
/// `zig/root.zig:106` imports it in *both* configurations, and both need it: a
/// linked build has no dispatch to carry `LoadSource` and `LoadError`, so it
/// takes them from the core module directly, while a runtime-loading build
/// takes them from the dispatch, which made the one core instance itself.
const rt_import_name = "rt";

/// The single public header, upstream's own, installed under its own name.
///
/// `utf8proc.h` is the entire public API (818 lines) and the only header in the
/// tree. It is installed at the root of the include directory, which is where
/// a C consumer's `#include <utf8proc.h>` finds it and where upstream's own
/// install rule puts it (`CMakeLists.txt`, `install(FILES utf8proc.h DESTINATION
/// ${CMAKE_INSTALL_INCLUDEDIR})`).
const public_header = "utf8proc.h";

/// The whole library: one translation unit.
///
/// `utf8proc_data.c` is not listed because `utf8proc.c:53` includes it with
/// quotes, and a quoted include resolves relative to the directory of the file
/// that includes it. Listing it again would compile 2.3 MB of tables into a
/// second, duplicate-symbol object.
const core_sources = [_][]const u8{
    "utf8proc.c",
};

/// Compile flags for every C translation unit in this package.
///
/// `-std=gnu11` is a pin, not a preference. The core is C99 and compiles as
/// C99 -- upstream builds it at exactly that level (`Makefile:13`,
/// `C99FLAG = -std=c99`, on the `UCFLAGS` line at `:15`) -- and the GNU dialect
/// is a strict superset of C99, so nothing C99-clean stops compiling. It is
/// chosen over strict `-std=c99` because it leaves `__STRICT_ANSI__` undefined,
/// which is what keeps the C library headers upstream's own test programs
/// include (`<wchar.h>` in `test/iterate.c:3`, `<wctype.h>` in
/// `test/case.c:2`, `<ctype.h>` in `test/tests.h:18`) declaring what those
/// programs use without this build having to reason about the feature-test
/// macro `test/tests.h:9` sets. Pinning the level is the point: a change of
/// clang default cannot silently move it.
///
/// Upstream's warning set -- `-Wsign-conversion -Wall -Wextra -Wc++-compat
/// -pedantic` (`Makefile:14`) -- is not passed. Those are the maintainer's
/// lint, not a property of the artifact, and upstream does not promote them to
/// errors here either; a build that failed on a compiler's new diagnostic would
/// be reporting the compiler, not this package.
const c_flags = [_][]const u8{
    "-std=gnu11",
};

/// One `Module.addCMacro` / `TranslateC.defineCMacro` pair: the macro's name
/// and its replacement list. `1` is the value every one of them carries, which
/// is what `Module.addCMacro` and `defineCMacro` both emit for it.
const Macro = [2][]const u8;

/// The macros the C core's own translation units are compiled with.
///
/// `UTF8PROC_STATIC` is not optional in the static linkage. `utf8proc.h:123-139`
/// defines `UTF8PROC_DLLEXPORT` as empty only when it is set; otherwise, under
/// `_WIN32`, it becomes `__declspec(dllimport)`. A Windows compile of the
/// static library without it would declare every entry point as imported from
/// a DLL that does not exist and fail at link. Upstream's own `build.zig:21-23`
/// passes the same define for the same reason.
///
/// The shared linkage defines `UTF8PROC_EXPORTS` instead, and defines it
/// *only* here. That is the build-side half of the switch `utf8proc.h:129-133`
/// reads, and it is what makes the DLL export rather than import: with it,
/// `_WIN32` gives every function `__declspec(dllexport)` and also the one
/// exported **data** symbol, `utf8proc_utf8class` at `utf8proc.c:56`, which is
/// declared `UTF8PROC_DLLEXPORT extern const utf8proc_int8_t
/// utf8proc_utf8class[256]` in `utf8proc.h:453`. On ELF and Darwin the same
/// macro resolves to `__attribute__((visibility("default")))`
/// (`utf8proc.h:135`), which is what upstream's shared build uses there.
///
/// Upstream's own build systems make the same split this file makes:
/// `CMakeLists.txt:34` marks `UTF8PROC_STATIC` `PUBLIC` on the static target
/// and `:40` marks `UTF8PROC_EXPORTS` `PRIVATE` on the shared one, and the
/// `Makefile` puts `-DUTF8PROC_EXPORTS` on the shared object link line only.
fn libraryMacros(linkage: std.builtin.LinkMode) []const Macro {
    return switch (linkage) {
        .static => &.{.{ "UTF8PROC_STATIC", "1" }},
        .dynamic => &.{.{ "UTF8PROC_EXPORTS", "1" }},
    };
}

/// The macros every *consumer* of this package's library is compiled with.
///
/// Three consumers, one list: `TranslateC.defineCMacro` on the translation
/// line, the `-D` on the preprocessing line where `preprocessedHeader` puts it,
/// and the nine upstream C test programs, which include `utf8proc.h` and link
/// the artifact. The compiled library, the text the translator reads, the text
/// the preprocessor produced and the programs upstream wrote against the same
/// header cannot disagree about what the artifact exports.
///
/// The static linkage defines `UTF8PROC_STATIC` here too, for the same reason
/// the core does: `utf8proc.h:123-126` is what leaves a Windows consumer's
/// declarations unqualified.
///
/// The shared linkage defines *neither*, and the empty define is the right
/// answer rather than an omission: `utf8proc.h:132` then gives a Windows
/// consumer `__declspec(dllimport)`, which is what consuming a DLL means, and
/// every other platform reads `:135` and gets the default-visibility attribute,
/// which is upstream's own answer there. `UTF8PROC_EXPORTS` is deliberately
/// absent from this list: a consumer that defines it asks for its own
/// translation unit to export those symbols.
///
/// `defineCMacro` and not `addCMacro` on the translate step, because
/// `addCMacro` is a `Module` method and `Step.TranslateC` does not have one
/// (`std/Build/Step/TranslateC.zig:108-145`). `defineCMacro` is what emits the
/// `-D` on the translator's own command line (`:153-156`, applied at
/// `:196-199`); the four fields of `TranslateC.Options` (`root_source_file`,
/// `target`, `optimize`, `link_libc`, `:22-27`) are only what `b.addTranslateC`
/// takes, and have nothing to do with whether a macro can reach the
/// translation.
fn consumerMacros(linkage: std.builtin.LinkMode) []const Macro {
    return switch (linkage) {
        .static => &.{.{ "UTF8PROC_STATIC", "1" }},
        .dynamic => &.{},
    };
}

/// The fork's translate-c root header.
const translate_header = "zig/translate.h";

/// The Zig facade, re-exporting the translation as `pub const c`.
const facade_root = "zig/root.zig";

/// The explicit executable exercise whose body calls every
/// public facade function.
const exercise_root = "zig/api_exercise.zig";

/// The behavioural tests.
const test_root = "tests.zig";

/// The smoke program.
const smoke_root = "smoke.zig";

/// Upstream's own `test/tests.c`, the `check`/`simple_getline`/`encode` helpers
/// every one of the test programs links. `test/tests.h:15` reaches the library
/// with `#include "../utf8proc.h"`, which is a quoted include resolved relative
/// to `test/`, so the two files must stay adjacent exactly as upstream ships
/// them.
const upstream_test_support = "test/tests.c";

/// One of upstream's own C test programs, built unmodified.
///
/// `fixtures` are the corpus files passed as `argv[1..]`, in upstream's own
/// argument order -- `test/iscase.c:58` requires exactly two and checks
/// `argv[1]` as Lowercase and `argv[2]` as Uppercase, and `Makefile:213` runs
/// them in that order. They are committed under `testdata/`, so nothing is
/// fetched at build or test time.
const UpstreamTest = struct {
    /// Upstream's program name, used as its step and artifact name.
    name: []const u8,
    /// Upstream's source, unmodified.
    source: []const u8,
    /// Corpus files to pass as arguments, in order.
    fixtures: []const []const u8 = &.{},
    /// Whether the program reads the `UNICODE_VERSION` macro.
    ///
    /// `test/misc.c:96-99` guards its Unicode-version cross-check with
    /// `#ifdef UNICODE_VERSION`, so without the define the program still prints
    /// success and still exits 0 and the assertion is simply gone. `Makefile:181`
    /// passes it, scraped out of `data/Makefile` by perl.
    reads_unicode_version: bool = false,
};

/// Upstream's own C test programs that this package builds and runs.
///
/// Ten of the eleven C programs upstream's `check` target compiles. `check`'s
/// prerequisite list is `Makefile:204`; its run list is `Makefile:206-215`.
///
/// The one omitted is `test/charwidth.c`. It is the only program whose oracle
/// is a system library: `test/charwidth.c:40` and `:75-86` compare
/// `utf8proc_charwidth` against the host's `wcwidth` through `<wchar.h>`, and
/// its own source calls those results "not necessarily errors" (`:79`,
/// "lots of these errors for out-of-date system unicode tables"). That
/// comparison is not available identically on six targets, and this package's
/// contract is to port a program's *invariants* rather than an
/// information-bearing difference against a system table. The oracle-free
/// invariants and the four pinned codepoints in that same file (`U+00AD`,
/// `U+E000`, `U+00A1`, `U+00A2`, lines 65-71) belong to the behavioural tests,
/// which is the API owner's file.
///
/// `test/printproperty.c` is also not built: upstream compiles it in `check`
/// (`:204`) and then never executes it (absent from `:206-215`). It is a
/// property *printer* that takes codepoints on `argv` and prints them, not a
/// test with an expected result, so there is no assertion for this build to run.
///
/// Not C programs, and recorded the same way: `bench/` needs ICU4C and
/// libunistring, `test/install_uninstall.sh` drives `make install`, and
/// `test/fuzzer.c` with `test/fuzz_main.c` is the OSS-Fuzz harness driven by
/// `test/ossfuzz.sh`, which `check` does not build either.
const upstream_tests = [_]UpstreamTest{
    // Unicode's own NormalizationTest.txt, all 20 conformance columns per row.
    .{
        .name = "normtest",
        .source = "test/normtest.c",
        .fixtures = &.{"testdata/NormalizationTest.txt"},
    },
    // Unicode's own GraphemeBreakTest.txt, against both the CHARBOUND output
    // and the stateful walk (`test/graphemetest.c:99-100`).
    .{
        .name = "graphemetest",
        .source = "test/graphemetest.c",
        .fixtures = &.{"testdata/GraphemeBreakTest.txt"},
    },
    // The deterministic DerivedCoreProperties extraction: every Lowercase and
    // Uppercase range, through `utf8proc_islower`/`tolower` and
    // `utf8proc_isupper`/`toupper`.
    .{
        .name = "iscase",
        .source = "test/iscase.c",
        .fixtures = &.{ "testdata/Lowercase.txt", "testdata/Uppercase.txt" },
    },
    .{
        .name = "valid",
        .source = "test/valid.c",
    },
    .{
        .name = "iterate",
        .source = "test/iterate.c",
    },
    .{
        .name = "case",
        .source = "test/case.c",
    },
    .{
        .name = "custom",
        .source = "test/custom.c",
    },
    // The regression programme: upstream issues 128, 102, 317 (the Hangul jamo
    // composition loop) and 288, then the Unicode-version cross-check that only
    // exists when `UNICODE_VERSION` is defined.
    .{
        .name = "misc",
        .source = "test/misc.c",
        .reads_unicode_version = true,
    },
    // The whole-space invariant that `utf8proc_decompose_char` never returns
    // more than 4 codepoints, which is the bound `utf8proc.h:539-541` states.
    .{
        .name = "maxdecomposition",
        .source = "test/maxdecomposition.c",
    },
};

/// The six targets `check` compiles for when no `-Dtarget` was given.
///
/// None of these is pre-judged. If a target turns out to need something this
/// machine lacks, that is for the gate to report, not for this script to guess
/// at and quietly skip.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

/// Everything one target's graph produced: the artifact, the module, and the
/// two facts the rest of this file must not recompute for itself.
///
/// The translated header is reached through `facadeModule`, which imports it
/// from the facade; nothing else in this file needs it by name, so it is not a
/// field here.
const Graph = struct {
    /// The C ABI artifact a C or Zig consumer links, and the one the facade
    /// module carries so a dependent gets it by asking for the module alone.
    c_lib: *std.Build.Step.Compile,
    /// The Zig facade. `c` is the translation and the library is linked in for a
    /// linked build; under `-Druntime=true` `c` is the generated dispatch and
    /// nothing at all is linked into the module.
    module: *std.Build.Module,
    /// What this graph's C consumers are compiled with. Carried here rather
    /// than recomputed so `addUpstreamTest` cannot describe a different linkage
    /// than the artifact it links.
    consumer_macros: []const Macro,
    /// The linkage this graph's artifact was built with, which is the
    /// requested one: a request this target cannot carry is refused, never
    /// quietly answered with a different one.
    linkage: std.builtin.LinkMode,
};

/// Whether this target can carry a shared object at all.
///
/// For most OSes that is exactly what `std.Target.DynamicLinker.kind` answers
/// from the OS tag alone (`lib/std/Target.zig:2345-2402`): `.arch_os` and
/// `.arch_os_abi` have one and `.none` does not. WASI is `.none` (`:2385`). A
/// `.so` there is a file nothing can load, so the question is not which artifact
/// to build instead but whether the request can be honoured at all.
///
/// Windows is the one `.none` that does carry one. `.windows` is `.none`
/// (`:2380`) because a PE/COFF image has no interpreter path and no PT_INTERP
/// segment at all -- its imports are resolved by the loader inside the OS, and
/// the shared object is an input to that loader rather than something an
/// interpreter names. The absence of an ELF interpreter is therefore not the
/// same fact as the absence of a shared object, and the two are read separately
/// here instead of being collapsed into one predicate. Reading it as a single
/// fact would refuse `-Dlinkage=dynamic` on the `x86_64-windows-gnu` cell of
/// `check_targets`, the one cell here that produces `utf8proc.dll`.
///
/// WASI is deliberately not given that pass: a `.wasm` module has no dynamic
/// linker, no OS loader that resolves its imports at load time, and nothing
/// that would open a second copy of one.
fn targetCarriesSharedObject(target: std.Build.ResolvedTarget) bool {
    if (target.result.os.tag == .windows) return true;
    return std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// Why `-Dlinkage=dynamic` cannot be delivered for this target, or `null` when
/// it can.
///
/// A refusal and not a substitution, and there is no third answer. A caller who
/// asked for a shared object either gets one or gets this text naming the
/// target that cannot carry it.
///
/// The text is deliberately unprefixed and composable, so the configure-time
/// `@panic` in `deliveredLinkage` and the failing check step in
/// `addTargetCheck` cannot describe the same boundary two different ways.
fn sharedObjectRefusal(b: *std.Build, target: std.Build.ResolvedTarget) ?[]const u8 {
    if (targetCarriesSharedObject(target)) return null;
    const triple = target.result.zigTriple(b.allocator) catch @panic("utf8proc: unspellable target");
    return b.fmt(
        "-Dlinkage=dynamic was requested for {s}, whose OS has no dynamic linker " ++
            "(std.Target.DynamicLinker.kind is .none for {s}), so this target cannot " ++
            "carry a shared object and this build will not hand back a static " ++
            "archive instead. Build it with -Dlinkage=static, or build it for an OS " ++
            "that has a dynamic linker.",
        .{ triple, @tagName(target.result.os.tag) },
    );
}

/// The linkage this build delivers: the requested one, or a refusal.
///
/// A static request is always deliverable, and it is the default, so
/// `wasm32-wasi` with no `-Dlinkage` is an ordinary static archive and this
/// function says nothing about it. A dynamic request is a claim that the target
/// can load a shared object; where the OS has no dynamic linker that claim is
/// false, and the build stops with the target's name and the reason.
///
/// There is deliberately no third answer. Delivering an archive for a request
/// that asked for a shared object is a substitution, and a substitution the
/// caller did not ask for -- announced by a printed line or not -- is a build
/// that answered a different question than the one it was given and reported
/// success. Refusing costs one command line the caller has to correct; a
/// substitution costs them a library that is not the one they asked for, and
/// every gate run afterwards measures that library.
fn deliveredLinkage(b: *std.Build, target: std.Build.ResolvedTarget, requested: std.builtin.LinkMode) std.builtin.LinkMode {
    if (requested == .dynamic) {
        if (sharedObjectRefusal(b, target)) |reason| std.debug.panic("utf8proc: {s}", .{reason});
    }
    return requested;
}

/// The artifact name for one target.
///
/// Cross-target checks need a distinct name per target: six libraries called
/// `utf8proc` in one build graph write to one cache path and make
/// `--summary all` unable to tell them apart.
fn artifactName(b: *std.Build, target: std.Build.ResolvedTarget, public: bool) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

/// Which front end reads `zig/translate.h` for one target.
const TranslationRoute = enum {
    /// Aro preprocesses and parses, from this repository's `zig/translate.h`.
    aro,
    /// The target's own C preprocessor runs first, and Aro parses what it
    /// wrote.
    preprocessed,
};

/// Chooses the front end for one target.
///
/// The module doc says what the choice is between and why it is per target.
/// This says which target gets which, and each clause names the header line
/// that fails without the extra front end. `OBSERVED`: of the published
/// 53-platform matrix, run `20261003-175929-14815-27659` of `cross-test`
/// translated `translate.h` through Aro on 38 targets and failed to translate
/// it on these fifteen -- nine NetBSD, five OpenBSD and `x86-windows` -- every
/// one of them a failure of Aro's own read of that target's C library.
///
/// The conditions are the property each cause turns on rather than a list of
/// triples, so the next architecture of any family below is covered instead of
/// silently left behind. `erfa`'s `aggregateRoute` argues the same point for a
/// family-wide condition.
fn translationRoute(target: std.Build.ResolvedTarget) TranslationRoute {
    const rt = target.result;
    return switch (rt.os.tag) {
        // Every NetBSD target, nine of them in this matrix. `__END_DECLS` is
        // `__END_PUBLIC_DECLS` (`generic-netbsd/sys/cdefs.h:431-432`), whose
        // body ends in `_Pragma("GCC visibility pop")` (`:413`); Aro 0.16
        // leaves the pragma in the token stream instead of executing it, so the
        // trailing `__END_DECLS` of `sys/types.h`, `sys/endian.h:74`,
        // `sys/bswap.h`, `x86_64-netbsd-none/machine/byte_swap.h:72` and
        // `<stdlib.h>` each stop with "unknown type name 'pragma'" and
        // "expected ';', found an identifier" -- twenty-one of them on
        // `x86_64-netbsd`. One family, one header, one cause.
        .netbsd => .preprocessed,
        // Two OpenBSD causes, and they are not the same one.
        //
        //   * ILP32. Aro's own `<stddef.h>` typedefs `size_t` as
        //     `__SIZE_TYPE__` (`aro/include/stddef.h:8`), which is
        //     `unsigned int` on a 32-bit target, while
        //     `generic-openbsd/sys/types.h:171-174` typedefs it as `__size_t`
        //     under a `_SIZE_T_DEFINED_` guard that Aro's header never sets,
        //     and `__size_t` is `unsigned long` here
        //     (`arm/_types.h:123`). Two typedefs of one name and two different
        //     types: "typedef redefinition with different types". On a 64-bit
        //     target both are `unsigned long`, the definitions agree, and the
        //     cell builds -- which is why exactly the three ILP32 OpenBSD
        //     targets and not the four 64-bit ones fail.
        //
        //   * MIPS. `generic-openbsd/mips64/endian.h:32-41` refuses to define
        //     `BYTE_ORDER` unless `__MIPSEL__` or `__MIPSEB__` is defined, and
        //     Aro's MIPS predefined macro table defines neither. Both OpenBSD
        //     MIPS targets reach that one header, and they are two
        //     architectures rather than one: `mips64-openbsd-none` and
        //     `mips64el-openbsd-none` are separate libc directories, and
        //     `std.Target.Cpu.Arch` gives them separate members, `.mips64` and
        //     `.mips64el` (`std/Target.zig:1350-1353`). Both are named below.
        .openbsd => if (std.Target.ptrBitWidth(&rt) != 64 or rt.cpu.arch == .mips64 or rt.cpu.arch == .mips64el) .preprocessed else .aro,
        // `any-windows-any/malloc.h:183-187` derives `_ALLOCA_S_MARKER_SIZE`
        // from `_ARM_`, `_X86_`, `__ia64__`, `__x86_64` or `__aarch64__`, and
        // Aro's Windows predefined macro table defines none of them for 32-bit
        // x86, so the two `_MarkAllocaS`/`_FreeAllocaS` inline functions that
        // name it do not compile there. `_X86_` is the one Clang supplies and
        // Aro does not, and Clang supplies it for 32-bit x86 alone, which is
        // why `aarch64-windows`, `thumb-windows` and `x86_64-windows` build.
        .windows => if (rt.cpu.arch == .x86) .preprocessed else .aro,
        // Everything else in this matrix -- GNU libc, musl, FreeBSD, Darwin,
        // WASI -- Aro translated from `translate.h` as it stands, with nothing
        // in front of it.
        else => .aro,
    };
}

/// `zig/translate.h`, preprocessed for the target being built.
///
/// The extra front end `translationRoute` selects. What it writes is upstream's
/// `utf8proc.h` with every `#include` resolved, every conditional settled and
/// every macro definition kept, for the target the C core is being compiled
/// for. Nothing is stubbed, narrowed, renamed or substituted, and no
/// architecture macro is invented: the preprocessor here is the compiler that
/// compiles `utf8proc.c`, so `__MIPSEL__`, `__MIPSEB__` and `_X86_` are the
/// ones the target really has, and `_Pragma` is handled as the operator the
/// standard defines it to be rather than left in the token stream.
///
/// ## Why `-dD`
///
/// Without it the expansion carries no macro definitions and `pub const c`
/// loses them. The five error codes (`utf8proc.h:223-231`) and the three
/// version macros (`:72-76`) are object-like `#define`s that no declaration in
/// the header uses, `UTF8PROC_DLLEXPORT` (`:125`) has an empty replacement
/// list, and `zig/root.zig:723-727` reads `UTF8PROC_ERROR_NOMEM` and its four
/// siblings out of the translation. `-dD` keeps the `#define` lines beside the
/// expanded text, so a macro a C caller reads as a macro still reaches Zig as
/// a constant. The `_Pragma` directives NetBSD carries come through as the
/// `#pragma` lines a preprocessor emits, which is the form Aro's parser reads
/// (`aro/Parser.zig:752-768`).
///
/// One consequence worth stating rather than leaving to be discovered: a dump
/// covers every header on the path, so on this route `pub const c` also carries
/// the C library's own macro constants (`_STDLIB_H_`, `ULONG_LONG_MAX`,
/// `__VERSION__` and so on) where the `aro` route carries only the ones
/// something in the translation referred to. That is additive -- utf8proc's own
/// declarations, constants and the opaque `utf8proc_property_t` are the same set
/// either way -- and `zig/root.zig` names nothing but utf8proc's own symbols.
///
/// The same round trip loses what no header wrote: Clang makes its builtin
/// 128-bit typedefs itself (`clang/lib/Sema/Sema.cpp:402-415`), so
/// `generic-netbsd/arm/cdefs.h:62-63` keeps `__ALIGNBYTES` as
/// `(sizeof(__int128_t) - 1)` while `__int128_t` itself is nowhere in the
/// expansion, and `zig translate-c` emits no implicit typedef to stand in for
/// it (`translate-c/Translator.zig:420-422`). `zig/translate.h` restates the two
/// typedefs above its include for that reason; that is a declaration of the
/// compiler's own, not a repair this step makes.
///
/// ## Why `-MD`
///
/// `utf8proc.h` is reached only through `#include`, and a `-I` directory
/// argument contributes nothing but its own resolved path string to a run
/// step's manifest (`std/Build/Step/Run.zig:827-831` hashes `resolved_arg`,
/// not the directory's contents). So without a depfile this step's declared
/// inputs would be `zig/translate.h` and two path strings, and a later revision
/// of `utf8proc.h` would be served from the run cache with the translation
/// still describing the previous one. `-MD` with `-MF`, through
/// `addPrefixedDepFileOutputArg`, hands the discovered headers to the build
/// system as this step's own inputs (`Run.zig:1016-1023`,
/// `std/Build/Cache.zig:1074-1114`).
///
/// ## What is deliberately not on this line
///
/// No `-std=` and no `-x c`. `translate.h` is a `.h` file, which is C to both
/// front ends, and a pinned dialect would be a third opinion: Aro reads
/// `zig translate-c`'s own command line, which carries no `-std`
/// (`std/Build/Step/TranslateC.zig:172-190`), and Aro's default and Clang's
/// default are the same dialect anyway -- C17 with GNU extensions, ISO C 2017
/// (`aro/LangOpts.zig:57-59` and `:99`). `utf8proc.h`'s own conditionals are
/// `_MSC_VER`, `__cplusplus`, `_WIN32`, `__GNUC__` and `UTF8PROC_STATIC`
/// (`:81`, `:96`, `:123`, `:128`, `:134`), none of which a `-std` flag moves.
/// `c_flags` is not repeated either: it is the code-generation flag list of the
/// C compile line, and the preprocessor neither needs it nor acts on it.
fn preprocessedHeader(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    macros: []const Macro,
) std.Build.LazyPath {
    // `b.graph.zig_exe` is the compiler running this build script, so the
    // preprocessor is the same pinned compiler the C core is compiled by.
    const run = b.addSystemCommand(&[_][]const u8{ b.graph.zig_exe, "cc", "-E", "-dD" });
    const triple = target.result.zigTriple(b.allocator) catch @panic("utf8proc: unspellable target");
    // The step name carries the triple because one `zig build check` builds six
    // of these at once and `--summary all` has to tell them apart, exactly as
    // `artifactName` does for the six archives.
    run.setName(b.fmt("preprocess utf8proc.h {s}", .{triple}));
    if (!target.query.isNative()) {
        run.addArg("-target");
        run.addArg(triple);
    }
    // The package root, which is the include path `translate.h:96`'s
    // `#include <utf8proc.h>` resolves through and the same one every C
    // translation unit of the core is compiled against. The preprocessor, not
    // the translation, is where this matters: on this route the translation is
    // handed a file with no `#include` left in it.
    run.addPrefixedDirectoryArg("-I", b.path("."));
    // The same `consumerMacros` the translation and every C consumer of this
    // package's library get, so the three cannot disagree about what the
    // artifact exports. On the shared linkage that list is empty and nothing is
    // defined here, which is what `utf8proc.h:132` needs to produce
    // `__declspec(dllimport)` for a consumer under `_WIN32`.
    for (macros) |macro| run.addArg(b.fmt("-D{s}={s}", .{ macro[0], macro[1] }));
    run.addArg("-o");
    // The generated file is this step's output, so the step is cached
    // (`Run.zig:707-725`, `:926-941`): a second build with the same inputs
    // neither re-runs the preprocessor nor rewrites the file.
    const preprocessed = run.addOutputFileArg("utf8proc-translate.c");
    run.addArg("-MD");
    // Discarded on purpose: `addPrefixedDepFileOutputArg` hands back a
    // `LazyPath` for the dep file, and nothing downstream wants that file --
    // what matters is that the run step now records it, and that `Run` reads it
    // back through `addDepFilePost` at `Run.zig:1018-1023`. `_ =` rather than a
    // bare call, so the discard is stated rather than left to be inferred.
    _ = run.addPrefixedDepFileOutputArg("-MF", "utf8proc-translate.d");
    // The translation unit itself. Its bytes are hashed into the manifest
    // (`Run.zig:821-826`) rather than only reached through the `-I`.
    run.addFileArg(b.path(translate_header));
    return preprocessed;
}

/// Everything one target's graph is built from.
///
/// `public` selects between the package module set, which is what a dependent
/// reaches through `dep.module("utf8proc")`, and a private module set. A
/// cross-target check needs the private form: modules are registered by name
/// against the whole build, so registering `utf8proc` once per cross target
/// would leave only the last one reachable and silently stop checking the rest.
///
/// `linkage` is the delivery the caller asked for, and `deliveredLinkage`
/// settles it against the target before anything is compiled: a request this
/// target cannot carry stops the build rather than being answered with the
/// other kind.
///
/// `runtime_loaded` selects the dispatch, not the delivery. It is orthogonal to
/// `linkage`, and a graph with it true still compiles and installs exactly the
/// artifact `linkage` selected -- the provider is named at run time, and it
/// need not be the one this build produced.
const GraphOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    public: bool,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
};

/// The runtime route's build half: the API role's `runtime/graph.zig`.
///
/// This is the one `@import` of it in the whole build script, and both entry
/// points are called from `addGraph`:
///
///     createModule(b, translate, target, optimize)
///         replaces `translate.createModule()` as the module bound to the
///         facade's `c` import, and is the only call in a `-Druntime=true`
///         build. It is handed *this build's own* `TranslateC` step, so the
///         dispatch re-exports the exact translated types and constants rather
///         than a second copy of them, and it links nothing: the symbols are
///         meant to arrive through the platform loader.
///
///     createCoreModule(b, target, optimize)
///         is the loader core itself, for a *linked* build, which has no
///         dispatch and therefore needs `rt` for `LoadSource` and `LoadError`.
///         A runtime-loading build must not ask for it separately: the dispatch
///         creates the one core instance and re-exports those two types from it,
///         so a second instance would make them nominally distinct types and a
///         consumer would be naming one while `load` expected the other.
///
/// `zig/root.zig:106` names `rt` in both configurations and takes
/// `LoadSource`/`LoadError` from `c` when the build is runtime-loaded
/// (`zig/root.zig:136,142`). That branch is chosen by a comptime constant, so
/// in a runtime-loading build the `rt` name is never resolved and the import is
/// not needed; in a linked build it is, which is why only the linked branch
/// below adds it.
const runtime_graph = @import("runtime/graph.zig");

/// Builds the C library, the translation and the facade for one target.
fn addGraph(b: *std.Build, options: GraphOptions) Graph {
    const target = options.target;
    const optimize = options.optimize;
    const linkage = deliveredLinkage(b, target, options.linkage);
    const build_macros = libraryMacros(linkage);
    const use_macros = consumerMacros(linkage);
    const c_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // libc, because `utf8proc.c` allocates: `malloc` and `realloc` at
        // `:785` and `:807` for `utf8proc_map`/`utf8proc_map_custom` and the
        // `utf8proc_NF*` shortcuts, and `free` at `:845` inside
        // `utf8proc_free`. Nothing else in the core needs libc -- no `memcpy`,
        // no `strlen`, no `strcmp` -- but the allocator is a real dependency of
        // the compiled archive.
        .link_libc = true,
        // A shared object has to be relocatable, so every object in it is
        // compiled `-fPIC` -- including the one translation unit that pulls in
        // `utf8proc_data.c`, which is 2.3 MB of tables and the only place a
        // non-PIC-relative reference could hide.
        //
        // The static linkage passes `null` rather than `false`. `Module.pic` is
        // a `?bool` and `appendZigProcessFlags` emits `-fPIC`, `-fno-PIC` or
        // nothing for `true`, `false` and `null` respectively, so `false` would
        // add a flag this archive has never been compiled with and would make
        // the default a change rather than the no-op it has to be.
        .pic = if (linkage == .dynamic) true else null,
    });
    // This repository's root, for `utf8proc.h`. `utf8proc.c:44` includes it
    // with quotes, which resolves relative to the source file and so would
    // work without this, but the path goes on the compile line anyway: it is
    // what makes the library's own `#include` resolvable by the same rule a
    // dependent's is, and it is the same root the translation is given.
    c_mod.addIncludePath(b.path("."));
    for (build_macros) |macro| c_mod.addCMacro(macro[0], macro[1]);
    c_mod.addCSourceFiles(.{
        .root = b.path("."),
        .files = &core_sources,
        .flags = &c_flags,
    });

    const c_lib = b.addLibrary(.{
        .name = artifactName(b, target, options.public),
        .linkage = linkage,
        // Upstream's own ABI version, and only for a shared object: an archive
        // has no soname and none of the versioned names would mean anything.
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = c_mod,
    });
    // Installing the header also puts it on the include search path of anything
    // that links this artifact, so a dependent that wants the C API does not
    // have to reach into this repository's tree for it.
    c_lib.installHeader(b.path(public_header), public_header);

    // The translation is handed the same target, so every header it pulls in --
    // `<stdlib.h>`, `<stddef.h>`, `<stdbool.h>`, `<stdint.h>`, `<limits.h>` --
    // is the target's own, and `<utf8proc.h>` resolves to this repository's
    // copy rather than to one installed on the build machine.
    //
    // Which front end reads `translate.h` is `translationRoute`'s call. The two
    // routes differ in exactly one respect: the `aro` one hands the translator
    // this repository's `zig/translate.h` to preprocess for itself, and the
    // `preprocessed` one hands it what `zig cc -E -dD` already wrote for the
    // same target, on the same include path and with the same macros.
    const translate = b.addTranslateC(.{
        .root_source_file = switch (translationRoute(target)) {
            .aro => b.path(translate_header),
            .preprocessed => preprocessedHeader(b, target, use_macros),
        },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // Inert on the `preprocessed` route -- there is no `#include` left in the
    // file by then -- and kept on both so the routes cannot drift into
    // resolving different headers.
    translate.addIncludePath(b.path("."));
    // The consumer half of the export split, never the library half: this
    // translation describes the library a consumer links, so it gets
    // `UTF8PROC_STATIC` in the static linkage and nothing at all in the shared
    // one.
    for (use_macros) |macro| translate.defineCMacro(macro[0], macro[1]);

    // The `c` import is the one seam the runtime route takes over.
    //
    // Linked: the translation itself, exactly as before, and `rt` beside it for
    // the two public types the facade re-exports (`zig/root.zig:136,142`), since
    // a linked build has no dispatch to carry them.
    //
    // Runtime-loaded: the generated dispatch, built from *this* `TranslateC`
    // step, so the types and constants `pub const c` exposes are the translated
    // ones rather than a second, nominally distinct set. `rt` is not added here:
    // the dispatch makes the one core instance and re-exports the two types from
    // it, so a second instance would make `LoadSource` two types and a consumer
    // would be naming one while `load` expected the other.
    const c_module = if (options.runtime_loaded)
        runtime_graph.createModule(b, translate, target, optimize)
    else
        translate.createModule();

    const module = if (options.public)
        b.addModule(module_name, .{
            .root_source_file = b.path(facade_root),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_root),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
    module.addImport(c_import_name, c_module);
    if (options.runtime_loaded) {
        // Nothing is linked into a runtime-loaded module -- not this tree's own
        // library and not an installed one -- because the symbols are meant to
        // arrive through the platform loader when the caller names a provider
        // with an explicit `load`. Linking the archive as well would make the
        // linker demand every entry point before `load` is ever called, and the
        // runtime route would silently be a linked one.
        //
        // The library is still built and installed in this configuration: a
        // caller may name a provider this tree did not build, and may equally
        // want to point at the one it did.
    } else {
        // Transitive linking: `dep.module("utf8proc")` has to carry the compiled
        // library, or a dependent would compile the facade against declarations
        // with nothing behind them and fail only at link time.
        module.addImport(rt_import_name, runtime_graph.createCoreModule(b, target, optimize));
        module.linkLibrary(c_lib);
    }
    // The package root on the facade's own include path, so a dependent that
    // compiles its own C against this module reaches the same `utf8proc.h` the
    // core was compiled with rather than whichever one is installed.
    module.addIncludePath(b.path("."));

    return .{ .c_lib = c_lib, .module = module, .consumer_macros = use_macros, .linkage = linkage };
}

/// A Zig program or test root that imports the published facade module.
///
/// `link_libc` is stated on every one of them even though the facade carries
/// it: a dependent states its own, and this build should fail here if the
/// facade ever stopped bringing the allocator along.
fn facadeModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    source: []const u8,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport(module_name, graph.module);
    return mod;
}

/// Reads the Unicode data version out of `data/Makefile`.
///
/// Upstream's own `Makefile:181` scrapes this value with
/// ``perl -ne "/^UNICODE_VERSION=/ and print $';" data/Makefile`` and passes it
/// to `test/misc.c`, where `test/misc.c:96-99` compares it against
/// `utf8proc_unicode_version()`. Doing the same read here, in the build script,
/// keeps the cross-check from drifting into a hand-copied constant: if the
/// committed data version and the version the compiled tables answer with ever
/// disagree, this program says so. It is a read of a committed file in this
/// tree, not a download, and there is no generated input to make per target.
///
/// The same read is what `data/Makefile:23-24` documents: "Unicode data
/// version (must also update utf8proc_unicode_version function)". `utf8proc.c:
/// 103-105` returns the literal `"18.0.0"`; that literal is upstream's, and
/// this build does not touch it.
fn unicodeVersion(b: *std.Build) []const u8 {
    const makefile = readPackageFile(b, "data/Makefile");
    var lines = std.mem.splitScalar(u8, makefile, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "UNICODE_VERSION=")) {
            return line["UNICODE_VERSION=".len..];
        }
    }
    @panic("data/Makefile has no UNICODE_VERSION= line; upstream's Makefile:181 scrapes it from there");
}

/// Reads one file from the package root, which is the upstream release tree.
///
/// `b.build_root.handle` is the same directory handle `b.path` resolves
/// against, and `readFileAlloc` through it is how a build script reads a
/// checked-in input in this Zig version; `LazyPath.getPath2` is the older,
/// deprecated spelling and is not used here.
fn readPackageFile(b: *std.Build, name: []const u8) []u8 {
    return b.build_root.handle.readFileAlloc(b.graph.io, name, b.allocator, .limited(8 << 20)) catch |err| {
        std.debug.panic("cannot read {s}: {s}", .{ name, @errorName(err) });
    };
}

/// The compile flags for one upstream test program.
///
/// `test/misc.c` additionally gets `-DUNICODE_VERSION="18.0.0"`, one argv
/// element with the quotes inside it, which is exactly how upstream's shell
/// reaches the compiler at `Makefile:181`. Without it `test/misc.c:96` skips
/// the whole block under `#ifdef` and the program prints a success it has not
/// earned.
///
/// The extra element is allocated from the build allocator rather than written
/// as a literal in an expression, because `Module.addCSourceFile` keeps the
/// flag slice for the whole build and a pointer into this frame would not
/// outlive it.
fn upstreamTestFlags(b: *std.Build, spec: UpstreamTest) []const []const u8 {
    if (!spec.reads_unicode_version) return &c_flags;
    const flags = b.allocator.alloc([]const u8, 2) catch @panic("OOM");
    flags[0] = c_flags[0];
    flags[1] = b.fmt("-DUNICODE_VERSION=\"{s}\"", .{unicodeVersion(b)});
    return flags;
}

/// Builds one upstream C test program, unmodified, for one target.
///
/// `test/tests.c` is upstream's own shared helper -- `Makefile:150-151`
/// compiles it once into `test/tests.o` and every program links that object
/// (`:154`, `:157`, ... `:184`) -- so it is compiled into each program here
/// rather than built once as an object and added by path. The source is 3 KB
/// and `Module.addObjectFile` would need an emitted-bin lazy path for it.
fn addUpstreamTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    spec: UpstreamTest,
    name: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // libc, because every one of these programs reads and prints through
        // `<stdio.h>` and upstream's `UCFLAGS` (`Makefile:15`) links the same
        // way.
        .link_libc = true,
    });
    // The package root, for `test/tests.h:15`'s `#include "../utf8proc.h"` and
    // so that the whole set of programs resolves the header by one rule.
    mod.addIncludePath(b.path("."));
    // This is a *consumer* of the library, so it gets the consumer half of the
    // export split and never `UTF8PROC_EXPORTS`: these programs include
    // `utf8proc.h`, so a Windows build of one against the static archive needs
    // `UTF8PROC_STATIC` -- without it every declaration is
    // `__declspec(dllimport)` for a DLL that does not exist -- and against the
    // DLL it needs the empty define, which is `utf8proc.h:132` itself.
    for (graph.consumer_macros) |macro| mod.addCMacro(macro[0], macro[1]);
    const flags = upstreamTestFlags(b, spec);
    mod.addCSourceFile(.{ .file = b.path(upstream_test_support), .flags = flags });
    mod.addCSourceFile(.{ .file = b.path(spec.source), .flags = flags });
    mod.linkLibrary(graph.c_lib);
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Compiles the C core, the facade, the API exercise, the tests, the smoke
/// program and every upstream C test program for one matrix target, and
/// attaches all of them to `step`.
///
/// Nothing is run here, so every result this produces is compile evidence and
/// not a claim that a cross-built binary executed. That is why the upstream
/// programs appear here as compiles rather than as runs: `upstream-test` runs
/// them natively, and a successful foreign compile is `build_only`.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
) void {
    const cross_target = b.resolveTargetQuery(query);
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // A row that cannot carry what the caller asked for becomes an explicit
    // failing step carrying the reason, and nothing at all is compiled for it.
    // That is the honest result of `zig build check -Dlinkage=dynamic`: one
    // refused row, the other five still compiled, and no archive handed back
    // under the flag that asked for a shared object. The row is not dropped,
    // not relabelled and not answered with something else, so it cannot pass
    // by omission.
    //
    // A step rather than a `@panic` here, and the difference is what the two
    // are for. The selected target's own graph has already been refused in
    // `deliveredLinkage` before this runs -- `zig build -Dtarget=wasm32-wasi
    // -Dlinkage=dynamic` stops at configure -- so this branch is only ever
    // reached for a row nobody named with `-Dtarget=`. Aborting there would
    // take down a native `zig build install`, which is entirely valid, over a
    // target that step never compiles.
    if (linkage == .dynamic) {
        if (sharedObjectRefusal(b, cross_target)) |reason| {
            step.dependOn(&b.addFail(b.fmt(
                "utf8proc: check row {s}: {s} No artifact was built for this row, and nothing was substituted for it.",
                .{ triple, reason },
            )).step);
            return;
        }
    }

    // The linkage the main graph was asked for, so this compiles the artifact
    // that graph would really deliver rather than an archive nobody asked for.
    // A shared object is a new artifact class and not a linkage flip, so
    // `check -Dlinkage=dynamic` has to walk it or it proves nothing about it.
    //
    // The runtime route needs a provider at run time and none of these binaries
    // is run, so `check` never selects it.
    const graph = addGraph(b, .{
        .target = cross_target,
        .optimize = optimize,
        .public = false,
        .linkage = linkage,
        .runtime_loaded = false,
    });

    // Instantiate every typed operation without adding wiring-only tests.
    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("utf8proc-api-exercise-{s}", .{triple}),
        .root_module = facadeModule(b, cross_target, optimize, graph, exercise_root),
    }).step);

    step.dependOn(&b.addTest(.{
        .name = b.fmt("utf8proc-tests-{s}", .{triple}),
        .root_module = facadeModule(b, cross_target, optimize, graph, test_root),
    }).step);

    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("utf8proc-smoke-{s}", .{triple}),
        .root_module = facadeModule(b, cross_target, optimize, graph, smoke_root),
    }).step);

    for (upstream_tests) |spec| {
        step.dependOn(&addUpstreamTest(
            b,
            cross_target,
            optimize,
            graph,
            spec,
            b.fmt("utf8proc-{s}-{s}", .{ spec.name, triple }),
        ).step);
    }
}

/// Runs the `consumer/` package as its own `zig build`.
///
/// The consumer is a separate package on purpose: a manifest dependency here
/// would close a cycle, because its manifest points back at this package by
/// path. Running it as a separate build is what makes the proof real -- that a
/// package which writes only `b.dependency("utf8proc", ...)` and
/// `dep.module("utf8proc")` gets a working, correctly linked library. Its
/// `build.zig` asks for nothing else, which is the point: if the module stopped
/// carrying the archive or the translation, this would stop linking.
///
/// The sub-command is `run` when this host can execute the selected target and
/// `install` when it cannot; `hostCanExecute` below is the predicate, so the
/// decision and the nested run cannot disagree. An executor counts only when
/// `-fwasmtime`, `-fqemu`, `-fwine` or `-fdarling` enabled one, and `install`
/// is compile-and-deliver evidence, not an observed consumer exchange.
///
/// The target travels down as the caller's *query*, never as this graph's
/// resolved target. `Target.Query.zigTriple` spells arch, OS, versions and ABI
/// and writes `native` for a query that names nothing
/// (`lib/std/Target/Query.zig:421-423`); `Target.Query.serializeCpu` spells the
/// model and its feature set as the separate string `standardTargetOptions`
/// reads from `-Dcpu` (`:488-528`, with the four standard options registered at
/// `lib/std/Build.zig:1474-1493`). That is the same pair `std.Build` itself
/// uses to hand a `ResolvedTarget` to a dependency (`lib/std/Build.zig:454-459`),
/// so both halves of the nested build parse exactly what this one resolved.
///
/// `target.result.zigTriple` was the wrong source, and the Nix
/// `devenv:consumer` gate is what said so. It spells the *resolved* target,
/// whose host CPU carries a feature range -- `x86_64-linux.6.12...6.12-gnu.2.42`
/// on this machine -- and a triple has no field for a dynamic linker at all.
/// The nested build therefore read an explicitly named target, resolved it
/// against the ABI's defaults rather than against this machine, and asked for
/// `/lib64/ld-linux-x86-64.so.2` where the host's real linker is the Nix store
/// path. Its `run` then refused, and it was right to: `Step.Run` compares
/// `b.graph.host.result.dynamic_linker` with the target's own
/// (`lib/std/Build/Step/Run.zig:1337-1348`). The same architecture, the same OS
/// and the same libc version are not a native selection, and the query is what
/// stops them from pretending to be one.
///
/// The dynamic linker rides the native route rather than travelling as an
/// argument. A query that names nothing *is* `b.graph.host`
/// (`lib/std/Build.zig:2704-2708`), so this graph and the nested one both
/// compile against the linker the machine actually has. No argument carries it
/// because `b.dependency` carries none either (`lib/std/Build.zig:439-461`
/// forwards `zigTriple` and `serializeCpuAlloc` and nothing else): a
/// `-Ddynamic-linker` forwarded to the nested build alone would give its
/// consumer executable a linker that its own library half never received.
///
/// The nested build is given this workspace's job width and its step list, and
/// it is given the caches this graph resolved. `-j8` and `--summary all` are
/// what `AGENTS.md:157-158` asks of every `zig build` entry, and nothing can
/// append a `-j` to a `Run` step's command afterwards, so a nested build left
/// to derive its own width takes `cpu_count - 1`
/// (`lib/std/Io/Threaded.zig:1634-1639`) -- the consumer this step proves then
/// compiles at a width neither this graph nor the gate asked for. The local
/// cache is forwarded as `<outer>/consumer` because two graphs must not write
/// one manifest directory; the global cache is forwarded whole and unsuffixed
/// because it is the shared package store both graphs have to read
/// (`lib/std/Build.zig:121-124`, populated before any script runs,
/// `lib/compiler/build_runner.zig:73-76`).
///
/// The install prefix travels with them, and only when the caller named one.
/// `b.install_prefix` is the `--prefix` this invocation resolved; a nested
/// `zig build` given none resolves `<its own build root>/zig-out`, which for
/// this step is `consumer/zig-out`, a build artefact inside a source package.
/// A relative value would resolve against the nested build's working
/// directory, `consumer/`, and not against this build's root, so it is made
/// absolute before it is handed on, and a caller who named no prefix is left
/// to the default both graphs resolve alike. `DESTDIR` needs no forwarding:
/// the nested build inherits the environment this one ran with.
fn runConsumer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) *std.Build.Step.Run {
    const query = target.query;
    // `addArg` copies each argument, so these temporaries can go right after.
    const triple = query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    const cpu = query.serializeCpuAlloc(b.allocator) catch @panic("OOM");
    defer b.allocator.free(cpu);

    // `b.graph.zig_exe` is the compiler running this build script, so the
    // nested build is the same toolchain rather than whatever is on PATH.
    const run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    run.setName("consumer package");
    run.setCwd(b.path("consumer"));
    run.addArg(if (hostCanExecute(b, target)) "run" else "install");
    run.addArg(b.fmt("-Dtarget={s}", .{triple}));
    // The model and its feature set, because the triple does not carry them.
    // `serializeCpu` writes `native` for a query that named no CPU and
    // `baseline` for a cross query that named none, and the name of an explicit
    // model followed by its added and subtracted features
    // (`lib/std/Target/Query.zig:490-527`), so the nested build compiles the
    // same consumer this graph would have compiled.
    run.addArg(b.fmt("-Dcpu={s}", .{cpu}));
    run.addArg(b.fmt("-Doptimize={s}", .{@tagName(optimize)}));
    // The delivery this graph actually built, so the consumer proves the
    // module route against the artifact that was delivered rather than a
    // second, unrequested archive. The consumer's own `build.zig` declares the
    // same option and forwards it into `b.dependency("utf8proc", ...)`.
    run.addArg(b.fmt("-Dlinkage={s}", .{@tagName(linkage)}));
    // The dispatch, forwarded for the same reason. The consumer's program
    // branches on `utf8proc.runtime_loaded` at comptime and, in the
    // runtime-loading build, names a provider on its command line or in
    // `UTF8PROC_TEST_PROVIDER` before it calls anything -- which only works if
    // this build is the one that asked for the runtime route. `zig build
    // consumer -Druntime=true` therefore needs a provider in the environment,
    // and says so rather than failing on a missing symbol.
    run.addArg(b.fmt("-Druntime={s}", .{if (runtime_loaded) "true" else "false"}));
    // Forward the selected executor and its dynamic-linker support.
    if (b.enable_darling) run.addArg("-fdarling");
    if (b.enable_qemu) run.addArg("-fqemu");
    if (b.enable_rosetta) run.addArg("-frosetta");
    if (b.enable_wasmtime) run.addArg("-fwasmtime");
    if (b.enable_wine) run.addArg("-fwine");
    if (b.libc_runtimes_dir) |runtimes| run.addArgs(&.{ "--libc-runtimes", runtimes });
    // The nested build carries this workspace's job count and summary in its own
    // command line. Nothing can append a `-j` to a `Run` step's command, so a
    // nested build left to derive its own width takes `cpu_count - 1`
    // (`lib/std/Io/Threaded.zig:1634-1639`) instead, and the consumer this step
    // proves then compiles at a different width from the build that asked for
    // it -- and at a different width again on whichever machine runs the gate.
    // `--summary all` is for the same reader: the nested build is a separate
    // graph whose steps are named after the consumer package, and a failure
    // inside it is otherwise one unnamed line.
    run.addArg("-j8");
    run.addArg("--summary");
    run.addArg("all");
    // Two arguments, not one `--cache-dir=...`: the second is the form the
    // build system emits to the compiler itself, not to the build runner. Two
    // build graphs must not write the same manifest directory, so the nested one
    // gets a subdirectory rather than sharing.
    if (b.cache_root.path) |cache| {
        run.addArg("--cache-dir");
        run.addArg(b.fmt("{s}/consumer", .{cache}));
    }
    // The global cache the caller selected, named whole and unsuffixed, because
    // it is a shared content-addressed store of packages rather than this
    // graph's manifest directory: the nested build has to read the store this
    // build is using, and one left to resolve its own lands wherever the
    // compiler defaults to -- outside the cache root the caller named. Two
    // arguments, as above, because `--global-cache-dir [path]` is the spelling
    // the build runner documents (`lib/compiler/build_runner.zig:1675`) and the
    // one the compiler itself emits from a build script
    // (`lib/std/Build/Step/Compile.zig:1478-1479`).
    if (b.graph.global_cache_root.path) |global_cache| {
        run.addArg("--global-cache-dir");
        run.addArg(global_cache);
    }
    // The install prefix this invocation resolved, forwarded when the caller
    // named one. Left to resolve its own the nested build installs into
    // `consumer/zig-out`, a build artefact inside a source package, rather
    // than into the directory the caller asked for. A relative `--prefix`
    // would resolve against the working directory set above, `consumer/`, and
    // not against this build's root, so it is made absolute before it is
    // handed on; `DESTDIR` needs no forwarding, because the nested build
    // inherits the environment this one ran with.
    const default_prefix = b.build_root.join(b.allocator, &.{"zig-out"}) catch @panic("OOM");
    if (!std.mem.eql(u8, b.install_prefix, default_prefix)) {
        const prefix = if (std.fs.path.isAbsolute(b.install_prefix))
            b.install_prefix
        else
            b.pathJoin(&.{ b.graph.cache.cwd, b.install_prefix });
        run.addArg("--prefix");
        run.addArg(prefix);
    }
    // The caller's own arguments, last and behind `--`.
    if (b.args) |args| {
        run.addArg("--");
        run.addArgs(args);
    }
    run.has_side_effects = true;
    return run;
}

/// True when this build can execute `target`'s binaries. `getExternalExecutor`
/// is the question `Step.Run` asks about the artifact it is about to spawn, and
/// `allow_*` carry this build's own executor switches, so this cannot disagree
/// with the nested run. `link_libc` is the consumer's: it inherits libc from the
/// facade module it imports, built with no linkage of its own.
fn hostCanExecute(b: *std.Build, target: std.Build.ResolvedTarget) bool {
    const host = &b.graph.host.result;
    const candidate = &target.result;
    const options: std.zig.system.GetExternalExecutorOptions = .{
        .allow_darling = b.enable_darling,
        .allow_qemu = b.enable_qemu,
        .allow_wasmtime = b.enable_wasmtime,
        .allow_wine = b.enable_wine,
        // The consumer is built with no linkage, so the musl half of `Run`'s
        // `need_cross_libc` never contributes and `isGnuLibC` is all of it.
        .qemu_fixes_dl = candidate.isGnuLibC() and b.libc_runtimes_dir != null,
        .link_libc = true,
    };
    return switch (std.zig.system.getExternalExecutor(b.graph.io, host, candidate, options)) {
        .native, .rosetta => true,
        // `Run` appends `-L <runtime triple>` for a cross libc target and
        // failsForeign on a missing `--libc-runtimes` rather than skipping, so
        // this is a case `Run` refuses and the answer has to be no.
        .qemu => !candidate.isGnuLibC() or b.libc_runtimes_dir != null,
        // Reachable only for an executor the switches above enabled, each of
        // which `Run` gates on the same switch and nothing else.
        .wine, .wasmtime, .darling => true,
        // Same OS and CPU with no dynamic linker to load, or an architecture
        // and system this build has no enabled executor for.
        .bad_dl, .bad_os_or_cpu => false,
    };
}

/// Whether the caller named a target on the command line.
///
/// `standardTargetOptions` cannot answer this: it folds `-Dtarget=X` and "no
/// -Dtarget at all" into the same resolved value, so comparing the query
/// against the host would report a host-native cross target as "not selected"
/// and check all six when the caller asked for one. The raw option table can,
/// because `standardTargetOptions` registers the option under exactly this name
/// and every `-Dname=value` the user passed is a key in it.
fn targetWasNamed(b: *const std.Build) bool {
    return b.user_input_options.contains("target");
}

/// The macro list rendered for the configure-time line, in the order the
/// compile line emits it. An empty list reads as `none`, which is what a
/// shared library's consumer line genuinely is: `utf8proc.h:132` is the answer
/// that needs no define.
fn macroNames(b: *std.Build, macros: []const Macro) []const u8 {
    if (macros.len == 0) return "none";
    var out: std.ArrayList(u8) = .empty;
    for (macros, 0..) |macro, i| {
        if (i != 0) out.append(b.allocator, ' ') catch @panic("OOM");
        out.appendSlice(b.allocator, macro[0]) catch @panic("OOM");
    }
    return out.items;
}

/// Every licence, provenance and data-term record that applies to what this
/// package installs, grouped under `share/licenses/utf8proc/`.
///
/// Three different grants govern three different parts of the output, and a
/// single label for the tree would be wrong for two of them:
///
///   * `LICENSE.md` is upstream's own file. Its first two sections are the two
///     MIT/expat grants that cover `utf8proc.c`, `utf8proc.h` and the tests,
///     and its third section is the separate Unicode Terms of Use that govern
///     `utf8proc_data.c` -- which is *compiled into the library* above, so that
///     grant ships with the binary and not only in the repository.
///   * `testdata/Unicode-License-V3.txt` is Unicode's own current licence text
///     for its data files, and it governs the five corpora `installFixtures`
///     copies beside it.
///   * `FORK-LICENSE.md`, `NOTICE.md`, `UPSTREAM.md` and `CHANGELOG.md` are this
///     fork's own records: the grant covering fork-authored material, the
///     per-file inventory, the pin, and the change history. They are shipped
///     because the output contains fork-authored files -- this graph, `tests.zig`,
///     the facade and the generated `libutf8proc.pc` are all compiled or
///     installed from here.
///
/// The four are fork records rather than upstream ones, and their licence is
/// recorded by the provenance role; nothing here states or changes it. `NOTICE.md`
/// already names each file's terms, so this list is deliberately the same set.
const licence_records = [_][]const u8{
    "LICENSE.md",
    "FORK-LICENSE.md",
    "NOTICE.md",
    "UPSTREAM.md",
    "CHANGELOG.md",
    "testdata/Unicode-License-V3.txt",
};

/// The committed Unicode corpora, installed one by one under
/// `share/utf8proc/testdata/`.
///
/// These are the same bytes `tests.zig` embeds with `@embedFile` and the same
/// bytes `upstream-test` passes as arguments, so an installed consumer receives
/// the exact corpora this package's own conformance gate replays rather than a
/// re-download. Upstream's `data/Makefile:44-48` fetches them with curl and
/// `data/Makefile:58-60` deletes them on `clean`, so a tree that does not carry
/// them cannot run upstream's own tests; this package does not fetch anything.
///
/// `Unicode-License-V3.txt` travels in the same directory rather than with the
/// licences because it governs *these* files, and a consumer who copies the
/// fixtures out of this tree needs to have the terms with them.
const fixtures = [_][]const u8{
    "testdata/NormalizationTest.txt",
    "testdata/GraphemeBreakTest.txt",
    "testdata/DerivedCoreProperties.txt",
    "testdata/Lowercase.txt",
    "testdata/Uppercase.txt",
    "testdata/Unicode-License-V3.txt",
};

/// Installs every carried licence, provenance and data-term record.
fn installRecords(b: *std.Build) void {
    for (licence_records) |name| {
        // The destination is the basename, so `LICENSE.md` and
        // `testdata/Unicode-License-V3.txt` land beside each other in one
        // directory rather than reproducing the repository's tree.
        b.installFile(name, b.pathJoin(&.{ "share", "licenses", lib_name, std.fs.path.basename(name) }));
    }
}

/// Installs the Unicode conformance fixtures and the licence that governs them.
fn installFixtures(b: *std.Build) void {
    for (fixtures) |name| {
        b.installFile(name, b.pathJoin(&.{ "share", lib_name, "testdata", std.fs.path.basename(name) }));
    }
}

/// Renders upstream's own `libutf8proc.pc.in` and installs it as link metadata.
///
/// The template is upstream's file and is substituted, not restated: it has
/// five placeholders and every one of them is filled from a value this build
/// graph already owns. Nothing here recomputes where the library lands.
///
/// Two of the five are corrected against upstream's template rather than
/// copied:
///
///   * `PREFIX` becomes `${pcfiledir}/../..` rather than an absolute path.
///     `pkg-config` defines `pcfiledir` as the directory holding the `.pc` file,
///     which is `<prefix>/lib/pkgconfig`, so `../..` is that prefix. The result is
///     relocatable: the installed tree can be moved, packed into another prefix
///     or staged under a sysroot and the file still describes the copy it
///     travels with. Upstream's `Makefile:100-106` substitutes the configured
///     absolute `--prefix`, which is right for a `make install` into a fixed
///     prefix and wrong for anything that is moved afterwards.
///   * `-DUTF8PROC_EXPORTS` in `Cflags` becomes the macro a *consumer* needs.
///     Both of upstream's templates put it there, and `utf8proc.h:129-133` reads
///     it as the build-side switch: with it, a Windows declaration is
///     `__declspec(dllexport)`, so a consumer that defines it asks for its own
///     translation unit to export those symbols -- the opposite of consuming
///     them. The static delivery needs `-DUTF8PROC_STATIC`, which
///     `utf8proc.h:123-126` turns into an empty export macro, and the shared
///     delivery needs no define at all, which is what `utf8proc.h:132` already
///     resolves to on its own. Both values are derivable from the header alone
///     and from the linkage this graph built, which is the only input here.
///
/// `Requires` and `Libs.private` stay absent on purpose: utf8proc's only
/// link-time requirement is the C runtime every consumer already has, and there
/// is no optional library to record.
fn installPkgConfig(b: *std.Build, linkage: std.builtin.LinkMode) void {
    const output = b.addWriteFiles();
    const contents = renderPkgConfig(
        b,
        readPackageFile(b, "libutf8proc.pc.in"),
        linkage,
    );
    // Generated into the build cache and installed from there, because the file
    // describes the install prefix rather than anything in this tree. It lands
    // in `lib/pkgconfig/`, which is upstream's own `pkgconfigdir` at
    // `Makefile:45` and `CMakeLists.txt:58`'s install destination.
    const pc = output.add("libutf8proc.pc", contents);
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(
        pc,
        .lib,
        "pkgconfig/libutf8proc.pc",
    ).step);
}

/// Substitutes upstream's `.pc` template, one placeholder at a time.
fn renderPkgConfig(b: *std.Build, template: []const u8, linkage: std.builtin.LinkMode) []const u8 {
    // The Cflags word is substituted with its leading space, so the shared
    // delivery's line ends at `-I${includedir}` rather than at a trailing space
    // where the macro used to be.
    const cflags = switch (linkage) {
        .static => " -DUTF8PROC_STATIC",
        .dynamic => "",
    };
    const version = b.fmt("{d}.{d}.{d}", .{
        upstream.version.major,
        upstream.version.minor,
        upstream.version.patch,
    });
    // The order matters only in that no replacement's text contains another
    // needle: `PREFIX`, `LIBDIR`, `INCLUDEDIR` and `VERSION` are distinct tokens,
    // `INCLUDEDIR` does not contain `LIBDIR`, and the object-like `Version:` key
    // is not the uppercase `VERSION` placeholder.
    var text = template;
    text = std.mem.replaceOwned(u8, b.allocator, text, " -DUTF8PROC_EXPORTS", cflags) catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "PREFIX", "${pcfiledir}/../..") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "LIBDIR", "lib") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "INCLUDEDIR", "include") catch @panic("OOM");
    text = std.mem.replaceOwned(u8, b.allocator, text, "VERSION", version) catch @panic("OOM");
    return text;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The delivery. `static` is the default and is what this package has always
    // produced, so a caller who passes nothing changes nothing; `dynamic` builds
    // a real shared object with upstream's own ABI soname. The two are otherwise
    // the same graph over the same sources, the same header and the same
    // translation.
    const requested_linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default, and " ++
            "exactly what this package produced before the option existed) or as " ++
            "a real shared object carrying upstream's ABI version: " ++
            "libutf8proc.so.3.3.0 with soname libutf8proc.so.3 on ELF, " ++
            "libutf8proc.3.3.0.dylib with install name libutf8proc.3.dylib on Darwin, " ++
            "utf8proc.dll plus its import library on Windows. Static compiles " ++
            "the core with -DUTF8PROC_STATIC and no PIC decision of its own; " ++
            "dynamic compiles every object -fPIC and with -DUTF8PROC_EXPORTS, " ++
            "which is what makes the DLL export its functions and its " ++
            "utf8proc_utf8class data symbol. A target whose platform cannot " ++
            "carry a shared object at all -- wasm32-wasi in this package's own " ++
            "matrix, though a Windows target can carry one and is not in that " ++
            "class -- and this build refuses such a request rather " ++
            "than delivering an archive in its place. For the selected target " ++
            "that refusal stops the build at configure time; inside `check` the " ++
            "unsupported row becomes an explicit failing step and every other " ++
            "row is still compiled.",
    ) orelse .static;

    // The dispatch, which is a different decision: under it the facade's native
    // calls go through one process-lifetime table an explicit `load` fills, and
    // nothing is linked into the module. Orthogonal to `-Dlinkage`, which still
    // decides which artifact this build produces and installs -- so a
    // runtime-loading build still produces and installs it, and the provider a
    // caller names need not be the one this build produced.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Build the facade so its native entry points dispatch through one " ++
            "process-lifetime table that an explicit load fills, and link no " ++
            "native library into the module at all: neither the library this " ++
            "tree builds nor an installed one. The library is still built and " ++
            "installed, so a caller may name a provider this tree did not " ++
            "build. Independent of -Dlinkage, which still selects the artifact " ++
            "that is delivered and installed. Default false, and a linked build " ++
            "is unchanged in every respect.",
    ) orelse false;

    // build.zig.zon must not drift away from the release this build pins.
    const package_version = std.SemanticVersion.parse(manifest.version) catch {
        @panic("build.zig.zon: .version is not a semantic version");
    };
    if (package_version.order(upstream.version) != .eq) {
        @panic("build.zig.zon .version no longer matches the pinned upstream release");
    }

    const graph = addGraph(b, .{
        .target = target,
        .optimize = optimize,
        .public = true,
        .linkage = requested_linkage,
        .runtime_loaded = runtime_loaded,
    });
    b.installArtifact(graph.c_lib);
    // A private repository removes no licence obligation. `utf8proc_data.c` is
    // compiled into the library above and `LICENSE.md` is the only file in the
    // tree carrying its terms -- two MIT grants and, in section 3, the separate
    // Unicode Terms of Use that govern the data file. It is installed, not
    // rewritten: `LICENSE.md` is upstream's file, byte for byte. The other
    // records, the data terms, the fixtures and the link metadata are installed
    // beside it by the three helpers below, so the install closure is this
    // graph's and one packaging script cannot reproduce it differently.
    b.installFile("LICENSE.md", "LICENSE.md");
    installRecords(b);
    installFixtures(b);
    installPkgConfig(b, graph.linkage);

    // `zig build` also compiles the smoke program. It is the cheapest proof that
    // the facade, the translated header and the archive agree on types, symbols
    // and link-time dependencies. It is compiled, not installed: it is a proof,
    // not a deliverable.
    const smoke = b.addExecutable(.{
        .name = "utf8proc-smoke",
        .root_module = facadeModule(b, target, optimize, graph, smoke_root),
    });
    b.getInstallStep().dependOn(&smoke.step);

    // A run artifact already depends on building the executable, which depends
    // on compiling the C core and linking the facade. `zig build smoke`
    // deliberately does not depend on the install step: installing is `zig
    // build`'s job, and conflating the two would make a smoke run depend on the
    // install layout.
    const run_smoke = b.addRunArtifact(smoke);
    // The smoke program reads no fixture and prints known answers, so it is
    // cheap to re-run; `has_side_effects` is what stops a second `zig build
    // smoke` being served from the run cache and reporting success without the
    // program ever running.
    run_smoke.has_side_effects = true;
    if (b.args) |args| run_smoke.addArgs(args);
    b.step("smoke", "Run the smoke program").dependOn(&run_smoke.step);

    // The test root is `tests.zig`, the file that names the test blocks; a root
    // that only re-exported them would discover no tests and still exit zero.
    // `addRunArtifact` rather than a plain compile, so this is a real runnable
    // test step for whatever `-Dtarget` names: a foreign target is left to
    // whichever executor the cross-test harness detects, and this build does
    // not decide that.
    const unit_tests = b.addTest(.{
        .name = "utf8proc-tests",
        .root_module = facadeModule(b, target, optimize, graph, test_root),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    // Execute the entire embedded corpus on every requested run.
    run_tests.has_side_effects = true;
    const test_step = b.step("test", "Run the behavioural tests for the selected target");
    test_step.dependOn(&run_tests.step);

    const exercise = b.addExecutable(.{
        .name = "utf8proc-api-exercise",
        .root_module = facadeModule(b, target, optimize, graph, exercise_root),
    });
    // Compiled by the default `zig build`, not installed. `dependOn` on a
    // `Step.Compile` puts the compilation under the install step and nothing
    // else: writing `zig-out/bin/` would take `b.installArtifact`, which this
    // does not ask for. The installed prefix is `LICENSE.md`,
    // `include/utf8proc.h`, the library under `lib/`, the records and fixtures
    // under `share/` and `lib/pkgconfig/libutf8proc.pc`.
    const run_exercise = b.addRunArtifact(exercise);
    run_exercise.has_side_effects = true;
    b.step("exercise", "Run every supported facade operation").dependOn(&run_exercise.step);
    b.getInstallStep().dependOn(&exercise.step);
    test_step.dependOn(&run_exercise.step);

    // Upstream's own C test programs, built and run, unmodified. Their exit
    // status is upstream's own report -- `test/tests.c:9-20` prints and exits on
    // the first failed `check`, and `test/maxdecomposition.c:17-21` returns the
    // success flag inverted -- so a non-zero exit needs no wrapper here to
    // interpret it.
    //
    // The three that read a corpus are given the committed file under
    // `testdata/` through `addFileArg`, which makes the file an input of the run
    // step as well as the argument, so a corpus change invalidates the run
    // rather than being read through a stale path. Nothing is downloaded.
    const upstream_step = b.step(
        "upstream-test",
        "Build and run upstream's own C test programs against the compiled library",
    );
    for (upstream_tests) |spec| {
        const program = addUpstreamTest(b, target, optimize, graph, spec, spec.name);
        const run = b.addRunArtifact(program);
        for (spec.fixtures) |fixture| run.addFileArg(b.path(fixture));
        run.has_side_effects = true;
        upstream_step.dependOn(&run.step);
    }

    // Compile every called facade body and each proof root without execution.
    const check_step = b.step(
        "check",
        "Compile the C core, the translated interface, the facade, the API " ++
            "exercise, the tests, the smoke program and every upstream C test " ++
            "program for the six-target matrix without running any of them",
    );
    if (targetWasNamed(b)) {
        addTargetCheck(b, check_step, target.query, optimize, requested_linkage);
    } else {
        for (check_targets) |query| addTargetCheck(b, check_step, query, optimize, requested_linkage);
    }

    // The consumer package is not part of the matrix: it is its own `zig
    // build`, run from inside `consumer/`. This step is that same proof driven
    // from here, so a consumer can be built or run for a target chosen on the
    // command line without changing directory.
    b.step(
        "consumer",
        "Build and run the independent dep.module(\"utf8proc\") consumer",
    ).dependOn(&runConsumer(b, target, optimize, requested_linkage, runtime_loaded).step);

    // A configure-time line, not a gate result: what this build graph compiled,
    // in which delivery, with which macros, and where its include path points.
    // It is printed whether or not any step runs, and it says nothing about
    // whether any result was executed.
    std.debug.print(
        "utf8proc: {s} from [{s}], {s}, Unicode {s}, header {s}, library macros {s}, consumer macros {s}\n",
        .{
            switch (graph.linkage) {
                .static => b.fmt("lib{s}.a", .{lib_name}),
                .dynamic => switch (target.result.os.tag) {
                    .macos, .ios, .tvos, .watchos, .visionos => b.fmt("lib{s}.{d}.{d}.{d}.dylib (link lib{s}.{d}.dylib, soname {s}.{d}.dylib)", .{
                        lib_name,
                        abi_version.major,
                        abi_version.minor,
                        abi_version.patch,
                        lib_name,
                        abi_version.major,
                        lib_name,
                        abi_version.major,
                    }),
                    .windows => b.fmt("{s}.dll", .{lib_name}),
                    else => b.fmt("lib{s}.so.{d}.{d}.{d} (soname lib{s}.so.{d})", .{
                        lib_name,
                        abi_version.major,
                        abi_version.minor,
                        abi_version.patch,
                        lib_name,
                        abi_version.major,
                    }),
                },
            },
            core_sources[0],
            c_flags[0],
            unicodeVersion(b),
            public_header,
            macroNames(b, libraryMacros(graph.linkage)),
            macroNames(b, graph.consumer_macros),
        },
    );
    if (runtime_loaded) {
        // Dispatch is a separate fact from delivery, and a runtime-loaded build
        // links nothing into the module: the caller names a provider with an
        // explicit load and the symbols arrive through the platform loader.
        // Printing it is what keeps "the library is still built and installed"
        // from reading as "the module links it".
        std.debug.print(
            "utf8proc: runtime-loaded dispatch (-Druntime=true); no library is linked into the module\n",
            .{},
        );
    }
}
