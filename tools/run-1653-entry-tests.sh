#!/usr/bin/env bash
# run-1653-entry-tests.sh — FAST test command for mutation-test-1653-entry.xml.
# The cycle-entry models are killed by the rendering/evidence suites alone;
# the CLI-level suites (real `dart pub get` children) are excluded from THIS
# scope to keep the per-mutant budget sane (~10s vs ~100s). Same --preset=all
# requirement as run-1653-mutation-tests.sh (the top-level exclude_tags: slow
# would silently empty the scope otherwise).
set -u

if [ -n "${TMPDIR:-}" ]; then
  rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null || true
fi
rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true

exec dart test \
  test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart \
  test/plugins/tdd/models/refactor_action_test.dart \
  test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart \
  test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart \
  test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart \
  --preset=all \
  -j 1
