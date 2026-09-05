#!/usr/bin/env bash
# run-theater-tests.sh — mutation-test wrapper for the spec-1006 theater
# files (the run-tdd-tests.sh pattern): cleans leaked per-process kernel
# dirs, runs the theater scope serialized (-j 1, the issue #506 flake
# guard). Exit code: dart test's exit code.
set -u
if [ -n "${TMPDIR:-}" ]; then
  rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null || true
fi
rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true
exec dart test test/plugins/tdd/theater/ test/plugins/tdd/commands/theater_command_test.dart -j 1
