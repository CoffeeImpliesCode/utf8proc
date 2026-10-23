const std = @import("std");

const manifest = @import("build.zig.zon");

/// Upstream API version, matched to the package manifest.
const upstream = struct {
    const version: std.SemanticVersion = .{ .major = 2, .minor = 12, .patch = 0 };
};

/// Upstream shared-library ABI version.
const abi_version: std.SemanticVersion = .{ .major = 3, .minor = 3, .patch = 0 };

const module_name = "utf8proc";
const lib_name = "utf8proc";

/// Import name for the translated C header.
const c_import_name = "c";

/// Import name for the runtime loader core.
const rt_import_name = "rt";

/// Upstream public C header installed with the library.
const public_header = "utf8proc.h";

/// One translation unit; utf8proc.c includes utf8proc_data.c.
const core_sources = [_][]const u8{
    "utf8proc.c",
};

const c_flags = [_][]const u8{
    "-std=gnu11",
};
const Macro = [2][]const u8;

fn libraryMacros(linkage: std.lang.LinkMode) []const Macro {
    return switch (linkage) {
        .static => &.{.{ "UTF8PROC_STATIC", "1" }},
        .dynamic => &.{.{ "UTF8PROC_EXPORTS", "1" }},
    };
}

fn consumerMacros(linkage: std.lang.LinkMode) []const Macro {
    return switch (linkage) {
        .static => &.{.{ "UTF8PROC_STATIC", "1" }},
        .dynamic => &.{},
    };
}

const translate_header = "zig/translate.h";

/// The Zig facade, re-exporting the translation as `pub const c`.
const facade_root = "zig/root.zig";

/// API exercise that calls every public facade function.
const exercise_root = "zig/api_exercise.zig";

const test_root = "tests.zig";

const smoke_root = "smoke.zig";

const upstream_test_support = "test/tests.c";

const UpstreamTest = struct {
    name: []const u8,
    source: []const u8,
    fixtures: []const []const u8 = &.{},
    reads_unicode_version: bool = false,
};

const upstream_tests = [_]UpstreamTest{
    .{
        .name = "normtest",
        .source = "test/normtest.c",
        .fixtures = &.{"testdata/NormalizationTest.txt"},
    },
    .{
        .name = "graphemetest",
        .source = "test/graphemetest.c",
        .fixtures = &.{"testdata/GraphemeBreakTest.txt"},
    },
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
    .{
        .name = "misc",
        .source = "test/misc.c",
        .reads_unicode_version = true,
    },
    .{
        .name = "maxdecomposition",
        .source = "test/maxdecomposition.c",
    },
};

const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

const Graph = struct {
    c_lib: *std.Build.Step.Compile,
    /// Typed facade with linked or runtime dispatch.
    module: *std.Build.Module,
    consumer_macros: []const Macro,
    /// Delivered linkage; unsupported dynamic requests are refused.
    linkage: std.lang.LinkMode,
};

/// Whether this target can deliver a shared object; Windows DLLs are loadable without an ELF linker.
fn targetCarriesSharedObject(target: std.Build.ResolvedTarget) bool {
    if (target.result.os.tag == .windows) return true;
    return std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

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

/// Refuse unsupported dynamic linkage; never substitute a static archive.
fn deliveredLinkage(b: *std.Build, target: std.Build.ResolvedTarget, requested: std.lang.LinkMode) std.lang.LinkMode {
    if (requested == .dynamic) {
        if (sharedObjectRefusal(b, target)) |reason| std.debug.panic("utf8proc: {s}", .{reason});
    }
    return requested;
}

fn artifactName(b: *std.Build, target: std.Build.ResolvedTarget, public: bool) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

const TranslationRoute = enum {
    aro,
    preprocessed,
};

fn translationRoute(target: std.Build.ResolvedTarget) TranslationRoute {
    const rt = target.result;
    return switch (rt.os.tag) {
        // Aro cannot process the _Pragma tokens in NetBSD headers.
        .netbsd => .preprocessed,
        // Use the target preprocessor for OpenBSD ILP32 and MIPS headers.
        .openbsd => if (std.Target.ptrBitWidth(&rt) != 64 or rt.cpu.arch == .mips64 or rt.cpu.arch == .mips64el) .preprocessed else .aro,
        // Aro lacks _X86_ for 32-bit Windows headers.
        .windows => if (rt.cpu.arch == .x86) .preprocessed else .aro,
        // Aro handles other target headers directly.
        else => .aro,
    };
}

fn preprocessedHeader(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    macros: []const Macro,
) std.Build.LazyPath {
    const run = b.addSystemCommand(&[_][]const u8{ b.graph.zig_exe, "cc", "-E", "-dD" });
    const triple = target.result.zigTriple(b.allocator) catch @panic("utf8proc: unspellable target");
    // Distinguish preprocessing steps by target.
    run.setName(b.fmt("preprocess utf8proc.h {s}", .{triple}));
    if (!target.query.isNative()) {
        run.addArg("-target");
        run.addArg(triple);
    }
    // Use the same package include root as the core and translator.
    run.addDirectoryArg2(b.path("."), .{ .prefix = "-I" });
    // Apply consumer-side linkage macros to the preprocessor.
    for (macros) |macro| run.addArg(b.fmt("-D{s}={s}", .{ macro[0], macro[1] }));
    run.addArg("-o");
    const preprocessed = run.addOutputFileArg2("utf8proc-translate.c", .{});
    run.addArg("-MD");
    // Track transitive headers for cache invalidation.
    _ = run.addDepFileOutputArg2("utf8proc-translate.d", .{ .prefix = "-MF" });
    // Track the translation header as a direct input.
    run.addFileArg2(b.path(translate_header), .{});
    return preprocessed;
}

const GraphOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    public: bool,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
};

