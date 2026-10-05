# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the utf8proc Zig SDK fork authors
#
# One source-only derivation, uncurried, with `lib`/`stdenv`/`zig` injected and
# `linkage` selecting the variant. Variants are named by the entry points
# (flake.nix's `.static`/`.shared`, devenv's `outputs.static`/`outputs.shared`),
# never by this file.
#
# It adds nothing to the installed closure. `build.zig` owns it: the library, the
# header, `LICENSE.md`, `lib/pkgconfig/libutf8proc.pc`, the licence and provenance
# records under `share/licenses/utf8proc/` and the Unicode fixtures under
# `share/utf8proc/testdata/` are all written by the build graph, and a packaging
# script that reproduced any of them would be a second writer for one output path.
# Never evaluated or built by the provenance role; every gate is the driver's.

{ lib
, stdenv
, zig
, linkage ? "static"
}:

assert lib.assertMsg (lib.elem linkage [ "static" "dynamic" ])
  "utf8proc: linkage must be \"static\" or \"dynamic\", got \"${linkage}\"";

let
  # The one source filter for this SDK: caches, outputs, VCS metadata and
  # developer state out of the build input, everything else - every source,
  # fixture, test and licence file - in. Matched on the basename, so it holds at
  # any depth. Both entry points call this file and inherit it; neither carries
  # a second copy.
  src = lib.cleanSourceWith {
    src = ./.;
    name = "utf8proc-source";
    filter = path: _type:
      let name = baseNameOf (toString path);
      in !(builtins.elem name [
        ".git"
        ".jj"
        ".zig-cache"
        "zig-cache"
        "zig-out"
        "zig-pkg"
        ".devenv"
        ".devenv.flake.nix"
        "devenv.local.nix"
        ".direnv"
      ])
      && name != "result"
      && !(lib.hasPrefix "result-" name);
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "utf8proc";
  version = "2.12.0";
  inherit src;

  strictDeps = true;
  nativeBuildInputs = [ zig ];

  # The Zig setup hook would contribute its own phases. `build.zig` is the whole
  # build and its default step is the install step, so only install runs here.
  # `dontInstall` would disable the installPhase below.
  dontConfigure = true;
  dontBuild = true;
  doCheck = false;
  # Without this the Zig setup hook substitutes its own `zig build test` for the
  # check phase, which is a second, differently-flagged build of the same tree.
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    # `src` is read-only in the sandbox, so the caches cannot live in the tree.
    # No fallback: the sandbox provides TMPDIR, and a derivation that quietly
    # reached for /tmp would build where this package's storage policy says it
    # must not. TMPDIR is resolved through `readlink -f` so the cache paths are
    # canonical, which keeps the cache keyed by one path rather than by whichever
    # symlink this build happened to arrive through.
    if [ -z "''${TMPDIR:-}" ]; then
      echo "utf8proc: TMPDIR is unset; the sandbox must provide it." >&2
      exit 1
    fi
    zig_cache_root="$(readlink -f "$TMPDIR")"
    export ZIG_LOCAL_CACHE_DIR="$zig_cache_root/zig-local-cache"
    export ZIG_GLOBAL_CACHE_DIR="$zig_cache_root/zig-global-cache"

    zig build \
      --prefix "$out" \
      -j"''${NIX_BUILD_CORES:-1}" \
      -Dcpu=baseline \
      -Doptimize=ReleaseSafe \
      -Dlinkage=${linkage} \
      --summary all

    runHook postInstall
  '';

  passthru = {
    inherit linkage;

    # `build.zig` installs the artifact under the name `artifactName` gives the
    # public build; a shared object additionally carries upstream's own ABI
    # version, `libutf8proc.so.3.3.0` with soname `libutf8proc.so.3`.
    installedLibrary =
      if linkage == "static" then "lib/libutf8proc.a" else "lib/libutf8proc.so";

    # libc is the only link-time requirement and every consumer already has it.
    propagatedBuildInputs = [ ];
  };

  meta = {
    description = "Unicode normalization, case-folding and grapheme segmentation, built from source by this SDK";
    license = lib.licenses.mit;
    licenseFile = ./LICENSE.md;
    platforms = lib.platforms.unix;
  };
})