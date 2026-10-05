//! utf8proc — Unicode normalization, case folding, grapheme segmentation and
//! scalar character properties, built on the upstream C library
//! utf8proc 2.12.0 (Unicode 18.0.0).
//!
//! This module is the *consumer* surface. It adds three things to the shipped C
//! API and nothing else:
//!
//! 1. Zig types for the option word (`Options`), the error set (`Error`) and the
//!    Unicode enumerations, so a caller never passes a bare `unsigned int`.
//! 2. Caller-buffer entry points for decomposition, normalization and
//!    re-encoding. Upstream's own header says applications wanting control over
//!    memory allocation should call `utf8proc_decompose` and `utf8proc_reencode`
//!    directly (`utf8proc.h:755-757`); those are the primary path here and they
//!    allocate nothing.
//! 3. Ownership and bounds the C API leaves to the caller: the spare byte
//!    `utf8proc_reencode` needs (`utf8proc.c:750-751`), the `NULL` terminator
//!    write at `utf8proc.c:768`, the `UTF8PROC_NULLTERM` flag that is unsafe on
//!    an ordinary slice, and the `malloc`/`free` pair behind `utf8proc_map` and
//!    the five `utf8proc_NF*` shortcuts (`nfd`, `nfc`, `nfkd`, `nfkc`,
//!    `nfkcCasefold`).
//!
//! Everything else is reached through the raw C route, `c`, which is the
//! translated, unmodified `utf8proc.h` shipped in `zig-out/include`.
//!
//! ## What upstream does *not* guarantee, stated here so it is not implied
//!
//! * `utf8proc_encode_char` does not validate its argument (`utf8proc.h:500`).
//!   It encodes the surrogate range `D800..DFFF` to three bytes that are *not*
//!   legal UTF-8, on purpose, so the API does not change (`utf8proc.c:187-188`).
//!   `encodeChar` reports upstream's own 0 return as `.rejected` and does not
//!   pretend to have validated the codepoint.
//! * Codepoints outside `[0, 0x110000)` and the `-1` grapheme sentinel are
//!   *passed through unchanged* by `utf8proc_normalize_utf32`, and composition
//!   never happens across one (`utf8proc.c:658-668`). `normalizeUtf32` inherits
//!   that; it is not input validation.
//! * `UTF8PROC_CHARBOUND` output contains `0xFF` bytes, which are not valid
//!   UTF-8 and are rejected by `utf8proc_iterate`. Such output does not round
//!   trip through `decode` (`utf8proc.c:204-209`).
//! * `utf8proc_get_property` returns a pointer into a static table. The C record
//!   contains bit fields, which Zig's C translator demotes to an opaque type
//!   (`lib/compiler/translate-c/Translator.zig:619-625`), so `Property` is
//!   opaque here too. Only properties that upstream also exports through a
//!   dedicated function are reachable from Zig: `category`, `charwidth` and
//!   `ambiguousWidth`. `combining_class`, `bidi_class`, `decomp_type`,
//!   `boundclass`, `ignorable` and the sequence indices are reachable through
//!   `c.utf8proc_get_property` from a C consumer, and are deliberately *not*
//!   faked here.

//! ## Two configurations: linked and runtime-loaded
//!
//! This module is built in one of two shapes, and `runtime_loaded` says which
//! at comptime.
//!
//! *Linked* is the default. The C library is linked, `c` is the translated
//! header, and every call below is a direct call with no table and no check.
//!
//! *Runtime-loaded* is opt-in, with `-Druntime=true`. The library is not
//! linked; `c` is a dispatch generated from the same translation step's output,
//! and all thirty-one functions `utf8proc.h:460-808` declares plus the one
//! exported object `utf8proc.h:453` declares are resolved through the platform
//! loader when the caller calls
//!
//! ```zig
//! try utf8proc.load(.{ .path = "/usr/lib/libutf8proc.so.3" });
//! ```
//!
//! before using anything else. A call into a module that has not loaded stops
//! the program with a message naming the function, in every optimization mode.
//! That is a programming error rather than a recoverable condition: the table
//! does not exist yet, and there is no partial state to fall back on. The load
//! itself reports a missing file, a provider that does not export what the
//! header declares, a request that cannot be honoured because a different
//! provider already won, or a reentrant call, as errors rather than as a
//! different library being loaded instead.
//!
//! The provider is reached, never guessed. `.path` names a file and `.system`
//! names a library for the platform loader; neither falls back to the other,
//! the module has no unload and no reset, and it keeps the handle and its own
//! copy of the request to the end of the process.
//!
//! What a provider must be is stated in `runtime/library.zig`, next to the ABI
//! boundary and what is and is not checked about it.
//!
//! ## The one exported object
//!
//! `utf8proc_utf8class` is the only exported *data* symbol in the header, and
//! it is reached through `utf8ClassTable`, never through a copy of the array.
//! In a linked build that is `&c.utf8proc_utf8class`, the address the linker
//! gave the archive; in a runtime-loading build it is the address the platform
//! loader resolved for the provider, read through the dispatch's guarded
//! `utf8proc_utf8classAddr`. Both are the provider's own memory, so a Zig copy
//! of the 256 bytes could only ever be a second, divergent answer to the same
//! question. Every read of it goes through the accessor, which is also what
//! makes a call before `load` a named panic instead of a read of whatever
//! happens to be in the table field.
const std = @import("std");
const raw = @import("c");

/// The loader core, which is where a linked build's two public types come from.
///
/// It is imported only by the linked configuration. In a runtime-loading build
/// the dispatch carries its own copy of the same declarations, and this module
/// is never referenced, so it is never resolved and never compiled. Either way
/// there is exactly one `LoadSource` and one `LoadError` in a build, which is
/// what keeps them one type for a consumer that names them.
const rt = @import("rt");

