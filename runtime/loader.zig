// SPDX-License-Identifier: MIT
//
//! Process-global loader for generated C dispatch tables.
//! `load` opens the exact requested path or system name, resolves required exports, validates, then publishes once.
//! Success retains the provider and request for process lifetime. Failed attempts publish nothing and may be retried explicitly.
//! Concurrent callers with the same request share one attempt; a different provider returns `ProviderMismatch`.
//! Recursive loads return `ReentrantLoad`; routed calls before readiness panic.
//! There is no path/name fallback, automatic retry, unload, or reset.
//! A provider constructor can deadlock if it waits on another thread calling `load`.

const std = @import("std");
const builtin = @import("builtin");

/// Names a file path or system-loader name; the two kinds are never converted.
/// `.path` must be absolute; `.system` must be a basename without separators.
pub const LoadSource = union(enum) {
    /// Absolute file path; relative paths and embedded NUL bytes are rejected.
    path: []const u8,
    /// Basename or SONAME searched by the platform loader; separators and NUL bytes are rejected.
    system: []const u8,
};

/// Errors returned when a load request or provider cannot be used.
pub const LoadError = error{
    /// Empty path or name, rejected before calling the platform loader.
    EmptySource,
    /// Request exceeds `max_source_len`; refuse instead of truncating the retained copy.
    SourceTooLong,
    /// Relative file path, system name with separators, or embedded NUL byte.
    InvalidSource,
    /// Target has no dynamic loader; the request is refused without a linked fallback.
    UnsupportedTarget,
    /// Platform loader refused the file or one of its dependencies.
    OpenFailed,
    /// A required export is missing; the candidate is closed and nothing is published.
    MissingSymbol,
    /// Library validation declined the resolved provider; nothing is published.
    ValidationFailed,
    /// Another provider is active or in flight; the selected request is unchanged.
    ProviderMismatch,
    /// The current attempt's owner called `load` recursively; return rather than deadlock.
    ReentrantLoad,
};

/// Maximum request length, in bytes.
pub const max_source_len = 32768;

/// Fixed-size request copy, stored without allocation.
/// Retention allows later comparisons after the caller's storage expires.
const SourceRecord = struct {
    tag: enum(u8) { none = 0, path, system } = .none,
    len: u32 = 0,
    bytes: [max_source_len]u8 = undefined,

    /// Called under the loader lock after checking the request length.
    fn set(self: *SourceRecord, request: LoadSource) void {
        const text = switch (request) {
            .path => |p| p,
            .system => |s| s,
        };
        @memcpy(self.bytes[0..text.len], text);
        self.len = @intCast(text.len);
        self.tag = switch (request) {
            .path => .path,
            .system => .system,
        };
    }

    /// Returns the remembered request as a slice into this record, or null if none.
    /// The slice remains valid for the record's lifetime.
    pub fn source(self: *const SourceRecord) ?LoadSource {
        const text = self.bytes[0..self.len];
        return switch (self.tag) {
            .none => null,
            .path => .{ .path = text },
            .system => .{ .system = text },
        };
    }
};

/// Compares request kind and bytes without normalization.
/// Different spellings such as `./libx.so` and `libx.so` are distinct.
pub fn eqlSource(a: LoadSource, b: LoadSource) bool {
    return switch (a) {
        .path => |pa| switch (b) {
            .path => |pb| std.mem.eql(u8, pa, pb),
            .system => false,
        },
        .system => |sa| switch (b) {
            .system => |sb| std.mem.eql(u8, sa, sb),
            .path => false,
        },
    };
}

