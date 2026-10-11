# Plan — Spec 1382 tier integrity pin

**Branch**: `1382-tier-integrity-pin` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

Fast-tier pin `test/tier_integrity_test.dart`: (B1) parse every
`test/regression/*_test.dart` for the `@Tags` regression annotation;
(B2) parse dart_test.yaml for the regression preset. Tag the three
untagged regression files. The spawn-based mismatch guard was rejected —
inside the targeted tier it cannot distinguish the invocation shape and
would recurse; the static pin + the documented preset are the honest
pair.

## Test strategy

Hermetic YAML/source assertions in the fast tier; scoped pin: the pin
itself + the retagged files' own suites (analyze).