/// The translated upstream header, published unchanged as the raw C route.
///
/// This is the whole of `utf8proc.h` as shipped: option flags, error macros,
/// the `utf8proc_property_t` record (opaque here, see `Property`), the
/// `utf8proc_category_t` / `utf8proc_bidi_class_t` / `utf8proc_decomp_type_t` /
/// `utf8proc_boundclass_t` / `utf8proc_indic_conjunct_break_t` enumerations and
/// every exported function. Use it for anything this facade does not wrap; see
/// the module doc comment for what that includes.
pub const c = raw;

/// Whether this module was configured to resolve its native symbols at run
/// time.
///
/// False for the ordinary build, where the C library is linked and `c` is the
/// translated header itself. True when the build generated a dispatch that
/// resolves the same symbols through the platform loader, in which case `load`
/// is the call that makes the library usable.
///
/// It is a comptime constant, so a consumer can write two different code paths
/// and have only the one it chose analyzed.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Which native library `load` should open.
///
/// `.path` is an explicit file path and `.system` is an explicit name for the
/// platform loader. There is no path-to-system fallback and no implicit
/// fallback of any kind; a request that cannot be honoured is an error, not a
/// different library.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Every way `load` can decline.
///
/// Declared here, in the module a consumer imports, rather than only inside the
/// loader: the caller names the failure it is handling.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load the native library this module dispatches to.
///
/// In a runtime-loading build this is the whole contract: call it once, then
/// use this module as if it were linked. Calling it again with the same request
/// succeeds and changes nothing; calling it with a different request after a
/// success is `ProviderMismatch`, and the library already in use stays in use.
/// A failed attempt publishes nothing and can be retried explicitly, by
/// calling this again: there is no automatic retry, and no implicit second
/// source.
///
/// It keeps the process handle and its own copy of the request to the end of
/// the process. There is no unload and no reset, because the table is
/// process-global state that other code may already have called through.
///
/// Safe to call from any thread. A thread that arrives while an attempt for the
/// same request is in flight waits for that attempt and gets its result,
/// whatever it was. A call from the thread that is running the attempt is
/// `ReentrantLoad` rather than a deadlock.
///
/// In a linked build there is no provider, no table and nothing to resolve, so
/// this stops the program with a message saying so instead of quietly
/// succeeding. `runtime_loaded` is false there, so a consumer that supports
/// both configurations can tell the two apart at comptime instead of meeting
/// this at run time.
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

/// The request that succeeded, or null when nothing has loaded yet.
///
/// The answer is the loader's own retained copy and stays valid for the life of
/// the process. Null in a linked build, which has no request.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// Signed status word returned by the C entry points: a count on success,
/// one of the five negative codes on failure.
pub const Status = raw.utf8proc_ssize_t;

/// `unsigned int` option word accepted by the C entry points.
pub const Option = raw.utf8proc_option_t;

/// Unicode general category (`UTF8PROC_CATEGORY_*`).
pub const Category = raw.utf8proc_category_t;

/// Unicode bidirectional class (`UTF8PROC_BIDI_CLASS_*`). Reachable only
/// through the raw route: upstream exports no accessor for it.
pub const BidiClass = raw.utf8proc_bidi_class_t;

/// Decomposition mapping type (`UTF8PROC_DECOMP_TYPE_*`). Reachable only
/// through the raw route.
pub const DecompType = raw.utf8proc_decomp_type_t;

/// Grapheme cluster boundary class (`UTF8PROC_BOUNDCLASS_*`). Reachable only
/// through the raw route.
pub const BoundClass = raw.utf8proc_boundclass_t;

/// `Indic_Conjunct_Break` value (`UTF8PROC_INDIC_CONJUNCT_BREAK_*`). Reachable
/// only through the raw route.
pub const IndicConjunctBreak = raw.utf8proc_indic_conjunct_break_t;

/// Opaque handle on one entry of upstream's static property table.
///
/// `utf8proc_get_property` returns `const utf8proc_property_t *`
/// (`utf8proc.h:516`). The record is defined with C bit fields
/// (`utf8proc.h:296-319`), and the Zig C translator demotes any record with a
/// bit field to an opaque type, so no field is readable from Zig. The pointer is
/// valid for the lifetime of the process and must not be stored past it by a
/// consumer that expects it to change; upstream never writes to the table.
pub const Property = *const raw.utf8proc_property_t;

/// Callback applied to each codepoint before any other transformation, passed
/// to `decomposeCustom` and `mapCustom` (`utf8proc.h:442-447`).
///
/// It runs on **the calling thread**, synchronously, inside the native call.
/// The call site is `custom_func(uc, custom_data)` at `utf8proc.c:572`, between
/// the decode and the `utf8proc_decompose_char` that consumes the answer, and
/// upstream starts no thread anywhere in `utf8proc.c`. Nothing is deferred and
/// nothing happens after the return, so a callback may use state belonging to
/// the calling function.
///
/// It runs once per codepoint on *every* pass upstream makes:
/// `utf8proc_map_custom` decomposes twice — once to size the buffer and once
/// to fill it (`utf8proc.c:787`, `utf8proc.c:791`) — so it must be a pure
/// function of `(codepoint, data)`. A callback that answers differently on the
/// two passes makes upstream bail out with `error.Overflow`
/// (`utf8proc.c:800-803`) rather than overflow the heap.
///
/// The return value is the codepoint that is then decomposed (`utf8proc.c:572`,
/// `utf8proc.c:574-577`), so it must lie in `[0, 0x110000)`; anything else is
/// `error.NotAssigned` (`utf8proc.c:449`). See `Error`.
///
/// `data` is the opaque pointer handed to the same call, and it is nothing
/// else. Upstream only forwards it. `custom_data` appears five times in the
/// core: the two parameter declarations (`utf8proc.c:543`, `utf8proc.c:781`),
/// the two forwards `utf8proc_map_custom` makes on its two passes
/// (`utf8proc.c:787`, `utf8proc.c:791`), and exactly one *use* — the second
/// argument of the call at `utf8proc.c:572`. Nothing dereferences it, copies it
/// or keeps it, so neither does this module, and the borrow lasts exactly the
/// `decomposeCustom` or `mapCustom` call, which returns without it. It may
/// therefore be the address of a local of the calling function. `data` may also
/// be `null`, which reaches the callback unchanged, so a callback must tolerate
/// it instead of assuming its context is there.
///
/// `custom == null` means no custom mapping at all: upstream's guard is
/// `if (custom_func != NULL)` (`utf8proc.c:571`) and the header says the
/// argument "is ignored if it is `NULL`" (`utf8proc.h:583`, `utf8proc.h:767`).
///
/// Reentering this module from the callback is allowed, with one bound.
/// Nothing in the core is mutable global state — every file-scope object in
/// `utf8proc.c` and `utf8proc_data.c` is a function or a `const` table, and
/// every entry point keeps its state in its own locals and in the caller's
/// buffer — so a nested call is safe as long as it is not handed the `dst`
/// the outer call is filling, which the outer call resumes writing at
/// `buffer + wpos` (`utf8proc.c:575`). Nor can a callback be running inside a
/// `load` attempt: a runtime-loading build dispatches no call until the table
/// is published (see the module doc comment), so `load` from here reaches
/// `accept` rather than `ReentrantLoad`; in a linked build there is no table
/// and `load` stops the program. See `load`.
pub const CustomFunc = ?*const fn (codepoint: i32, data: ?*anyopaque) callconv(.c) i32;

