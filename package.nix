# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the utf8proc Zig SDK fork authors
# Source-only derivation; build.zig installs every output.

{ lib
, stdenv
, zig
, linkage ? "static"
}:

assert lib.assertMsg (lib.elem linkage [ "static" "dynamic" ])
  "utf8proc: linkage must be \"static\" or \"dynamic\", got \"${linkage}\"";

let
  # Exclude caches and outputs from the source closure.
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

  # Let build.zig own configuration, build and install.
  dontConfigure = true;
  dontBuild = true;
  doCheck = false;
  # Disable the setup hook's duplicate test build.
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    # Store Zig caches under the sandbox-provided TMPDIR.
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

    # Shared output keeps upstream ABI version 3.3.0.
    installedLibrary =
      if linkage == "static" then "lib/libutf8proc.a" else "lib/libutf8proc.so";

    # No propagated link-time dependencies.
    propagatedBuildInputs = [ ];
  };

  meta = {
    description = "Unicode normalization, case-folding and grapheme segmentation, built from source by this SDK";
    license = lib.licenses.mit;
    licenseFile = ./LICENSE.md;
    platforms = lib.platforms.unix;
  };
})