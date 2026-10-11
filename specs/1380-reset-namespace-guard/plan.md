# Plan — Spec 1380 reset namespace guard

**Branch**: `1380-reset-namespace-guard` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`_findDriftedOwnedFiles`: after the shape check, compute the candidate's
lane-relative path (`p.relative(normalized, from: dir)`); when it has a
feature segment (≥2 segments) and that segment ≠ the feature being reset,
classify it foreign (`foreignOwnedLookingById`) and skip. Flat candidates
and own-namespace candidates keep the existing flow.

## Test strategy

`test/plugins/tdd/commands/bug_1380_reset_namespace_guard_test.dart`
(slow tier): B1 foreign same-id files survive a reset of 004-login-ui,
B2 own-namespace drift recovery unchanged. Scoped pin: split 1000,
realize-mock, #1373 driver, #1264 reset phantom, #1331 make adopted +
analyze.
