// SPDX-License-Identifier: MIT

//! A package that consumes `utf8proc` from outside.
//!
//! This exists to prove one thing: that a dependent needs only
//! `dep.module("utf8proc")` and gets a working, correctly linked library. If the
//! facade module stopped carrying the compiled archive, or the translated
//! header stopped matching the compiled `utf8proc.c`, or the package root
//! stopped being on the facade's include path, this would stop building or stop
//! producing the results below, and nothing inside the library itself would
//! notice.
//!
//! Run it with `zig build run`. It exits non-zero if any result disagrees with
//! the independent expectation it states, so it is a check and not a demo.
//! `zig build install` builds that same executable without running it, which is
//! what a caller that cannot execute the target receives instead.
//!
//! It deliberately asks for nothing but the module. There is no
//! `dep.artifact("utf8proc")` here, no `-I` for `utf8proc.h`, no
//! `-DUTF8PROC_STATIC`, and no `link_libc`: a dependent that had to supply any
//! of those would prove nothing about the module being self-contained, and
//! adding them here would hide a library that forgot to declare them.
//!
//! Two options are passed through, and both are the library's own. `-Dlinkage`
//! selects `libutf8proc.a` (the default) or the shared object, and
//! `-Druntime=true` selects the dispatch in which the module links no library
//! and every native call goes through a table an explicit `load` fills. Each
//! value is handed to `b.dependency("utf8proc", ...)` unchanged, so the consumer
//! is built against the configuration that was asked for rather than against a
//! second, unrequested one. Nothing here interprets either value, and a value
//! the library does not recognise is the library's error to report, not
//! something this build translates into something else.
//!
//! `src/main.zig` is written for both: `utf8proc.runtime_loaded` is a comptime
//! constant, so the runtime-loading build loads the provider named by
//! `--provider <path>` or by `UTF8PROC_TEST_PROVIDER` before its first native
//! call and every answer below follows from that one call. Run with
//! `-Druntime=true`, that environment variable has to be set by the caller; the
//! build cannot set it, and the program says which variable is missing rather
//! than failing on an unresolved symbol.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Which delivery of utf8proc to build against: the static archive " ++
            "(the library's own default) or the shared object. Forwarded to the " ++
            "library unchanged.",
    ) orelse .static;

    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Build against the runtime-loading module: every native call goes " ++
            "through one process-lifetime table an explicit load fills, and the " ++
            "module links no library. Forwarded to the library unchanged.",
    ) orelse false;

    const dep = b.dependency("utf8proc", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .runtime = runtime_loaded,
    });

    // No `link_libc` here on purpose. The C requirement belongs to the library
    // module, which carries it: utf8proc's core allocates with `malloc` and
    // releases through `utf8proc_free`, so a dependent needs a libc, and the
    // module is what must say so. This program needs nothing beyond what the
    // library already brings.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("utf8proc", dep.module("utf8proc"));

    const exe = b.addExecutable(.{
        .name = "utf8proc-consumer",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.has_side_effects = true;
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}
