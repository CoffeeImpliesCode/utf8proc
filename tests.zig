//! Tests the utf8proc Zig facade.
//! Replays the 20,171 normalization and 853 grapheme rows in embedded Unicode 18.0.0 data.
//! Covers full-space, regression, ownership and error contracts; stale system `wcwidth` is not an oracle.
//! Runtime tests require `UTF8PROC_TEST_PROVIDER`; linked builds need no provider.

const std = @import("std");
const testing = std.testing;
const utf8proc = @import("utf8proc");

/// Explicit provider path for runtime tests.
const provider_variable = "UTF8PROC_TEST_PROVIDER";

/// No-op for linked builds; runtime tests load the explicit provider once.
/// Missing or failed loads stop the suite rather than allowing untested success.
fn nativeReady() void {
    if (comptime !utf8proc.runtime_loaded) return;
    if (utf8proc.loadedSource() != null) return;

    var buffer: [4096]u8 = undefined;
    const value = std.testing.environ.getAlloc(testing.allocator, provider_variable) catch
        missingProvider();
    defer testing.allocator.free(value);
    if (value.len == 0 or value.len > buffer.len) missingProvider();
    @memcpy(buffer[0..value.len], value);
    utf8proc.load(.{ .path = buffer[0..value.len] }) catch |err| {
        std.debug.print(
            "tests.zig: loading " ++ provider_variable ++ " = \"{s}\" failed: {t}\n",
            .{ buffer[0..value.len], err },
        );
        @panic("tests.zig: the provider named by " ++ provider_variable ++
            " did not load; nothing below this line ran");
    };
}

fn missingProvider() noreturn {
    @panic(
        "tests.zig: this is a runtime-loading build and " ++ provider_variable ++
            " is not set. Point it at a shared object exporting the entry points " ++
            "of utf8proc.h, for example the one `zig build -Dlinkage=dynamic` " ++
            "installs, and export it for the whole `zig build` invocation: the " ++
            "build cannot inject a path into a run step's environment.",
    );
}

fn readFixture(comptime name: []const u8) []const u8 {
    return @embedFile("testdata/" ++ name);
}

/// Reads fixture lines and strips a trailing CR.
const Lines = struct {
    data: []const u8,
    cursor: usize = 0,
    line_number: usize = 0,

    fn init(data: []const u8) Lines {
        return .{ .data = data };
    }

    fn next(self: *Lines) ?[]const u8 {
        if (self.cursor >= self.data.len) return null;
        const start = self.cursor;
        const end = std.mem.findScalarPos(u8, self.data, start, '\n') orelse self.data.len;
        self.cursor = @min(end + 1, self.data.len);
        self.line_number += 1;
        const line = self.data[start..end];
        if (line.len > 0 and line[line.len - 1] == '\r') return line[0 .. line.len - 1];
        return line;
    }
};

/// Parses whitespace-separated hexadecimal codepoints into `out`.
fn parseCodepoints(text: []const u8, out: []i32) !usize {
    var count: usize = 0;
    var tokens = std.mem.tokenizeAny(u8, text, " \t");
    while (tokens.next()) |token| {
        if (count == out.len) return error.CorpusRowTooLong;
        out[count] = try std.fmt.parseInt(i32, token, 16);
        count += 1;
    }
    return count;
}

/// Parses `XXXX` or `XXXX..YYYY`, ignoring surrounding whitespace.
const Span = struct { start: i32, end: i32 };

fn parseSpan(text: []const u8) !Span {
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    if (std.mem.find(u8, trimmed, "..")) |dots| {
        return .{
            .start = try std.fmt.parseInt(i32, trimmed[0..dots], 16),
            .end = try std.fmt.parseInt(i32, trimmed[dots + 2 ..], 16),
        };
    }
    const single = try std.fmt.parseInt(i32, trimmed, 16);
    return .{ .start = single, .end = single };
}

/// Parses `start..end ; Property` rows for the named section.
/// Accepts source-section headers and extracted lowercase/uppercase files.
fn parseSpans(gpa: std.mem.Allocator, data: []const u8, property_name: []const u8, derived_file: bool) ![]Span {
    var list: std.ArrayList(Span) = .empty;
    errdefer list.deinit(gpa);

    var in_section = !derived_file;
    var lines = Lines.init(data);
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        if (line[0] == '#') {
            if (derived_file and std.mem.startsWith(u8, line, "# Derived Property:")) {
                const name = std.mem.trim(u8, line["# Derived Property:".len..], " \t");
                in_section = std.mem.eql(u8, name, property_name);
            }
            continue;
        }
        if (!in_section) continue;
        const semicolon = std.mem.findScalar(u8, line, ';') orelse return error.MalformedDerivedProperty;
        try list.append(gpa, try parseSpan(line[0..semicolon]));
    }
    return list.toOwnedSlice(gpa);
}

/// Scratch buffers sized for the full fixtures: 1024 codepoints and 4097 aligned bytes.
/// Too-small buffers fail with `ScratchTooSmall`; they never truncate.
const Scratch = struct {
    cps: [1024]i32 = undefined,
    work: [4097]u8 align(4) = undefined,

    /// Normalizes through caller buffers without allocating.
    fn normalize(str: []const u8, options: utf8proc.Options, scratch: *Scratch) ![]const u8 {
        const count = switch (try utf8proc.decompose(str, scratch.cps[0..], options)) {
            .written => |n| n,
            .needs_more => return error.ScratchTooSmall,
        };
        @memcpy(scratch.work[0 .. count * @sizeOf(i32)], std.mem.sliceAsBytes(scratch.cps[0..count]));
        const written = try utf8proc.reencode(scratch.work[0..], count, options);
        return scratch.work[0..written];
    }
};

