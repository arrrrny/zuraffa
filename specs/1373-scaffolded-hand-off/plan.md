# Plan — Spec 1373 scaffolded hand-off

**Branch**: `1373-scaffolded-hand-off` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`run_driver_core.dart`: a marker-gated arm in the make-failure handling
(before the generic stop), mirroring the #1308 vacuous-green hand step —
`_testCarriesScaffoldedMarker` (fail-open probe of the generated test)
gates the named hand step `stopped_at=<id>:hand` with the
`--author --finders-file` remedy.

## Test strategy

`test/plugins/tdd/commands/bug_1373_scaffolded_hand_off_driver_test.dart`
(slow tier): the scripted fake zfa binary drives gen → verify-red
(unexpected-green skip shape) → make not-certified-red; B1 asserts the
hand step with the marker present, B2 the generic stop without it.
Scoped pin: the #1308 remedy driver suite + #1309 + analyze.
