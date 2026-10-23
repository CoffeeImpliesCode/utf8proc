// SPDX-License-Identifier: MIT
//
//! Executable probe that instantiates every public facade declaration.
//! Runtime mode requires a provider from `--provider <path>` or `UTF8PROC_TEST_PROVIDER`.

const std = @import("std");
const utf8proc = @import("utf8proc");

/// Runtime provider environment variable.
const provider_variable = "UTF8PROC_TEST_PROVIDER";

/// No provider configured for a runtime build.
const ConfigurationError = error{NoProviderConfigured};

fn expect(condition: bool) error{UnexpectedResult}!void {
    if (!condition) return error.UnexpectedResult;
}

fn replaceX(codepoint: i32, data: ?*anyopaque) callconv(.c) i32 {
    const replacement: *const i32 = @ptrCast(@alignCast(data.?));
    return if (codepoint == 'X') replacement.* else codepoint;
}

pub fn main(init: std.process.Init) !void {
    if (comptime utf8proc.runtime_loaded) {
        try utf8proc.load(.{ .path = try providerRequest(init) });
    }

    std.debug.print("utf8proc {s}, Unicode {s}: {s}\n", .{
        utf8proc.version(),                                           utf8proc.unicodeVersion(),
        utf8proc.errorMessage(utf8proc.c.UTF8PROC_ERROR_INVALIDUTF8),
    });
    std.debug.print("utf8proc: {s} build, provider {s}\n", .{
        if (utf8proc.runtime_loaded) "runtime-loaded" else "linked",
        if (utf8proc.loadedSource()) |source| switch (source) {
            .path => |p| p,
            .system => |s| s,
        } else "linked in",
    });

    try expect(utf8proc.codepointValid('A') and !utf8proc.codepointValid(0xD800));
    const decoded = (try utf8proc.decode("\u{00E9}!")).?;
    try expect(decoded.bytes_read == 2 and decoded.codepoint == 0x00E9);
    var encoded: [4]u8 = undefined;
    try expect(utf8proc.encodeChar(0x00E9, &encoded).bytes == 2);
    try expect(std.mem.eql(u8, encoded[0..2], "\u{00E9}"));
    _ = utf8proc.property('A');
    // Lead-byte class gives the expected length, not UTF-8 validity.
    const lead_bytes = utf8proc.utf8ClassTable();
    try expect(lead_bytes[0xF0] == 4 and lead_bytes[0x80] == 0);
    try expect(utf8proc.charWidth('A') == 1 and utf8proc.charWidth(0x0301) == 0);
    try expect(utf8proc.charWidthAmbiguous(0x00A1));
    try expect(utf8proc.toLower('A') == 'a' and utf8proc.toUpper('a') == 'A');
    try expect(utf8proc.toTitle(0x01C4) == 0x01C5);
    try expect(utf8proc.isLower('a') and utf8proc.isUpper('A'));
    try expect(utf8proc.utf8Class(0xC3) == 2);

    var codepoints: [64]i32 = undefined;
    const options = utf8proc.Options.fromBits(utf8proc.c.UTF8PROC_DECOMPOSE);
    try expect(try utf8proc.decomposeCount("\u{00E9}", options) == 2);
    const decomposed = try utf8proc.decompose("\u{00E9}", &codepoints, options);
    try expect(decomposed.written == 2 and codepoints[0] == 'e' and codepoints[1] == 0x0301);
    const per_char = try utf8proc.decomposeChar(0x00E9, &codepoints, options, null);
    try expect(per_char.written == 2);
    var replacement: i32 = 0x00E9;
    const custom = try utf8proc.decomposeCustom("X", &codepoints, options, &replaceX, &replacement);
    try expect(custom.written == 2 and codepoints[0] == 'e' and codepoints[1] == 0x0301);
    const normalized = try utf8proc.normalizeUtf32(codepoints[0..2], .{ .compose = true });
    try expect(normalized == 1 and codepoints[0] == 0x00E9);
    var workspace: [5]u8 align(4) = undefined;
    @memcpy(workspace[0..4], std.mem.sliceAsBytes(codepoints[0..1]));
    const bytes = try utf8proc.reencode(&workspace, 1, .{});
    try expect(std.mem.eql(u8, workspace[0..bytes], "\u{00E9}") and workspace[bytes] == 0);

    var iterator = utf8proc.GraphemeIterator{};
    try expect(!iterator.next('a', 0x0301));
    try expect(iterator.next(0x0301, 'b'));
    iterator.reset();
    try expect(!iterator.next('a', 0x0301));
    try expect(utf8proc.graphemeBreak(0x03B1, 0x03B2));
    try expect(utf8proc.firstGraphemeBreak(&.{ 'a', 0x0301, 'b' }) == 2);

    const owned = try utf8proc.map("Stra\u{00DF}e", .{ .casefold = true });
    defer owned.deinit();
    try expect(std.mem.eql(u8, owned.bytes(), "strasse"));
    const mapped = try utf8proc.mapCustom("X", .{}, &replaceX, &replacement);
    defer mapped.deinit();
    try expect(std.mem.eql(u8, mapped.bytes(), "\u{00E9}"));

    try exerciseShortcuts();

    std.debug.print("utf8proc: all typed operations exercised\n", .{});
}

/// Exercises all five NUL-terminated normalization shortcuts.
fn exerciseShortcuts() !void {
    const composed = try utf8proc.nfc("e\u{0301}");
    defer composed.deinit();
    try expect(std.mem.eql(u8, composed.bytes(), "\u{00E9}"));

    const already = try utf8proc.nfd("e\u{0301}");
    defer already.deinit();
    try expect(std.mem.eql(u8, already.bytes(), "e\u{0301}"));

    // U+FB01 has only a compatibility decomposition, so NFKD splits it while NFD does not.
    const compat = try utf8proc.nfkd("\u{FB01}");
    defer compat.deinit();
    try expect(std.mem.eql(u8, compat.bytes(), "fi"));
    const canonical = try utf8proc.nfd("\u{FB01}");
    defer canonical.deinit();
    try expect(std.mem.eql(u8, canonical.bytes(), "\u{FB01}"));

    // U+212B compatibility singleton normalizes to U+00C5.
    const singleton = try utf8proc.nfkc("\u{212B}");
    defer singleton.deinit();
    try expect(std.mem.eql(u8, singleton.bytes(), "\u{00C5}"));

    // U+1E9E case-folds to "ss"; simple lowercase does not.
    const sharp = try utf8proc.nfkcCasefold("\u{1E9E}");
    defer sharp.deinit();
    try expect(std.mem.eql(u8, sharp.bytes(), "ss"));

    // Empty input is valid and remains empty.
    const empty = try utf8proc.nfc("");
    defer empty.deinit();
    try expect(empty.bytes().len == 0);
}

/// Takes an explicit provider path from `--provider` or `UTF8PROC_TEST_PROVIDER`; never guesses.
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
        "api_exercise: this is a runtime-loading build. Pass --provider <path>, " ++
            "or export " ++ provider_variable ++ " with a shared object exporting " ++
            "the entry points of utf8proc.h. Nothing is loaded by default and no " ++
            "other file is tried.\n",
        .{},
    );
    return error.NoProviderConfigured;
}