/// Encodes codepoints as UTF-8 with upstream's encoder.
fn encodeAll(out: []u8, codepoints: []const i32) ![]const u8 {
    var written: usize = 0;
    for (codepoints) |codepoint| {
        var buffer: [4]u8 = undefined;
        switch (utf8proc.encodeChar(codepoint, &buffer)) {
            .rejected => return error.CorpusCodepointNotEncodable,
            .bytes => |n| {
                if (written + n > out.len) return error.ScratchTooSmall;
                @memcpy(out[written..][0..n], buffer[0..n]);
                written += n;
            },
        }
    }
    return out[0..written];
}

/// Decodes UTF-8 text into codepoints.
fn decodeAll(text: []const u8, out: []i32) !usize {
    var count: usize = 0;
    var rest = text;
    while (rest.len > 0) {
        const decoded = (try utf8proc.decode(rest)) orelse break;
        if (count == out.len) return error.CorpusRowTooLong;
        out[count] = @intCast(decoded.codepoint);
        count += 1;
        rest = rest[decoded.bytes_read..];
    }
    return count;
}

/// Four normalization option sets matching upstream's shortcut flags.
const nfc = utf8proc.Options{ .stable = true, .compose = true };
const nfd = utf8proc.Options{ .stable = true, .decompose = true };
const nfkc = utf8proc.Options{ .stable = true, .compose = true, .compat = true };
const nfkd = utf8proc.Options{ .stable = true, .decompose = true, .compat = true };

test "UTF8PROC_NULLTERM is refused on every slice entry point" {
    nativeReady();
    const nullterm = utf8proc.Options{ .nullterm = true };
    var scratch = Scratch{};
    var destination: [8]i32 = undefined;

    try testing.expectError(error.InvalidOptions, utf8proc.decomposeCount("a", nullterm));
    try testing.expectError(error.InvalidOptions, utf8proc.decompose("a", destination[0..], nullterm));
    try testing.expectError(error.InvalidOptions, utf8proc.decomposeCustom("a", destination[0..], nullterm, null, null));
    try testing.expectError(error.InvalidOptions, utf8proc.decomposeChar('a', destination[0..], nullterm, null));
    try testing.expectError(error.InvalidOptions, utf8proc.normalizeUtf32(destination[0..], nullterm));
    try testing.expectError(error.InvalidOptions, utf8proc.reencode(scratch.work[0..], 1, nullterm));
    try testing.expectError(error.InvalidOptions, utf8proc.map("a", nullterm));
    try testing.expectError(error.InvalidOptions, utf8proc.mapCustom("a", nullterm, null, null));
}

test "error mapping is checked against upstream's own return values" {
    nativeReady();
    // Upstream rejects surrogate UTF-8 even though `encodeChar` can produce it.
    var codepoint: i32 = 0;
    const status = utf8proc.c.utf8proc_iterate("\xED\xA0\x80", 3, &codepoint);
    try testing.expectEqual(@as(utf8proc.Status, utf8proc.c.UTF8PROC_ERROR_INVALIDUTF8), status);
    try testing.expectEqual(@as(i32, -1), codepoint);
    try testing.expectError(error.InvalidUtf8, utf8proc.decode("\xED\xA0\x80"));

    // CHARBOUND's `0xFF` marker is not valid UTF-8.
    try testing.expectError(error.InvalidUtf8, utf8proc.decode("\xFF"));

    // `compose | decompose` is invalid upstream.
    var scratch = Scratch{};
    try testing.expectError(
        error.InvalidOptions,
        Scratch.normalize("a", .{ .compose = true, .decompose = true }, &scratch),
    );
    // `stripmark` requires `compose` or `decompose`.
    try testing.expectError(
        error.InvalidOptions,
        Scratch.normalize("a", .{ .stripmark = true }, &scratch),
    );

    // `rejectna` rejects unassigned codepoints; out-of-range values always fail.
    var destination: [8]i32 = undefined;
    try testing.expectError(
        error.NotAssigned,
        utf8proc.decomposeChar(0x0378, destination[0..], .{ .rejectna = true }, null),
    );
    try testing.expectError(
        error.NotAssigned,
        utf8proc.decomposeChar(0x110000, destination[0..], .{ .decompose = true }, null),
    );
}

test "reencode refuses a workspace that is one byte short" {
    nativeReady();
    // `reencode` requires `4 * length + 1`; upstream does not check capacity.
    const codepoints = [_]i32{ 'e', 0x0301, 'x', 'y' };
    var tight: [4 * 4]u8 align(4) = undefined;
    @memcpy(tight[0..], std.mem.sliceAsBytes(codepoints[0..]));
    const before = tight;

    try testing.expectError(
        error.WorkspaceTooSmall,
        utf8proc.reencode(tight[0..], codepoints.len, .{ .compose = true }),
    );
    try testing.expectEqualSlices(u8, &before, &tight);

    // The extra byte holds the trailing NUL.
    var roomy: [4 * 4 + 1]u8 align(4) = undefined;
    @memcpy(roomy[0 .. 4 * 4], std.mem.sliceAsBytes(codepoints[0..]));
    const written = try utf8proc.reencode(roomy[0..], codepoints.len, .{ .compose = true });
    try testing.expectEqual(@as(usize, 4), written);
    try testing.expectEqualStrings("\u{00E9}xy", roomy[0..written]);
    try testing.expectEqual(@as(u8, 0), roomy[written]);

    // Even empty output needs one byte for NUL.
    var single: [1]u8 align(4) = undefined;
    try testing.expectEqual(@as(usize, 0), try utf8proc.reencode(single[0..], 0, .{}));
    try testing.expectEqual(@as(u8, 0), single[0]);
    try testing.expectError(error.WorkspaceTooSmall, utf8proc.reencode(single[0..], 1, .{}));

    // The workspace-size calculation must detect overflow.
    var tiny: [4]u8 align(4) = undefined;
    try testing.expectError(
        error.WorkspaceTooSmall,
        utf8proc.reencode(tiny[0..], std.math.maxInt(usize), .{}),
    );
}

