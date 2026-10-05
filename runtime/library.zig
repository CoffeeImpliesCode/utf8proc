// SPDX-License-Identifier: MIT
//
//! utf8proc's side of the runtime loader: the names its synchronization binding
//! has, and what it requires of a provider beyond resolving its symbols.
//!
//! Everything else about the runtime route is generic. `runtime/loader.zig` is
//! the state machine and the platform layer; `runtime/generate.zig` builds the
//! dispatch from whatever the translation step actually produced;
//! `runtime/graph.zig` wires them together. This file is what makes them
//! utf8proc's, and it is the file another SDK replaces.
//!
//! ## What a provider must be
//!
//! Every entry point `utf8proc.h` declares, all of them: the thirty-one
//! functions of `utf8proc.h:460-808` and the one exported object,
//! `utf8proc_utf8class` (`utf8proc.h:453`). The list is not written out here
//! because it is not this file's to state: `runtime/generate.zig` reads it from
//! the translation step's own output, so the authoritative record of what *was*
//! routed is the `symbols` array in the generated dispatch for the target and
//! configuration being built.
//!
//! There is no conditional entry point to make a judgement call about. Every
//! macro in `utf8proc.h` either is an option-word enumerator, a negative error
//! code, a version macro, or one of the export macros at `utf8proc.h:123-139`,
//! and none of them gates a declaration. See `provider_optional` in
//! `runtime/graph.zig`.
//!
//! ## The ABI boundary, stated honestly
//!
//! The C ABI, the platform's scalar widths and the declarations the header
//! fixes are the requirements. Concretely, what a provider must agree with
//! this build:
//!
//!   * `utf8proc_ssize_t` is `ptrdiff_t` (`utf8proc.h:118`), so every status,
//!     length and byte count is a signed machine word and not a fixed 32 or 64
//!     bits. `utf8proc_iterate` returns it *and* writes an `int32_t` through a
//!     pointer, so both conventions are exercised below.
//!   * `utf8proc_bool` is C99 `bool` (`utf8proc.h:119`), one byte, returned in
//!     the platform's own register.
//!   * `utf8proc_custom_func` (`utf8proc.h:447`) is an `int32_t (*)(int32_t,
//!     void *)`, so a provider calling back into this process uses the same
//!     argument convention the loader's own calls use.
//!   * `utf8proc_property_t` (`utf8proc.h:296-319`) is a bit-field record.
//!     Upstream indexes `utf8proc_stage1table` with its `lower` and `upper`
//!     fields and with `codepoint >> 15` (`utf8proc.c:233-240`), so a provider
//!     must be compiled from the **same Unicode version** as this build's
//!     tables, or the index is out of range for the provider's own table and the
//!     two disagree about every codepoint. This is the one requirement that is
//!     not about the C ABI at all, and it is why `validate` below asks for the
//!     Unicode version to be present rather than for any particular value.
//!   * the option word is `unsigned int` at every call site
//!     (`utf8proc.h:146-148`) and its bits are fixed by the enumerators of
//!     `utf8proc.h:150-216`. This build's `Options` is a `packed struct(u32)`
//!     whose `@bitCast` is bit-identical to it by construction.
//!   * `utf8proc_utf8class` is `const utf8proc_int8_t[256]`, an object of 256
//!     one-byte elements (`utf8proc.h:453`). The table stores the *address* of
//!     that object, never a copy, and the generated `utf8proc_utf8classAddr`
//!     accessor hands out that address. Reading through it is the only thing
//!     that proves the resolved symbol is an object of the right width rather
//!     than a same-named function.
//!
//! **What `validate` is and is not.** It resolves nothing — the loader has
//! already done that — and it does not compare version numbers, which proves
//! nothing about compatibility. What it does is *call* five resolved entry
//! points and *read* the resolved data object, through the exact field types the
//! translated header declares, and require the answers the Unicode standard
//! fixes. Those answers cannot be produced by a pointer whose calling
//! convention, argument widths or data-object element width differ from this
//! build's. That is an ABI check and not a compatibility claim: a provider built
//! for a different Unicode version resolves every symbol, passes every one of
//! these checks and still disagrees about codepoints this build has never asked
//! about.
//!
//! Every call `validate` makes is a pure query on upstream's static tables. None
//! of them allocates, none of them writes to a caller-visible buffer beyond the
//! local `i32` below, and none of them can fail.

const rt = @import("rt");

