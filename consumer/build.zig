// SPDX-License-Identifier: MIT

//! External consumer check for `utf8proc`.
//! Uses only `dep.module("utf8proc")`, with no separate artifact, header, or libc link.
//! Passes `-Dlinkage` and `-Druntime` through unchanged; runtime mode needs an explicit provider.
//! `zig build run` checks independent expectations; `zig build install` builds without running.

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

    // The library module declares the libc dependency used by utf8proc allocations.
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
