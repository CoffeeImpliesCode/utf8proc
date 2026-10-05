# SPDX-License-Identifier: MIT
# Copyright (c) 2026 the utf8proc Zig SDK fork authors
#
# The canonical development shell for this SDK: tools only, plus the two package
# variants as lazy `outputs`. `devenv build outputs.static` and
# `devenv build outputs.shared` are the packaging route; entering the shell
# builds nothing.
#
# Every script below locates this SDK itself. devenv materialises a script as a
# generated program that inherits the caller's working directory, and the
# canonical caller is `devenv shell -- <name>` from a project directory that is
# not this checkout: there is no `build.zig`, no `consumer/` and no
# `UPSTREAM.sha256` there for a relative path to find.
#
# Cache locations are the caller's business: this file never unsets
# ZIG_GLOBAL_CACHE_DIR, ZIG_LOCAL_CACHE_DIR, TMPDIR, XDG_RUNTIME_DIR or
# DEVENV_HOME, and names no host path. A value the caller exported wins
# unchanged; a missing one is filled in each script body from XDG_CACHE_HOME,
# then TMPDIR, and a caller who named none of the three stops before the
# compiler. That is what keeps sdk-build installing beneath
# $ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out and keeps every build out of this
# checkout's own .zig-cache. Never run by the provenance role; every gate is the
# driver's.

{ pkgs, lib, ... }:

let
  # The source filter lives in package.nix, which owns the package's inputs;
  # carrying a second copy here is the way two trees drift apart.
  sdk = linkage: pkgs.callPackage ./package.nix {
    zig = pkgs.zig_0_16;
    inherit linkage;
  };

  # Never `zig fmt` an upstream file: that would rewrite upstream's bytes.
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

  # This SDK's own directory, quoted once for a shell. `./.` in an expression is
  # relative to the file that contains it, so it is this SDK and not whichever
  # directory the caller happened to be in; `lib.escapeShellArg` so a checkout
  # whose path carries a space or a quote still works. `builtins.toString`, and
  # not a path literal: interpolating `${./.}` hands the generated program a
  # path with a store context, Nix then copies this whole tree into the
  # read-only store, and a build that wrote there could not.
  sdkRoot = lib.escapeShellArg (builtins.toString ./.);

  # The first line of every exec body below, so no two scripts can drift on it.
  inSdkRoot = "cd ${sdkRoot} || exit 1\n";

  # Where `sdk-build` installs: beneath the `ZIG_LOCAL_CACHE_DIR` the caller
  # exported, never `zig-out/` inside this checkout. This repository is the
  # working tree `UPSTREAM.sha256` and the driver's source digest cover, and a
  # delivery prefix is build output that does not belong in it.
  deliveryPrefix = "$ZIG_LOCAL_CACHE_DIR/utf8proc/zig-out";

  # The build cache every `zig build` below writes to: this SDK's own
  # subdirectory of the local cache the caller named, under the same `utf8proc`
  # name `deliveryPrefix` already carries. `--cache-dir` is explicit on every
  # build because Zig's own default is `.zig-cache` inside this checkout, which
  # is the working tree the driver's source digest covers.
  localCacheDir = "$ZIG_LOCAL_CACHE_DIR/utf8proc";

  # The cache half of every build preamble. It is in the body and not only in
  # `enterShell` because a devenv script is a program that inherits the caller's
  # environment, so nothing the shell hook exported is guaranteed to be set when
  # a body starts. A value the caller exported is used unchanged; only a missing
  # one is filled, from `XDG_CACHE_HOME` first and `TMPDIR` second — the order
  # and the directory names `box2d`, `geographiclib-c` and `libunibreak` already
  # use. No fallback is a literal `/tmp`, a `/var/tmp`, an NFS mount or a path
  # inside this repository.
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

  # The refusal, standing where the compiler would have been reached: with both
  # variables still empty there is nowhere outside this checkout to build, so
  # the body stops instead of letting Zig write `.zig-cache` into a tree the
  # driver digests. `enterShell` reports the same two states without stopping.
  requireCaches = ''
    if [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ] || [ -z "''${ZIG_GLOBAL_CACHE_DIR:-}" ]; then
      echo "utf8proc: ZIG_LOCAL_CACHE_DIR and ZIG_GLOBAL_CACHE_DIR are unset and" >&2
      echo "neither XDG_CACHE_HOME nor TMPDIR names a location, so no cache" >&2
      echo "outside this checkout is known. Export them at an approved mount." >&2
      exit 1
    fi
  '';

  # What all seven `zig build` bodies below share, so no two of them can drift:
  # this workspace's job count, both cache directories named explicitly, and the
  # step list the receipts are read against. `sdk-build` adds its own
  # `--prefix`; the other six steps install nothing, so a prefix there would be
  # a flag that changes nothing.
  zigBuildFlags = "--cache-dir \"${localCacheDir}\" --global-cache-dir \"$ZIG_GLOBAL_CACHE_DIR\" -j8 --summary all";

  # Self-location and both caches, in that order, before any compiler runs.
  buildPreamble = inSdkRoot + fillCaches + requireCaches;
