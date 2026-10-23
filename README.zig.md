# Zig facade API

## Types

| Type | Contract |
|---|---|
| `Status`, `Option` | C signed status/count type and `unsigned int` option word. |
| `Category`, `BidiClass`, `DecompType`, `BoundClass`, `IndicConjunctBreak` | Upstream Unicode enums; the latter four have no typed facade accessors. |
| `Property` | Opaque pointer to an upstream property record. C bit-fields prevent field access from Zig. |
| `Options` | Packed `u32`; fields are `nullterm`, `stable`, `compat`, `compose`, `decompose`, `ignore`, `rejectna`, `nlf2ls`, `nlf2ps`, `stripcc`, `casefold`, `charbound`, `lump`, `stripmark`, `stripna`, and `reserved: u17`. |
| `Decoded` | `{ bytes_read: usize, codepoint: u21 }`; decoded values are Unicode scalars. |
| `Encoded` | `.bytes: u3` or `.rejected`; `.bytes == 3` does not prove scalar validity. |
| `DecomposeResult` | `.written` or `.needs_more`; the latter reports required capacity and leaves `dst` undefined. |
| `Error` | `OutOfMemory`, `Overflow`, `InvalidUtf8`, `NotAssigned`, `InvalidOptions`, `InputOutputOverlap`. |
| `ReencodeError` | `Error` plus `WorkspaceTooSmall`. |
| `ShortcutError` | `NoResult`; normalization shortcuts cannot distinguish invalid UTF-8 from allocation failure. |
| `CustomFunc` | Optional C-callconv callback `(i32, ?*anyopaque) i32`; `data` is borrowed for the call. |
| `OwnedString` | C-allocated result with `bytes()` and `deinit()`; release exactly once through `deinit`. |
| `GraphemeIterator` | Stateful UAX #29 iterator; feed every adjacent pair in order. |

`Options` fields default to `false`. `nlf2lf` combines `nlf2ls` and `nlf2ps`; `toBits()` and `fromBits()` preserve unknown bits. Upstream ignores unimplemented flags. `nullterm` is rejected by slice APIs, and `stable` has no effect in this core.

| Flags | Entry points that honor them |
|---|---|
| `compat`, `decompose`, `ignore`, `rejectna`, `casefold`, `lump`, `stripna` | `decomposeChar`, `decompose*`, `map*` |
| `compose` | `decomposeChar`, `decompose*`, `normalizeUtf32`, `reencode`, `map*` |
| `nlf2ls`, `nlf2ps` | `decompose*`, `normalizeUtf32`, `reencode`, `map*`; `decomposeChar` also uses them with `lump` and the paired NLF flag |
| `stripcc` | `normalizeUtf32`, `reencode`, `map*`; not `decompose*` |
| `charbound` | `decomposeChar`, `decompose*`, `reencode`, `map*` |
| `stripmark` | `decomposeChar`; `decompose*` and `map*` require `compose` or `decompose` |

Here `decompose*` means `decompose` and `decomposeCustom`; `map*` means `map` and `mapCustom`. Upstream also rejects `compose` with `decompose` and `stripmark` without either.

## Functions

| Function | Result or behavior |
|---|---|
| `version()`, `unicodeVersion()`, `errorMessage(status)` | NUL-terminated slices. |
| `decode(bytes)` | `Error!?Decoded`; `null` for empty input, `InvalidUtf8` for malformed input. |
| `codepointValid(cp)` | Whether `cp` is a valid Unicode scalar, whether assigned or not. |
| `encodeChar(cp, out)` | Writes up to four bytes; upstream encodes surrogates rather than rejecting them. |
| `property(cp)`, `category(cp)`, `categoryString(cp)` | Property handle, general category, and two-letter category name. |
| `charWidth(cp)`, `charWidthAmbiguous(cp)` | Width and East Asian ambiguous-width property; `charWidth` returns `0` for non-printable codepoints. |
| `toLower/Upper/Title(cp)`, `isLower/Upper(cp)` | Simple one-codepoint mappings and lowercase/uppercase predicates; use `casefold` for full folding. |
| `utf8ClassTable()`, `utf8Class(byte)` | Upstream's 256-entry lead-byte table and the expected sequence length for one byte; not UTF-8 validation. |
| `decomposeChar(cp, dst, options, last_boundclass)` | Decomposes one codepoint; does not compose. CHARBOUND requires a state pointer. |
| `decomposeCount(str, options)` | Required codepoint capacity for a decomposition; allocates nothing. |
| `decompose(str, dst, options)`, `decomposeCustom(...)` | Caller-buffer decomposition; input and output byte ranges must not overlap. |
| `normalizeUtf32(codepoints, options)` | Normalizes in place and returns the result length; does not validate codepoints. |
| `reencode(workspace, length, options)` | Converts in place from UTF-32 to UTF-8 and returns the byte length. |
| `graphemeBreak(previous, current)` | Legacy stateless Unicode 8 pair test; use `GraphemeIterator` for extended grapheme clusters. |
| `GraphemeIterator.reset()`, `.next(previous, current)` | Reset state or test the next adjacent pair. |
| `firstGraphemeBreak(codepoints)` | Index of the first break, or `null`; checks pairs with a stateful iterator. |
| `map(str, options)`, `mapCustom(...)` | Allocating mapping; return `Error!OwnedString` using upstream's allocator. |
| `nfd`, `nfc`, `nfkd`, `nfkc`, `nfkcCasefold` | NUL-terminated normalization shortcuts; return `ShortcutError!OwnedString`. |
| `load(source)`, `loadedSource()` | Runtime-loader API; see below. |

## Buffer and ownership rules

- Size a `decompose` buffer with `decomposeCount`. On `.needs_more`, do not read `dst`.
- `normalizeUtf32` passes invalid codepoints through. Call `codepointValid` first when input validity is required.
- `reencode` requires a 4-byte-aligned workspace holding `length` native-endian `i32` values and at least `4 * length + 1` bytes. It writes a NUL after the UTF-8 result; insufficient space returns `WorkspaceTooSmall` before writing.
- CHARBOUND uses `-1` in UTF-32 and emits `0xFF` in UTF-8. That output is not valid UTF-8.
- `map` and `mapCustom` allocate with the library's C allocator. `OwnedString.deinit()` calls `utf8proc_free`; do not free it with a Zig allocator or `std.mem.free`.
- `mapCustom` may call its callback twice, to size and fill the result. The callback must be deterministic and return a valid codepoint; `data` is borrowed until the call returns.
- `Error.Overflow` includes input lengths that do not fit the C signed length type. `InputOutputOverlap` is returned before decomposition writes to `dst`.

## Runtime loading

`runtime_loaded` is a comptime `bool`. In a runtime-loaded build, `LoadSource.path` names a file and `LoadSource.system` names a library for the platform loader. Call `load(source)` before using the facade; `loadedSource()` returns the successful request or `null`. The same request is idempotent; a different request after success returns `ProviderMismatch`. There is no unload or reset. In a linked build, `load` panics.

A runtime provider must match the facade's ABI and Unicode data revision. `OwnedString` must be released through the same provider that allocated it.
