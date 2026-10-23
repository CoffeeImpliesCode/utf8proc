//! External consumer of the published `utf8proc` package.
//! Uses only `dep.module("utf8proc")` and independent expectations.
//! Builds linked or runtime-loaded; runtime mode requires an explicit provider before API calls.

const std = @import("std");
const utf8proc = @import("utf8proc");

/// Environment variable used when runtime mode has no `--provider` argument.
const provider_variable = "UTF8PROC_TEST_PROVIDER";

/// Error returned when runtime mode has no provider request.
const ConfigurationError = error{NoProviderConfigured};

pub fn main(init: std.process.Init) !void {
    // Load before any API call; runtime dispatch needs a ready table.
    if (comptime utf8proc.runtime_loaded) {
        try utf8proc.load(.{ .path = try providerRequest(init) });
    }

    var output_buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writer(init.io, &output_buffer);
    const w = &out.interface;
    defer out.flush() catch {};

    try w.print("consumer: utf8proc {s} / Unicode {s} ({s} build)\n", .{
        utf8proc.version(),
        utf8proc.unicodeVersion(),
        if (utf8proc.runtime_loaded) "runtime-loaded" else "linked",
    });

    try checkNormalization(w);
    try checkCase(w);
    try checkGraphemes(w);
    try checkProperties(w);
    try checkReencode(w);
    try checkShortcuts(w);

    try w.print("consumer OK\n", .{});
    try out.flush();
}

fn checkNormalization(w: *std.Io.Writer) !void {
    var codepoints: [64]i32 = undefined;

    const decomposed = try utf8proc.decompose("e\u{0301}", codepoints[0..], .{
        .stable = true,
        .decompose = true,
    });
    const count = switch (decomposed) {
        .written => |n| n,
        .needs_more => return error.ConsumerWorkspaceTooSmall,
    };
    if (count != 2 or codepoints[0] != 0x0065 or codepoints[1] != 0x0301) {
        return error.ConsumerDecompositionMismatch;
    }

    // The count-only call returns the required output size without a destination.
    const needed = try utf8proc.decomposeCount("\u{FB01}", .{ .stable = true, .compose = true, .compat = true });
    if (needed != 2) return error.ConsumerDecompositionMismatch;

    const composed = try utf8proc.normalizeUtf32(codepoints[0..count], .{ .compose = true });
    if (composed != 1 or codepoints[0] != 0x00E9) return error.ConsumerCompositionMismatch;

    var workspace: [4 * 4 + 1]u8 align(4) = undefined;
    @memcpy(workspace[0 .. composed * 4], std.mem.sliceAsBytes(codepoints[0..composed]));
    const written = try utf8proc.reencode(workspace[0..], composed, .{});
    if (!std.mem.eql(u8, "\u{00E9}", workspace[0..written])) return error.ConsumerReencodeMismatch;
    if (workspace[written] != 0) return error.ConsumerReencodeMismatch;

    try w.print("  NFC  e+U+0301 -> {s}; U+FB01 needs {d} codepoints\n", .{ workspace[0..written], needed });
}

fn checkCase(w: *std.Io.Writer) !void {
    if (utf8proc.toUpper('a') != 'A') return error.ConsumerCaseMismatch;
    if (utf8proc.toLower('A') != 'a') return error.ConsumerCaseMismatch;
    if (utf8proc.toTitle(0x01C4) != 0x01C5) return error.ConsumerCaseMismatch;
    if (!utf8proc.isLower('a') or !utf8proc.isUpper('A')) return error.ConsumerCaseMismatch;
    if (utf8proc.isUpper(0x01C5)) return error.ConsumerCaseMismatch;

    const folded = try utf8proc.map("\u{1E9E}", .{
        .stable = true,
        .compose = true,
        .compat = true,
        .casefold = true,
        .ignore = true,
    });
    defer folded.deinit(); // utf8proc_free; not allocator.free
    if (!std.mem.eql(u8, "ss", folded.bytes())) return error.ConsumerCaseMismatch;

    try w.print("  case U+1E9E folds to {s}\n", .{folded.bytes()});
}

