/* SPDX-License-Identifier: MIT */

/* translate.h - the translation unit root for addTranslateC.
 *
 * Zig's `zig translate-c` reads exactly one header and makes every declaration
 * it can see available to Zig as the module `c`, which `zig/root.zig` imports
 * and re-exports as `pub const c`. This file exists so that module is a
 * translation of upstream's published API and nothing else: it lists no part
 * of that API by hand and copies no signature. The only declarations here are
 * the compiler's own 128-bit typedefs, restated under "the 128-bit bridge"
 * below; they are not utf8proc's, and nothing about its API, its ABI or the
 * compiled archive depends on them.
 *
 * ## Why this file exists at all, when utf8proc.h is a single self-contained
 * ## header
 *
 * For the two compiler typedefs below, neither of which is utf8proc's; the
 * typedefs have their own section.
 *
 * ## The export macros are build configuration, and this file defines none
 *
 * `utf8proc.h:123-139` resolves `UTF8PROC_DLLEXPORT` from two macros:
 * `UTF8PROC_STATIC` makes it empty, and without it, under `_WIN32`, it is
 * `__declspec(dllexport)` when `UTF8PROC_EXPORTS` is defined and
 * `__declspec(dllimport)` when it is not. Neither is defined here, and nothing
 * in this file should define them: upstream puts them on the compiler command
 * line, not in the header, because they say how this particular library was
 * built rather than what the interface is. `Makefile:15` compiles the shared
 * object with `-DUTF8PROC_EXPORTS` and upstream's own `build.zig:21-23` compiles
 * the archive with `-DUTF8PROC_STATIC`, in both cases from outside any header.
 *
 * This translation describes the library a *consumer* links, so it takes the
 * consumer half of that split and nothing else:
 *
 *   - `-Dlinkage=static` (the default) gets `-D UTF8PROC_STATIC=1` here, from
 *     `consumerMacros` in build.zig, so `UTF8PROC_DLLEXPORT` is empty on every
 *     platform. A Windows translation without it would declare every entry
 *     point `__declspec(dllimport)` from a DLL that does not exist, and would
 *     then fail at link against the static archive this package builds.
 *   - `-Dlinkage=dynamic` gets no define here at all, and the empty define is
 *     the right answer rather than an omission: `utf8proc.h:132` then gives a
 *     Windows consumer `__declspec(dllimport)`, which is what consuming a DLL
 *     means, and every other platform reads `:135` and gets upstream's own
 *     `__attribute__((visibility("default")))`.
 *
 * `UTF8PROC_EXPORTS` is deliberately never given to this translation. It is
 * the build-side half: it is on the library's own compile line for the shared
 * object, and never on a consumer's, because a consumer that defines it asks
 * for its own translation unit to export those symbols.
 *
 * A macro reaches the preprocessor that reads this file on both routes:
 * `Step.TranslateC.defineCMacro` appends `-D <name>=<value>` to the
 * translator's own command line (`lib/std/Build/Step/TranslateC.zig:153-156`,
 * applied at `:196-199`), and `build.zig`'s `preprocessedHeader` puts the same
 * `-D` on the `zig cc -E -dD` line for the `preprocessed` route. The four
 * fields of `TranslateC.Options` -- `root_source_file`, `target`, `optimize`,
 * `link_libc` (`:22-27`) -- are only the arguments `b.addTranslateC` accepts;
 * they are not what decides whether a macro can reach the translation.
 *
 * ## The 128-bit bridge
 *
 * `__int128_t` and `__uint128_t` are the compiler's own, restated below because
 * no header on the include path declares them. Clang declares them itself when
 * the target has the 128-bit integer extension, pushing both typedefs onto the
 * translation-unit scope under `TargetInfo::hasInt128Type()`
 * (`clang/lib/Sema/Sema.cpp:402-415`, in `InitializeStandardTypes`). Aro
 * mirrors that (`aro/Parser.zig:843-844`, `addImplicitTypedef`), but `zig
 * translate-c` emits no implicit typedef -- "Implicit typedefs are translated
 * only if referenced" (`translate-c/Translator.zig:420-422`). A library header
 * that merely *names* one of them therefore reaches the translation as a bare
 * identifier: `generic-netbsd/arm/cdefs.h:62-63` defines `__ALIGNBYTES` as
 * `(sizeof(__int128_t) - 1)`, `-dD` keeps that definition beside the expanded
 * text, and the translation then reads `__helpers.sizeof(__int128_t)` with
 * nothing behind that name (`OBSERVED`: `check -Dtarget=aarch64-netbsd`,
 * `utf8proc-translate.zig:1191`, "use of undeclared identifier '__int128_t'").
 * Restating the two is what puts the declarations into the file the translator
 * reads, and they resolve to the same `i128` and `u128` the compiler's own
 * would, so utf8proc's API, its ABI and the archive compiled from it are
 * unchanged.
 *
 * `__SIZEOF_INT128__` is the guard because it is the compiler's own capability
 * macro, defined under that same `hasInt128Type()` test
 * (`clang/lib/Frontend/InitPreprocessor.cpp:1169-1170`; Aro mirrors it at
 * `aro/Compilation.zig:985-987`), so a target without `__int128` declares
 * neither. This restates a declaration the compiler already makes; it invents
 * no predefine and no architecture macro, and both routes read the same lines.
 *
 * ## Which front end reads this file
 *
 * `zig translate-c` parses with Aro, and Aro preprocesses as well as parses, so
 * this file can be read either way round. `build.zig`'s `translationRoute`
 * chooses, per target: on most of the published 53-platform matrix Aro reads
 * this file as it stands, and on the targets whose C library Aro cannot
 * preprocess -- the NetBSD family, the ILP32 and MIPS OpenBSD targets, and
 * `x86-windows` -- the target's own C preprocessor (`zig cc -E -dD`, the same
 * compiler that compiles `utf8proc.c`) expands this file for that target first
 * and Aro parses the result. `build.zig` names each target and the header line
 * that fails without the extra front end; none of them is repaired by inventing
 * a predefine the real compiler supplies.
 *
 * Either way what the translator reads is this repository's `utf8proc.h`, with
 * this repository's root as the include path and the linkage's own consumer
 * macro defined, so the two routes cannot describe two different libraries or
 * two different linkages. Nothing about the macro or the include below changes
 * between them.
 *
 * ## The include
 *
 * `#include <utf8proc.h>`, by angle brackets, with this repository's root on
 * the include path `build.zig` gives whichever front end resolves it: the
 * translation on the `aro` route, and the preprocessing step on the
 * `preprocessed` route, where by the time the translation reads the file there
 * is no `#include` left in it to resolve.
 *
 * The angle brackets are the point rather than a style choice: they make this
 * file resolve `utf8proc.h` by exactly the same search rule a C consumer's
 * `#include <utf8proc.h>` uses. Upstream's own install rule puts `utf8proc.h`
 * at the root of the include directory (`CMakeLists.txt`,
 * `install(FILES utf8proc.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})`), and this
 * repository's root is that same directory as far as this package is concerned.
 *
 * Because `build.zig` puts the repository root on that search path rather than
 * leaving it empty, the translation cannot bind to whatever `utf8proc.h`
 * happens to be installed on the build machine. Translating a bundled header
 * against a different library is the `WISDOM.md` W14 failure, and utf8proc is
 * exactly the case where it bites: the installed `utf8proc_free` that
 * `utf8proc.h:802-808` documents does not exist before 2.12.0, so a translated
 * 2.12.0 surface bound to an installed 2.11.3 library would compile and then
 * fail to link. Pinning the include path is what keeps the two the same
 * library.
 *
 * ## What the translation makes of this header
 *
 * Two shapes in `utf8proc.h` need no help and get none here:
 *
 *   * `utf8proc_property_t` (`utf8proc.h:240-320`) is a struct of C bit fields
 *     (`comb_index:10`, `comb_length:5`, `comb_issecond:1`, then `unsigned`
 *     bit fields). Zig's translator demotes any record containing a bit field
 *     to an opaque type, so `c.utf8proc_property_t` is `opaque{}` and no field
 *     of it is reachable from Zig. That is upstream's ABI, not a gap in this
 *     package: `utf8proc_get_property` is upstream's only way to reach those
 *     values, the values it returns are readable in C only, and no upstream
 *     accessor exposes `combining_class`, `bidi_class` or `boundclass` as a
 *     scalar either. `zig/root.zig` therefore treats the pointer as opaque
 *     rather than pretending at a layout, and `README.zig.md` states the
 *     boundary.
 *
 *   * The five error codes (`utf8proc.h:223-231`) are object-like `#define`s,
 *     not enumerators, and the translator turns an object-like macro into a
 *     module-level `pub const`, so they arrive as `c.UTF8PROC_ERROR_NOMEM` and
 *     friends. The option flags are enumerators of `utf8proc_option_t`
 *     (`utf8proc.h:150-216`), but they do not arrive any differently: Zig's
 *     translator gives a C enum its underlying integer type --
 *     `c.utf8proc_option_t` is `c_uint` -- and emits each enumerator as a
 *     module-level `pub const` beside it, so they are read as
 *     `c.UTF8PROC_NULLTERM`, `c.UTF8PROC_COMPOSE` and the rest. They are not
 *     members of a Zig enum, and there is no scoped type to qualify them with.
 *     Both spellings are upstream's own and neither is adjusted here.
 * `UTF8PROC_DLLEXPORT` translates to an empty string constant on both routes in
 * the static linkage, which is the correct result: that is what the macro
 * expands to when `UTF8PROC_STATIC` is defined. In the shared linkage the
 * macro expands to `__declspec(dllimport)` under `_WIN32` and to the
 * default-visibility attribute elsewhere, and Zig's translator records neither
 * as anything but an empty declaration attribute, which is also the correct
 * result for a declaration whose storage class is not a Zig concept. Nothing in
 * this package references the constant.
 */

#ifndef FOUNDATION_UTF8PROC_TRANSLATE_H
#define FOUNDATION_UTF8PROC_TRANSLATE_H

/* The export macros are supplied by build.zig, per linkage, and are
 * deliberately not defined here. See "The export macros are build
 * configuration" above. */

/* The compiler's own 128-bit typedefs, restated for the translator. */
#if defined(__SIZEOF_INT128__)
typedef __int128 __int128_t;
typedef unsigned __int128 __uint128_t;
#endif

#include <utf8proc.h>

#endif /* FOUNDATION_UTF8PROC_TRANSLATE_H */