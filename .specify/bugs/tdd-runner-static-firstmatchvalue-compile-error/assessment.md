# Bug Assessment: runner.dart calls static _firstMatchValue as instance method — compile error

- **Slug**: tdd-runner-static-firstmatchvalue-compile-error
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/695
- **Verdict**: valid
- **Severity**: high

## Report

`runner.dart` calls `_firstMatchValue(...)` as an instance method, but it is declared `static`, causing a compile error that stops `zfa tdd run` at the first A*:make step.

## Symptom

`zfa tdd run` stops at A*:make with `runner.dart:95:22: Error: The method '_firstMatchValue' isn't defined`.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart:257` — `static String? _firstMatchValue(...)`.
- Lines 95, 120, 130, 173, 195, 203 — called as instance method.

## Root Cause Hypothesis

Static method called as instance method. Confidence: **high** — deterministic compile error.

## Proposed Remediation

**Option B (preferred):** Remove `static` from line 257, making it an instance method accessible without prefix.

**Files likely to change:**
- `lib/src/plugins/tdd/services/runner.dart`

**Tests to add or update:**
- `dart analyze lib/src/plugins/tdd/services/runner.dart` → zero errors.
- `zfa tdd run` proceeds past A*:make for acceptance behaviors.

## Open Questions

- None blocking.