const runtime_graph = @import("runtime/graph.zig");

fn addGraph(b: *std.Build, options: GraphOptions) Graph {
    const target = options.target;
    const optimize = options.optimize;
    const linkage = deliveredLinkage(b, target, options.linkage);
    const build_macros = libraryMacros(linkage);
    const use_macros = consumerMacros(linkage);
    const c_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // The native core uses libc allocation routines.
        .link_libc = true,
        // Shared objects need PIC; static mode keeps the default.
        .pic = if (linkage == .dynamic) true else null,
    });
    // Use the package header for core and translator includes.
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
        // Apply upstream's ABI version only to shared libraries.
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = c_mod,
    });
    c_lib.installHeader(b.path(public_header), public_header);

    // Translate the same header and target configuration as the core.
    const translate = b.addTranslateC(.{
        .root_source_file = switch (translationRoute(target)) {
            .aro => b.path(translate_header),
            .preprocessed => preprocessedHeader(b, target, use_macros),
        },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // Apply the include root on both translation routes.
    translate.addIncludePath(b.path("."));
    // Apply consumer-side, never export-side, linkage macros.

    // Bind the facade to translated declarations or generated dispatch.
    for (use_macros) |macro| translate.defineCMacro(macro[0], macro[1]);
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
        // Runtime-loaded modules resolve through an explicit provider.
    } else {
        // Link the native artifact through the public facade.
        module.addImport(rt_import_name, runtime_graph.createCoreModule(b, target, optimize));
        module.linkLibrary(c_lib);
    }
    // Expose the package header to C consumers of the facade.
    module.addIncludePath(b.path("."));

    return .{ .c_lib = c_lib, .module = module, .consumer_macros = use_macros, .linkage = linkage };
}

fn facadeModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
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
fn runConsumer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
) *std.Build.Step.Run {
    const triple = target.query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    const cpu = target.query.serializeCpuAlloc(b.allocator) catch @panic("OOM");
    defer b.allocator.free(cpu);

    const run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    run.setName("consumer package");
    // Keep relative cache and Zig library environment paths rooted at the caller's cwd.
    run.addArg("--build-file");
    run.addFileArg2(b.path("consumer/build.zig"), .{ .make_absolute = true });
    for ([_][]const u8{ "ZIG_GLOBAL_CACHE_DIR", "ZIG_LIB_DIR" }) |key| {
        if (b.graph.environ_map.get(key)) |value| run.setEnvironmentVariable(key, value);
    }
    run.addArg(if (hostCanExecute(b, target)) "run" else "install");
    run.addArg(b.fmt("-Dtarget={s}", .{triple}));
    run.addArg(b.fmt("-Dcpu={s}", .{cpu}));
    run.addArg(b.fmt("-Doptimize={s}", .{@tagName(optimize)}));
    run.addArg(b.fmt("-Dlinkage={s}", .{@tagName(linkage)}));
    run.addArg(b.fmt("-Druntime={}", .{runtime_loaded}));
    run.addThirdPartyEnabledArgDarling(.{ .enabled = "-fdarling" });
    run.addThirdPartyEnabledArgQemu(.{ .enabled = "-fqemu" });
    run.addThirdPartyEnabledArgRosetta(.{ .enabled = "-frosetta" });
    run.addThirdPartyEnabledArgWasmtime(.{ .enabled = "-fwasmtime" });
    run.addThirdPartyEnabledArgWine(.{ .enabled = "-fwine" });
    run.addArgs(&.{ "-j8", "--summary", "all", "--cache-dir" });
    run.addDirectoryArg2(
        .{ .relative = .{ .base = .local_cache, .sub_path = "consumer" } },
        .{ .make_absolute = true },
    );
    run.addArg("--prefix");
    run.addDirectoryArg2(
        .{ .relative = .{ .base = .install_prefix } },
        .{ .make_absolute = true },
    );
    run.addArg("--");
    run.addPassthruArgs();
    run.has_side_effects = true;
    return run;
}

