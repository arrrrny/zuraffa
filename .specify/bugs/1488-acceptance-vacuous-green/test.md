# Test — #1488 acceptance lane certifies vacuous greens

Suite: `test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart`
(slow tag — spawns real `dart test` subprocesses in throwaway fixture
projects; run with `--preset=all`).

## Fixtures

- `guardOnlyAcceptanceTest` — the gen-emitted guard-only acceptance test
  (#1512 fallback shape mirrored from `bug_1259_vacuous_green_test.dart`):
  the void-safe capture (`subject.<target>(); return null;` inside the
  UnimplementedError try/catch) + `expect(result,
  isNot(isA<UnimplementedError>()))` as the ONLY assertion.
- `outcomeAssertedAcceptanceTest` — the same test + one outcome
  assertion. The acceptance capture is void-safe by design (returns null
  for any non-throwing runner), so the honest completion-surface
  assertion is `expect(result, isNull)` — NOT `isNotNull` (the unit-lane
  mirror's shape; the acceptance capture can never resolve non-null).
- `scaffoldedVoidSubject` / `scaffoldedUnitSubject` — the non-throwing
  subject states (composed / func-scaffolded) the guard-only tests
  vacuously pass against.
- Seeding: `fx.seedTestList` (kind-resolved rows) + `fx.seedCertifiedRed`
  (registry record + cycle-log red entry + test + subject on disk).

## Pins

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1488-a1 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | acceptance | an acceptance test whose only assertion is the UnimplementedError guard cannot certify green — even when it passes (exit 1, outcome=vacuous-green, no green evidence) | FR-1488, make step 3c gate | GREEN |
| A-1488-a2 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | acceptance | the acceptance test WITH an outcome assertion still certifies green — the refusal keys on the assertion set, not the lane | FR-1488, contentIsVacuousGreen backstop | GREEN |
| A-1488-a3 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | acceptance | kindless/legacy rows keep the fail-open skip transition — no resolvable kind, no refusal | FR-1488, #1259 fail-open contract | GREEN |
| U-1488-u1 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | unit | the unit lane refusal is unchanged — a guard-only unit test is still refused (#1259 U1 mirror) | FR-1488, unit-lane scope preserved | GREEN |

## Inverted legacy pins (pre-#1488 contract, closed by this fix)

| id | suite | change | state |
| -- | ----- | ------ | ----- |
| U-1259-u3 | test/plugins/tdd/bug_1259_vacuous_green_test.dart | acceptance guard-only rows: legacy skip green → REFUSED vacuous-green (cites #1488) | GREEN |
| A-1162e | test/plugins/tdd/bug_1162_bug_subject_green_path_test.dart | unexpressible acceptance make: stub-only compose green → REFUSED before generation planning (no compose dispatch) | GREEN |

## RED evidence (captured pre-fix, HEAD b621f38b)

```
A1: Expected: <1>
    Actual: <0>
  zfa tdd make: behavior A-1488
     target test already passes — skipping generation (issue #694 skip
     transition); the suite is not re-run (issue #741)
     green evidence appended to specs/090-tdd-fixture/tdd/cycle-log.md
  make: behavior=A-1488 outcome=skipped feature=090-tdd-fixture
```

Result pre-fix: `+3 -1` (A1 fails = the bug; A2/A3/U1 pass = the
guardrails hold). Post-fix: `+4 -0`.
