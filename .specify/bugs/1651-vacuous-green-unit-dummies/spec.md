**Template Version**: `zuraffa-1.0`

# Bug Spec: tdd engine lane certifies vacuous greens — unit subjects ship as `return 0;` dummies with result=complete

**Input**: GitHub issue #1651 — `zfa tdd run` certifies `result=complete,
done=10` on the zcalc probe while all four unit subjects on disk are
func-scaffolded dummies (`return 0;` / `return 0.0;`). The post-#1259
generated unit test asserts only the declared return TYPE
(`expect(result, isA<int>())`) with representative arguments `(0, 0)`;
the #1517 func pass rewrites the throwing stub to `return 0;`, which
satisfies a type assertion, so terminal green is certified with zero
declared-contract code. This is the #1259 bug class reproducing through
the scalar-declared contract path the #1259 remediation itself added.
Goal: a dummy-body scalar pair can never certify green — the loop must
stop at the designed hand step until a value-discriminating assertion
and a real implementation land.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa tdd gen` for a traced scalar-declared unit contract
  MUST emit the typed outcome assertion WITH the `zfa:tdd: vacuous-guard`
  marker and a remedy comment naming the type-only vacuity (issue
  #1651) — the same marker discipline the entity/void branch already
  carries (the marker is the run driver's `stopped_at=<id>:hand`
  discriminator). The emitted assertion itself stays
  `expect(result, isA<T>())`.
            traces: VacuousGuardGate
- **FR-002**: `contentIsVacuousGreen` MUST classify a test whose
  assertion set reduces to scalar-type-only `expect(x, isA<T>())` checks
  (T ∈ {String, int, num, double, bool}) — bare, or layered on the
  UnimplementedError guard — as vacuous, so legacy marker-less generated
  tests are refused by every existing consumer (make step-3c, the
  born-green arm, the gen contract-drift probe, the #1482 preflight
  exemption). Value-discriminating assertions (`equals(...)`,
  `throwsA(...)`, `isNot(...)`-wrapped, entity-type `isA<T>()`) keep the
  test real: a `return 0;` dummy fails them.
            traces: VacuousGuardGate
- **FR-003**: the make step-3c refusal and the run driver's
  marker-present hand-step stop MUST handle the new shape through the
  EXISTING machinery unchanged — the unit remedy already prescribes the
  designed unlock: add an assertion on the observable outcome named by
  the behavior description (the spec's scenario values), remove the
  marker, re-run make.
            traces: VacuousGuardGate
- **FR-004**: legacy pins that coded the old assumption (typed outcome
  assertion ⇒ no marker ⇒ make certifies a dummy-satisfied green) MUST
  be updated to the new contract: the scalar-branch pins flip to
  marker-present, and the #1310 U6 dummy-`=> false;` certification flips
  to the vacuous-green refusal.
            traces: VacuousGuardGate

## Layer Contracts

**Function**:
- `VacuousGuardGate`: `contentIsVacuousGreen(String content) -> bool`

## User Story 1

**US1**: As a migration driver, I want the unit lane to refuse
dummy-body greens so that `done` on the engine receipt means a real
implementation pinned by a value assertion.

**Acceptance Scenarios**:

1. **Given** a fresh zcalc-style package with a scalar-declared contract
   (`add(int a, int b) -> int`) and its FR tracing the row, **When**
   `zfa tdd gen` + `zfa tdd func` + `zfa tdd make` run (the #1517 func
   pass fills `return 0;`), **Then** make refuses with
   `outcome=vacuous-green` instead of certifying green. **Type**:
   acceptance
2. **Given** a hand-authored test whose only assertions are
   `expect(result, isA<int>())` (with or without the guard), **When**
   `contentIsVacuousGreen` classifies it, **Then** the verdict is
   vacuous; adding one `expect(result, equals(5));` flips it real.
   **Type**: acceptance

## Test Plan

- **U1**: detector — scalar-type-only assertion sets are vacuous
  (bare type-only; guard + type-only; legacy marker-less shape).
  → `test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart`
- **U2**: detector — value-discriminating assertion sets stay real
  (`equals`, `throwsA`, `isNot(isA<...>)`, entity-type `isA<T>()`).
  → same file
- **U3**: writer — the scalar-declared contract emits the typed
  assertion WITH the marker + #1651 remedy comment.
  → same file
- **U4**: make — the gen → func → make repro refuses
  `outcome=vacuous-green` (the issue's exact flow).
  → same file
- **A1**: RED — pre-fix, U1–U4 fail (evidence in `red-evidence.md`).
- **A2**: GREEN — the updated legacy pins (bug_1259 U5, 1310 U5/U6,
  1538 B1) and the vacuous-family suites pass post-fix.

## Notes

- Scenario example-values from acceptance Given/When/Then (issue ask 1:
  mechanically deriving `subject_u1(2, 3) == 5`-shaped unit assertions)
  stay a FOLLOW-UP: the repo parses no structured Given/When/Then value
  model (`_extractScenarioText` keeps only the Then-clause text), so
  that ask is a feature, not this fix. Until it lands, the hand step is
  the unlock — exactly the #1488/#1626 remedy family.
- The warning-token surface (`zfa:tdd: guard-only`) is untouched: the
  traced scalar row carries a contract shape, so the gen-time fallback
  warning stays silent (its `contractShape == null` gate).