fn hostCanExecute(b: *std.Build, target: std.Build.ResolvedTarget) bool {
    const host = &b.graph.host.result;
    return switch (std.zig.system.getExternalExecutor(b.graph.io, &target.result, .{
        .host_cpu_arch = host.cpu.arch,
        .host_os_tag = host.os.tag,
        .link_mode = .dynamic,
        .link_libc = true,
    })) {
        .native => true,
        else => false,
    };
}

/// Read the Unicode data version used by upstream's misc test.
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

fn readPackageFile(b: *std.Build, name: []const u8) []u8 {
    const file = b.root.openFile(b.graph.io, name, .{}) catch |err| {
        std.debug.panic("cannot open {s}: {s}", .{ name, @errorName(err) });
    };
    defer file.close(b.graph.io);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(b.graph.io, &buffer);
    return reader.interface.allocRemaining(b.allocator, .limited(8 << 20)) catch |err| {
        std.debug.panic("cannot read {s}: {s}", .{ name, @errorName(err) });
    };
}

/// Add the committed Unicode version to misc.c's compile flags.
fn upstreamTestFlags(b: *std.Build, spec: UpstreamTest) []const []const u8 {
    if (!spec.reads_unicode_version) return &c_flags;
    const flags = b.allocator.alloc([]const u8, 2) catch @panic("OOM");
    flags[0] = c_flags[0];
    flags[1] = b.fmt("-DUNICODE_VERSION=\"{s}\"", .{unicodeVersion(b)});
    return flags;
}

fn addUpstreamTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    graph: Graph,
    spec: UpstreamTest,
    name: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("."));
    // Apply consumer macros; never define UTF8PROC_EXPORTS here.
    for (graph.consumer_macros) |macro| mod.addCMacro(macro[0], macro[1]);
    const flags = upstreamTestFlags(b, spec);
    mod.addCSourceFile(.{ .file = b.path(upstream_test_support), .flags = flags });
    mod.addCSourceFile(.{ .file = b.path(spec.source), .flags = flags });
    mod.linkLibrary(graph.c_lib);
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Compile all test roots for one target without running them.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
) void {
    const cross_target = b.resolveTargetQuery(query);
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // Fail an unsupported shared row without aborting supported checks.
    if (linkage == .dynamic) {
        if (sharedObjectRefusal(b, cross_target)) |reason| {
            step.dependOn(&b.addFail(b.fmt(
                "utf8proc: check row {s}: {s} No artifact was built for this row, and nothing was substituted for it.",
                .{ triple, reason },
            )).step);
            return;
        }
    }

    // Check the selected linkage; matrix targets are compile-only.
    const graph = addGraph(b, .{
        .target = cross_target,
        .optimize = optimize,
        .public = false,
        .linkage = linkage,
        .runtime_loaded = false,
    });

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


fn targetWasNamed(b: *const std.Build) bool {
    return b.user_input_options.contains("target");
}

fn macroNames(b: *std.Build, macros: []const Macro) []const u8 {
    if (macros.len == 0) return "none";
    var out: std.ArrayList(u8) = .empty;
    for (macros, 0..) |macro, i| {
        if (i != 0) out.append(b.allocator, ' ') catch @panic("OOM");
        out.appendSlice(b.allocator, macro[0]) catch @panic("OOM");
    }
    return out.items;
}

/// License and provenance records installed with the package.
const licence_records = [_][]const u8{
    "LICENSE.md",
    "FORK-LICENSE.md",
    "NOTICE.md",
    "UPSTREAM.md",
    "CHANGELOG.md",
    "testdata/Unicode-License-V3.txt",
};

/// Unicode conformance corpora and their licence.
const fixtures = [_][]const u8{
    "testdata/NormalizationTest.txt",
    "testdata/GraphemeBreakTest.txt",
    "testdata/DerivedCoreProperties.txt",
    "testdata/Lowercase.txt",
    "testdata/Uppercase.txt",
    "testdata/Unicode-License-V3.txt",
};

fn installRecords(b: *std.Build) void {
    for (licence_records) |name| {
        b.installFile(name, b.pathJoin(&.{ "share", "licenses", lib_name, std.Io.Dir.path.basename(name) }));
    }
}

fn installFixtures(b: *std.Build) void {
    for (fixtures) |name| {
        b.installFile(name, b.pathJoin(&.{ "share", lib_name, "testdata", std.Io.Dir.path.basename(name) }));
    }
}

/// Render the upstream pkg-config template with relocatable paths and linkage-specific macros.
fn installPkgConfig(b: *std.Build, linkage: std.lang.LinkMode) void {
    const output = b.addWriteFiles();
    const contents = renderPkgConfig(
        b,
        readPackageFile(b, "libutf8proc.pc.in"),
        linkage,
    );
    const pc = output.add("libutf8proc.pc", contents);
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(
        pc,
        .lib,
        "pkgconfig/libutf8proc.pc",
    ).step);
}