/// The five native failures plus the facade's aliased-buffer refusal.
///
/// `InvalidOptions` also rejects NULLTERM on a slice and CHARBOUND without a
/// state pointer in `decomposeChar`. `Overflow` includes slice lengths which
/// do not fit the native signed size type. Refusals happen before native writes.
pub const Error = error{
    /// `UTF8PROC_ERROR_NOMEM` (`-1`): upstream's own `malloc` failed. Only
    /// reachable through `map` and `mapCustom`; the caller-buffer paths cannot
    /// fail this way because they allocate nothing.
    OutOfMemory,
    /// `UTF8PROC_ERROR_OVERFLOW` (`-2`): the input is too long to process
    /// (`utf8proc.c:580-581`), or a `CustomFunc` was not stable across
    /// `mapCustom`'s two passes (`utf8proc.c:800-803`).
    Overflow,
    /// `UTF8PROC_ERROR_INVALIDUTF8` (`-3`): the input is not well-formed
    /// UTF-8 (`utf8proc.c:562`, `utf8proc.c:569`).
    InvalidUtf8,
    /// `UTF8PROC_ERROR_NOTASSIGNED` (`-4`): `Options.rejectna` was set and an
    /// unassigned codepoint was found, or a codepoint outside
    /// `[0, 0x110000)` was decomposed (`utf8proc.c:449`, `utf8proc.c:468-470`).
    NotAssigned,
    /// `UTF8PROC_ERROR_INVALIDOPTS` (`-5`), or a `nullterm` option this facade
    /// refuses to pass through. See `Error`.
    InvalidOptions,
    /// Input and output byte ranges overlap in `decompose` or `decomposeCustom`.
    InputOutputOverlap,
};

/// The single failure of the `utf8proc_NF*` shortcuts (`nfd`, `nfc`, `nfkd`,
/// `nfkc`, `nfkcCasefold`).
///
/// It is one value rather than five because upstream throws the status away:
/// those five functions call `utf8proc_map` and return only its pointer
/// (`utf8proc.c:818-846`), and the pointer is NULL for at least two different
/// reasons — `malloc` failing and the input being rejected as malformed UTF-8.
/// Naming either of upstream's five negative codes here would be a guess about
/// which one happened, so this reports what the caller actually learned.
///
/// `map` and `decompose` return `Error`, which is closed at what upstream
/// actually said.
pub const ShortcutError = error{
    /// The shortcut returned NULL. Either its allocation failed or the input was
    /// not well-formed UTF-8; see this type's own doc comment.
    NoResult,
};

