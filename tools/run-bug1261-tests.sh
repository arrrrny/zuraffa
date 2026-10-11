#!/usr/bin/env bash
# run-bug1261-tests.sh — test runner invoked by `mutation-test-1261.xml`
# (bug #1261: tdd visual-contract surface).
#
# Mirrors tools/run-tdd-tests.sh hygiene:
#   1. Cleans leftover $TMPDIR/dart_test.kernel.* dirs from prior mutants
#      (the dart test runner leaks them; without the cleanup the rootfs
#      fills after ~6 mutants and every subsequent mutant is
#      miscategorized as "NotCovered" — the audit becomes corrupt).
#   2. Deliberately does NOT delete .dart_tool/test/incremental_kernel*
#      (the persistent incremental-compile cache; removing it forces every
#      mutant to recompile ~133 transitive dills from scratch).
#   3. Runs `dart test -j 1` to avoid the parallel-test CWD-cascade flake
#      (issue #506).
#
# Scope: the bug #1261 red→green suite — it covers every changed file of
# the fix end to end (spec_parser golden parsing, the [golden] row tag in
# the reader, plan/split golden marks + refusals + guidance, gen's
# flagless declared-golden hook + staleness idempotency, and the widget
# scaffold's conditional golden comment).
export TMPDIR="${TMPDIR:-/tmp}"
rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null
exec dart test test/plugins/tdd/bug_1261_visual_contract_surface_test.dart -j 1