test "decompose reports the required size instead of a truncated result" {
    nativeReady();
    var scratch = Scratch{};

    // Hangul syllables may decompose to three jamo; a two-slot buffer reports that size.
    const result = try utf8proc.decompose("\u{AC01}", scratch.cps[0..2], .{ .decompose = true });
    try testing.expectEqual(@as(usize, 3), result.needs_more);
    try testing.expectEqual(@as(usize, 3), try utf8proc.decomposeCount("\u{AC01}", .{ .decompose = true }));

    const written = try utf8proc.decompose("\u{AC01}", scratch.cps[0..], .{ .decompose = true });
    try testing.expectEqual(@as(usize, 3), written.written);
    try testing.expectEqual(@as(i32, 0x1100), scratch.cps[0]);
    try testing.expectEqual(@as(i32, 0x1161), scratch.cps[1]);
    try testing.expectEqual(@as(i32, 0x11A8), scratch.cps[2]);

    // Empty `dst` requests capacity without writing.
    const empty = try utf8proc.decompose("\u{AC01}", scratch.cps[0..0], .{ .decompose = true });
    try testing.expectEqual(@as(usize, 3), empty.needs_more);

    try testing.expectError(error.InvalidUtf8, utf8proc.decomposeCount("\xFF", .{ .decompose = true }));
    try testing.expectError(error.InvalidUtf8, utf8proc.decompose("\x80", scratch.cps[0..], .{ .decompose = true }));
}

test "decode and encode agree on every valid codepoint" {
    nativeReady();
    var buffer: [4]u8 = undefined;
    var checked: usize = 0;
    var codepoint: i32 = 0;
    while (codepoint < 0x110000) : (codepoint += 1) {
        if (!utf8proc.codepointValid(codepoint)) continue;
        const length = switch (utf8proc.encodeChar(codepoint, &buffer)) {
            .rejected => {
                std.debug.panic("valid codepoint {X} was rejected by encodeChar", .{codepoint});
            },
            .bytes => |n| n,
        };
        const decoded = (try utf8proc.decode(buffer[0..length])).?;
        try testing.expectEqual(length, decoded.bytes_read);
        try testing.expectEqual(@as(u21, @intCast(codepoint)), decoded.codepoint);
        checked += 1;
    }
    // All Unicode scalar values, excluding the 2048 surrogates.
    try testing.expectEqual(@as(usize, 0x110000 - 0x800), checked);
}
test "surrogates encode to bytes decode rejects" {
    nativeReady();
    // Upstream encodes surrogate values, but UTF-8 decoding rejects them.
    var buffer: [4]u8 = undefined;
    var codepoint: i32 = 0xD800;
    while (codepoint < 0xE000) : (codepoint += 1) {
        const length = switch (utf8proc.encodeChar(codepoint, &buffer)) {
            .rejected => {
                std.debug.panic("surrogate {X} was rejected by encodeChar", .{codepoint});
            },
            .bytes => |n| n,
        };
        try testing.expectEqual(@as(u3, 3), length);
        try testing.expect(!utf8proc.codepointValid(codepoint));
        try testing.expectError(error.InvalidUtf8, utf8proc.decode(buffer[0..length]));
    }

    // Values outside `[0, 0x110000)` are rejected without writing.
    switch (utf8proc.encodeChar(-1, &buffer)) {
        .rejected => {},
        .bytes => return error.CodepointShouldHaveBeenRejected,
    }
    switch (utf8proc.encodeChar(0x110000, &buffer)) {
        .rejected => {},
        .bytes => return error.CodepointShouldHaveBeenRejected,
    }
}

test "decomposeChar never returns more than four codepoints" {
    nativeReady();
    // Upstream's max-decomposition invariant keeps the four-codepoint limit valid.
    var destination: [16]i32 = undefined;
    var largest: usize = 0;
    var codepoint: i32 = 0;
    while (codepoint < 0x110000) : (codepoint += 1) {
        const count = switch (try utf8proc.decomposeChar(codepoint, destination[0..], .{ .decompose = true }, null)) {
            .written => |n| n,
            .needs_more => |n| n,
        };
        largest = @max(largest, count);
        // A zero-capacity probe must report the same required size, not a clamped count.
        const probing = try utf8proc.decomposeChar(codepoint, destination[0..0], .{ .decompose = true }, null);
        try testing.expectEqual(count, switch (probing) {
            .written => |n| n,
            .needs_more => |n| n,
        });
    }
    try testing.expectEqual(@as(usize, 4), largest);
}

