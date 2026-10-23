// SPDX-License-Identifier: MIT
//
//! Wires translated C declarations to runtime-loaded dispatch and synchronization modules.
//! The runtime facade must not also link the C archive.

const std = @import("std");

/// Prefix shared by `runtime/sync.c` and `runtime/library.zig`; both sides must match.
const sync_prefix = "utf8proc_rt";

/// C-library declarations kept direct instead of resolved from the provider.
/// The union is from Zig 0.16.0's selected libc headers; extra names are ignored, omissions can make loading fail.
/// Keep `utf8proc` exports out of this list.
const libc_noise =
    \\_ASSERTE, _Exit, _LIBC_COUNT, _LIBC_SINGLE_BY_DEFAULT, _LIBC_SIZE,
    \\_MarkAllocaS, _OSSwapInt16, _OSSwapInt32, _OSSwapInt64, _PTQ_HEAD,
    \\_Static_assert, __API_AVAILABLE, __CAST, __DARWIN_OSSwapConstInt16,
    \\__DARWIN_OSSwapConstInt32, __DARWIN_OSSwapConstInt64,
    \\__DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_4,
    \\__DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1,
    \\__DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_2,
    \\__DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_3,
    \\__DEFINE_CPP_OVERLOAD_SECURE_FUNC_2_0,
    \\__DEFINE_CPP_OVERLOAD_SECURE_FUNC_SPLITPATH, __GEN_ENDIAN_DEC,
    \\__GEN_ENDIAN_ENC, __IOS_DEPRECATED, __LDBL_REDIR1_DECL, __NTH,
    \\__OSX_AVAILABLE_STARTING, __OSX_DEPRECATED, __REDIRECT, __REDIRECT_NTH,
    \\__RENAME, __TVOS_DEPRECATED, __WATCHOS_DEPRECATED, ___mb_cur_max,
    \\___mb_cur_max_func, ___mb_cur_max_l, __alloc_size, __alloc_size2, __asm,
    \\__asm__, __attr_access, __attr_dealloc, __attribute__,
    \\__attribute_alloc_align__, __attribute_alloc_size__, __bswap_16,
    \\__bswap_32, __bswap_64, __bswap_constant_16, __bswap_constant_32,
    \\__bswap_constant_64, __builtin_bswap16, __builtin_bswap32,
    \\__builtin_bswap64, __builtin_llabs, __builtin_unreachable, __chk_fail,
    \\__ctype_get_mb_cur_max, __debugbreak, __deprecated_msg, __doserrno,
    \\__fastfail, __fdelt_chk, __fdelt_warn, __fortified_attr_access,
    \\__fortify_clang_overload_arg, __fortify_clang_warning_only_if_bos0_lt2,
    \\__fortify_clang_warning_only_if_bos_lt, __get_environ_ptr,
    \\__get_wenviron_ptr, __glibc_fortify, __glibc_fortify_n, __glibc_objsize,
    \\__isoc23_strtol, __isoc23_strtol_l, __isoc23_strtoll, __isoc23_strtoll_l,
    \\__isoc23_strtoul, __isoc23_strtoul_l, __isoc23_strtoull,
    \\__isoc23_strtoull_l, __mb_cur_max, __mbstowcs_chk, __mbstowcs_nulldst,
    \\__mingw_aligned_free, __mingw_aligned_malloc, __mingw_aligned_msize,
    \\__mingw_aligned_offset_malloc, __mingw_aligned_offset_realloc,
    \\__mingw_aligned_realloc, __mingw_get_crt_info, __mingw_strtod,
    \\__mingw_strtof, __mingw_strtold, __mingw_wcstod, __mingw_wcstof,
    \\__mingw_wcstold, __nonnull, __p___argc, __p___argv, __p___wargv,
    \\__p__amblksiz, __p__environ, __p__fmode, __p__osplatform, __p__osver,
    \\__p__pgmptr, __p__wenviron, __p__winmajor, __p__winminor, __p__winver,
    \\__p__wpgmptr, __prefetch, __printflike, __ptrcheck_abi_assume_single,
    \\__ptsname_r_chk, __qsort_r_compat, __realpath_alias, __realpath_chk,
    \\__realpath_chk_warn, __sized_by_or_null, __ssp_bos, __ssp_check_iovec,
    \\__ssp_overlap, __ssp_redirect, __ssp_redirect_raw_impl, __stack_chk_fail,
    \\__strtod, __swap16md, __swap32md, __swap64md, __swift_unavailable,
    \\__sym_compat, __sys_errlist, __sys_nerr, __threadhandle, __threadid,
    \\__uint16_identity, __uint32_identity, __uint64_identity, __volatile__,
    \\__warnattr, __wcstombs_chk, __wctomb_alias, __wctomb_chk, __zeroll,
    \\__zeroull, _abs64, _aligned_free, _aligned_malloc, _aligned_msize,
    \\_aligned_offset_malloc, _aligned_offset_realloc, _aligned_offset_recalloc,
    \\_aligned_realloc, _aligned_recalloc, _alloca, _atodbl, _atodbl_l, _atof_l,
    \\_atoflt, _atoflt_l, _atoi64, _atoi64_l, _atoi_l, _atol_l, _atoldbl,
    \\_atoldbl_l, _beep, _byteswap_uint64, _byteswap_ulong, _byteswap_ushort,
    \\_dupenv_s, _ecvt, _ecvt_s, _errno, _exit, _expand, _fcvt, _fcvt_s, _freea,
    \\_fullpath, _gcvt, _gcvt_s, _get_amblksiz, _get_doserrno, _get_environ,
    \\_get_errno, _get_fmode, _get_heap_handle, _get_invalid_parameter_handler,
    \\_get_osplatform, _get_osver, _get_pgmptr, _get_purecall_handler,
    \\_get_sbh_threshold, _get_wenviron, _get_winmajor, _get_winminor,
    \\_get_winver, _get_wpgmptr, _heapadd, _heapchk, _heapmin, _heapset,
    \\_heapused, _heapwalk, _i64toa, _i64toa_s, _i64tow, _i64tow_s, _itoa,
    \\_itoa_s, _itow, _itow_s, _lrotl, _lrotr, _ltoa, _ltoa_s, _ltow, _ltow_s,
    \\_makepath, _makepath_s, _mb_cur_max_l, _mblen_l, _mbstowcs_l,
    \\_mbstowcs_s_l, _mbstrlen, _mbstrlen_l, _mbstrnlen, _mbstrnlen_l,
    \\_mbtowc_l, _msize, _onexit, _putenv, _putenv_s, _recalloc, _resetstkoflw,
    \\_rotl, _rotl64, _rotr, _rotr64, _searchenv, _searchenv_s,
    \\_set_abort_behavior, _set_amblksiz, _set_doserrno, _set_errno,
    \\_set_error_mode, _set_fmode, _set_invalid_parameter_handler,
    \\_set_malloc_crt_max_wait, _set_purecall_handler, _set_sbh_threshold,
    \\_seterrormode, _setheaphook, _sleep, _splitpath, _splitpath_s, _strtod_l,
    \\_strtof_l, _strtoi64, _strtoi64_l, _strtol_l, _strtoui64, _strtoui64_l,
    \\_strtoul_l, _swab, _ui64toa, _ui64toa_s, _ui64tow, _ui64tow_s, _ultoa,
    \\_ultoa_s, _ultow, _ultow_s, _wcstod_l, _wcstof_l, _wcstoi64, _wcstoi64_l,
    \\_wcstol_l, _wcstombs_l, _wcstombs_s_l, _wcstoui64, _wcstoui64_l,
    \\_wcstoul_l, _wctomb_l, _wctomb_s_l, _wdupenv_s, _wfullpath, _wgetenv,
    \\_wgetenv_s, _wmakepath, _wmakepath_s, _wperror, _wputenv, _wputenv_s,
    \\_wsearchenv, _wsearchenv_s, _wsplitpath, _wsplitpath_s, _wsystem, _wtof,
    \\_wtof_l, _wtoi, _wtoi64, _wtoi64_l, _wtoi_l, _wtol, _wtol_l, a64l, abort,
    \\abort2, abort_handler_s, abs, aligned_alloc, alloca, arc4random,
    \\arc4random_addrandom, arc4random_buf, arc4random_stir, arc4random_uniform,
    \\at_quick_exit, atexit, atexit_b, atof, atof_l, atoi, atoi_l, atol, atol_l,
    \\atoll, atoll_l, be16dec, be16enc, be32dec, be32enc, be64dec, be64enc,
    \\bsearch, bsearch_b, bsearch_s, bswap16, bswap32, bswap64, call_once,
    \\calloc, calloc_conceal, canonicalize_file_name, cfree, cgetcap, cgetclose,
    \\cgetent, cgetfirst, cgetmatch, cgetnext, cgetnum, cgetset, cgetstr,
    \\cgetusedb, cgetustr, clearenv, csetexpandtc, daemon, daemonfd,
    \\dehumanize_number, devname, devname_r, div, drand48, drand48_r, ecvt,
    \\ecvt_r, erand48, erand48_r, exit, fcvt, fcvt_r, fdevname, fdevname_r,
    \\free, free_aligned_sized, free_sized, freezero, ftruncate, gcvt, getbsize,
    \\getdevmajor, getenv, getenv_r, getenv_s, getiopolicy_np, getloadavg,
    \\getpriority, getprogname, getpt, getrlimit, getrusage, getsubopt, grantpt,
    \\heapsort, heapsort_b, hmac, htonl, htons, humanize_number,
    \\ignore_handler_s, initstate, initstate_r, itoa, jrand48, jrand48_r, l64a,
    \\l64a_r, labs, lcong48, lcong48_deterministic, lcong48_r, ldiv, le16dec,
    \\le16enc, le32dec, le32enc, le64dec, le64enc, llabs, lldiv, lltoa, lltow,
    \\lrand48, lrand48_r, lseek, ltoa, malloc, malloc_conceal,
    \\malloc_type_aligned_alloc, malloc_type_calloc, malloc_type_free,
    \\malloc_type_malloc, malloc_type_posix_memalign, malloc_type_realloc,
    \\malloc_type_valloc, malloc_type_zone_free, mblen, mblen_l, mbstowcs,
    \\mbstowcs_l, mbstowcs_s, mbtowc, mbtowc_l, memalign, memalignment,
    \\mergesort, mergesort_b, mi_vector_hash, mkdtemp, mkdtemps, mkostemp,
    \\mkostemp64, mkostemps, mkostemps64, mkostempsat, mkstemp, mkstemp64,
    \\mkstemps, mkstemps64, mktemp, mrand48, mrand48_r, nrand48, nrand48_r,
    \\ntohl, ntohs, on_exit, onexit, perror, posix_memalign, posix_openpt,
    \\pselect, psort, psort_b, psort_r, ptsname, ptsname_r, putenv, qabs, qdiv,
    \\qecvt, qecvt_r, qfcvt, qfcvt_r, qgcvt, qsort, qsort_b, qsort_r, qsort_s,
    \\quick_exit, radixsort, rand, rand_r, rand_s, random, random_r, realloc,
    \\reallocarr, reallocarray, reallocf, realpath, recallocarray, rpmatch,
    \\secure_getenv, seed48, seed48_deterministic, seed48_r, select,
    \\set_constraint_handler_s, setenv, setiopolicy_np, setkey, setpriority,
    \\setproctitle, setprogname, setrlimit, setstate, setstate_r, shquote,
    \\shquotev, sradixsort, srand, srand48, srand48_deterministic, srand48_r,
    \\srand_deterministic, sranddev, srandom, srandom_deterministic, srandom_r,
    \\srandomdev, strfromd, strfromf, strfromf128, strfromf128x, strfromf16,
    \\strfromf32, strfromf32x, strfromf64, strfromf64x, strfroml, strsuftoll,
    \\strsuftollx, strtod, strtod_l, strtof, strtof128, strtof128_l, strtof128x,
    \\strtof128x_l, strtof16, strtof16_l, strtof32, strtof32_l, strtof32x,
    \\strtof32x_l, strtof64, strtof64_l, strtof64x, strtof64x_l, strtof_l,
    \\strtol, strtol_l, strtold, strtold_l, strtoll, strtoll_l, strtonum,
    \\strtoq, strtoq_l, strtoul, strtoul_l, strtoull, strtoull_l, strtouq,
    \\strtouq_l, swab, system, truncate, ttyslot, uabs, ulabs, ullabs,
    \\ulltoa, ulltow, ultoa, unlockpt, unsetenv, valloc, wait, wait3, wait4,
    \\waitid, waitpid, wcstod, wcstof, wcstol, wcstold, wcstombs, wcstombs_l,
    \\wcstombs_s, wcstoul, wctomb, wctomb_l, wctomb_s, wtoll,
    \\malloc_conf, malloc_message, malloc_type_zone_calloc,
    \\malloc_type_zone_malloc, malloc_type_zone_memalign,
    \\malloc_type_zone_realloc, malloc_type_zone_valloc, signal, suboptarg,
    \\__ptsname_r_alias, __ptsname_r_chk_warn, __mbstowcs_alias,
    \\__mbstowcs_chk_warn, __wcstombs_alias, __wcstombs_chk_warn,
