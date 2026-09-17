#!/usr/bin/env bash
# run-1653-mutation-tests.sh — scoped test command for mutation-test-1653.xml
# (issue #1653 verification). Same discipline as tools/run-tdd-tests.sh: the
# mutation_test package parses <command> by whitespace-splitting, so shell
# quoting/redirects must live in a wrapper script.
set -u

# Clean stale kernel caches so leaked dart_test.kernel.* dirs cannot fill the
# rootfs and corrupt the audit with NotCovered miscategorizations.
if [ -n "${TMPDIR:-}" ]; then
  rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null || true
fi
rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true

# Scoped to the tests covering the #1653 surfaces (patcher opt-in, pre-
# resolver, baseline init threading, receipt timing models). -j 1 serializes
# within a single mutant (issue #506 CWD-cascade flake).
#
# --preset=all is REQUIRED here (not --exclude-tags): dart_test.yaml already
# excludes `slow` at the top level, and a CLI --exclude-tags flag COMBINES
# with it (`slow || flutter || e2e`) — which silently skipped every
# slow-tagged covering test (this audit's whole test scope, all @Tags(['slow']))
# and scored the audit against an empty test set. --preset=all sets
# exclude_tags to "false" so the scoped files actually run.
exec dart test \
  test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart \
  test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart \
  test/cli/writers/tdd/bug_1370_flutter_consumer_test_baseline_test.dart \
  test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart \
  test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart \
  test/plugins/tdd/services/refactor_passes_test.dart \
  test/plugins/tdd/models/refactor_action_test.dart \
  test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart \
  test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart \
  --preset=all \
  -j 1