test "character width invariants hold over the whole codepoint space" {
    nativeReady();
    // Check Unicode width invariants; system `wcwidth` may use stale tables.
    const lu = utf8proc.c.UTF8PROC_CATEGORY_LU;
    const lo = utf8proc.c.UTF8PROC_CATEGORY_LO;
    const mn = utf8proc.c.UTF8PROC_CATEGORY_MN;
    const me = utf8proc.c.UTF8PROC_CATEGORY_ME;
    const nd = utf8proc.c.UTF8PROC_CATEGORY_ND;
    const sc = utf8proc.c.UTF8PROC_CATEGORY_SC;
    const so = utf8proc.c.UTF8PROC_CATEGORY_SO;
    const zs = utf8proc.c.UTF8PROC_CATEGORY_ZS;
    const cn = utf8proc.c.UTF8PROC_CATEGORY_CN;
    const co = utf8proc.c.UTF8PROC_CATEGORY_CO;

    var codepoint: i32 = 0;
    while (codepoint <= 0x110000) : (codepoint += 1) {
        const cat = utf8proc.category(codepoint);
        const width = utf8proc.charWidth(codepoint);

        // Combining marks have zero width.
        if (cat == mn or cat == me) try testing.expectEqual(@as(i32, 0), width);

        // Letters, numbers and symbols are never zero-width.
        if (width == 0) {
            try testing.expect(!((cat >= lu and cat <= lo) or
                (cat >= nd and cat <= sc) or
                (cat >= so and cat <= zs)));
        }

        // Unassigned and private-use codepoints have width one.
        if (cat == cn or cat == co) try testing.expectEqual(@as(i32, 1), width);

        // Ambiguous-width characters are not double-width.
        if (utf8proc.charWidthAmbiguous(codepoint)) try testing.expect(width < 2);

        // Non-printing categories are derived from the general-category fields.
        const printish = (cat >= lu and cat <= zs) or
            codepoint == 0x0601 or codepoint == 0x0602 or codepoint == 0x0603 or
            codepoint == 0x06DD or codepoint == 0x00AD or cat == cn or cat == co;
        if (!printish) try testing.expectEqual(@as(i32, 0), width);
    }

    // Four codepoints are pinned by upstream's width test.
    try testing.expectEqual(@as(i32, 1), utf8proc.charWidth(0x00AD));
    try testing.expect(utf8proc.charWidthAmbiguous(0x00AD));
    try testing.expectEqual(@as(i32, 1), utf8proc.charWidth(0xE000));
    try testing.expect(utf8proc.charWidthAmbiguous(0xE000));
    try testing.expect(utf8proc.charWidthAmbiguous(0x00A1));
    try testing.expect(!utf8proc.charWidthAmbiguous(0x00A2));

    // ASCII is never ambiguous-width.
    var ascii: i32 = 0;
    while (ascii < 128) : (ascii += 1) {
        try testing.expect(!utf8proc.charWidthAmbiguous(ascii));
    }
}

test "regression: canonical ordering, casefold and STRIPNA (issues 128 and 102)" {
    nativeReady();
    var scratch = Scratch{};

    // Issue 128: canonical ordering moves U+0323 before U+0307; NFC composes them.
    try testing.expectEqualStrings(
        "\u{1E5B}\u{0307}",
        try Scratch.normalize("r\u{0307}\u{0323}", nfc, &scratch),
    );
    try testing.expectEqualStrings(
        "r\u{0323}\u{0307}",
        try Scratch.normalize("r\u{0307}\u{0323}", nfd, &scratch),
    );

    // Issue 102: `ignore` drops soft hyphen; `stripna` removes U+2065, which otherwise survives.
    const input = "X\u{2065}E\u{0300}\u{00AD}\u{1D2C}";
    const casefold = utf8proc.Options{
        .stable = true,
        .compose = true,
        .compat = true,
        .casefold = true,
        .ignore = true,
    };
    try testing.expectEqualStrings(
        "x\u{00E8}a",
        try Scratch.normalize(input, .{ .stable = true, .compose = true, .compat = true, .casefold = true, .ignore = true, .stripna = true }, &scratch),
    );
    try testing.expectEqualStrings("x\u{2065}\u{00E8}a", try Scratch.normalize(input, casefold, &scratch));
}

test "regression: Hangul jamo composition (issue 317)" {
    nativeReady();
    var scratch = Scratch{};

    // The trailing-jamo base itself must not compose.
    try testing.expectEqualStrings("\u{C8E0}\u{11A7}", try Scratch.normalize("\u{C8E0}\u{11A7}", nfc, &scratch));
    // One past the last trailing jamo must not compose.
    try testing.expectEqualStrings("\u{C8E0}\u{11C3}", try Scratch.normalize("\u{C8E0}\u{11C3}", nfc, &scratch));

    // Every valid trailing jamo composes, as in upstream's regression test.
    var trailing: i32 = 0x11A8;
    while (trailing < 0x11C3) : (trailing += 1) {
        var input: [8]u8 = undefined;
        var combined: [4]u8 = undefined;
        const input_len = (try encodeAll(input[0..], &.{ 0xC8E0, trailing })).len;
        const combined_len = switch (utf8proc.encodeChar(0xC8E0 + (trailing - 0x11A7), &combined)) {
            .rejected => return error.CodepointShouldHaveBeenEncoded,
            .bytes => |n| n,
        };
        try testing.expectEqualStrings(
            combined[0..combined_len],
            try Scratch.normalize(input[0..input_len], nfc, &scratch),
        );
    }

    // LV and LVT Hangul syllables decompose algorithmically.
    try testing.expectEqualStrings(
        "\u{1100}\u{1161}",
        try Scratch.normalize("\u{AC00}", nfd, &scratch),
    );
    try testing.expectEqualStrings(
        "\u{AC01}",
        try Scratch.normalize("\u{1100}\u{1161}\u{11A8}", nfc, &scratch),
    );
}

test "regression: uninterpretable codepoints survive normalizeUtf32 (issue 288)" {
    nativeReady();
    var compose = [_]i32{ 0x0041, 0x0301 };
    try testing.expectEqual(@as(usize, 1), try utf8proc.normalizeUtf32(compose[0..], .{ .compose = true }));
    try testing.expectEqual(@as(i32, 0x00C1), compose[0]);

    // Out-of-range values pass through and block composition; property lookup would be out of bounds.
    var out_of_range = [_]i32{ 0x0041, 0x110000, 0x0301 };
    try testing.expectEqual(@as(usize, 3), try utf8proc.normalizeUtf32(out_of_range[0..], .{ .compose = true }));
    try testing.expectEqualSlices(i32, &.{ 0x0041, 0x110000, 0x0301 }, out_of_range[0..]);

    // The decomposition grapheme-break sentinel behaves the same way.
    var sentinel = [_]i32{ 0x0041, -1, 0x0301 };
    try testing.expectEqual(@as(usize, 3), try utf8proc.normalizeUtf32(sentinel[0..], .{ .compose = true }));
    try testing.expectEqualSlices(i32, &.{ 0x0041, -1, 0x0301 }, sentinel[0..]);

    // Re-encoding drops the invalid value but preserves the blocked composition.
    var workspace: [4 * 3 + 1]u8 align(4) = undefined;
    @memcpy(workspace[0 .. 4 * 3], std.mem.sliceAsBytes(out_of_range[0..]));
    const written = try utf8proc.reencode(workspace[0..], 3, .{ .compose = true });
    try testing.expectEqualStrings("A\u{0301}", workspace[0..written]);
}