fn validateSource(source: LoadSource) LoadError!void {
    const text = switch (source) {
        .path => |p| p,
        .system => |s| s,
    };
    if (text.len == 0) return error.EmptySource;
    if (text.len > max_source_len) return error.SourceTooLong;
    if (std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidSource;
    switch (source) {
        .path => {
            const absolute = if (builtin.target.os.tag == .windows)
                switch (std.Io.Dir.path.getWin32PathType(u8, text)) {
                    .drive_absolute, .unc_absolute, .local_device, .root_local_device => true,
                    .relative, .rooted, .drive_relative => false,
                }
            else
                std.Io.Dir.path.isAbsolutePosix(text);
            if (!absolute) return error.InvalidSource;
        },
        .system => {
            for (text) |byte| {
                if (std.Io.Dir.path.isSep(byte)) return error.InvalidSource;
                if (builtin.target.os.tag == .windows and byte == ':') return error.InvalidSource;
            }
        },
    }
}

/// State of the configured dispatch table.
pub const Phase = enum(u8) {
    /// No successful load is active; failed attempts return here.
    not_loaded = 0,
    /// An attempt is in progress; the table is unpublished.
    loading = 1,
    /// All required symbols are published.
    ready = 2,
};

/// Acquire/release flag that publishes the configured dispatch table.
/// A reader that sees `.ready` also sees the table writes.
pub const Ready = struct {
    phase: std.atomic.Value(u8) = .init(@backingInt(Phase.not_loaded)),

    /// Acquire-loads readiness before a routed call reads the table.
    pub fn isReady(self: *const Ready) bool {
        return self.phase.load(.acquire) == @backingInt(Phase.ready);
    }

    /// Returns the current phase.
    pub fn state(self: *const Ready) Phase {
        return @fromBackingInt(@intCast(self.phase.load(.acquire)));
    }

    /// Publishes the phase with release ordering.
    pub fn set(self: *Ready, value: Phase) void {
        self.phase.store(@backingInt(value), .release);
    }
};

/// Kind of exported symbol stored in the dispatch table.
pub const SymbolKind = enum {
    /// Stores the translated C function-pointer type.
    function,
    /// Stores the exported object's address, never a copy.
    data,
};

/// One required export and its kind.
pub const Symbol = struct {
    /// Exported name as declared by the C header.
    name: [:0]const u8,
    /// Function or data object.
    kind: SymbolKind,
};

/// Panics in every optimization mode when a routed call occurs before publication.
/// Names the library and function to diagnose the ordering error.
pub fn panicNotReady(library: []const u8, comptime symbol: []const u8) noreturn {
    std.debug.panic(
        "{s}: {s} was called before this module was loaded; call " ++
            "load({{ .path = \"...\" }}) or load({{ .system = \"...\" }}) first",
        .{ library, symbol },
    );
}

/// False on WASI, Emscripten, and freestanding targets.
pub const supported_target: bool = switch (builtin.os.tag) {
    .wasi, .emscripten, .freestanding => false,
    else => true,
};

/// Generic process-global loader for one dispatch table.
/// `Config` supplies symbols, assignments, synchronization hooks, and optional validation.
pub fn Loader(comptime Config: type) type {
    return struct {
        const LoaderType = @This();

        /// The configured dispatch table type.
        pub const table_type = Config.table;

        /// In-flight or undrained attempt, retained until all waiters finish.
        attempt: ?Attempt = null,

        /// Owned request copy; immutable after publication and accessed under the lock before readiness.
        request: SourceRecord = .{},

        /// Opens the exact provider request and fills the table only after validation.
        /// Same-request callers share an attempt; changed requests fail and errors permit explicit retry.
        pub fn load(self: *LoaderType, source: LoadSource) LoadError!void {
            try validateSource(source);
            // Published requests need only an acquire check before comparison.
            if (Config.ready().isReady()) return self.accept(source);

            Config.sync.lock();
            while (true) {
                switch (Config.ready().state()) {
                    .ready => {
                        Config.sync.unlock();
                        return self.accept(source);
                    },
                    .loading => {
                        const attempt = &self.attempt.?;
                        if (attempt.owner == Config.sync.threadSelf()) {
                            Config.sync.unlock();
                            return error.ReentrantLoad;
                        }
                        if (!eqlSource(self.request.source().?, source)) {
                            Config.sync.unlock();
                            return error.ProviderMismatch;
                        }
                        // Join the current attempt and receive its result.
                        attempt.waiters += 1;
                        while (Config.ready().state() == .loading) Config.sync.wait();
                        const result = attempt.result;
                        attempt.waiters -= 1;
                        // Keep the attempt record until every attached waiter reads its result.
                        Config.sync.broadcast();
                        Config.sync.unlock();
                        return result;
                    },
                    .not_loaded => {
                        // A retry waits until the prior attempt's waiters drain.
                        if (self.attempt != null) {
                            Config.sync.wait();
                            continue;
                        }
                        break;
                    },
                }
            }

            self.request.set(source);
            self.attempt = .{ .owner = Config.sync.threadSelf() };
            Config.ready().set(.loading);
            Config.sync.unlock();

            // Run provider constructors without the lock; other callers wait on the attempt.
            const outcome = runAttempt(self.request.source().?);
            const succeeded = if (outcome) |_| true else |_| false;

            Config.sync.lock();
            self.attempt.?.result = outcome;
            Config.ready().set(if (succeeded) .ready else .not_loaded);
            // Wake every waiter attached to this attempt.
            Config.sync.broadcast();
            // Release the lock while attached waiters drain.
            while (self.attempt.?.waiters > 0) Config.sync.wait();
            self.attempt = null;
            // Wake callers waiting to retry.
            Config.sync.broadcast();
            Config.sync.unlock();

            return outcome;
        }

        /// Returns null until success, then the retained request for process lifetime.
        pub fn loadedSource(self: *const LoaderType) ?LoadSource {
            if (!Config.ready().isReady()) return null;
            return self.request.source();
        }

        /// Accepts only the already-selected request.
        fn accept(self: *const LoaderType, source: LoadSource) LoadError!void {
            // The acquire load precedes access to the published request.
            const published = self.request.source() orelse unreachable;
            if (eqlSource(published, source)) return;
            return error.ProviderMismatch;
        }

        /// Opens, resolves, and validates a candidate without holding the lock.
        /// Closes the handle unless every step succeeds.
        fn runAttempt(source: LoadSource) LoadError!void {
            const handle = platform.open(source) catch |err| return err;

            var retain = false;
            defer if (!retain) platform.close(handle);

            if (@hasDecl(Config, "optional_symbols")) {
                inline for (Config.optional_symbols, 0..) |_, index| {
                    Config.assignMissing(index, Config.tablePtr());
                }
            }

            inline for (Config.symbols, 0..) |symbol, index| {
                const address = platform.lookup(handle, symbol.name) orelse
                    return error.MissingSymbol;
                Config.assign(index, Config.tablePtr(), address);
            }

            if (@hasDecl(Config, "optional_symbols")) {
                inline for (Config.optional_symbols, 0..) |symbol, index| {
                    if (platform.lookup(handle, symbol.name)) |address| {
                        Config.assignOptional(index, Config.tablePtr(), address);
                    }
                }
            }

            if (@hasDecl(Config, "validate")) {
                if (Config.validate(Config.tablePtr())) |refusal| {
                    // Preserve the validator's refusal reason in the diagnostic.
                    std.debug.print("{s}: refusing this provider: {s}\n", .{
                        Config.library_name,
                        refusal,
                    });
                    return error.ValidationFailed;
                }
            }

            // The table points into this handle, so retain it for process lifetime.
            retain = true;
        }
    };
}

/// One in-flight or undrained load attempt.
const Attempt = struct {
    /// Thread identity used to detect recursive loads.
    owner: u64,
    /// Written under the lock before readiness leaves `.loading`; waiters read it afterward.
    result: LoadError!void = error.OpenFailed,
    /// Waiters not yet finished; the attempt remains until this reaches zero.
    waiters: usize = 0,
};

/// Windows path buffer size in UTF-16 units: 32,767 path units plus a terminator.
/// UTF-8 uses at most one UTF-16 unit per byte.
const windows_path_units = 32768;

const platform = if (builtin.os.tag == .windows)
    Windows
else if (supported_target)
    Unix
else
    NoLoader;

/// Platform stub for targets without a dynamic loader.
const NoLoader = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget };

    fn open(source: LoadSource) OpenError!*anyopaque {
        _ = source;
        return error.UnsupportedTarget;
    }
    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        _ = handle;
        _ = name;
        return null;
    }
    fn close(handle: *anyopaque) void {
        _ = handle;
    }
};