/// The option word, as a struct of independent flags.
///
/// The bit order is upstream's enumerator order (`utf8proc.h:150-216`), so
/// `@bitCast` of this struct is bit-identical to the `utf8proc_option_t` value
/// with the same flags set. Every field defaults to `false`, so `.{ .{}` and
/// partial literals are both valid.
///
/// Which flags each entry point honours is a property of upstream, not of this
/// type:
///
/// | Field | Honoured by | Upstream reference |
/// |---|---|---|
/// | `nullterm` | **nothing here** — rejected with `error.InvalidOptions` | `utf8proc.h:151`, `utf8proc.c:545` |
/// | `stable` | Accepted and forwarded; this pinned core has no branch on the bit | `utf8proc.h:154`, `utf8proc.c` |
/// | `compat` | `decomposeChar`, `decompose`, `map` | `utf8proc.h:157` |
/// | `compose` | `decomposeChar`, `decompose`, `normalizeUtf32`, `reencode`, `map` | `utf8proc.h:158` |
/// | `decompose` | `decomposeChar`, `decompose`, `map` | `utf8proc.h:160` |
/// | `ignore` | `decomposeChar`, `decompose`, `map` | `utf8proc.h:161` |
/// | `rejectna` | `decomposeChar`, `decompose`, `map` | `utf8proc.h:163`, `utf8proc.c:468-470` |
/// | `nlf2ls` | `decomposeChar` (with `lump` and `nlf2ps`), `decompose`, `normalizeUtf32`, `reencode`, `map` | `utf8proc.h:166`, `utf8proc.c:481` |
/// | `nlf2ps` | `decomposeChar` (with `lump` and `nlf2ls`), `decompose`, `normalizeUtf32`, `reencode`, `map` | `utf8proc.h:171`, `utf8proc.c:481` |
/// | `stripcc` | `normalizeUtf32`; `reencode` and `map` only through it — **not** `decompose`, `decomposeCustom` or `decomposeChar` | `utf8proc.h:179`, `utf8proc.c:619,627,641` |
/// | `casefold` | `decomposeChar`, `decompose`, `map` | `utf8proc.h:190` |
/// | `charbound` | `decomposeChar`, `decompose`, `reencode` (which turns the `-1` sentinel into the `0xFF` byte), `map` | `utf8proc.h:192`, `utf8proc.c:519`, `utf8proc.c:757` |
/// | `lump` | `decomposeChar`, `decompose`, `map` | `utf8proc.h:197` |
/// | `stripmark` | `decomposeChar`; `decompose` and `map` require `compose` or `decompose` | `utf8proc.h:204`, `utf8proc.c:503-506,549-551` |
/// | `stripna` | `decomposeChar`, `decompose`, `map` | `utf8proc.h:213` |
///
/// `stripcc` is the one row whose reach has to be stated in full, because
/// upstream reads the bit in exactly one function. `UTF8PROC_STRIPCC` appears
/// three times in the core — `utf8proc.c:619`, `utf8proc.c:627` and
/// `utf8proc.c:641` — and all three are inside `utf8proc_normalize_utf32`.
/// Neither `utf8proc_decompose_char` (`:445-531`) nor
/// `utf8proc_decompose_custom` (`:540-615`) tests it, which upstream's own
/// per-function option lists agree with: `utf8proc.h:523-532` does not list
/// `UTF8PROC_STRIPCC` for `utf8proc_decompose_char`, where `utf8proc.h:601`
/// and `utf8proc.h:624` do list it for `utf8proc_normalize_utf32` and
/// `utf8proc_reencode`. `reencode` calls `utf8proc_normalize_utf32` before it
/// encodes anything (`utf8proc.c:752`), and `map` is `decompose` followed by
/// `reencode` (`utf8proc.h:755-757`, `utf8proc.c:787`, `utf8proc.c:804`), so
/// those two honour the flag only by that route, and `decompose(str, dst,
/// .{ .stripcc = true })` returns every control character unchanged. Acting on
/// them needs `normalizeUtf32` or `reencode` with the same word. That word
/// does not simply delete controls: with no NLF option set, LF, CR, NEL, VT, FF
/// and HT all become U+0020 (`utf8proc.c:626-633`, `utf8proc.c:641-643`), while
/// every other codepoint below U+0020 or in `[0x7F, 0x00A0)` is removed outright
/// (`utf8proc.c:641-642`). Upstream's own prose says "NLF-sequences are
/// transformed into space … All other control characters are simply removed"
/// (`utf8proc.h:181-184`) and names HT and FF among the NLF sequences; the code
/// puts VT there as well (`utf8proc.c:627`).
///
/// Unknown option words are the caller's problem only when upstream checks
/// them: it rejects `compose | decompose` and `stripmark` without either, and
/// silently ignores everything else it does not implement for a given function.
pub const Options = packed struct(u32) {
    /// Rejected by every entry point in this module. See the module doc comment.
    nullterm: bool = false,
    stable: bool = false,
    compat: bool = false,
    compose: bool = false,
    decompose: bool = false,
    ignore: bool = false,
    rejectna: bool = false,
    nlf2ls: bool = false,
    nlf2ps: bool = false,
    stripcc: bool = false,
    casefold: bool = false,
    charbound: bool = false,
    lump: bool = false,
    stripmark: bool = false,
    stripna: bool = false,
    /// Undeclared high bits, preserved by `fromBits`; upstream ignores them.
    reserved: u17 = 0,

    /// `UTF8PROC_NLF2LF`: convert LF, CRLF, CR and NEL to LF (`utf8proc.h:178`).
    pub const nlf2lf = Options{ .nlf2ls = true, .nlf2ps = true };

    /// The `unsigned int` word handed to upstream.
    pub fn toBits(self: Options) u32 {
        return @bitCast(self);
    }

    /// The struct for an arbitrary option word. Bits above 14 are not a flag
    /// this version defines; `utf8proc.h` stops at `UTF8PROC_STRIPNA = 1<<14`.
    pub fn fromBits(bits: u32) Options {
        return @bitCast(bits);
    }
};

/// Result of decoding one codepoint from UTF-8.
pub const Decoded = struct {
    /// Bytes consumed from the front of the input. Never 0.
    bytes_read: usize,
    /// The decoded scalar value.
    ///
    /// Typed `u21` because `utf8proc_iterate` rejects surrogates
    /// (`utf8proc.c:151-152`), values below `0x800` in a three-byte sequence
    /// (`utf8proc.c:154-155`) and anything above `U+10FFFF` (`utf8proc.c:164-168`),
    /// so every value it returns successfully is a valid Unicode scalar.
    codepoint: u21,
};

/// Result of `encodeChar`.
pub const Encoded = union(enum) {
    /// `n` UTF-8 bytes were written to `out`. Note that a value of 3 does *not*
    /// imply validity: upstream encodes surrogates as three bytes on purpose.
    bytes: u3,
    /// Upstream returned 0, which it does for `codepoint < 0` and
    /// `codepoint >= 0x110000` (`utf8proc.c:178-200`). `out` is untouched.
    rejected,
};

/// Result of a `decompose`-family call.
pub const DecomposeResult = union(enum) {
    /// `count` codepoints were written to `dst`; `dst[0..count]` is meaningful.
    written: usize,
    /// Upstream needed `count` codepoints and `dst` was too small.
    ///
    /// `dst` now holds undefined data: upstream does not promise partial output
    /// (`utf8proc.h:570-572`). Nothing further can be read from it.
    needs_more: usize,
};

/// Result of `reencode`.
pub const ReencodeError = Error || error{
    /// `workspace` is smaller than `4 * length + 1` bytes. Returned before any
    /// byte is written, so `workspace` is unchanged.
    WorkspaceTooSmall,
};