test "regression: CHARBOUND keeps its markers next to COMPOSE and DECOMPOSE (issue 356)" {
    nativeReady();
    var scratch = Scratch{};
    const compose = utf8proc.Options{ .charbound = true, .compose = true };
    const decompose = utf8proc.Options{ .charbound = true, .decompose = true };

    // NFC composes `e` + acute; NFD leaves the sequence unchanged.
    const composed = try Scratch.normalize("e\u{0301}xy", compose, &scratch);
    try testing.expectEqual(@as(usize, 7), composed.len);
    try testing.expectEqualStrings("\xFF\u{00E9}\xFFx\xFFy", composed);

    const decomposed = try Scratch.normalize("e\u{0301}xy", decompose, &scratch);
    try testing.expectEqual(@as(usize, 8), decomposed.len);
    try testing.expectEqualStrings("\xFFe\u{0301}\xFFx\xFFy", decomposed);

    // Issue 144: U+FFFF and U+FFFE are each their own cluster.
    try testing.expectEqualStrings(
        "\xFF\u{FFFF}\xFF\u{FFFE}",
        try Scratch.normalize("\u{FFFF}\u{FFFE}", .{ .charbound = true }, &scratch),
    );
}

test "regression: emoji ZWJ, regional indicators and GB9c" {
    nativeReady();
    const ClusterCase = struct {
        text: []const u8,
        /// Break occurs before index `i`.
        ends: []const usize,
    };

    const cases = [_]ClusterCase{
        // GB12/GB13 pair regional indicators in twos (issue julia#37680).
        .{ .text = "\u{1F1F8}\u{1F1EA}\u{1F1F8}\u{1F1EA}", .ends = &.{ 2, 4 } },
        // GB11: Extended_Pictographic Extend* ZWJ x Extended_Pictographic.
        .{ .text = "\u{1F926}\u{1F3FC}\u{200D}\u{2642}\u{FE0F}", .ends = &.{5} },
        .{ .text = "\u{1F468}\u{1F3FB}\u{200D}\u{1F91D}\u{200D}\u{1F468}\u{1F3FD}", .ends = &.{7} },
        // GB9c prevents a break after the linker sequence.
        .{ .text = "\u{0915}\u{0300}\u{094D}\u{0300}\u{0924}", .ends = &.{5} },
        .{ .text = "\u{0915}\u{0300}\u{094D}\u{0300}\u{094D}\u{0924}", .ends = &.{6} },
        .{ .text = "\u{0915}\u{0300}\u{0300}\u{0924}", .ends = &.{ 3, 4 } },
        .{ .text = "\u{0915}\u{0300}\u{094D}\u{0300}\u{0078}", .ends = &.{ 4, 5 } },
        // GB9c does not require a leading consonant.
        .{ .text = "\u{0300}\u{094D}\u{0300}\u{0924}", .ends = &.{4} },
        // GB9 and GB9a keep combining and spacing marks in the cluster.
        .{ .text = "\u{03B1}\u{0302}", .ends = &.{2} },
        // GB3 keeps CRLF together; GB4/GB5 break around controls.
        .{ .text = "\r\n", .ends = &.{2} },
    };

    var codepoints: [64]i32 = undefined;
    for (cases) |case| {
        const count = try decodeAll(case.text, codepoints[0..]);

        var iterator = utf8proc.GraphemeIterator{};
        var next_end: usize = 0;
        var index: usize = 1;
        while (index < count) : (index += 1) {
            const is_break = iterator.next(codepoints[index - 1], codepoints[index]);
            if (next_end < case.ends.len and index == case.ends[next_end]) {
                try testing.expect(is_break);
                next_end += 1;
            } else {
                try testing.expect(!is_break);
            }
        }
        // The final codepoint ends a cluster even without a following pair.
        if (next_end < case.ends.len and case.ends[next_end] == count) next_end += 1;
        try testing.expectEqual(case.ends.len, next_end);
    }

    try testing.expect(utf8proc.graphemeBreak(0x03B1, 0x03B2));
    try testing.expect(!utf8proc.graphemeBreak(0x03B1, 0x0302));

    // The stateless helper lacks the regional-indicator history required by GB12/GB13.
    const flags = [_]i32{ 0x1F1E6, 0x1F1E8, 0x1F1EA, 0x1F1EC };
    try testing.expect(!utf8proc.graphemeBreak(flags[0], flags[1]));
    try testing.expect(!utf8proc.graphemeBreak(flags[2], flags[3]));
}

test "stateful segmentation, its reset, and firstGraphemeBreak" {
    nativeReady();
    const flags = [_]i32{ 0x1F1E6, 0x1F1E8, 0x1F1EA, 0x1F1EC };
    var iterator = utf8proc.GraphemeIterator{};
    try testing.expect(!iterator.next(flags[0], flags[1]));
    try testing.expect(iterator.next(flags[1], flags[2]));
    try testing.expect(!iterator.next(flags[2], flags[3]));

    try testing.expectEqual(@as(?usize, 2), utf8proc.firstGraphemeBreak(flags[0..]));
    try testing.expectEqual(@as(?usize, null), utf8proc.firstGraphemeBreak(flags[0..2]));
    try testing.expectEqual(@as(?usize, null), utf8proc.firstGraphemeBreak(flags[0..1]));
    try testing.expectEqual(@as(?usize, null), utf8proc.firstGraphemeBreak(flags[0..0]));

    // Reset starts a fresh string.
    iterator.reset();
    try testing.expect(!iterator.next(flags[0], flags[1]));

    // CRLF stays together; the next CR starts a new cluster.
    const crlf = [_]i32{ '\r', '\n', '\r', '\n' };
    var walk = utf8proc.GraphemeIterator{};
    try testing.expect(!walk.next(crlf[0], crlf[1]));
    try testing.expect(walk.next(crlf[1], crlf[2]));
    try testing.expect(!walk.next(crlf[2], crlf[3]));
}

