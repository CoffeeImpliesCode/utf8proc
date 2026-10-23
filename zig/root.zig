//! utf8proc 2.12.0 (Unicode 18.0.0) Zig facade for transforms, properties and grapheme segmentation.
//! Caller-buffer operations allocate nothing; `c` exposes the full translated C API.
//! Runtime mode needs an explicit provider load before other operations.
const std = @import("std");
const raw = @import("c");

/// Loader types used by linked builds; runtime dispatch owns its loader core.
const rt = @import("rt");

/// Translated upstream C header; use it for declarations not wrapped below.
pub const c = raw;

/// Comptime flag indicating whether calls use a runtime-loaded provider.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Explicit path or system name for the provider; the loader does not fall back between them.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Errors returned by `load`.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Loads an explicit provider; identical requests share an attempt, while conflicting or reentrant requests fail.
/// Failed attempts can be retried. Successful handles stay open for process lifetime; linked builds panic.
pub fn load(source: LoadSource) LoadError!void {
    if (comptime !runtime_loaded) {
        std.debug.panic(
            "utf8proc: load was called on a linked build; this module is not " ++
                "runtime-loaded, so there is no library to load. Build with " ++
                "runtime loading configured, or do not call load.",
            .{},
        );
    }
    return c.load(source);
}

/// Returns the retained load request, or `null` before load and in linked builds.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// Signed status/count type used by the C entry points.
pub const Status = raw.utf8proc_ssize_t;

/// Upstream option-word type.
pub const Option = raw.utf8proc_option_t;

/// Upstream Unicode general-category values.
pub const Category = raw.utf8proc_category_t;

/// Upstream bidi classes, available through the raw C route.
pub const BidiClass = raw.utf8proc_bidi_class_t;

/// Upstream decomposition types, available through the raw C route.
pub const DecompType = raw.utf8proc_decomp_type_t;

/// Upstream grapheme-boundary classes, available through the raw C route.
pub const BoundClass = raw.utf8proc_boundclass_t;

/// Upstream Indic conjunct-break values, available through the raw C route.
pub const IndicConjunctBreak = raw.utf8proc_indic_conjunct_break_t;

/// Opaque pointer to an entry in upstream's static property table.
/// C bit fields are opaque to Zig; the immutable table remains valid for process lifetime.
pub const Property = *const raw.utf8proc_property_t;

/// Runs synchronously on the caller thread; `data` is borrowed and may be null.
/// Results must be stable scalars across passes; nested calls must not reuse outer output.
pub const CustomFunc = ?*const fn (codepoint: i32, data: ?*anyopaque) callconv(.c) i32;

/// Upstream errors plus facade refusals for options, lengths and overlapping buffers.
pub const Error = error{
    /// Upstream allocation failed; caller-buffer paths do not allocate.
    OutOfMemory,
    /// Input length overflow, or unstable callback output between map passes.
    Overflow,
    /// Input is not well-formed UTF-8.
    InvalidUtf8,
    /// An unassigned or out-of-range codepoint was rejected.
    NotAssigned,
    /// Upstream rejected options, or the facade refused `nullterm` or missing state.
    InvalidOptions,
    /// Input and output byte ranges overlap in `decompose` or `decomposeCustom`.
    InputOutputOverlap,
};

/// Failure returned by the `utf8proc_NF*` shortcuts.
/// Upstream returns null, so allocation failure and invalid UTF-8 cannot be distinguished.
pub const ShortcutError = error{
    /// Upstream returned null; allocation failure and invalid UTF-8 are indistinguishable.
    NoResult,
};

