# Plan — Spec 1377 fixture FR-001 traces

**Branch**: `1377-fixture-fr001-traces` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

Add `traces: adaptive_layouts` to FR-001 in
`example/specs/004-login-ui/spec.md`; pin it structurally
(`test/plugins/tdd/commands/bug_1377_fixture_traces_pin_test.dart`: B1 the
traces line exists, B2 the traced row is declared). Verify plan routes U1
DECLARED and commit the regenerated lane evidence (declared routing in
04-ENGINE.md, refreshed artifacts/provenance/test-list, the #1366
split-receipt, the gen'd U1 pair).

## Test strategy

Structural pins (B1/B2) + the committed plan/provenance evidence. Scoped
pin: analyze on the test file.