test "case mappings and categories agree with the extracted ranges" {
    nativeReady();
    const lowercase = readFixture("Lowercase.txt");
    const uppercase = readFixture("Uppercase.txt");

    try expectCaseFile(lowercase, "Lowercase", utf8proc.isLower, utf8proc.toLower);
    try expectCaseFile(uppercase, "Uppercase", utf8proc.isUpper, utf8proc.toUpper);

    // Titlecase letters map uppercase but are neither `isUpper` nor `isLower`.
    try testing.expectEqual(@as(i32, 0x01C5), utf8proc.toTitle(0x01C4));
    try testing.expect(!utf8proc.isUpper(0x01C5));
    try testing.expect(!utf8proc.isLower(0x01C5));
    try testing.expectEqualStrings("Lt", utf8proc.categoryString(0x01C5));
    try testing.expectEqualStrings("Lu", utf8proc.categoryString('A'));
    try testing.expectEqualStrings("Ll", utf8proc.categoryString('a'));
    try testing.expectEqualStrings("Cn", utf8proc.categoryString(0x110000));
    try testing.expectEqualStrings("Co", utf8proc.categoryString(0xE000));

    try testing.expectEqual(@as(i32, 0x0301), utf8proc.toLower(0x0301));
    try testing.expectEqual(@as(i32, 0x0301), utf8proc.toUpper(0x0301));
    try testing.expectEqual(@as(i32, 0x1E9E), utf8proc.toUpper(0x00DF)); // capital sharp s
    try testing.expectEqual(@as(i32, 'i'), utf8proc.toLower(0x0130));
}

/// Checks sorted, disjoint spans and identity mappings inside each span.
/// Codepoints outside the spans must not have the property.
fn expectCaseFile(data: []const u8, name: []const u8, comptime is_case: fn (i32) bool, comptime that_case: fn (i32) i32) !void {
    const gpa = testing.allocator;
    const spans = try parseSpans(gpa, data, name, false);
    defer gpa.free(spans);
    try testing.expect(spans.len > 0);

    var codepoint: i32 = 0;
    var previous_end: i32 = -1;
    for (spans) |span| {
        try testing.expect(span.start > previous_end);
        try testing.expect(span.end >= span.start);
        while (codepoint < span.start) : (codepoint += 1) try testing.expect(!is_case(codepoint));
        while (codepoint <= span.end) : (codepoint += 1) {
            try testing.expect(is_case(codepoint));
            try testing.expectEqual(codepoint, that_case(codepoint));
        }
        previous_end = span.end;
    }
    while (codepoint <= 0x110000) : (codepoint += 1) try testing.expect(!is_case(codepoint));
}

test "NormalizationTest.txt in full: the 20-check normalization matrix" {
    nativeReady();
    const data = readFixture("NormalizationTest.txt");

    // Columns are source, NFC, NFD, NFKC and NFKD.
    var encoded: [5][2048]u8 = undefined;
    var lengths: [5]usize = @splat(0);
    var parsed: [5][256]i32 = undefined;
    var scratch = Scratch{};

    var rows: usize = 0;
    var checks: usize = 0;
    var lines = Lines.init(data);
    while (lines.next()) |raw| {
        if (raw.len == 0 or raw[0] == '#' or raw[0] == '@') continue;
        const body = raw[0 .. std.mem.findScalar(u8, raw, '#') orelse raw.len];

        var fields = std.mem.splitScalar(u8, body, ';');
        for (0..5) |column| {
            const field = fields.next() orelse return error.ShortNormalizationRow;
            const count = try parseCodepoints(field, parsed[column][0..]);
            lengths[column] = (try encodeAll(encoded[column][0..], parsed[column][0..count])).len;
        }
        rows += 1;

        const composed_inputs = [_][]const u8{
            encoded[0][0..lengths[0]], encoded[1][0..lengths[1]], encoded[2][0..lengths[2]],
        };
        const all_inputs = [_][]const u8{
            encoded[0][0..lengths[0]], encoded[1][0..lengths[1]], encoded[2][0..lengths[2]],
            encoded[3][0..lengths[3]], encoded[4][0..lengths[4]],
        };

        // Apply the file's twenty conformance equalities.
        try expectRow("NFC", nfc, &composed_inputs, encoded[1][0..lengths[1]], lines.line_number, &scratch, &checks);
        try expectRow("NFC", nfc, all_inputs[3..], encoded[3][0..lengths[3]], lines.line_number, &scratch, &checks);
        try expectRow("NFD", nfd, &composed_inputs, encoded[2][0..lengths[2]], lines.line_number, &scratch, &checks);
        try expectRow("NFD", nfd, all_inputs[3..], encoded[4][0..lengths[4]], lines.line_number, &scratch, &checks);
        try expectRow("NFKC", nfkc, &all_inputs, encoded[3][0..lengths[3]], lines.line_number, &scratch, &checks);
        try expectRow("NFKD", nfkd, &all_inputs, encoded[4][0..lengths[4]], lines.line_number, &scratch, &checks);
    }

    // All 20,171 fixture rows have twenty checks: no sampled execution.
    try testing.expectEqual(@as(usize, 20171), rows);
    try testing.expectEqual(@as(usize, 20171 * 20), checks);
}