/// A UTF-8 string allocated by upstream's `malloc`, released only by
/// `utf8proc_free`.
///
/// This memory comes from the C library the archive was linked against, not
/// from any Zig allocator (`utf8proc.c:789`, `utf8proc.c:811`, `utf8proc.c:849`).
/// Three consequences, all of them binding:
///
/// * `deinit` calls `utf8proc_free` and nothing else. Never release it with
///   `std.mem.free`, an allocator, or a raw `free` reached through any other
///   route: `utf8proc_free` is safer precisely because the application may be
///   linked to a different C library than the one utf8proc was built against
///   (`utf8proc.h:805-806`).
/// * Release it exactly once. Copying the `ptr` produces a second handle for one
///   allocation, and releasing both is a double free. `OwnedString` is a value;
///   treat it like a unique pointer and do not duplicate it.
/// * Zig's test allocator cannot supply a leak oracle across this boundary. A
///   test that leaks one of these will not be reported by `std.testing`.
///
/// ## Which `free`, in a runtime-loading build
///
/// Both halves of that pair come from the **same** library, and in a
/// runtime-loading build that is the provider, not whatever C library this
/// process is linked against. The allocation is made by the provider's
/// `malloc` (`utf8proc.c:789`, `utf8proc.c:811`) and the release is the
/// provider's own `utf8proc_free`, which is the one it exports from
/// `utf8proc.c:848-850` and which the header documents as *its* `free`
/// (`utf8proc.h:802-808`). `deinit` therefore goes out through the same table
/// entry `map` came in through, and a program that loads one provider must
/// release only what that same provider allocated.
///
/// Two consequences follow, and both are why `utf8proc_free` is a routed symbol
/// rather than C library noise:
///
///   * A provider that does not export `utf8proc_free` is refused at load time
///     rather than half used. `map` and the five `utf8proc_NF*` shortcuts
///     allocate through it and there is no other correct way to give the memory
///     back.
///   * Replacing the provider is not possible after the first allocation, which
///     is not a gap in the loader: `load` refuses a different provider after a
///     success (`ProviderMismatch`) precisely because the allocator behind these
///     strings is part of what was chosen.
pub const OwnedString = struct {
    ptr: [*c]u8,
    len: usize,

    /// The result bytes, excluding the trailing NUL upstream always writes.
    pub fn bytes(self: OwnedString) []const u8 {
        return self.ptr[0..self.len];
    }

    /// Releases the allocation. Exactly once per handle; see `OwnedString`.
    pub fn deinit(self: OwnedString) void {
        raw.utf8proc_free(self.ptr);
    }
};

/// Stateful grapheme-cluster iterator over consecutive codepoints.
///
/// `utf8proc_grapheme_break_stateful` implements UAX #29 extended grapheme
/// clusters, which include rules GB10/GB12/GB13 — emoji ZWJ sequences and
/// regional-indicator pairing — that cannot be decided from a pair of
/// codepoints alone (`utf8proc.c:246-260`). Upstream therefore requires the
/// call to be made **in order on every candidate break in the string**, with the
/// state reset to 0 at the start (`utf8proc.h:649-658`).
///
/// This type owns that state so the requirement cannot be forgotten. Feed it
/// every adjacent pair of the string, in order:
///
/// ```zig
/// var it = utf8proc.GraphemeIterator{};
/// var breaks = std.ArrayList(usize).initCapacity(allocator, 8); // break before index i
/// for (codepoints[1..], 1..) |cp, i| {
///     if (it.next(codepoints[i - 1], cp)) try breaks.append(allocator, i);
/// }
/// ```
pub const GraphemeIterator = struct {
    /// Upstream's packed state: bound class in the low byte, `Indic_Conjunct_Break`
    /// in the next (`utf8proc.c:300-301`). Starts at 0, which is upstream's
    /// documented "beginning of the string" value.
    state: i32 = 0,

    /// Forgets the string so far. Safe at any time, including after a break
    /// (`utf8proc.h:658`).
    pub fn reset(self: *GraphemeIterator) void {
        self.state = 0;
    }

    /// Whether a grapheme cluster ends between `previous` and `current`.
    ///
    /// Must be called in order, on every adjacent pair, with a single iterator
    /// for the whole string. Calling it out of order, skipping a pair, or mixing
    /// iterators between two points of one string gives a wrong answer with no
    /// error.
    pub fn next(self: *GraphemeIterator, previous: i32, current: i32) bool {
        return raw.utf8proc_grapheme_break_stateful(previous, current, &self.state);
    }
};

// ---------------------------------------------------------------------------
// Library identity
// ---------------------------------------------------------------------------

/// The API version upstream reports, `MAJOR.MINOR.PATCH` (`utf8proc.c:99-101`).
/// Stringized from the shipped header's own macros, so it is not a constant
/// this facade could get out of step with.
pub fn version() [:0]const u8 {
    return std.mem.span(raw.utf8proc_version());
}

/// The Unicode version the compiled tables were generated from
/// (`utf8proc.c:103-105`).
pub fn unicodeVersion() [:0]const u8 {
    return std.mem.span(raw.utf8proc_unicode_version());
}

/// Upstream's own sentence for a status word (`utf8proc.c:107-122`). Any value
/// outside the five negative codes gets upstream's generic sentence, so this is
/// total.
pub fn errorMessage(status: Status) [:0]const u8 {
    return std.mem.span(raw.utf8proc_errmsg(status));
}

// ---------------------------------------------------------------------------
// Codepoints: decode, encode, properties
// ---------------------------------------------------------------------------

/// Decodes one codepoint from the front of `bytes`.
///
/// Returns `null` for an empty slice: there is nothing to decode, and upstream
/// agrees (`utf8proc.c:132` returns 0 and sets the output to -1).
///
/// Never passes a negative length, so upstream reads at most `bytes.len` bytes
/// and cannot run past the slice. Upstream's `strlen < 0` mode, which reads up
/// to 4 bytes regardless, is reachable only through `c.utf8proc_iterate`.
///
/// Returns `error.InvalidUtf8` for a malformed sequence, including a lone
/// continuation byte, an over-long encoding, a surrogate (`utf8proc.c:151-152`)
/// and anything above `U+10FFFF` (`utf8proc.c:164-168`).
pub fn decode(bytes: []const u8) Error!?Decoded {
    if (bytes.len == 0) return null;
    var codepoint: raw.utf8proc_int32_t = -1;
    const read = raw.utf8proc_iterate(bytes.ptr, try nativeLength(bytes.len), &codepoint);
    if (read < 0) return errorFromStatus(read);
    return Decoded{ .bytes_read = @intCast(read), .codepoint = @intCast(codepoint) };
}

