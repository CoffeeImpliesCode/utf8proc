#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# cross-test.profile.sh — settings only, for the `cross-test` harness.
#
# `cross-test` is run from this package root. It compiles and runs this
# package's real `test` step, `zig build test -Dtarget=TARGET`, once per target
# of the published Zig 0.16.0 Tier 1/2 matrix (53 platforms), and it owns the
# matrix, the runner policy and the QEMU/Wine/Wasmtime detection. This file
# configures none of that and must not: it holds ordinary Bash variable
# definitions only, no `cross_build_command`/`cross_artifact` hooks (so the
# standard Zig-build mode is used), no `CROSS_MATRIX` and no `TARGETS` (so the
# full published matrix is selected, never a subset), and no host-specific
# path. Every value here is a default that the command line overrides, so
# `cross-test --jobs N --build-jobs N --build-timeout N --timeout N` still
# wins; see `cross-test --help`.
#
# There is deliberately no matrix or target list named here for a second
# reason specific to this package. The fast six-target compile matrix in
# `build.zig` is a *different* thing from this one: `zig build check` compiles
# the C core, the translation, the facade, the API exercise, the tests, the
# smoke program and all nine upstream C test programs for six targets without
# running anything. A matrix declared in this file would replace the 53-platform
# run rather than add to it, and the two must not be confused: `check` is
# compile evidence, and this profile runs the behavioural tests.
#
# `CROSS_LIBC_RUNTIMES` is deliberately absent: it names a directory of foreign
# libc loaders on the machine running the harness, which is that machine's
# business and not this package's. Supply it in the environment when a
# GNU-libc or dynamically linked musl cell needs one.
#
# Licence: **MIT**, SPDX identifier `MIT`. `FORK-LICENSE.md` records the grant,
# the owner's authorization of 2026-10-04 and the scope; this file is inside that
# scope, and the earlier "none asserted" note described the state before the
# identifier was supplied, not a different view of it.
#
# Linkage.  This profile chooses none.  The harness owns `-Dtarget`, and no
# `-D` option appears below, so every one of the 53 platforms is built through
# this package's default `static` graph -- the artifact this SDK produced before
# `-Dlinkage` existed, and the one every gate in this repository's recorded
# history observed.  A shared-artifact matrix is a separate gate: it is the
# same `cross-test` run with `CROSS_BUILD_ARGS=(-Dlinkage=dynamic)` supplied by
# whoever runs it, so this file does not hard-code one linkage and silently
# narrow the other out.  That shared run is also where the refusal is observable:
# a platform with no dynamic linker -- WASI, whose `std.Target.DynamicLinker.kind`
# is `.none` -- cannot carry a `.so`, so `build.zig` stops with the target's
# name and the reason rather than compiling an archive under the same flag.  Such
# a cell is a refused request, not `build_only` coverage and not a pass, and the
# harness is what records which cells those are.  The default graph below is
# unaffected: with no `-Dlinkage` every one of the 53 platforms is static,
# including the WASI ones.
#
# The step that runs the public Zig API tests. This is the harness default too;
# it is named here so the package's contract is in the package. `build.zig`
# hands that step a real `addRunArtifact` for whatever `-Dtarget` resolves to,
# which is what leaves the runner policy open: a host target executes, a
# foreign target executes under whatever executor the harness detects (QEMU
# user mode, Wine, wasmtime), and a foreign target with no executor is reported
# as build-only coverage — compiled, never executed, never counted as a pass.
CROSS_BUILD_STEP=test

# One target at a time inside one `zig build`. A target graph compiles the
# 2.3 MB `utf8proc_data.c` translation unit inside `utf8proc.c`, translates
# `utf8proc.h` for that target, and links the test binary against the result --
# and on the targets whose C library Aro cannot preprocess it puts the target's
# own C preprocessor in front of the translator first (`build.zig`'s
# `translationRoute`), which is one extra cached step per such target.
# Keeping four build jobs available lets a cell use the machine without making
# the host oversubscribed by 53 targets' worth of memory pressure.
CROSS_BUILD_JOBS=4

# Deadline for one `zig build test -Dtarget=...`, covering both the compile and
# the run of that target's test binary.
CROSS_BUILD_TIMEOUT=3600

# Per-test-binary deadline, passed on as `zig build --test-timeout`. The
# conformance tests read the whole of `NormalizationTest.txt` (2.8 MB, 20,232
# lines, 20 conformance columns each), the whole of `GraphemeBreakTest.txt`
# (137 KB, 883 lines) and the whole of the `Lowercase.txt`/`Uppercase.txt`
# ranges, with no sampling. Those corpora are embedded whole in the test binary
# at compile time -- `tests.zig` reaches each one through `@embedFile` -- so no
# runner needs a source-tree path and no cell reads a corpus off disk at run
# time; the whole of the cost is compiling them in and then executing all of
# them. The API exercise alongside them has no corpus at all: it is a fixed set
# of small, independent checks. On a cell whose runner is an emulator rather
# than the host that is a long run, so the 300 s default is not a ceiling this
# package can meet. Every value on this file is a default chosen in advance, not
# a receipt; what a run produced belongs to the driver's own cross-test
# summary, not here.
CROSS_TIMEOUT=1800