;

/// Provider exports that may be omitted; no utf8proc functions are optional.
const provider_optional = "";

/// Additional names excluded from provider requirements; none for utf8proc.
const provider_excluded = "";

/// Creates the loader-core module shared by the facade and runtime dispatch.
/// Sharing preserves the public `LoadSource` and `LoadError` types across configurations.
pub fn createCoreModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("runtime/loader.zig"),
        .target = target,
        .optimize = optimize,
        // The Unix loader uses `dlopen`, which requires libc.
        .link_libc = true,
    });
}

/// Creates the runtime-loaded `c` module from this target's translation.
/// Its generated declarations match that translation; the native archive is not linked.
pub fn createModule(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const core = createCoreModule(b, target, optimize);

    const library = b.createModule(.{
        .root_source_file = b.path("runtime/library.zig"),
        .target = target,
        .optimize = optimize,
    });
    library.addImport("rt", core);

    return createDispatchModule(b, translate, target, optimize, core, library);
}

const GeneratedSources = struct {
    native: std.Build.LazyPath,
    dispatch: std.Build.LazyPath,
};

fn createDispatchModule(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    core: *std.Build.Module,
    library: *std.Build.Module,
) *std.Build.Module {
    const sources = generateDispatch(b, translate, target);

    const dispatch = b.createModule(.{
        .root_source_file = sources.dispatch,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    dispatch.addImport("rt", core);
    dispatch.addImport("library", library);
    // The patched translation points `__root` at `c_routed`, so nested declarations use routed wrappers and retain translated type identities.
    const native = b.createModule(.{
        .root_source_file = sources.native,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    native.addImport("c_routed", dispatch);
    dispatch.addImport("c_native", native);
    dispatch.addCSourceFiles(.{
        .files = &.{"runtime/sync.c"},
        .flags = &.{b.fmt("-DRT_SYNC_PREFIX={s}", .{sync_prefix})},
        .language = .c,
    });
    return dispatch;
}

/// Runs the host generator over this target's translation output.
/// Each target and C configuration gets its own dispatch.
fn generateDispatch(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
) GeneratedSources {
    const generator = b.addExecutable(.{
        .name = b.fmt("utf8proc-runtime-generate-{s}", .{
            target.result.zigTriple(b.allocator) catch @panic("unspellable target"),
        }),
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtime/generate.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run = b.addRunArtifact(generator);
    run.addArg("--library");
    run.addArg("utf8proc");
    run.addArg("--translate");
    run.addFileArg(translate.getOutput());
    if (libc_noise.len != 0) {
        run.addArg("--noise");
        run.addArg(libc_noise);
    }
    if (provider_optional.len != 0) {
        run.addArg("--optional");
        run.addArg(provider_optional);
    }
    if (provider_excluded.len != 0) {
        run.addArg("--exclude");
        run.addArg(provider_excluded);
    }
    run.addArg("--native-output");
    const native_source = run.addOutputFileArg("native.zig");
    run.addArg("--output");
    const dispatch_source = run.addOutputFileArg("dispatch.zig");
    return .{ .native = native_source, .dispatch = dispatch_source };
}
