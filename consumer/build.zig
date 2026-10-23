// SPDX-License-Identifier: MIT

//! External consumer using only `dep.module("utf8proc")`.
//! Runtime mode requires an explicit provider.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(
        std.lang.LinkMode,
        "linkage",
        "Library linkage: static or dynamic",
    ) orelse .static;
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Use runtime dispatch with an explicit provider",
    ) orelse false;

    const dep = b.dependency("utf8proc", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .runtime = runtime_loaded,
    });

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
    run_exe.addPassthruArgs();
    b.step("run", "Build and run the consumer program").dependOn(&run_exe.step);
}
