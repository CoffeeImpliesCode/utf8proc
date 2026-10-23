# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the utf8proc Zig SDK fork authors
# Static and shared outputs use package.nix; static is the default.

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
      # Use package.nix's source filter for both variants.
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
          default = mk "static";
        }
      );

      # The development shell adds tools without building the package.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell { packages = devTools pkgs; };
      });
    };
}