//! Executable smoke test for the published facade in linked and runtime modes.
//! It checks basic calls and provider loading; `tests.zig` covers the Unicode corpora.

const std = @import("std");
const utf8proc = @import("utf8proc");

/// Runtime provider environment variable.
const provider_variable = "UTF8PROC_TEST_PROVIDER";

/// No provider configured for a runtime build.
const ConfigurationError = error{NoProviderConfigured};

pub fn main(init: std.process.Init) !void {
    var output_buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writer(init.io, &output_buffer);
    const w = &out.interface;
    defer out.flush() catch {};

    // Runtime calls need a loaded provider; linked builds omit this branch.
    if (comptime utf8proc.runtime_loaded) {
        try utf8proc.load(.{ .path = try providerRequest(init) });
    }

    try w.print("utf8proc API {s}, Unicode {s} ({s} build)\n", .{
        utf8proc.version(),
        utf8proc.unicodeVersion(),
        if (utf8proc.runtime_loaded) "runtime-loaded" else "linked",
    });

    try checkNormalization(w);
    try checkCase(w);
    try checkGraphemes(w);
    try checkShortcuts(w);
    try checkProperties(w);
    try checkReencode(w);

    try w.print("smoke OK\n", .{});
    try out.flush();
}

/// Checks caller-buffer normalization without allocating.
fn checkNormalization(w: *std.Io.Writer) !void {
    var codepoints: [64]i32 = undefined;

    // NFD splits `e` + acute; NFC composes it again.
    const decomposed = try utf8proc.decompose("e\u{0301}", codepoints[0..], .{
        .stable = true,
        .decompose = true,
    });
    const count = switch (decomposed) {
        .written => |n| n,
        .needs_more => return error.SmokeWorkspaceTooSmall,
    };
    if (count != 2 or codepoints[0] != 0x0065 or codepoints[1] != 0x0301) {
        return error.SmokeDecompositionMismatch;
    }

    const needed = try utf8proc.decomposeCount("\u{FB01}", .{
        .stable = true,
        .compose = true,
        .compat = true,
    });
    if (needed != 2) return error.SmokeDecompositionMismatch;

    const composed = try utf8proc.normalizeUtf32(codepoints[0..count], .{ .compose = true });
    if (composed != 1 or codepoints[0] != 0x00E9) return error.SmokeCompositionMismatch;

    var workspace: [4 * 4 + 1]u8 align(4) = undefined;
    @memcpy(workspace[0 .. composed * 4], std.mem.sliceAsBytes(codepoints[0..composed]));
    const written = try utf8proc.reencode(workspace[0..], composed, .{});
    if (!std.mem.eql(u8, "\u{00E9}", workspace[0..written])) return error.SmokeReencodeMismatch;
    if (workspace[written] != 0) return error.SmokeReencodeMismatch;

    try w.print("  NFC  e+U+0301 -> {s} (U+00E9), ligature U+FB01 decomposes to {d} codepoints\n", .{
        workspace[0..written],
        needed,
    });
}

fn checkCase(w: *std.Io.Writer) !void {
    // Full case-fold expands sharp S to "ss"; simple mappings do not.
    if (utf8proc.toUpper('a') != 'A') return error.SmokeCaseMismatch;
    if (utf8proc.toLower('A') != 'a') return error.SmokeCaseMismatch;
    if (utf8proc.toTitle(0x01C4) != 0x01C5) return error.SmokeCaseMismatch;
    if (!utf8proc.isLower('a') or !utf8proc.isUpper('A')) return error.SmokeCaseMismatch;
    // Titlecase letters are not `isUpper`.
    if (utf8proc.isUpper(0x01C5)) return error.SmokeCaseMismatch;

    const folded = try utf8proc.map("\u{1E9E}", .{
        .stable = true,
        .compose = true,
        .compat = true,
        .casefold = true,
        .ignore = true,
    });
    defer folded.deinit();
    if (!std.mem.eql(u8, "ss", folded.bytes())) return error.SmokeCaseMismatch;

    try w.print("  case U+1E9E folds to {s}; titlecase U+01C5 is not isupper\n", .{folded.bytes()});
}

