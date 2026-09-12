# Red Evidence: wire refuses contract-derived subjects (#1500)

- **Slug**: 1500-wire-contract-derived-subject
- **Captured**: 2026-09-11 (pre-fix binary, branch
  `fix/1500-wire-contract-derived-subject`)

## Red run (TDD step 2 — failing tests for the RIGHT reasons)

Command:

```bash
dart test test/plugins/tdd/bug_1500_wire_contract_subject_test.dart
```

Result (pre-fix): `Some tests failed` — 8 failing, 4 passing.

Failing (the bug surface):

| Case | Pre-fix failure |
| --- | --- |
| U-1500a | `Expected: <0>` / `Actual: <1>` — wire printed `subject at "lib/u2_subject.dart" carries an UnimplementedError in an unrecognized shape — refusing to rewrite a file this command did not generate.` |
| U-1500b | refused as unrecognized shape before ever reaching the mock-data check |
| U-1500c | same unrecognized-shape refusal (`List<Task>` return) |
| U-1500d | same unrecognized-shape refusal (`Task?` return) |
| U-1500e | same unrecognized-shape refusal (`String` declared return stub) |
| U-1500f | same unrecognized-shape refusal (`bool` declared return stub) |
| U-1500k | same unrecognized-shape refusal (provenance-header fallback case) |
| U-1500l | same unrecognized-shape refusal (declared-beats-description case) |

Passing pre-fix (regression pins, must stay passing post-fix):

| Case | Why it passes pre-fix |
| --- | --- |
| U-1500g | the `int count() -> int` stub matches the LEGACY regex and the description-derived body coincides (`return 0;`) |
| U-1500h | legacy no-arg int/void stubs were always wired |
| U-1500i | a commented-out stub line never matched the legacy regex |
| U-1500j | the `class Weird` block-body shape was always refused |

The U-1500a transcript above is the exact failure signature the issue
reports: `runner-error`, "unrecognized shape", exit 1 — for a stub
SubjectWriter emitted.

## Red run for the second half (`return null as Task;`)

Covered inside U-1500a/d/c assertions (`isNot(contains('return null as'))`)
and U-1500b (the missing-mock-data misfire-stop). Pre-fix the wire never
got far enough to render a body for these shapes; the cast-error body is
therefore exercised as part of the GREEN assertions and the misfire-stop
test.
