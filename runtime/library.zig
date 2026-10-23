// SPDX-License-Identifier: MIT
//
//! utf8proc-specific synchronization binding and provider checks for the runtime loader.
//! The generated dispatch requires every utf8proc function and the exported `utf8proc_utf8class` object.
//! Validation probes calls and the data table to check ABI shape.
//! It does not compare Unicode versions; a different version may still pass.

const rt = @import("rt");

/// Namespaced synchronization functions supplied by `runtime/sync.c`.
/// Their prefix must match the build's `RT_SYNC_PREFIX`.
pub const Sync = struct {
    extern fn utf8proc_rt_lock() void;
    extern fn utf8proc_rt_unlock() void;
    extern fn utf8proc_rt_wait() void;
    extern fn utf8proc_rt_broadcast() void;
    // Matches C `unsigned long long` on every target this SDK supports.
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

/// Adapts a generated dispatch to the reusable loader.
/// The dispatch supplies its table and symbol lists; this descriptor adds assignments, sync hooks, and ABI validation.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Name used in the pre-load panic.
        pub const library_name = "utf8proc";

        /// Generated table for this target's translated declarations.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// Namespaced synchronization binding for this SDK.
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

        /// Checks the resolved functions and data object before publication.
        /// Returns a refusal message on ABI mismatch, or null on success; Unicode-version compatibility is not checked.
        pub fn validate(dst: *const table) ?[]const u8 {
            // Check only for a null pointer; do not read provider-owned string contents.
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

            // Checks the C `int32_t` argument and `bool` return convention.
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

            // Checks a pointer-written `int32_t` and signed machine-word length and return.
            var decoded: i32 = 0;
            if (dst.utf8proc_iterate("\u{00E9}", 2, &decoded) != 2 or decoded != 0x00E9) {
                return "utf8proc_iterate() did not decode the two bytes of U+00E9 " ++
                    "into U+00E9, so its pointer, length and out-parameter " ++
                    "conventions do not match this header";
            }

            // Known entries exercise the resolved signed-byte table's pointer and element width.
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

            // Checks the C `int` return and `int32_t` argument.
            if (dst.utf8proc_charwidth(0x41) != 1) {
                return "utf8proc_charwidth('A') is not 1; its int return or its " ++
                    "int32 argument does not match this header";
            }

            return null;
        }
    };
}