/// Packed upstream option flags with matching bit positions and false defaults.
/// `nullterm`, simultaneous `compose`/`decompose`, and `stripmark` without either fail.
pub const Options = packed struct(u32) {
    /// Rejected by every slice API that accepts `Options`.
    nullterm: bool = false,
    stable: bool = false,
    compat: bool = false,
    compose: bool = false,
    decompose: bool = false,
    ignore: bool = false,
    rejectna: bool = false,
    nlf2ls: bool = false,
    nlf2ps: bool = false,
    /// Used by `normalizeUtf32`, `reencode` and `map`, not by decomposition.
    stripcc: bool = false,
    casefold: bool = false,
    charbound: bool = false,
    lump: bool = false,
    stripmark: bool = false,
    stripna: bool = false,
    /// Reserved high bits are preserved by `fromBits` and ignored by upstream.
    reserved: u17 = 0,

    /// `UTF8PROC_NLF2LF`: convert LF, CRLF, CR and NEL to LF.
    pub const nlf2lf = Options{ .nlf2ls = true, .nlf2ps = true };

    /// Returns the upstream `unsigned int` option word.
    pub fn toBits(self: Options) u32 {
        return @bitCast(self);
    }

    /// Reinterprets an upstream option word, preserving undefined high bits.
    pub fn fromBits(bits: u32) Options {
        return @bitCast(bits);
    }
};

/// Decoded codepoint and input length.
pub const Decoded = struct {
    /// Number of input bytes consumed.
    bytes_read: usize,
    /// Valid Unicode scalar returned by upstream's UTF-8 decoder.
    codepoint: u21,
};

/// Result of `encodeChar`.
pub const Encoded = union(enum) {
    /// Number of bytes written. Surrogate encodings are not valid UTF-8.
    bytes: u3,
    /// Upstream returned zero for an out-of-range codepoint; `out` is unchanged.
    rejected,
};

/// Result of a caller-buffer decomposition.
pub const DecomposeResult = union(enum) {
    /// Number of initialized codepoints in `dst`.
    written: usize,
    /// Required capacity. Upstream does not promise valid partial output.
    needs_more: usize,
};

/// Errors returned while re-encoding a caller-owned workspace.
pub const ReencodeError = Error || error{
    /// Requires `4 * length + 1` workspace bytes; failure writes nothing.
    WorkspaceTooSmall,
};

/// Owns an upstream allocation. Free it once with `deinit`, never with a Zig allocator.
/// Runtime-loaded results must be freed through the provider that allocated them.
pub const OwnedString = struct {
    ptr: [*c]u8,
    len: usize,

    /// Returns result bytes without the trailing NUL.
    pub fn bytes(self: OwnedString) []const u8 {
        return self.ptr[0..self.len];
    }

    /// Frees through upstream's `utf8proc_free`; call once per owned result.
    pub fn deinit(self: OwnedString) void {
        raw.utf8proc_free(self.ptr);
    }
};

/// Stateful UAX #29 iterator; feed every adjacent pair in string order.
/// Carries GB10/GB12/GB13 state that the stateless helper cannot track.
pub const GraphemeIterator = struct {
    /// Packed upstream state; zero starts a new string.
    state: i32 = 0,

    /// Resets the iterator for a new string.
    pub fn reset(self: *GraphemeIterator) void {
        self.state = 0;
    }

    /// Returns whether a break falls between the pair. Call in order without skipping pairs.
    pub fn next(self: *GraphemeIterator, previous: i32, current: i32) bool {
        return raw.utf8proc_grapheme_break_stateful(previous, current, &self.state);
    }
};

/// Returns upstream's semantic version as a sentinel-terminated string.
pub fn version() [:0]const u8 {
    return std.mem.span(raw.utf8proc_version());
}

/// Returns the Unicode version used to generate upstream's tables.
pub fn unicodeVersion() [:0]const u8 {
    return std.mem.span(raw.utf8proc_unicode_version());
}

/// Returns upstream's NUL-terminated status message.
pub fn errorMessage(status: Status) [:0]const u8 {
    return std.mem.span(raw.utf8proc_errmsg(status));
}