in
{
  packages = [
    pkgs.zig_0_16
    pkgs.pkg-config
    pkgs.gnumake
  ];

  assertions = [
    {
      assertion = pkgs.zig_0_16.version == "0.16.0";
      message = "utf8proc: this SDK is written against Zig 0.16.0 (pkgs.zig_0_16).";
    }
  ];

  outputs = {
    static = sdk "static";
    shared = sdk "dynamic";
    # The SDK's own linkage policy, unchanged.
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
    # The default step is the install step, so this is the one script that
    # writes a delivery: `include/utf8proc.h`, the library, the records and the
    # fixtures under `share/`, and `lib/pkgconfig/libutf8proc.pc`. Its prefix is
    # the caller's, below the cache directory the caller exported.
    sdk-build = {
      description = "Build the library and compile the proofs; install under $ZIG_LOCAL_CACHE_DIR";
      exec = ''
        ${buildPreamble}
        zig build --prefix "${deliveryPrefix}" ${zigBuildFlags}
      '';
    };

    # None of the five below depends on the install step: they compile, run or
    # check, and build.zig keeps the smoke and exercise programs out of the
    # installed prefix on purpose, so a prefix here would be a flag that changes
    # nothing.
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

    # `zig build consumer` is the command that belongs here and `cd consumer`
    # is not: `runConsumer` in build.zig runs the nested `zig build run` with
    # `setCwd(b.path("consumer"))`, which is relative to this build root, and
    # forwards this run's target query, cpu, optimize, linkage and runtime
    # selection. It reads `b.cache_root.path` and `b.graph.global_cache_root.path`,
    # both optional captures, so the explicit `--cache-dir` and
    # `--global-cache-dir` below are what make the nested run take this build's
    # own cache subdirectory rather than a default inside this checkout. That
    # nested step depends on the executable alone — `consumer/build.zig` puts the
    # artifact on the install step and `run` on the run step — so no delivery
    # prefix applies to this script and it gains no flag that changes nothing.
    sdk-consumer = {
      description = "Build and run the independent path-dependent consumer package";
      exec = ''
        ${buildPreamble}
        zig build consumer ${zigBuildFlags}
      '';
    };

    # The record's 56 paths are relative to this SDK (`utf8proc.c`,
    # `testdata/NormalizationTest.txt`, `test/…`), so the check has to run with
    # this directory as its working directory; `sha256sum -c` resolves each
    # name against the current directory and has no option to root itself
    # elsewhere.
    sdk-integrity = {
      description = "Check the carried upstream and fixture bytes against UPSTREAM.sha256";
      exec = ''
        ${inSdkRoot}
        sha256sum -c UPSTREAM.sha256
      '';
    };

    # Relative paths, so this one needs the same first line as the rest.
    sdk-format = {
      description = "Format this SDK's own Zig and ZON files, never upstream's";
      exec = ''
        ${inSdkRoot}
        zig fmt ${lib.concatStringsSep " " forkZigFiles}
      '';
    };
  };
}