/// Whether `codepoint` is a valid Unicode scalar, assigned or not
/// (`utf8proc.c:173-175`). Surrogates `D800..DFFF` are not valid.
pub fn codepointValid(codepoint: i32) bool {
    return raw.utf8proc_codepoint_valid(codepoint);
}

/// Encodes `codepoint` as UTF-8 into `out`, which must be 4 bytes
/// (`utf8proc.h:495`).
///
/// Upstream does not validate its argument, so this does not either: the
/// surrogate range is encoded to three bytes that are not legal UTF-8, by
/// design (`utf8proc.c:187-188`). Only the `utf8proc.c:178-200` boundaries
/// produce `.rejected`. Use `codepointValid` first if you need a guarantee.
pub fn encodeChar(codepoint: i32, out: *[4]u8) Encoded {
    const written = raw.utf8proc_encode_char(codepoint, out);
    if (written == 0) return .rejected;
    return .{ .bytes = @intCast(written) };
}

/// The property table entry for `codepoint`.
///
/// Returns upstream's shared sentinel record whose `category` is `0`
/// (`UTF8PROC_CATEGORY_CN`) for any codepoint outside `[0, 0x110000)`
/// (`utf8proc.c:242-244`). The record is opaque here — see `Property`.
pub fn property(codepoint: i32) Property {
    return raw.utf8proc_get_property(codepoint).?;
}

/// The Unicode general category of `codepoint` (`utf8proc.c:432-434`).
pub fn category(codepoint: i32) Category {
    return raw.utf8proc_category(codepoint);
}

/// The two-letter category name, e.g. `"Lu"` (`utf8proc.c:436-439`). Always
/// NUL-terminated; never null.
pub fn categoryString(codepoint: i32) [:0]const u8 {
    return std.mem.span(raw.utf8proc_category_string(codepoint));
}

/// Display width in terminal cells, `0`, `1` or `2` (`utf8proc.c:424-426`).
///
/// `0` means non-printable, unlike `wcwidth` which reports `-1`
/// (`utf8proc.h:705-711`). This is utf8proc's own table, not the C library's;
/// the two disagree for codepoints the system's tables are out of date on.
pub fn charWidth(codepoint: i32) i32 {
    return raw.utf8proc_charwidth(codepoint);
}

/// Whether `codepoint` has East Asian width class A, ambiguous
/// (`utf8proc.c:428-430`). Such codepoints have width 1 unless they are
/// non-printable, and some East Asian fonts draw them double width.
pub fn charWidthAmbiguous(codepoint: i32) bool {
    return raw.utf8proc_charwidth_ambiguous(codepoint);
}

/// The simple lowercase mapping of `codepoint`, or `codepoint` itself when there
/// is none or it is out of range (`utf8proc.c:392-396`).
///
/// This is the *simple* mapping, one codepoint to at most one codepoint. It is
/// not case folding; use `decompose` with `Options.casefold` for that.
pub fn toLower(codepoint: i32) i32 {
    return raw.utf8proc_tolower(codepoint);
}

/// The simple uppercase mapping, or `codepoint` itself (`utf8proc.c:398-402`).
pub fn toUpper(codepoint: i32) i32 {
    return raw.utf8proc_toupper(codepoint);
}

/// The simple titlecase mapping, or `codepoint` itself (`utf8proc.c:404-408`).
pub fn toTitle(codepoint: i32) i32 {
    return raw.utf8proc_totitle(codepoint);
}

/// Whether `codepoint` is a lowercase letter (`utf8proc.c:410-414`).
pub fn isLower(codepoint: i32) bool {
    return raw.utf8proc_islower(codepoint) != 0;
}

/// Whether `codepoint` is an uppercase letter (`utf8proc.c:416-420`). Titlecase
/// letters are excluded.
pub fn isUpper(codepoint: i32) bool {
    return raw.utf8proc_isupper(codepoint) != 0;
}

/// Upstream's exported `utf8proc_utf8class` table, as the provider's own
/// address.
///
/// The object is 256 signed bytes (`utf8proc.h:453`, defined at
/// `utf8proc.c:56`), and this returns a pointer to it rather than a copy of
/// it, so every read below is a read of the table the loaded or linked library
/// actually uses. Copying it would be a second source of truth about lead
/// bytes, and it could only agree with the provider until one of them changed.
///
/// In a runtime-loading build this is the dispatch's `utf8proc_utf8classAddr`,
/// which checks that a load has published the table before handing the address
/// out; in a linked build it is the array the linker resolved. Both are live
/// provider memory.
pub fn utf8ClassTable() *const [256]raw.utf8proc_int8_t {
    if (comptime runtime_loaded) return c.utf8proc_utf8classAddr();
    return &raw.utf8proc_utf8class;
}

/// The byte length upstream expects for a UTF-8 sequence starting with `byte`
/// (`utf8proc.c:56-72`): 0, 1, 2, 3 or 4. Purely a property of the first byte;
/// it says nothing about whether the sequence is well formed.
pub fn utf8Class(byte: u8) i8 {
    return @intCast(utf8ClassTable()[byte]);
}

// ---------------------------------------------------------------------------
// Decomposition — caller buffers
// ---------------------------------------------------------------------------

/// Decomposes one codepoint into `dst`.
///
/// With `Options.charbound`, upstream may emit the `-1` grapheme-break sentinel
/// immediately before the codepoint and then the codepoint itself, which is why
/// the documented default size doubles (`utf8proc.h:539-540`). The sentinel is
/// an artifact of the intermediate UTF-32 form and is not a valid codepoint;
/// `reencode` with `Options.charbound` turns it into a `0xFF` byte.
///
/// `last_boundclass` carries `boundclass + (indic_conjunct_break << 8)` from the
/// previous codepoint and is written back (`utf8proc.h:533-537`). Pass `null`
/// when `Options.charbound` is not set. With CHARBOUND, a live state is required.
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