/// Decodes one codepoint from `bytes`; returns `null` for an empty slice.
/// Returns `InvalidUtf8` for malformed or non-scalar sequences.
pub fn decode(bytes: []const u8) Error!?Decoded {
    if (bytes.len == 0) return null;
    var codepoint: raw.utf8proc_int32_t = -1;
    const read = raw.utf8proc_iterate(bytes.ptr, try nativeLength(bytes.len), &codepoint);
    if (read < 0) return errorFromStatus(read);
    return Decoded{ .bytes_read = @intCast(read), .codepoint = @intCast(codepoint) };
}

/// Tests whether `codepoint` is a Unicode scalar, assigned or not.
pub fn codepointValid(codepoint: i32) bool {
    return raw.utf8proc_codepoint_valid(codepoint);
}

/// Encodes into a four-byte buffer; upstream does not validate surrogate values.
/// Returns `.rejected` only outside `[0, 0x110000)`; use `codepointValid` for scalars.
pub fn encodeChar(codepoint: i32, out: *[4]u8) Encoded {
    const written = raw.utf8proc_encode_char(codepoint, out);
    if (written == 0) return .rejected;
    return .{ .bytes = @intCast(written) };
}

/// Returns the opaque static property-table entry for `codepoint`.
pub fn property(codepoint: i32) Property {
    return raw.utf8proc_get_property(codepoint).?;
}

/// Returns the Unicode general category.
pub fn category(codepoint: i32) Category {
    return raw.utf8proc_category(codepoint);
}

/// Returns the NUL-terminated two-letter category name.
pub fn categoryString(codepoint: i32) [:0]const u8 {
    return std.mem.span(raw.utf8proc_category_string(codepoint));
}

/// Returns terminal width 0, 1 or 2; zero means non-printable, not `wcwidth`'s -1.
pub fn charWidth(codepoint: i32) i32 {
    return raw.utf8proc_charwidth(codepoint);
}

/// Tests whether `codepoint` has East Asian width class A.
pub fn charWidthAmbiguous(codepoint: i32) bool {
    return raw.utf8proc_charwidth_ambiguous(codepoint);
}

/// Returns the simple lowercase mapping; use case-fold options for full folding.
pub fn toLower(codepoint: i32) i32 {
    return raw.utf8proc_tolower(codepoint);
}

/// Returns the simple uppercase mapping, or the input codepoint.
pub fn toUpper(codepoint: i32) i32 {
    return raw.utf8proc_toupper(codepoint);
}

/// Returns the simple titlecase mapping, or the input codepoint.
pub fn toTitle(codepoint: i32) i32 {
    return raw.utf8proc_totitle(codepoint);
}

/// Tests whether `codepoint` is lowercase.
pub fn isLower(codepoint: i32) bool {
    return raw.utf8proc_islower(codepoint) != 0;
}

/// Tests whether `codepoint` is uppercase; titlecase letters are excluded.
pub fn isUpper(codepoint: i32) bool {
    return raw.utf8proc_isupper(codepoint) != 0;
}

/// Returns the provider's 256-byte table by address, not by copy.
/// The linked library or runtime provider owns this storage.
pub fn utf8ClassTable() *const [256]raw.utf8proc_int8_t {
    if (comptime runtime_loaded) return c.utf8proc_utf8classAddr();
    return &raw.utf8proc_utf8class;
}

/// Returns the byte count implied by a lead byte, not sequence validity.
pub fn utf8Class(byte: u8) i8 {
    return @intCast(utf8ClassTable()[byte]);
}

/// Decomposes one codepoint into caller-owned `dst`; `needs_more` gives required capacity.
/// `charbound` requires `last_boundclass` to carry state between calls.
pub fn decomposeChar(
    codepoint: i32,
    dst: []i32,
    options: Options,
    last_boundclass: ?*i32,
) Error!DecomposeResult {
    try requireSliced(options);
    if (options.charbound and last_boundclass == null) return error.InvalidOptions;
    const written = raw.utf8proc_decompose_char(
        codepoint,
        dst.ptr,
        try nativeLength(dst.len),
        options.toBits(),
        last_boundclass,
    );
    if (written < 0) return errorFromStatus(written);
    if (@as(usize, @intCast(written)) > dst.len) return .{ .needs_more = @intCast(written) };
    return .{ .written = @intCast(written) };
}