fn checkGraphemes(w: *std.Io.Writer) !void {
    // Stateful segmentation keeps combining marks and regional-indicator pairs together.
    const combining = [_]i32{ 'a', 0x0301, 'b' };
    if (utf8proc.firstGraphemeBreak(combining[0..]) != 2) return error.SmokeGraphemeMismatch;

    const flags = [_]i32{ 0x1F1E6, 0x1F1E8, 0x1F1EA, 0x1F1EC };
    if (utf8proc.firstGraphemeBreak(flags[0..]) != 2) return error.SmokeGraphemeMismatch;
    if (utf8proc.graphemeBreak(flags[0], flags[1])) return error.SmokeGraphemeMismatch;

    // CHARBOUND emits invalid-UTF-8 `0xFF` markers.
    const marked = try utf8proc.map("\u{1F1E6}\u{1F1E8}\u{1F1EA}\u{1F1EC}", .{ .charbound = true });
    defer marked.deinit();
    var markers: usize = 0;
    for (marked.bytes()) |byte| {
        if (byte == 0xFF) markers += 1;
    }
    if (markers != 2) return error.SmokeGraphemeMismatch;

    try w.print("  graphemes: {d} clusters in {d} regional indicators, {d} 0xFF markers\n", .{ 2, flags.len, markers });
}

fn checkProperties(w: *std.Io.Writer) !void {
    if (utf8proc.charWidth('a') != 1) return error.SmokeWidthMismatch;
    if (utf8proc.charWidth(0x0301) != 0) return error.SmokeWidthMismatch;
    if (utf8proc.charWidth(0x6F22) != 2) return error.SmokeWidthMismatch;
    if (!utf8proc.charWidthAmbiguous(0x00A1)) return error.SmokeWidthMismatch;
    if (!std.mem.eql(u8, "Zs", utf8proc.categoryString(0x0020))) return error.SmokeCategoryMismatch;
    if (utf8proc.categoryString(0x110000)[0] != 'C') return error.SmokeCategoryMismatch;
    if (utf8proc.utf8Class(0xE2) != 3) return error.SmokeWidthMismatch;

    try w.print("  properties: U+6F22 width {d}, U+0301 width {d}, U+0020 is {s}\n", .{
        utf8proc.charWidth(0x6F22),
        utf8proc.charWidth(0x0301),
        utf8proc.categoryString(0x0020),
    });
}

/// Checks all five normalization shortcuts and their collapsed error.
fn checkShortcuts(w: *std.Io.Writer) !void {
    // NFC composes `e` + acute; NFKD splits U+FB01 to "fi".
    const composed = try utf8proc.nfc("e\u{0301}");
    defer composed.deinit(); // utf8proc_free; not allocator.free
    if (!std.mem.eql(u8, "\u{00E9}", composed.bytes())) return error.SmokeShortcutMismatch;

    const ligature = try utf8proc.nfkd("\u{FB01}");
    defer ligature.deinit();
    if (!std.mem.eql(u8, "fi", ligature.bytes())) return error.SmokeShortcutMismatch;

    // Upstream's null result cannot distinguish malformed input from allocation failure.
    if (utf8proc.nfc("\xFF")) |_| {
        return error.SmokeShortcutShouldHaveFailed;
    } else |err| switch (err) {
        error.NoResult => {},
    }

    try w.print("  shortcuts: NFC e+U+0301 -> {s}, NFKD U+FB01 -> {s}, invalid UTF-8 refused\n", .{
        composed.bytes(),
        ligature.bytes(),
    });
}

/// Reads `--provider` or `UTF8PROC_TEST_PROVIDER`; no fallback is tried.
fn providerRequest(init: std.process.Init) ConfigurationError![]const u8 {
    const args = init.minimal.args.toSlice(init.arena.allocator()) catch
        return noProvider();
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) return noProvider();
            return args[index + 1];
        }
    }
    return init.environ_map.get(provider_variable) orelse
        return noProvider();
}

fn noProvider() ConfigurationError {
    std.debug.print(
        "smoke: this is a runtime-loading build. Pass --provider <path>, or " ++
            "export " ++ provider_variable ++ " with a shared object exporting " ++
            "the entry points of utf8proc.h. Nothing is loaded by default and " ++
            "no other file is tried.\n",
        .{},
    );
    return error.NoProviderConfigured;
}

/// Confirms `reencode` requires a spare byte for the terminator.
fn checkReencode(w: *std.Io.Writer) !void {
    const codepoints = [_]i32{ 0x1F1E6, 0x1F1E8 };
    var tight: [4 * 2]u8 align(4) = undefined;
    @memcpy(tight[0..], std.mem.sliceAsBytes(codepoints[0..]));

    if (utf8proc.reencode(tight[0..], codepoints.len, .{})) |_| {
        return error.SmokeReencodeShouldHaveFailed;
    } else |err| switch (err) {
        error.WorkspaceTooSmall => {},
        else => return err,
    }

    var roomy: [4 * 2 + 1]u8 align(4) = undefined;
    @memcpy(roomy[0 .. 4 * 2], std.mem.sliceAsBytes(codepoints[0..]));
    const written = try utf8proc.reencode(roomy[0..], codepoints.len, .{});

    try w.print("  reencode: {d} bytes for {d} codepoints, terminator byte {d}, short workspace refused\n", .{
        written,
        codepoints.len,
        roomy[written],
    });
}