/// The synchronization this loader calls, bound by exact name.
///
/// The names below are `runtime/sync.h` compiled with
/// `RT_SYNC_PREFIX=utf8proc_rt`, which is what `runtime/graph.zig` passes. Two
/// spellings of that prefix have to agree: this file names the symbols, and
/// graph.zig defines the macro. A build where they disagree does not link, and
/// that is the whole error report: there is no runtime path that could hide it.
///
/// The core in `runtime/loader.zig` never names a symbol of its own, which is
/// what lets two SDKs, or two configurations of one SDK, hold their own loader
/// state in one process without sharing any of it.
pub const Sync = struct {
    extern fn utf8proc_rt_lock() void;
    extern fn utf8proc_rt_unlock() void;
    extern fn utf8proc_rt_wait() void;
    extern fn utf8proc_rt_broadcast() void;
    // `unsigned long long`. Declared as u64, which is the same type in every
    // ABI this SDK targets: 64-bit on x86_64, aarch64, riscv64 and wasm32.
    extern fn utf8proc_rt_thread_self() u64;

    pub fn lock() void {
        utf8proc_rt_lock();
    }
    pub fn unlock() void {
        utf8proc_rt_unlock();
    }
    pub fn wait() void {
        utf8proc_rt_wait();
    }
    pub fn broadcast() void {
        utf8proc_rt_broadcast();
    }
    pub fn threadSelf() u64 {
        return utf8proc_rt_thread_self();
    }
};

/// The loader's configuration for this SDK, given the dispatch that owns the
/// table.
///
/// `dispatch` is the generated module, passed as a type by the dispatch itself
/// so that this file never has to import it. The direction is one-way on
/// purpose: the descriptor knows what the loader needs, the dispatch knows what
/// the header said, and neither imports the other.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Named in the pre-load panic, so the message says which library was
        /// reached for before it was loaded.
        pub const library_name = "utf8proc";

        /// The table the generated dispatch declares, and the symbols it needs
        /// to fill it. Both come from the translated header, not from this file.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// The project's namespaced synchronization binding.
        pub const sync = Sync;

        pub fn tablePtr() *table {
            return dispatch.tablePtr();
        }

        pub fn ready() *rt.Ready {
            return &dispatch.ready;
        }

        pub fn assign(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assign(index, dst, address);
        }

        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// The library-specific check, run after every symbol resolved and
        /// before anything is published.
        ///
        /// Every condition here is one this code can evaluate to false, and
        /// every message names the symbol whose answer was wrong, because that is
        /// what a reader needs and cannot otherwise get from `load`.
        pub fn validate(dst: *const table) ?[]const u8 {
            // A `const char *` return, checked for the pointer itself rather than
            // for its contents: how long the string is says nothing about the
            // ABI, and reading past it here would turn a descriptor check into a
            // way to fault inside a provider.
            if (dst.utf8proc_version() == null) {
                return "utf8proc_version() answered with a null pointer, so this " ++
                    "provider is not a C library with this header's shape";
            }
            if (dst.utf8proc_unicode_version() == null) {
                return "utf8proc_unicode_version() answered with a null pointer; " ++
                    "the Unicode version is the one requirement here that is not " ++
                    "about the C ABI, and a provider that cannot name it cannot be " ++
                    "compared with these tables";
            }

            // One argument, `int32_t`, answered in a `bool`. A pointer reached
            // with the wrong convention, or reached at all where the provider
            // expected something else, cannot produce these two answers.
            if (!dst.utf8proc_codepoint_valid(0x41)) {
                return "utf8proc_codepoint_valid('A') answered false, so the " ++
                    "int32 argument or the bool return convention does not match " ++
                    "this header";
            }
            if (dst.utf8proc_codepoint_valid(0x110000)) {
                return "utf8proc_codepoint_valid(0x110000) answered true; U+110000 " ++
                    "is outside [0, 0x110000), which is what utf8proc.h:491 says " ++
                    "this returns 0 for";
            }

            // Three arguments including an `int32_t` written through a pointer,
            // a length that is a signed machine word, and that same word
            // returned as the result. This is the widest call the table makes
            // without allocating, and it is the one whose conventions a
            // mismatched `ptrdiff_t` width would break.
            var decoded: i32 = 0;
            if (dst.utf8proc_iterate("\u{00E9}", 2, &decoded) != 2 or decoded != 0x00E9) {
                return "utf8proc_iterate() did not decode the two bytes of U+00E9 " ++
                    "into U+00E9, so its pointer, length and out-parameter " ++
                    "conventions do not match this header";
            }

            // The exported object, read through the address the table holds. A
            // provider whose `utf8proc_utf8class` were a function, or an array
            // of some other element width, cannot answer with these bytes: the
            // lead byte 0xC3 promises exactly two continuation bytes
            // (utf8proc.c:56-72) and 0xFF is not a lead byte at all.
            if (dst.utf8proc_utf8class[0xC3] != 2) {
                return "utf8proc_utf8class[0xC3] is not 2; the resolved exported " ++
                    "object is not the 256-entry signed-byte table utf8proc.h:453 " ++
                    "declares";
            }
            if (dst.utf8proc_utf8class[0xFF] != 0) {
                return "utf8proc_utf8class[0xFF] is not 0, so the resolved " ++
                    "exported object does not start where utf8proc.h:453 says it " ++
                    "starts";
            }

            // A plain `int` return, one more convention for free.
            if (dst.utf8proc_charwidth(0x41) != 1) {
                return "utf8proc_charwidth('A') is not 1; its int return or its " ++
                    "int32 argument does not match this header";
            }

            return null;
        }
    };
}