/// Unix dynamic loader using `dlopen`, `dlsym`, and `dlclose`.
const Unix = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget };

    fn open(source: LoadSource) OpenError!*anyopaque {
        const text = switch (source) {
            .path => |p| p,
            .system => |s| s,
        };
        var buffer: [max_source_len + 1]u8 = undefined;
        @memcpy(buffer[0..text.len], text);
        buffer[text.len] = 0;
        // RTLD_NOW reports missing dependencies at load time; RTLD_LOCAL prevents cross-SDK symbol lookup.
        return std.c.dlopen(
            // `dlopen` requires a sentinel-terminated name.
            buffer[0..text.len :0].ptr,
            .{ .NOW = true, .GLOBAL = false },
        ) orelse error.OpenFailed;
    }

    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        return std.c.dlsym(handle, name.ptr);
    }

    fn close(handle: *anyopaque) void {
        _ = std.c.dlclose(handle);
    }
};

/// Local Windows loader bindings, kept behind one platform-specific block.
const kernel32 = struct {
    extern "kernel32" fn LoadLibraryExW(
        file_name: [*:0]const u16,
        file: ?*anyopaque,
        flags: u32,
    ) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn GetProcAddress(module: *anyopaque, name: [*:0]const u8) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn FreeLibrary(module: *anyopaque) callconv(.winapi) i32;
};

/// Windows dynamic loader.
const Windows = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget, SourceTooLong };

    /// Searches standard directories for bare names and uses explicit paths as written; it omits the current directory.
    const load_library_search_default_dirs: u32 = 0x0000_1000;
    const load_library_search_dll_load_dir: u32 = 0x0000_0100;

    fn open(source: LoadSource) OpenError!*anyopaque {
        const text = switch (source) {
            .path => |p| p,
            .system => |s| s,
        };
        if (text.len > windows_path_units) return error.SourceTooLong;
        var buffer: [windows_path_units + 1]u16 = undefined;
        const units = std.unicode.utf8ToUtf16Le(buffer[0..text.len], text) catch
            return error.OpenFailed;
        buffer[units] = 0;
        return kernel32.LoadLibraryExW(
            buffer[0..units :0],
            null,
            load_library_search_default_dirs | switch (source) {
                .path => load_library_search_dll_load_dir,
                .system => @as(u32, 0),
            },
        ) orelse error.OpenFailed;
    }

    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        return kernel32.GetProcAddress(handle, name.ptr);
    }

    fn close(handle: *anyopaque) void {
        _ = kernel32.FreeLibrary(handle);
    }
};