fn expectRow(
    name: []const u8,
    options: utf8proc.Options,
    inputs: []const []const u8,
    expected: []const u8,
    line: usize,
    scratch: *Scratch,
    checks: *usize,
) !void {
    for (inputs) |input| {
        const actual = try Scratch.normalize(input, options, scratch);
        if (!std.mem.eql(u8, expected, actual)) {
            std.debug.print(
                "NormalizationTest.txt line {d}: {s} mismatch\n  expected: {s}\n  actual:   {s}\n",
                .{ line, name, expected, actual },
            );
            return error.NormalizationMismatch;
        }
        checks.* += 1;
    }
}

test "GraphemeBreakTest.txt in full: stateful walk and CHARBOUND markers" {
    nativeReady();
    const data = readFixture("GraphemeBreakTest.txt");

    var codepoints: [256]i32 = undefined;
    var breaks: [257]bool = undefined;
    var decomposed: [512]i32 = undefined;
    var workspace: [4097]u8 align(4) = undefined;
    var expected: [4097]u8 = undefined;

    var rows: usize = 0;
    var utf8_rows: usize = 0;
    var surrogate_rows: usize = 0;
    var lines = Lines.init(data);
    while (lines.next()) |raw| {
        if (raw.len == 0 or raw[0] == '#') continue;
        @memset(breaks[0..], false);

        var count: usize = 0;
        var has_surrogate = false;
        var tokens = std.mem.tokenizeAny(u8, raw, " \t");
        while (tokens.next()) |token| {
            if (token.len == 0) continue;
            if (token[0] == '#') break;
            if (token.len == 2 and token[0] == 0xC3) switch (token[1]) {
                // U+00F7 DIVISION SIGN: a grapheme break.
                0xB7 => {
                    if (count == breaks.len) return error.CorpusRowTooLong;
                    breaks[count] = true;
                    continue;
                },
                // U+00D7 MULTIPLICATION SIGN: no break.
                0x97 => continue,
                else => {},
            };
            if (count == codepoints.len) return error.CorpusRowTooLong;
            const value = try std.fmt.parseInt(i32, token, 16);
            if (value >= 0xD800 and value < 0xE000) has_surrogate = true;
            codepoints[count] = value;
            count += 1;
        }
        if (count == 0) continue;
        rows += 1;
        // Every row starts with a boundary marker.
        try testing.expect(breaks[0]);

        // Stateful GB10/12/13 checks require every adjacent pair in order.
        var iterator = utf8proc.GraphemeIterator{};
        var index: usize = 1;
        while (index < count) : (index += 1) {
            try testing.expectEqual(breaks[index], iterator.next(codepoints[index - 1], codepoints[index]));
        }
        try testing.expectEqual(firstBreak(breaks[0..count]), utf8proc.firstGraphemeBreak(codepoints[0..count]));

        // Skip CHARBOUND for surrogate rows, which have no UTF-8 encoding.
        if (has_surrogate) {
            surrogate_rows += 1;
            continue;
        }
        utf8_rows += 1;

        var expected_len: usize = 0;
        index = 0;
        while (index < count) : (index += 1) {
            if (breaks[index]) {
                if (expected_len == expected.len) return error.CorpusRowTooLong;
                expected[expected_len] = 0xFF;
                expected_len += 1;
            }
            var buffer: [4]u8 = undefined;
            const width = switch (utf8proc.encodeChar(codepoints[index], &buffer)) {
                .rejected => return error.CorpusCodepointNotEncodable,
                .bytes => |n| n,
            };
            if (expected_len + width > expected.len) return error.CorpusRowTooLong;
            @memcpy(expected[expected_len..][0..width], buffer[0..width]);
            expected_len += width;
        }

        var input: [1024]u8 = undefined;
        const input_len = (try encodeAll(input[0..], codepoints[0..count])).len;
        const written = switch (try utf8proc.decompose(input[0..input_len], decomposed[0..], .{ .charbound = true })) {
            .written => |n| n,
            .needs_more => return error.ScratchTooSmall,
        };
        @memcpy(workspace[0 .. written * 4], std.mem.sliceAsBytes(decomposed[0..written]));
        const bytes = try utf8proc.reencode(workspace[0..], written, .{ .charbound = true });
        if (!std.mem.eql(u8, expected[0..expected_len], workspace[0..bytes])) {
            std.debug.print("GraphemeBreakTest.txt line {d}: CHARBOUND markers differ\n", .{lines.line_number});
            return error.GraphemeMismatch;
        }
        // CHARBOUND emits `0xFF`, which is invalid UTF-8.
        try testing.expect(std.mem.findScalar(u8, workspace[0..bytes], 0xFF) != null);
        try testing.expectError(error.InvalidUtf8, utf8proc.decode(workspace[0..bytes]));
    }

    try testing.expectEqual(@as(usize, 853), rows);
    // Report CHARBOUND coverage and rows skipped because of surrogate codepoints.
    try testing.expect(utf8_rows > 0);
    std.debug.print("grapheme rows: {d}, checked through CHARBOUND: {d}, surrogate-only: {d}\n", .{ rows, utf8_rows, surrogate_rows });
}

fn firstBreak(breaks: []const bool) ?usize {
    for (breaks[1..], 1..) |is_break, index| {
        if (is_break) return index;
    }
    return null;
}

test "upstream-allocated map agrees with the caller-buffer path and frees with utf8proc_free" {
    nativeReady();
    var scratch = Scratch{};
    // `map` owns memory allocated and freed by upstream.
    const casefold = utf8proc.Options{ .stable = true, .compose = true, .compat = true, .casefold = true, .ignore = true };
    const input = "X\u{2065}E\u{0300}\u{00AD}\u{1D2C}";
    const owned = try utf8proc.map(input, casefold);
    defer owned.deinit();
    try testing.expectEqualStrings("x\u{2065}\u{00E8}a", owned.bytes());
    try testing.expectEqualStrings(
        "x\u{2065}\u{00E8}a",
        try Scratch.normalize(input, casefold, &scratch),
    );

    // Empty input still returns a NUL-terminated zero-length result.
    const empty = try utf8proc.map("", .{});
    defer empty.deinit();
    try testing.expectEqual(@as(usize, 0), empty.len);
    try testing.expectEqual(@as(u8, 0), empty.ptr[0]);

    try testing.expectError(error.InvalidUtf8, utf8proc.map("\xFF", .{}));
}