/// Returns required output capacity without allocating.
pub fn decomposeCount(str: []const u8, options: Options) Error!usize {
    try requireSliced(options);
    const needed = raw.utf8proc_decompose(str.ptr, try nativeLength(str.len), null, 0, options.toBits());
    if (needed < 0) return errorFromStatus(needed);
    return @intCast(needed);
}

/// Decomposes and canonically orders `str` into caller-owned `dst`.
/// Use `decomposeCount` to size `dst`; input and output ranges must not overlap.
pub fn decompose(str: []const u8, dst: []i32, options: Options) Error!DecomposeResult {
    return decomposeCustom(str, dst, options, null, null);
}

/// Decomposes with an optional `CustomFunc`; `data` is borrowed for this call.
/// Input and output ranges must not overlap; see `CustomFunc` for callback rules.
pub fn decomposeCustom(
    str: []const u8,
    dst: []i32,
    options: Options,
    custom: CustomFunc,
    data: ?*anyopaque,
) Error!DecomposeResult {
    try requireSliced(options);
    const input_length = try nativeLength(str.len);
    const output_length = try nativeLength(dst.len);
    try rejectOverlap(str, dst);
    // Null-buffer sizing matches upstream's query in `utf8proc_map`.
    var buffer: [*c]raw.utf8proc_int32_t = null;
    if (dst.len > 0) buffer = dst.ptr;
    const written = raw.utf8proc_decompose_custom(
        str.ptr,
        input_length,
        buffer,
        output_length,
        options.toBits(),
        custom,
        data,
    );
    if (written < 0) return errorFromStatus(written);
    if (@as(usize, @intCast(written)) > dst.len) return .{ .needs_more = @intCast(written) };
    return .{ .written = @intCast(written) };
}

/// Normalizes caller-owned codepoints in place and returns the new length.
/// Out-of-range values and the `-1` grapheme sentinel pass through and block composition.
pub fn normalizeUtf32(codepoints: []i32, options: Options) Error!usize {
    try requireSliced(options);
    const length = raw.utf8proc_normalize_utf32(codepoints.ptr, try nativeLength(codepoints.len), options.toBits());
    if (length < 0) return errorFromStatus(length);
    return @intCast(length);
}

/// Re-encodes the aligned workspace in place, writes NUL and returns the byte length.
/// Requires `4 * length + 1` bytes; `charbound` outputs invalid-UTF-8 `0xFF` markers.
pub fn reencode(
    workspace: []align(4) u8,
    length: usize,
    options: Options,
) ReencodeError!usize {
    try requireSliced(options);
    const needed = std.math.mul(usize, length, 4) catch return error.WorkspaceTooSmall;
    if (needed +| 1 > workspace.len) return error.WorkspaceTooSmall;
    const written = raw.utf8proc_reencode(
        @ptrCast(workspace.ptr),
        try nativeLength(length),
        options.toBits(),
    );
    if (written < 0) return errorFromStatus(written);
    return @intCast(written);
}

/// Legacy Unicode 8 pair test; it lacks the stateful GB10/12/13 rules.
pub fn graphemeBreak(previous: i32, current: i32) bool {
    return raw.utf8proc_grapheme_break(previous, current);
}

/// Returns the first break index, or `null` when no break exists.
/// Processes every adjacent pair in order with one stateful iterator.
pub fn firstGraphemeBreak(codepoints: []const i32) ?usize {
    if (codepoints.len < 2) return null;
    var it = GraphemeIterator{};
    for (codepoints[1..], 1..) |current, i| {
        if (it.next(codepoints[i - 1], current)) return i;
    }
    return null;
}

