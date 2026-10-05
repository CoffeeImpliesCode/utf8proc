# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the utf8proc Zig SDK fork authors
#
# Two package variants of one SDK, both from `./package.nix`. `default` keeps the
# SDK's own linkage policy, which is upstream's: static. No prefixed aliases.
#
# devenv is the canonical development interface (`devenv.nix`, `.envrc`); this
# flake is the portable entry point. `flake.lock` is the driver's — none is
# written here. Never evaluated by the provenance role; every gate is the
# driver's.

{
  description = "utf8proc — Unicode normalization, case-folding and grapheme segmentation, as a standalone Zig SDK";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      devTools = pkgs: with pkgs; [ zig_0_16 pkg-config gnumake ];
    in
    {
      # The source filter lives in package.nix. `self` is deliberately not the
      # source: a flake reference carries only committed files, so it would
      # compile something other than the tree standing here.
      packages = forAllSystems (
        pkgs:
        let
          mk = linkage: pkgs.callPackage ./package.nix {
            zig = pkgs.zig_0_16;
            inherit linkage;
          };
        in
        {
          static = mk "static";
          shared = mk "dynamic";
          # static is this SDK's own linkage policy.
          default = mk "static";
        }
      );

      # Tools only: entering a shell must not build the library.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell { packages = devTools pkgs; };
      });
    };
}