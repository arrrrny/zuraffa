**Template Version**: `zuraffa-1.0`

# Spec: 1376-verify-kind-trace

## Summary

`zfa tdd verify` is kind-blind. The finder-kind taxonomy (#964) landed —
every generated widget test carries a machine-readable
`// scenario-assertions:` header (presence, absence, route-outcome,
enabled-state, sequence) — but the referee never reports what kinds it
watched. EPIC #1133 exit criterion 3 demands: "zfa tdd verify on
004-login-ui shows all 5 behavior kinds traced". Today the verification
report (stdout, `tdd/verification.md`, and the `verdict.v1` JSON envelope)
carries mutation buckets and behavior trace ids only — zero kind data
(`verify_command.dart` has no reference to `ScenarioAssertionClass` at
all). Discovered during the EPIC #1133 verify run; tracked as issue #1376.

## Acceptance Scenarios

1. **Given** a feature whose registered behaviors' generated tests declare
   kinds in their `// scenario-assertions:` headers (e.g. 004-login-ui:
   a3 presence, a4 route-outcome, a5 absence, a6 enabled-state, a7
   sequence + presence + route-outcome) **When** `zfa tdd verify
   --feature <f>` completes **Then** the verification report carries a
   behavior-kind breakdown: per-kind traced counts across the feature
   (all 5 canonical kinds present for 004-login-ui) and the per-behavior
   kind list, in both `tdd/verification.md` and the stdout summary.
2. **Given** a behavior whose generated test file is missing on disk or
   whose test declares no `// scenario-assertions:` header **When** verify
   completes **Then** that behavior is reported under an explicit
   `not-traced` bucket (honest absence — never silently dropped, never
   inferred post hoc from prose).
3. **Given** the `--json` verdict envelope (VISION §5) **When** verify
   completes **Then** the envelope's `details` carry the same per-kind
   counts so machine consumers read the kind trace without parsing
   markdown.
4. **Given** the existing verify gate semantics (FR-012..023 of spec 044)
   **When** the kind trace is emitted **Then** gate decisions, exit
   codes, mutation buckets, and restoration scopes are unchanged — the
   trace is additive reporting, never a new gate (the kind-MISMATCH gate
   lives in verify-red, #959/#964, and stays there).

## Functional Requirements

- **FR-001**: The verify audit MUST derive each registered behavior's
  declared assertion kinds from the behavior's generated test file — the
  `// scenario-assertions:` header the writer emits
  (`FinderTaxonomy.headerLine`) is the single machine-certified source;
  kinds are parsed, never re-derived from scenario prose.
- **FR-002**: The parsed kind labels MUST be validated against the
  canonical taxonomy labels (`presence`, `absence`, `route-outcome`,
  `enabled-state`, `sequence`); an unrecognized token is reported under
  `not-traced` with the raw token preserved (forward compatibility — a
  future taxonomy extension must not crash the referee).
- **FR-003**: The verification report (`tdd/verification.md`) MUST carry
  a `## Behavior kinds` section: a per-kind count table in canonical
  order plus a per-behavior kind list, and a `not-traced` bucket naming
  every behavior with no parseable header (FR-002 honesty rule).
- **FR-004**: The verify stdout summary line MUST include the per-kind
  counts (the same aggregation as FR-003), so a human running
  `zfa tdd verify` sees all 5 kinds traced without opening the report.
- **FR-005**: The `--json` verdict envelope MUST include a
  `behavior_kinds` object in `details`: per-kind counts, per-behavior
  kinds, and the `not-traced` list.
- **FR-006**: Hard constraints preserved: the mutation gate semantics,
  exit classes, preflight flow, restoration scope, and the verify-red
  kind-match gate (#959) are unchanged; the generated test shape and the
  `scenario-assertions:` header format are unchanged (verify only READS).

## Success Criteria

- **SC-1**: On the repo's own `example/` app, `zfa tdd verify --feature
  004-login-ui` reports all 5 canonical kinds traced (presence ≥ 1,
  absence ≥ 1, route-outcome ≥ 1, enabled-state ≥ 1, sequence ≥ 1) —
  EPIC #1133 exit criterion 3 reads directly off the output.
- **SC-2**: A registered behavior whose test file lacks the header lands
  in `not-traced` (both markdown and JSON), with the behavior id named.
- **SC-3**: The existing mutation-auditor and verify suites pass
  unchanged (no gate/report regression); the new report section is
  additive.

## Traceability

- Epic: #1133 (EPIC 2 — TDD Loop Completeness), sub-issue #964, exit
  criterion 3.
- Misfire: #1376 (verify output kind-blind).
- Composes with: #966 (typed ledger rows — plan-time kinds), #1140 (the
  plan's kind cell), #959 (verify-red kind-match gate).
