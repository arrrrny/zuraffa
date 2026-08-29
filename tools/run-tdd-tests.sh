#!/usr/bin/env bash
# run-tdd-tests.sh — test runner invoked by `mutation-test.xml`.
#
# Why a wrapper script (not `bash -c "..."` inline in the XML):
#   The `mutation_test` Dart package parses <command> elements by splitting
#   on whitespace (see mutation_test-1.8.0/lib/src/configuration/
#   configuration.dart `_addCommand`). It does NOT honor shell quotes,
#   so `bash -c "rm -rf \"$TMPDIR\"/dart_test.kernel.* ..."` would be
#   tokenized as `["bash", "-c", "\"rm", "-rf", ...]` and bash would
#   error with "unexpected EOF while looking for matching quote".
#
#   By pointing the config at this script instead, mutation_test runs
#   `bash tools/run-tdd-tests.sh` with zero args and bash interprets the
#   script body normally — quotes, redirects, and variable expansion all
#   work as expected.
#
# What this script does:
#   1. Cleans leftover `$TMPDIR/dart_test.kernel.*` directories from prior
#      runs. Each `dart test` invocation creates one such dir per process;
#      the dart test runner does NOT reliably clean them up on exit
#      (issue filed upstream). Without this cleanup the rootfs fills up
#      after ~6 mutants and every subsequent mutant is miscategorized as
#      "NotCovered" — the audit becomes corrupt.
#   2. Runs `dart test` against the TDD test scope (writers + plugin +
#      tdd_command aggregator + setup_command) with `-j 1` to avoid the
#      parallel-test CWD-cascade flake (issue #506).
#
# We deliberately DO NOT delete `.dart_tool/test/incremental_kernel*`:
#   that is the persistent incremental-compile cache. Removing it forces
#   every mutant to recompile all ~133 transitive library dills from
#   scratch (~8.5GB of tmp + ~50s per mutant vs. the ~11s incremental
#   baseline).
#
# Exit code: dart test's exit code (0 = pass, non-zero = fail).
# Used by: mutation-test.xml <command> element.
set -u

# Clean stale kernel caches (best-effort; ignore failures from concurrent mutants).
if [ -n "${TMPDIR:-}" ]; then
  rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null || true
fi
# Also clean the system /tmp variant — dart falls back to /tmp when TMPDIR
# is not honored by the test runner's isolate-spawn path.
rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true

# Run the TDD-scoped test suite. -j 1 serializes within a single mutant.
exec dart test test/cli/writers/tdd/ test/plugins/tdd/ test/commands/setup_command_test.dart -j 1