/// The number of codepoints `decompose` would write for `str`.
///
/// This is upstream's own sizing query: a null buffer with size 0
/// (`utf8proc.c:787` is upstream doing exactly this inside `utf8proc_map`).
/// It allocates nothing.
pub fn decomposeCount(str: []const u8, options: Options) Error!usize {
    try requireSliced(options);
    const needed = raw.utf8proc_decompose(str.ptr, try nativeLength(str.len), null, 0, options.toBits());
    if (needed < 0) return errorFromStatus(needed);
    return @intCast(needed);
}

/// Decomposes `str` into `dst`, applying canonical ordering.
///
/// The primary caller-buffer normalization entry point. It is upstream's
/// `utf8proc_decompose`, which is what `utf8proc_map` itself is built from
/// (`utf8proc.c:755-757`). Nothing is allocated: `dst` must be at least
/// `decomposeCount(str, options)` codepoints long.
/// Input and output slices must have disjoint byte ranges.
pub fn decompose(str: []const u8, dst: []i32, options: Options) Error!DecomposeResult {
    return decomposeCustom(str, dst, options, null, null);
}

/// `decompose` with a `custom` mapping applied to every codepoint before any
/// other transformation, and a `data` pointer passed through to it
/// (`utf8proc.h:580-583`).
///
/// `custom` may be `null`, in which case this is `decompose`. `data` is
/// forwarded to the callback untouched and borrowed for exactly this call;
/// `CustomFunc` states both obligations.
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
    // Upstream's sizing query is a null buffer with size 0
    // (`utf8proc.c:787`); taking that branch verbatim keeps `needs_more`
    // reporting the same number either way.
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

/// Normalizes `codepoints` **in place** and returns the new length.
///
/// Allocation-free and non-allocating by contract: `codepoints[0..returned]` is
/// the result, and the tail is stale. Upstream only ever writes `wpos <= length`
/// entries, so the slice can be narrowed with `codepoints[0..returned]`.
///
/// `Options.nullterm` is rejected. Upstream ignores it here anyway
/// (`utf8proc.c:618`), and ignoring a flag the caller set is worse than
/// refusing it.
///
/// Codepoints outside `[0, 0x110000)` and the `-1` grapheme sentinel survive
/// unchanged and block composition across themselves (`utf8proc.c:658-668`).
/// Upstream must do this: reading a property for an out-of-range codepoint would
/// index `utf8proc_stage1table` out of bounds (`utf8proc.c:233-240`).
pub fn normalizeUtf32(codepoints: []i32, options: Options) Error!usize {
    try requireSliced(options);
    const length = raw.utf8proc_normalize_utf32(codepoints.ptr, try nativeLength(codepoints.len), options.toBits());
    if (length < 0) return errorFromStatus(length);
    return @intCast(length);
}

/// Re-encodes the first `length` codepoints of `workspace` as UTF-8, **in
/// place**, and returns the byte length, excluding the NUL upstream writes at
/// `workspace[result]` (`utf8proc.c:768`).
///
/// `workspace` must be 4-byte aligned and hold `length` native-endian `i32`
/// codepoints on entry. It receives UTF-8 bytes on exit.
///
/// **The spare byte is owned here.** Upstream requires "one spare byte of free
/// space at the end" and checks nothing (`utf8proc.c:750-751`); the header
/// repeats it as a warning that the program *might crash* (`utf8proc.h:636-639`).
/// A buffer of exactly `4 * length` bytes — which is what `length` elements of
/// `i32` are — is one byte short, and a stack array of `i32` always is. This
/// function computes `4 * length + 1` with an ordinary comparison before it
/// writes anything and returns `error.WorkspaceTooSmall` when the workspace is
/// too small, so the overrun cannot happen from Zig.
///
/// `workspace[0..result]` is the UTF-8 result; `workspace[result] == 0`.
/// Overlap is not a hazard: the input and the output are the same bytes by
/// contract, and upstream writes forward (`utf8proc.c:763-766`), reading each
/// codepoint before writing its bytes.
///
/// With `Options.charbound`, `-1` entries become `0xFF` bytes
/// (`utf8proc.c:204-209`). `0xFF` is not valid UTF-8 and `decode` rejects it, so
/// such output must not be fed back in.
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

// ---------------------------------------------------------------------------
// Grapheme segmentation
// ---------------------------------------------------------------------------

/// The stateless, Unicode 8.0.0 pair test (`utf8proc.c:351-354`).
///
/// Supported for legacy reasons only: it omits GB10, GB12 and GB13, so it
/// reports a break inside an emoji ZWJ sequence and never pairs regional
/// indicators correctly (`utf8proc.h:663-665`). Prefer `GraphemeIterator` for
/// anything new.
pub fn graphemeBreak(previous: i32, current: i32) bool {
    return raw.utf8proc_grapheme_break(previous, current);
}

/// The index of the first grapheme break in `codepoints`, or `null` if there is
/// none.
///
/// Index `i` means a cluster ends between `codepoints[i - 1]` and
/// `codepoints[i]`, so the smallest value is 1 and `null` covers both "empty" and
/// "one codepoint, no break". Every adjacent pair is offered to one
/// `GraphemeIterator`, in order, as UAX #29 requires. A break at index `i`
/// resets nothing: the iterator's state is already correct for the next pair.
pub fn firstGraphemeBreak(codepoints: []const i32) ?usize {
    if (codepoints.len < 2) return null;
    var it = GraphemeIterator{};
    for (codepoints[1..], 1..) |current, i| {
        if (it.next(codepoints[i - 1], current)) return i;
    }
    return null;
}

// ---------------------------------------------------------------------------
// Mapping — upstream-allocated
// ---------------------------------------------------------------------------

/// Maps `str` with `utf8proc_map` and returns upstream's allocation.
///
/// This is `decompose` followed by `reencode` (`utf8proc.c:783-815`), with a
/// `malloc` in the middle. Reach for `decompose` plus `reencode` instead whenever
/// a reusable buffer is possible: this path allocates on every call, cannot be
/// routed through a Zig allocator, and cannot be covered by a Zig leak oracle
/// (see `OwnedString`).
///
/// `Options.nullterm` is rejected: the result is always NUL-terminated
/// regardless (`utf8proc.h:740-743`), and the input length is always `str.len`.
pub fn map(str: []const u8, options: Options) Error!OwnedString {
    return mapCustom(str, options, null, null);
}