fn checkGraphemes(w: *std.Io.Writer) !void {
    const combining = [_]i32{ 'a', 0x0301, 'b' };
    if (utf8proc.firstGraphemeBreak(combining[0..]) != 2) return error.ConsumerGraphemeMismatch;

    const flags = [_]i32{ 0x1F1E6, 0x1F1E8, 0x1F1EA, 0x1F1EC };
    if (utf8proc.firstGraphemeBreak(flags[0..]) != 2) return error.ConsumerGraphemeMismatch;
    if (utf8proc.graphemeBreak(flags[0], flags[1])) return error.ConsumerGraphemeMismatch;

    const marked = try utf8proc.map("\u{1F1E6}\u{1F1E8}\u{1F1EA}\u{1F1EC}", .{ .charbound = true });
    defer marked.deinit();
    var markers: usize = 0;
    for (marked.bytes()) |byte| {
        if (byte == 0xFF) markers += 1;
    }
    if (markers != 2) return error.ConsumerGraphemeMismatch;

    try w.print("  graphemes: {d} clusters, {d} 0xFF markers\n", .{ 2, markers });
}

fn checkProperties(w: *std.Io.Writer) !void {
    if (utf8proc.charWidth('a') != 1) return error.ConsumerWidthMismatch;
    if (utf8proc.charWidth(0x0301) != 0) return error.ConsumerWidthMismatch;
    if (utf8proc.charWidth(0x6F22) != 2) return error.ConsumerWidthMismatch;
    if (!utf8proc.charWidthAmbiguous(0x00A1)) return error.ConsumerWidthMismatch;
    if (!std.mem.eql(u8, "Zs", utf8proc.categoryString(0x0020))) return error.ConsumerCategoryMismatch;
    if (utf8proc.utf8Class(0xE2) != 3) return error.ConsumerWidthMismatch;

    try w.print("  properties: U+6F22 width {d}, U+0020 is {s}\n", .{
        utf8proc.charWidth(0x6F22),
        utf8proc.categoryString(0x0020),
    });
}

fn checkReencode(w: *std.Io.Writer) !void {
    const codepoints = [_]i32{ 0x1F1E6, 0x1F1E8 };
    var tight: [4 * 2]u8 align(4) = undefined;
    @memcpy(tight[0..], std.mem.sliceAsBytes(codepoints[0..]));

    if (utf8proc.reencode(tight[0..], codepoints.len, .{})) |_| {
        return error.ConsumerReencodeShouldHaveFailed;
    } else |err| switch (err) {
        error.WorkspaceTooSmall => {},
        else => return err,
    }

    var roomy: [4 * 2 + 1]u8 align(4) = undefined;
    @memcpy(roomy[0 .. 4 * 2], std.mem.sliceAsBytes(codepoints[0..]));
    const written = try utf8proc.reencode(roomy[0..], codepoints.len, .{});

    try w.print("  reencode: {d} bytes, terminator byte {d}, short workspace refused\n", .{ written, roomy[written] });
}

/// Checks convenience wrappers and their error behavior.
fn checkShortcuts(w: *std.Io.Writer) !void {
    // NFC composes `e` plus U+0301; NFKD maps U+FB01 to `fi`.
    const composed = try utf8proc.nfc("e\u{0301}");
    defer composed.deinit(); // utf8proc_free; not allocator.free
    if (!std.mem.eql(u8, "\u{00E9}", composed.bytes())) return error.ConsumerShortcutMismatch;

    const ligature = try utf8proc.nfkd("\u{FB01}");
    defer ligature.deinit();
    if (!std.mem.eql(u8, "fi", ligature.bytes())) return error.ConsumerShortcutMismatch;

    // These shortcuts collapse malformed-input and allocation errors; the status API distinguishes them.
    if (utf8proc.nfc("\xFF")) |_| {
        return error.ConsumerShortcutShouldHaveFailed;
    } else |err| switch (err) {
        error.NoResult => {},
    }
    if (utf8proc.map("\xFF", .{})) |_| {
        return error.ConsumerShortcutShouldHaveFailed;
    } else |err| switch (err) {
        error.InvalidUtf8 => {},
        else => return err,
    }

    try w.print("  shortcuts: NFC e+U+0301 -> {s}, NFKD U+FB01 -> {s}, invalid UTF-8 refused\n", .{
        composed.bytes(),
        ligature.bytes(),
    });
}

/// Selects the provider from `--provider <path>` or `UTF8PROC_TEST_PROVIDER`.
/// Returns the selected value or `NoProviderConfigured`; there is no default path.
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

/// Prints explicit provider instructions and returns `NoProviderConfigured`.
fn noProvider() ConfigurationError {
    std.debug.print(
        "consumer: this is a runtime-loading build. Pass --provider <path>, or " ++
            "export " ++ provider_variable ++ " with a shared object exporting " ++
            "the entry points of utf8proc.h. Nothing is loaded by default and no " ++
            "other file is tried.\n",
        .{},
    );
    return error.NoProviderConfigured;
}
