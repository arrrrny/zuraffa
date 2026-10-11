# Implementation Plan: FR manual exemption (issue #1484)

**Branch**: `feat/1484-fr-manual-exemption` | **Spec**: `specs/1484-fr-manual-exemption/spec.md` | **Generated**: 2026-09-11

## Summary

`zfa tdd plan` derives one unit behaviour row per functional requirement, unconditionally (`SpecParser._extractUnit`). Inherently non-unit FRs (UI appearance, non-functional constraints, whole-app properties) therefore manufacture unit rows that can never pass `make`, permanently blocking `zfa tdd run`. This feature adds the FR-side escape hatch: a `**Type**: manual` continuation line on an FR routes it to a manual declaration in `traceability.md` instead of a unit row, and FRs without a `traces:` binding default to manual — collapsing the fallback-routing dead-end class. Acceptance criteria have had the equivalent `(manual:)` escape hatch since #846; this extends the same concept to FRs with a marker syntax that mirrors the existing scenario `**Type**:` pattern.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK constraint `^3.11.0`), pure-Dart CLI package (`zuraffa` v6.2.2)
**Primary change surface**: `lib/src/plugins/tdd/services/spec_parser.dart` — the FR→behaviour derivation (`_extractUnit`, line ~1143; the issue cites the derivation entry at spec_parser.dart:249's `manualScenarioMarker` concept extended to FRs)
**Secondary surfaces**: `lib/src/plugins/tdd/services/requirement_scan.dart` (CoverageGate accounting + TraceabilityMatrix rendering), `lib/src/plugins/tdd/commands/plan_command.dart` (warning emission + gate wiring), `lib/src/plugins/tdd/commands/ingest_command.dart` + `lib/src/plugins/tdd/services/spec_mutator.dart` (gate callers must pass the manual set to keep their coverage gates coherent)
**Untouched (hard constraint)**: `run_command.dart`, `run_driver_core.dart`, `make_command.dart`, `gen_command.dart`, `verify_command.dart`, `verify_red_command.dart` — `zfa tdd run` only sees behaviours that passed plan; manually-declared FRs never produce a unit row, so the loop needs no change.
**Testing**: `dart test` (package:test), fixtures built in temp dirs via `CliRunner(exitOnCompletion: false)` + `--project`, mirroring `plan_routing_provenance_test.dart`.

## Data Model / Design

### New parser API (spec_parser.dart)

```dart
class FrRouting {
  final String frId;            // FR-010 (as written)
  final String unitId;          // U10 — document-wide, aligned with _extractUnit
  final int specLine;           // 1-based spec line of the FR header
  final bool manualMarker;      // block carries `**Type**: manual`
  final List<String> traceTokens; // first `traces:` line in block (first wins)
  final String rawText;         // FR prose after the id colon (raw)
  bool get traced => traceTokens.isNotEmpty;
  bool get routesManual => manualMarker || !traced; // declaration outranks trace
}

static List<FrRouting> parseFrRoutings(String specMd);
```

Walk mirrors `parseFrContractTraces` exactly: fenced code blocks blanked (documentation ≠ declaration), `_frLine` recognises bullet + FR-table grammars, `uIdx` increments on EVERY FR header (manual FRs consume their unit id — the #846 id-alignment precedent), FR block = continuation lines until `_endsFrBlock`, first `traces:` line wins, first `**Type**: manual` line wins.

### Routing decision (the derivation fix)

| FR state (in document order) | Before #1484 | After #1484 |
| --- | --- | --- |
| `traces:` binds contract rows | unit row (declared routing) | unit row — **unchanged** |
| `**Type**: manual` marker | unit row (no opt-out existed) | **no row** — manual declaration |
| no marker AND no binding | unit row via legacy fallback (dead-end class) | **no row** — manual declaration (default) + plan warning |
| marker AND binding (contradiction) | n/a | manual — the explicit declaration outranks the trace |

### Coverage gate (requirement_scan.dart)

`CoverageGate.evaluate(scan, behaviors, {Set<String> manualFrIds = const {}})` — an FR statement whose id is in `manualFrIds` counts as covered (manual declaration), never a gap. Default `const {}` preserves the existing pure-function contract for untouched callers. Callers updated to pass the set: `plan_command.dart`, `ingest_command.dart`, `spec_mutator.dart` (`validateSpecContract`).

### Traceability matrix (requirement_scan.dart)

`TraceabilityMatrix.render` gains `frManual`: the map of FR id → tag for manually-declared FRs. Rendering:
- main table row status becomes `manual` (behaviour cell `—`) instead of `GAP`;
- a new `## manual:` section after the table lists each manual FR with full text + tag (`manual (**Type**: manual)` for explicit, `manual (defaulted: no traces: binding)` for the default);
- machine block: `manual:` counts acceptance-side `(manual:)` statements + FR manual declarations; a new `fr-manual:` line carries the FR breakdown; `open-gaps` stays 0.

### Plan warning (plan_command.dart)

For every defaulted FR (no marker, no binding), plan prints a warning naming the FR and both remedies:

```
zfa tdd plan: WARNING: FR-010 derives no unit behaviour — no `traces:` binding and no `**Type**: manual` marker; recorded as a manual declaration in tdd/traceability.md.
  --> fix: add a `traces:` line naming a declared contract row to derive an automated unit behaviour, or add `**Type**: manual` under the FR to declare the exemption explicitly.
```

Explicitly-marked FRs warn nothing (the author already declared it). Guidance only — exit stays 0.

## Compatibility & Risks

- **Backwards compatible for all-FR-traced specs**: every FR with a non-empty binding still derives its row; ids, provenance, lanes, markers identical. The marker is opt-in.
- **Deliberate semantic change**: untraced+unmarked FRs flip from unit-row to manual. Existing tests asserting the old fallback default are updated to the declared semantics (SC-005).
- **Consumers of `SpecParser().parse`**: `spec_fuzz_auditor` and `spec_mutator` re-derive behaviours from (mutated) specs — they inherit the new routing, which is the point: the fuzzed invariant is now "manual FRs never yield unit rows".
- **Marker emission (#1186)**: untouched — only scenario kinds are emitted back into the spec; FR manual markers are hand-authored.

## Migration / Ops

None. Specs opt in by adding the marker; untraced FRs need no edit (they become manual declarations with a warning). `traceability.md` gains fields — downstream consumers parse `spec-hash` only (`TraceabilityMatrix.extractSpecHash`), so verify/corpus drift checks are unaffected.
