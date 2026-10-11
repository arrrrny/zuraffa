# Implementation Plan: 1536-named-param-syntax-parsing

**Branch**: `feat/1536-named-param-syntax-parsing` | **Date**: 2026-09-13 | **Spec**: specs/1536-named-param-syntax-parsing/spec.md

**Input**: Feature specification from `specs/1536-named-param-syntax-parsing/spec.md`

## Summary

Contract-row parameter parsing mis-handles Dart named-parameter syntax:
`Signature.parse` splits the parameter text on every bare comma, so
`{level, onRecord}` degrades into two brace-dangling positional tokens,
and `_defaultParamName` lowercases whole words so `onRecord}` renders as
`onrecord`. The generated subject + test pair does not compile (FR-011
violation). The remediation makes the contract-row grammar parse named
parameters (brace-aware top-level comma split; named group kept whole;
named params render `{...}` in subject signatures and named arguments in
test capture sites) and refuses genuinely unparseable parameter syntax
with a named remedy riding the existing malformed-declaration machinery.

## Technical Context

**Language/Version**: Dart SDK ^3.11.0 (CLI package `zuraffa`)

**Primary Dependencies**: args, analyzer (>=14.0.0 <15.0.0), code_builder, dart_style — none added by this fix

**Storage**: N/A (pure parsing/rendering change; artifacts on disk are the CLI's existing outputs)

**Testing**: `dart test` (package:test), `dart analyze` for lint/compile gates

**Target Platform**: Linux/macOS/Windows CLI (`zfa tdd gen|plan|wire|func`)

**Project Type**: library/cli

**Performance Goals**: parse cost unchanged (single-pass token split)

**Constraints**: byte-identical output for existing positional-parameter contract rows; no new analyzer warnings; grammar lives in ONE place

**Scale/Scope**: 4 lib files + 1 new test file; no model/schema changes beyond one additive `named` flag

## Technical Context (domain notes)

- **Contract-row parameter parsing**: `Signature.parse`
  (`lib/src/plugins/tdd/models/routing.dart`) is the ONLY parse site for
  Layer Contract signature rows. Its `_shape` regex captures the whole
  parameter list; the defect lives in the bare `split(',')` after the
  match.
- **Named vs positional syntax**: inside a named group, Dart semantics
  apply — a single-identifier token is a parameter NAME (named params
  always carry a name), type implied `Object?` (the same renderable
  degradation the shape already uses for non-existent entities). A
  two-word token keeps the existing `Type name` split. Positional
  tokens keep the existing single-identifier = TYPE reading
  (`format(String)` → param named `text`).
- **Subject signature generation**: `SubjectWriter._renderContractUnitSubject`
  renders `shape.params`; it must place named params in a trailing
  `{...}` group. `func_command._renderScaffolded` renders the same
  shape for `zfa tdd func` — one shared renderer on `UnitContractShape`
  (the #1323 lesson: the grammar lives in ONE place).
- **Test argument stubs**: `behavior_test_writer._captureInvocation`
  builds the arg list and `_argN()` helpers; named params pass
  `name: expr`, positional stay positional. Helper messages carry whole
  declared types — no dangling `{level` fragments.
- **Refusal surface**: `parseContractRows` already turns
  `Signature.parse`'s [FormatException] into a [StateError] naming the
  row, spec line, and `--> fix:` for FUNCTION-layer rows;
  `plan_command` parses declared rows before any artifact is written
  (plan-time refusal) and gen/wire surface the same refusal through
  `DeclaredRouting.declaredSignatureFor`. A stray/unbalanced-brace
  parameter token throws the named remedy from `Signature.parse` and
  rides this machinery — no state-machine change.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Errors-are-an-API: the refusal names the supported grammar and a
  `--> fix:` remedy (FR-005). PASS.
- Minimal compilable stub (FR-011): named groups render compilable
  signatures; unparseable syntax refuses before artifacts exist. PASS.
- The grammar lives in ONE place: the token splitter and the param-list
  renderer are single shared functions consumed by all render sites.
  PASS.
- Honest red: unchanged — the pair still fails at assertion level (or
  the declared seam), never at compile. PASS (void-return capture is
  #1538's companion scope, explicitly out of scope here).

## Project Structure

### Documentation (this feature)

```text
specs/1536-named-param-syntax-parsing/
├── plan.md              # this file
├── spec.md              # measurable success criteria
├── tasks.md             # MVP-first, RED-first behavior tasks
└── tdd/
    ├── test-list.md     # behavior test list (derived from spec)
    └── verification.md  # post-green verification record
```

### Source Code (touch surface)

```text
lib/src/plugins/tdd/
├── models/
│   └── routing.dart                  # FR-001: brace-aware token split + grammar doc + refusal
├── services/
│   ├── unit_contract_shape.dart      # FR-002/FR-004: named expansion + camelCase preservation + shared renderer
│   ├── subject_writer.dart           # FR-003: grouped rendering via the shared renderer
│   └── behavior_test_writer.dart     # FR-003: named args at the capture site
└── commands/
    └── func_command.dart             # FR-003: scaffold uses the shared renderer
test/plugins/tdd/
└── issue_1536_named_param_syntax_test.dart  # RED-first behavior coverage
```

### Affected consumers (verified read-only)

- `wire_command`: uses `declaredReturn` + verbatim stub param capture —
  unaffected (its `_declaredShapeFromStubHeader` re-parse now parses
  named headers correctly).
- `run_driver_core` / `plan_command`: consume `scalarOutcome` /
  seam-cost forecasts only — unaffected.
- `dependency_mock_builder`: uses `DependencySignature` (its own
  grammar) — out of scope by constraint.