test "a custom mapping runs on every codepoint, in both caller-buffer and map paths" {
    nativeReady();
    const Doubler = struct {
        fn call(codepoint: i32, data: ?*anyopaque) callconv(.c) i32 {
            _ = data;
            return codepoint * 2;
        }
    };
    const doubling: utf8proc.CustomFunc = &Doubler.call;
    const options = utf8proc.Options{ .decompose = true };

    // Doubling maps `a` to U+00C2 and U+0301 to U+0602 before decomposition.
    var buffer: [16]i32 = undefined;
    const result = try utf8proc.decomposeCustom("a\u{0301}", buffer[0..], options, doubling, null);
    try testing.expectEqual(@as(usize, 3), result.written);
    try testing.expectEqualSlices(i32, &.{ 0x0041, 0x0302, 0x0602 }, buffer[0..3]);

    // `mapCustom` invokes its callback during both sizing and fill passes.
    const mapped = try utf8proc.mapCustom("a\u{0301}", options, doubling, null);
    defer mapped.deinit();
    try testing.expectEqualStrings("A\u{0302}\u{0602}", mapped.bytes());

    // Without a callback, only the literal input is decomposed.
    const plain = try utf8proc.decompose("a\u{0301}", buffer[0..], options);
    try testing.expectEqual(@as(usize, 2), plain.written);
    try testing.expectEqual(@as(i32, 0x0061), buffer[0]);
    try testing.expectEqual(@as(i32, 0x0301), buffer[1]);
}

test "utf8Class agrees with the decoder's own lead-byte table" {
    nativeReady();
    try testing.expectEqual(@as(i8, 1), utf8proc.utf8Class('a'));
    try testing.expectEqual(@as(i8, 0), utf8proc.utf8Class(0xFF));
    try testing.expectEqual(@as(i8, 0), utf8proc.utf8Class(0x80));
    try testing.expectEqual(@as(i8, 2), utf8proc.utf8Class(0xC3));
    try testing.expectEqual(@as(i8, 3), utf8proc.utf8Class(0xE2));
    try testing.expectEqual(@as(i8, 4), utf8proc.utf8Class(0xF0));

    // A lead byte's class is only a length promise; the decoder validates bytes.
    const truncated = "\xE2\x82";
    try testing.expectEqual(@as(i8, 3), utf8proc.utf8Class(truncated[0]));
    try testing.expectError(error.InvalidUtf8, utf8proc.decode(truncated));
}

test "the NF* shortcuts answer Unicode's own values and refuse what they cannot" {
    nativeReady();

    // NFC composes `e` + acute to U+00E9; NFD preserves the sequence.
    const composed = try utf8proc.nfc("e\u{0301}");
    defer composed.deinit();
    try testing.expectEqualStrings("\u{00E9}", composed.bytes());

    const decomposed = try utf8proc.nfd("e\u{0301}");
    defer decomposed.deinit();
    try testing.expectEqualStrings("e\u{0301}", decomposed.bytes());

    // Compatibility forms split U+FB01; canonical forms preserve it.
    const ligature = try utf8proc.nfkd("\u{FB01}");
    defer ligature.deinit();
    try testing.expectEqualStrings("fi", ligature.bytes());

    const kept = try utf8proc.nfd("\u{FB01}");
    defer kept.deinit();
    try testing.expectEqualStrings("\u{FB01}", kept.bytes());

    // U+212B maps to U+00C5; U+1E9E case-folds to "ss".
    const singleton = try utf8proc.nfkc("\u{212B}");
    defer singleton.deinit();
    try testing.expectEqualStrings("\u{00C5}", singleton.bytes());

    const sharp = try utf8proc.nfkcCasefold("\u{1E9E}");
    defer sharp.deinit();
    try testing.expectEqualStrings("ss", sharp.bytes());

    // Shortcuts collapse malformed-input and allocation failures to `NoResult`.
    try testing.expectError(error.NoResult, utf8proc.nfc("\xFF"));
    // `map` preserves the specific UTF-8 error.
    try testing.expectError(error.InvalidUtf8, utf8proc.map("\xFF", .{}));

    // Empty input is valid and remains empty.
    const empty = try utf8proc.nfc("");
    defer empty.deinit();
    try testing.expectEqual(@as(usize, 0), empty.bytes().len);
}

test "decomposition refuses aliased input before changing caller bytes" {
    nativeReady();
    var storage: [8]u8 align(4) = .{ 'A', 'B', 0, 0, 0, 0, 0, 0 };
    const original = storage;
    const output: []i32 = @as([*]i32, @ptrCast(&storage))[0..2];
    try testing.expectError(error.InputOutputOverlap, utf8proc.decompose(storage[0..2], output, .{}));
    try testing.expectEqualSlices(u8, &original, &storage);
}

test "CHARBOUND requires a live per-character state" {
    nativeReady();
    var output: [4]i32 = .{ 101, 102, 103, 104 };
    try testing.expectError(error.InvalidOptions, utf8proc.decomposeChar('A', &output, .{ .charbound = true }, null));
    try testing.expectEqualSlices(i32, &.{ 101, 102, 103, 104 }, &output);
    var state: i32 = 0;
    const result = try utf8proc.decomposeChar('A', &output, .{ .charbound = true }, &state);
    try testing.expectEqual(@as(usize, 2), result.written);
    try testing.expectEqualSlices(i32, &.{ -1, 'A' }, output[0..2]);
}
