#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Defaults for cross-test.
# The harness owns the published 53-platform Zig 0.16.0 Tier 1/2 matrix and runner policy.
# No linkage override: build.zig's static default is used.
# Set CROSS_LIBC_RUNTIMES externally when foreign libc loaders are needed.
CROSS_BUILD_STEP=test

# Limit each target build to four Zig compile jobs.
CROSS_BUILD_JOBS=4

# Timeout for compiling and running one target test step (seconds).
CROSS_BUILD_TIMEOUT=3600

# Timeout for one test binary (seconds); tests use full Unicode corpora.
CROSS_TIMEOUT=1800