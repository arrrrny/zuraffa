#!/usr/bin/env bash
# run-1693-mutation-tests.sh — test runner invoked by `mutation-test-1693.xml`.
#
# Same wrapper-script convention as tools/run-tdd-tests.sh: mutation_test
# (v1.8) splits <command> text on whitespace and does not honor shell
# quotes, so the shell logic lives here.
#
# Scope: the spec-1693 cert-gate suites — the consumers of the mutated
# freshness logic (cert_registry.dart) and canonical digest
# (format_canonical_digest.dart):
#   - spec_1693_gate_format_drift_test.dart       (the gate red→green cycle)
#   - spec_1693_receipt_and_certifier_test.dart   (the receipt + certifier seam)
#   - cert_registry_test.dart                     (the spec-1110 guards)
set -u

if [ -n "${TMPDIR:-}" ]; then
  rm -rf "$TMPDIR"/dart_test.kernel.* 2>/dev/null || true
fi
rm -rf /tmp/dart_test.kernel.* 2>/dev/null || true

exec dart test \
  test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart \
  test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart \
  test/plugins/mock/cert_registry_test.dart \
  -j 1 --exclude-tags "flutter || e2e"
