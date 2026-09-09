**Template Version**: `zuraffa-1.0`

# Plan: 1376-verify-kind-trace

## Technical Context

- **Language/toolchain**: pure Dart CLI (Dart SDK ^3.11.0); the verify
  audit path runs under `package:test`, no Flutter dependency on this
  package's own test path.
- **Feature surface** (all reporting layer — issue #1376 hard constraint:
  gate semantics, exit classes, preflight flow, and the verify-red
  kind-match gate are untouched; verify only READS the generated tests):
  - `lib/src/plugins/tdd/services/behavior_kind_trace.dart` (NEW) — the
    kind-trace reader: parses the machine-readable
    `// scenario-assertions:` header (`FinderTaxonomy.headerLine` shape:
    `presence("lit")`, `route-outcome("lit")`, `absence("lit")`,
    `enabled-state("lit")(disabled|enabled)`, bare `sequence`) from each
    registered behavior's generated test file, validates labels against
    the canonical taxonomy, and aggregates per-kind counts in canonical
    order. A behavior whose test file is missing or header-less lands in
    `not-traced` (honest absence, FR-002).
  - `lib/src/plugins/tdd/services/mutation_auditor.dart` —
    `MutationAuditReport` GAINS an optional `behaviorKindsByBehavior`
    map (+ `notTracedBehaviors` list) populated by the auditor after the
    scope resolves (registry records already carry behaviorId →
    testPath); `toMarkdown()` GAINS the additive `## Behavior kinds`
    section. All existing constructors keep their shape (the new fields
    default to empty — early-return reports stay byte-identical).
  - `lib/src/plugins/tdd/commands/verify_command.dart` — after the audit,
    the stdout summary line GAINS the per-kind counts and the
    `verdict.v1` envelope `details` GAINS the `behavior_kinds` object
    (FR-004/FR-005). No gate logic touched.

## Key decisions

- **D1 — the generated test's `scenario-assertions:` header is the
  single source of truth.** The plan's `kind` cell (#1140) is the
  PREDICTION; the header in the emitted test is what the referee
  actually certified. Parsing the emitted artifact keeps verify honest
  (a plan row that gen never materialized shows up as `not-traced`)
  and reuses the exact format `FinderTaxonomy.headerLine` already
  guarantees — no new contract, no writer change.
- **D2 — validate against the canonical enum, never crash on the
  unknown.** Tokens are matched against `ScenarioAssertionClass.label`
  values; anything unrecognized is preserved verbatim under
  `not-traced` (with the behavior id) so a future taxonomy extension
  degrades to honest reporting, not a referee crash (FR-002).
- **D3 — additive reporting, zero new gate.** The kind trace rides the
  existing report envelope (`toMarkdown`, stdout summary, `details`).
  Gate decisions and exit classes are byte-compatible (FR-006); the
  kind-MISMATCH enforcement stays in verify-red where #959 landed it.
- **D4 — compute once in the auditor, consume everywhere.** The auditor
  resolves the registry records already; the trace is computed there
  (one file read per behavior test) and flows to markdown/stdout/JSON
  through the report object — no duplicated parsing, no second registry
  pass in the command.

## Risks / notes

- Behavior test paths in the registry may be relative or absolute; the
  reader resolves them against the audit's working directory the same
  way the preflight does (missing file → `not-traced`, never a throw).
- The `sequence` kind appears as a bare token (no literal) in the
  header — the parser must accept both token shapes.
- The early-return report constructors (NOT_ASSESSED paths) keep the
  new fields empty; the markdown section is omitted when the scope was
  empty (no fake zeros).
