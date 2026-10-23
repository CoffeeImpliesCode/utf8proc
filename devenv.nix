# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the utf8proc Zig SDK fork authors
# Tools-only shell with lazy static/shared package outputs.
# Scripts locate the checkout and respect caller cache paths.

{ pkgs, lib, ... }:

let
  # Reuse package.nix's source filter.
  sdk = linkage: pkgs.callPackage ./package.nix {
    zig = pkgs.zig_0_17;
    inherit linkage;
  };

  # Format fork-owned Zig files only.
  forkZigFiles = [
    "build.zig"
    "build.zig.zon"
    "tests.zig"
    "smoke.zig"
    "zig/root.zig"
    "zig/api_exercise.zig"
    "consumer/build.zig"
    "consumer/build.zig.zon"
    "consumer/src/main.zig"
  ];

  # Resolve this checkout for scripts run from other directories.
  sdkRoot = lib.escapeShellArg (builtins.toString ./.);

  # Change to the SDK root at each script's start.
  inSdkRoot = "cd ${sdkRoot} || exit 1\n";

  # Install under ZIG_LOCAL_CACHE_DIR.
  deliveryPrefix = "$ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out";

  # Keep Zig's local build cache under ZIG_LOCAL_CACHE_DIR.
  localCacheDir = "$ZIG_LOCAL_CACHE_DIR/utf8proc";

  # Fill unset cache roots from XDG_CACHE_HOME, then TMPDIR.
  fillCaches = ''
    if [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        ZIG_LOCAL_CACHE_DIR="''${XDG_CACHE_HOME}/zig-local-cache"
        export ZIG_LOCAL_CACHE_DIR
      elif [ -n "''${TMPDIR:-}" ]; then
        ZIG_LOCAL_CACHE_DIR="''${TMPDIR}/zig-local-cache"
        export ZIG_LOCAL_CACHE_DIR
      fi
    fi
    if [ -z "''${ZIG_GLOBAL_CACHE_DIR:-}" ]; then
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        ZIG_GLOBAL_CACHE_DIR="''${XDG_CACHE_HOME}/zig-global-cache"
        export ZIG_GLOBAL_CACHE_DIR
      elif [ -n "''${TMPDIR:-}" ]; then
        ZIG_GLOBAL_CACHE_DIR="''${TMPDIR}/zig-global-cache"
        export ZIG_GLOBAL_CACHE_DIR
      fi
    fi
  '';

  # Require cache roots before invoking Zig.
  requireCaches = ''
    if [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ] || [ -z "''${ZIG_GLOBAL_CACHE_DIR:-}" ]; then
      echo "utf8proc: ZIG_LOCAL_CACHE_DIR and ZIG_GLOBAL_CACHE_DIR are unset and" >&2
      echo "neither XDG_CACHE_HOME nor TMPDIR names a location, so no cache" >&2
      echo "outside this checkout is known. Export them at an approved mount." >&2
      exit 1
    fi
  '';

  # Shared cache flags for every Zig build script.
  zigBuildFlags = "--cache-dir \"${localCacheDir}\" --global-cache-dir \"$ZIG_GLOBAL_CACHE_DIR\" -j8 --summary all";

  # Set the root and cache environment before each build.
  buildPreamble = inSdkRoot + fillCaches + requireCaches;
in
{
  packages = [
    pkgs.zig_0_17
    pkgs.pkg-config
    pkgs.gnumake
  ];

  assertions = [
    {
      assertion = pkgs.zig_0_17.version == "0.17.0";
      message = "utf8proc: this SDK is written against Zig 0.17.0 (pkgs.zig_0_17).";
    }
  ];

  outputs = {
    static = sdk "static";
    shared = sdk "dynamic";
    # Keep static as the default linkage.
    default = sdk "static";
  };

  enterShell = ''
    ${fillCaches}
    echo "utf8proc SDK — Zig $(zig version), libutf8proc 2.12.0, Unicode 18.0.0"
    echo "  scripts: sdk-build sdk-test sdk-smoke sdk-exercise sdk-check"
    echo "           sdk-upstream-test sdk-consumer sdk-integrity sdk-format"
    echo "  every script locates this SDK itself, so the directory you ran"
    echo "  devenv from does not matter; sdk-build installs under"
    if [ -n "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      echo "           $ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out, never into the checkout"
    else
      echo "           nothing yet: export ZIG_LOCAL_CACHE_DIR, or XDG_CACHE_HOME"
      echo "           or TMPDIR, and every build refuses to run until one names a"
      echo "           location outside this checkout"
    fi
    echo "  packages: devenv build outputs.static | devenv build outputs.shared"
  '';

  scripts = {
    # Install under the caller's cache prefix.
    sdk-build = {
      description = "Build the library and compile the proofs; install under $ZIG_LOCAL_CACHE_DIR";
      exec = ''
        ${buildPreamble}
        zig build --prefix "${deliveryPrefix}" ${zigBuildFlags}
      '';
    };

    # Test and check scripts do not install the package.
    sdk-test = {
      description = "Run the behavioural tests and the API exercise";
      exec = ''
        ${buildPreamble}
        zig build test ${zigBuildFlags}
      '';
    };

    sdk-smoke = {
      description = "Run the smoke program";
      exec = ''
        ${buildPreamble}
        zig build smoke ${zigBuildFlags}
      '';
    };

    sdk-exercise = {
      description = "Run the API exercise: every public facade operation, called";
      exec = ''
        ${buildPreamble}
        zig build exercise ${zigBuildFlags}
      '';
    };

    sdk-check = {
      description = "Compile everything for every selected target, without running it";
      exec = ''
        ${buildPreamble}
        zig build check ${zigBuildFlags}
      '';
    };

    sdk-upstream-test = {
      description = "Build and run upstream's own C test programs against this library";
      exec = ''
        ${buildPreamble}
        zig build upstream-test ${zigBuildFlags}
      '';
    };

    # Forward options and cache paths to the separate consumer build.
    sdk-consumer = {
      description = "Build and run the independent path-dependent consumer package";
      exec = ''
        ${buildPreamble}
        zig build consumer ${zigBuildFlags}
      '';
    };

    # Run checksum verification from the package root.
    sdk-integrity = {
      description = "Check the carried upstream and fixture bytes against UPSTREAM.sha256";
      exec = ''
        ${inSdkRoot}
        sha256sum -c UPSTREAM.sha256
      '';
    };

    # Format fork-owned files from the package root.
    sdk-format = {
      description = "Format this SDK's own Zig and ZON files, never upstream's";
      exec = ''
        ${inSdkRoot}
        zig fmt ${lib.concatStringsSep " " forkZigFiles}
      '';
    };
  };
}