fn renderPkgConfig(b: *std.Build, template: []const u8, linkage: std.lang.LinkMode) []const u8 {
    // Keep the shared Cflags free of a trailing space.
    const cflags = switch (linkage) {
        .static => " -DUTF8PROC_STATIC",
        .dynamic => "",
    };
    const version = b.fmt("{d}.{d}.{d}", .{
        upstream.version.major,
        upstream.version.minor,
        upstream.version.patch,
    });
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

    // Static is the default; dynamic uses upstream's ABI version.
    const requested_linkage = b.option(
        std.lang.LinkMode,
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

    // Runtime dispatch changes module linking, not artifact delivery.
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
    // Install the upstream license and Unicode data terms with the artifact.
    b.installFile("LICENSE.md", "LICENSE.md");
    installRecords(b);
    installFixtures(b);
    installPkgConfig(b, graph.linkage);

    // Compile the smoke program by default without installing its binary.
    const smoke = b.addExecutable(.{
        .name = "utf8proc-smoke",
        .root_module = facadeModule(b, target, optimize, graph, smoke_root),
    });
    b.getInstallStep().dependOn(&smoke.step);

    // Keep the smoke run independent of installation.
    const run_smoke = b.addRunArtifact(smoke);
    // Always execute the smoke program.
    run_smoke.has_side_effects = true;
    run_smoke.addPassthruArgs();
    b.step("smoke", "Run the smoke program").dependOn(&run_smoke.step);

    // Use tests.zig as the test root so Zig discovers its test blocks.
    const unit_tests = b.addTest(.{
        .name = "utf8proc-tests",
        .root_module = facadeModule(b, target, optimize, graph, test_root),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    // Always run the tests against the current build.
    run_tests.has_side_effects = true;
    const test_step = b.step("test", "Run the behavioural tests for the selected target");
    test_step.dependOn(&run_tests.step);

    const exercise = b.addExecutable(.{
        .name = "utf8proc-api-exercise",
        .root_module = facadeModule(b, target, optimize, graph, exercise_root),
    });
    // Compile the API exercise by default without installing its binary.
    const run_exercise = b.addRunArtifact(exercise);
    run_exercise.has_side_effects = true;
    b.step("exercise", "Run every supported facade operation").dependOn(&run_exercise.step);
    b.getInstallStep().dependOn(&exercise.step);
    test_step.dependOn(&run_exercise.step);

    // Run upstream C tests with committed fixtures as tracked inputs.
    const upstream_step = b.step(
        "upstream-test",
        "Build and run upstream's own C test programs against the compiled library",
    );
    for (upstream_tests) |spec| {
        const program = addUpstreamTest(b, target, optimize, graph, spec, spec.name);
        const run = b.addRunArtifact(program);
        for (spec.fixtures) |fixture| run.addFileArg2(b.path(fixture), .{});
        run.has_side_effects = true;
        upstream_step.dependOn(&run.step);
    }

    // Compile the facade and test roots for each matrix target.
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

    b.step(
        "consumer",
        "Build the independent consumer package and run it for native targets",
    ).dependOn(&runConsumer(b, target, optimize, requested_linkage, runtime_loaded).step);

    // Print build configuration, not test results.
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
        // Report runtime dispatch separately from artifact delivery.
        std.debug.print(
            "utf8proc: runtime-loaded dispatch (-Druntime=true); no library is linked into the module\n",
            .{},
        );
    }
}
