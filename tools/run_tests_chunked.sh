#!/usr/bin/env bash
# run_tests_chunked.sh — disk-safe fast-suite runner for small/disposable
# cloud agents.
#
# Problem: a single `dart test test` invocation compiles the ENTIRE test
# tree's kernel into one cache that grows to ~6.5 GB
# (.dart_tool/test/incremental_kernel.* plus per-process
# $TMPDIR/dart_test.kernel.* / /tmp/dart_test.kernel.* dirs). On a ~10 GB
# disk that exhausts space and the run dies.
#
# Fix: run the FAST suite (dart_test.yaml already excludes `slow`; we also
# drop `flutter`-tagged tests, which need the Flutter SDK) ONE FOLDER AT A
# TIME, clearing the Dart kernel caches between chunks so peak disk stays
# bounded to a single chunk's kernel (a few hundred MB) instead of the
# whole tree.
#
# Heavy folders (test/plugins, test/core, ...) are recursed into subfolders
# so no single chunk's kernel can blow the budget.
#
# This deliberately does NOT run --preset=all (regression/integration/
# property/benchmark): those spawn temp projects that run `dart pub get` +
# `build_runner` and fill several GB under /tmp — never use them on small
# agents (see dart_test.yaml header).
#
# Usage:
#   tools/run_tests_chunked.sh            # run the whole fast suite, chunked
#   DRY_RUN=1 tools/run_tests_chunked.sh  # just print the chunk list, exit 0
#
# Exit code: non-zero if any chunk fails.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

THRESHOLD=40   # a folder with more test files than this is split into subfolders

clean_kernel() {
  # Persistent incremental-compile cache (the big one).
  rm -rf .dart_tool/test/incremental_kernel.* 2>/dev/null || true
  # Per-process kernel dirs created by the test runner (see tools/run-tdd-tests.sh).
  if [ -n "${TMPDIR:-}" ]; then
    rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null || true
  fi
  rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true
}

# Recursively emit test directories, splitting any dir heavier than THRESHOLD
# into its subfolders. Directories with no test files are skipped.
emit_chunks() {
  local dir="$1"
  local count
  count=$(find "$dir" -name '*_test.dart' | wc -l)
  if [ "$count" -eq 0 ]; then
    return
  fi
  if [ "$count" -gt "$THRESHOLD" ]; then
    local sub
    while IFS= read -r sub; do
      [ -d "$sub" ] && emit_chunks "$sub"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d | sort)
  else
    echo "$dir"
  fi
}

# Build the chunk list from every top-level folder under test/.
CHUNKS=""
while IFS= read -r d; do
  CHUNKS+="$d"$'\n'
done < <(find test -mindepth 1 -maxdepth 1 -type d | sort | while read -r d; do emit_chunks "$d"; done)

if [ "${DRY_RUN:-}" = "1" ]; then
  echo "Chunks (threshold=${THRESHOLD}):"
  printf '%s\n' "$CHUNKS"
  exit 0
fi

# Ensure a package config exists for the runner.
dart pub get >/dev/null 2>&1 || true

clean_kernel
fail=0
while IFS= read -r d; do
  [ -z "$d" ] && continue
  echo "=== chunk: $d ==="
  dart test "$d" --exclude-tags flutter || fail=1
  clean_kernel
done <<< "$CHUNKS"

if [ "$fail" -ne 0 ]; then
  echo "FAIL: one or more chunks failed."
  exit 1
fi
echo "OK: all chunks passed."
