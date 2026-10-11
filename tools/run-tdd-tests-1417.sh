#!/usr/bin/env bash
# run-tdd-tests-1417.sh — test runner invoked by `mutation-test-1417.xml`.
#
# Same wrapper pattern as tools/run-tdd-tests.sh (the mutation_test package
# splits <command> text on whitespace and does NOT honor shell quotes), with
# the issue-#1417 scope: the in-process `SpeckitScaffoldingWriter unit` group
# of test/commands/initialize_speckit_test.dart.
#
# Scope rationale: the subprocess acceptance tests in the same file drive the
# real CLI through its AOT binary — a lib/ mutant marks that binary stale and
# forces an ~85-100s recompile PER MUTANT (issue #1623/#1664 budgets), which
# cannot fit the rubric's "<10s per mutant". The in-process group exercises
# the writer logic directly under `dart test` (JIT + the persistent
# incremental kernel cache), so a mutant costs seconds. The subprocess
# acceptance tests remain outside the mutation loop as behavior guards.
#
# What this script does:
#   1. Cleans leftover $TMPDIR/dart_test.kernel.* dirs from prior mutants
#      (the dart test runner leaks them; rootfs fills after ~6 mutants and
#      corrupts the audit by miscategorizing mutants as "NotCovered").
#   2. Deliberately does NOT delete `.dart_tool/test/incremental_kernel*`
#      (the persistent incremental-compile cache).
#   3. Runs the writer-unit group with `-j 1` to avoid the parallel-test
#      CWD-cascade flake (issue #506).

rm -rf "${TMPDIR:-/tmp}"/dart_test.kernel.* 2>/dev/null || true

exec dart test test/commands/initialize_speckit_test.dart -j 1 \
  -n 'SpeckitScaffoldingWriter unit'