/// `map` with a `custom` mapping applied to each codepoint before any other
/// transformation (`utf8proc.h:763-767`).
///
/// `custom` may be `null`, in which case this is `map`, and `data` is then
/// ignored with it (`utf8proc.h:767`).
///
/// `custom` runs twice per call, once to size the allocation and once to fill it
/// (`utf8proc.c:787`, `utf8proc.c:791`), so it must be a pure function of
/// `(codepoint, data)`. An impure one yields `error.Overflow`, not corruption.
/// `data` is forwarded untouched and borrowed for exactly this call;
/// `CustomFunc` states both obligations.
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

// ---------------------------------------------------------------------------
// Normalization shortcuts — upstream's own option words, NUL-terminated
// ---------------------------------------------------------------------------
//
// The five `utf8proc_NF*` entry points (`utf8proc.h:786-800`). Each one is
// `map` with `UTF8PROC_NULLTERM` and a fixed option word, so each one takes its
// length from the terminator and allocates upstream's `malloc`ed result. They
// report one failure, `ShortcutError.NoResult`, because upstream discards the
// status that would distinguish the rest; see `ShortcutError`.

/// Canonical decomposition (NFD) of a NUL-terminated string.
///
/// This is `utf8proc_NFD` (`utf8proc.h:788`), which is `map` with
/// `NULLTERM | STABLE | DECOMPOSE` (`utf8proc.c:818-822`). It takes the length
/// from the terminator, which is why the parameter is `[:0]const u8` and not a
/// slice: a string with an interior `0x00` is exactly the input upstream is
/// built to stop at, and silently normalizing a different length would be worse
/// than making the caller say which one it meant.
///
/// Reach for `decompose` and `reencode` instead when a reusable buffer is
/// possible; see `map`.
///
/// Answers `error.NoResult` for input upstream could not normalize, which
/// includes malformed UTF-8 as well as an allocation failure.
pub fn nfd(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFD(nulTerminated(str)));
}

/// Canonical composition (NFC) of a NUL-terminated string
/// (`utf8proc.h:790`, `utf8proc.c:824-828`).
/// Answers `error.NoResult`; see `nfd`.
pub fn nfc(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFC(nulTerminated(str)));
}

/// Compatibility decomposition (NFKD) of a NUL-terminated string
/// (`utf8proc.h:792`, `utf8proc.c:830-834`).
/// Answers `error.NoResult`; see `nfd`.
pub fn nfkd(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFKD(nulTerminated(str)));
}

/// Compatibility composition (NFKC) of a NUL-terminated string
/// (`utf8proc.h:794`, `utf8proc.c:836-840`).
/// Answers `error.NoResult`; see `nfd`.
pub fn nfkc(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFKC(nulTerminated(str)));
}

/// NFKC_Casefold of a NUL-terminated string (`utf8proc.h:799`,
/// `utf8proc.c:842-846`): compatibility composition, case folding and default
/// ignorable removal in one pass. This is the string form of the `CaseFolding`
/// derived property in `DerivedCoreProperties.txt`, not the simple lowercase
/// mapping `toLower` gives.
/// Answers `error.NoResult`; see `nfd`.
pub fn nfkcCasefold(str: [:0]const u8) ShortcutError!OwnedString {
    return ownedFromNormalization(raw.utf8proc_NFKC_Casefold(nulTerminated(str)));
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

/// Every entry point here takes an explicit slice, so `UTF8PROC_NULLTERM` is
/// refused rather than silently reinterpreted. Upstream's own rule is that with
/// `NULLTERM` the length argument is ignored (`utf8proc.c:545`); letting a
/// caller set a flag whose only effect is to discard the length they passed
/// would be the unsafe choice on an ordinary slice, which may legitimately
/// contain `0x00` bytes.
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

/// A slice's bytes as the `const utf8proc_uint8_t *` the C entry points take.
///
/// The `utf8proc_NF*` family is the one place upstream's own API is written in
/// terms of a terminator rather than a length (`utf8proc.h:774-786`), so the
/// parameter there is `[:0]const u8` and this is the one conversion it needs.
/// Nothing is copied and no terminator is added: the slice already carries its
/// sentinel.
fn nulTerminated(str: [:0]const u8) [*c]const u8 {
    return @ptrCast(str.ptr);
}

/// Turns one of the `utf8proc_NF*` results into an `OwnedString`.
///
/// Those five functions discard `utf8proc_map`'s return value and hand back its
/// pointer (`utf8proc.c:818-846`), so a NULL is the only signal a caller gets,
/// and it stands for every cause `utf8proc_map_custom` has for leaving
/// `*dstptr` at NULL (`utf8proc.c:786`): `malloc` failing (`utf8proc.c:790`)
/// and a decomposition pass rejecting the input (`utf8proc.c:788`). Upstream
/// throws the status away, so this cannot tell those apart and does not
/// pretend to: it reports one honest failure rather than guessing which of
/// upstream's five negative codes happened to be the true one.
///
/// `map` is the entry point to reach for when the reason matters; it returns
/// the status directly and answers `Error`.
///
/// The length is the terminator's offset, not `utf8proc_map`'s return value:
/// the result is always NUL-terminated (`utf8proc.h:741-743`) and that return
/// counts the same bytes, but the caller of these five functions never sees it.
fn ownedFromNormalization(pointer: [*c]u8) ShortcutError!OwnedString {
    const result = pointer orelse return error.NoResult;
    const terminated = std.mem.span(@as([*:0]u8, @ptrCast(result)));
    return .{ .ptr = @ptrCast(terminated.ptr), .len = terminated.len };
}

/// Maps one of upstream's five negative statuses onto `Error`.
///
/// Closed at five because `utf8proc_errmsg` itself is closed at five
/// (`utf8proc.c:107-122`) and no exported function returns any other negative
/// value. The `else` arm is therefore unreachable, not an input check.
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