/// Maps `str` into upstream-owned memory returned as `OwnedString`.
/// Rejects `nullterm`; the input uses its explicit slice length.
pub fn map(str: []const u8, options: Options) Error!OwnedString {
    return mapCustom(str, options, null, null);
}

/// Maps with optional `custom`; `data` is borrowed for this call and may be null.
/// Callback results must stay stable across sizing and fill passes; see `CustomFunc`.
pub fn mapCustom(
    str: []const u8,
    options: Options,
    custom: CustomFunc,
    data: ?*anyopaque,
) Error!OwnedString {
    try requireSliced(options);
    var result: [*c]u8 = null;
    const length = raw.utf8proc_map_custom(
        str.ptr,
        try nativeLength(str.len),
        &result,
        options.toBits(),
        custom,
        data,
    );
    if (length < 0) return errorFromStatus(length);
    return .{ .ptr = result, .len = @intCast(length) };
}

/// Returns NFD of a NUL-terminated string.
/// Returns `NoResult` for malformed UTF-8 or allocation failure.
pub fn nfd(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFD(nulTerminated(str)));
}

/// Returns NFC of a NUL-terminated string.
/// Returns `ShortcutError.NoResult` on failure; see `nfd`.
pub fn nfc(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFC(nulTerminated(str)));
}

/// Returns NFKD of a NUL-terminated string.
/// Returns `ShortcutError.NoResult` on failure; see `nfd`.
pub fn nfkd(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFKD(nulTerminated(str)));
}

/// Returns NFKC of a NUL-terminated string.
/// Returns `ShortcutError.NoResult` on failure; see `nfd`.
pub fn nfkc(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFKC(nulTerminated(str)));
}

/// Returns NFKC_Casefold of a NUL-terminated string.
/// Returns `NoResult` if upstream cannot normalize or allocate.
pub fn nfkcCasefold(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFKC_Casefold(nulTerminated(str)));
}

/// Rejects `nullterm` because this facade receives explicit slice lengths.
fn requireSliced(options: Options) Error!void {
    if (options.nullterm) return error.InvalidOptions;
}

fn nativeLength(length: usize) Error!Status {
    return std.math.cast(Status, length) orelse error.Overflow;
}

fn rejectOverlap(input: []const u8, output: []i32) Error!void {
    const output_bytes = std.math.mul(usize, output.len, @sizeOf(i32)) catch return error.Overflow;
    if (input.len == 0 or output_bytes == 0) return;
    const input_start = @intFromPtr(input.ptr);
    const output_start = @intFromPtr(output.ptr);
    const overlaps = if (input_start <= output_start)
        output_start - input_start < input.len
    else
        input_start - output_start < output_bytes;
    if (overlaps) return error.InputOutputOverlap;
}

/// Casts a sentinel-terminated string to the C pointer used by the shortcuts.
fn nulTerminated(str: [:0]const u8) [*c]const u8 {
    return @ptrCast(str.ptr);
}

/// Converts a shortcut's nullable result; upstream does not expose the failure cause.
fn ownedFromNormalization(pointer: [*c]u8) ShortcutError!OwnedString {
    const result = pointer orelse return error.NoResult;
    const terminated = std.mem.span(@as([*:0]u8, @ptrCast(result)));
    return .{ .ptr = @ptrCast(terminated.ptr), .len = terminated.len };
}

/// Maps upstream's five negative statuses to `Error`.
fn errorFromStatus(status: Status) Error {
    return switch (status) {
        raw.UTF8PROC_ERROR_NOMEM => error.OutOfMemory,
        raw.UTF8PROC_ERROR_OVERFLOW => error.Overflow,
        raw.UTF8PROC_ERROR_INVALIDUTF8 => error.InvalidUtf8,
        raw.UTF8PROC_ERROR_NOTASSIGNED => error.NotAssigned,
        raw.UTF8PROC_ERROR_INVALIDOPTS => error.InvalidOptions,
        else => unreachable,
    };
}
