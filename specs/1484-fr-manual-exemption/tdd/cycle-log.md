# Cycle Log: 1484-fr-manual-exemption

**Feature**: 1484-fr-manual-exemption | **Engine**: dart_test | **Loop**: inside-out

Append-only evidence — one entry per red-green-refactor cycle.

---

## Cycle 1 — U1/U2/U3: the parser routing facts + the derivation flip

- **Phase**: RED @ 2026-09-11
- **Evidence**: `dart test test/plugins/tdd/services/spec_parser_fr_manual_1484_test.dart` →
  loading error: `Member not found: 'SpecParser.parseFrRoutings'`,
  `No named parameter with the name 'manualFrIds'` /
  `'frManualTags'` — the 1484 API does not exist yet.
- **Tests written**: `spec_parser_fr_manual_1484_test.dart` (parser facts, marker
  routing, outranks-trace, fenced-marker documentation, FR-table grammar,
  unit derivation, gate accounting, matrix rendering).

## Cycle 2 — U6/U7/A1/A2/A3: the plan-level routing

- **Phase**: RED @ 2026-09-11
- **Evidence**: `dart test test/plugins/tdd/commands/plan_fr_manual_1484_test.dart` →
  `00:00 +0 -5: Some tests failed` — manual FRs still derived unit rows,
  no warning, no `## manual:` section.
- **Tests written**: `plan_fr_manual_1484_test.dart` (explicit-marker e2e,
  defaulted-FR warning e2e, explicit-FR-silent, all-traced backwards compat,
  machine-block counts).

## Cycle 3 — implementation (GREEN)

- **Phase**: GREEN @ 2026-09-11
- **Change**:
  - `spec_parser.dart`: `FrRouting` + `parseFrRoutings` +
    `manualFrCriterionIds`; `_extractUnit` routes manual FRs (explicit marker
    OR unbound) to no row while consuming the unit id;
    `parseScenarioTypeMarkers` cedes `**Type**: manual` lines outside
    scenario blocks to the FR walk (any other kind still refuses).
  - `requirement_scan.dart`: `CoverageGate.evaluate` gains `manualFrIds`
    (manual FRs covered, never gaps); `TraceabilityMatrix.render` gains
    `frManualTags` (main-table `manual` status, `## manual:` section with
    full text + tag, machine-block `manual:`/`fr-manual:` counts).
  - `plan_command.dart`: FR routing parsed once; defaulted-FR WARNING naming
    the FR + both remedies; gate + matrix wired.
  - `ingest_command.dart` + `spec_mutator.dart`: gate callers pass the
    manual set (coherent coverage accounting).
- **Evidence**: `dart test` both 1484 suites → `00:00 +17: All tests passed!`

## Cycle 4 — legacy sweep (fixtures updated to the declared semantics)

- **Phase**: GREEN @ 2026-09-11
- **Scope**: fixtures that pinned the OLD fallback-to-unit default for
  untraced FRs were updated to bind `traces:` (preserving each test's
  intent: derivation, id alignment, persistence marking, lane routing,
  pipe escaping, stale-guard regeneration), or re-pinned to the new
  semantics (U3 @1310 asserts the untraced FR derives NO row; A4 @071
  strict refusal now names the acceptance scenario A1; B @1319 asserts
  no fallback and no unit row; U7 @1310 seeds a legacy criterion-only
  prior list against a traced spec; U6/U7 @1320 reach the criterion-only
  cell via the self-trace token). The ZikZak corpus generator now emits
  `traces:` on every format-robustness shape; `modern-undeclared` stays
  the dedicated no-binding shape with the honest 1484 oracle
  `(3, 3, 0, 2, 3)`; the corpus was regenerated
  (`dart run tool/generate_zikzak_corpus.dart`, 120 specs).
- **Evidence**: `dart test test/plugins/tdd/services` → `+816: All tests
  passed!`; `dart test test/plugins/tdd/commands` → `+468: All tests
  passed!`

## Cycle 5 — repo-wide regression sweep

- **Phase**: GREEN @ 2026-09-11
- **Evidence** (chunked runs, kernel caches cleaned between chunks):
  test/tdd +152, test/cli +230, test/commands +370, test/plugins/mcp +130,
  test/agent +240, core/config/domain/engine/state/skin/utils +1074,
  integration/regression/fixes/migration/graphql/mock +255, misc dirs +587,
  root files + mock/slice/skeleton +413, plugin batches +347/+262/+813.
- **Pre-existing, unrelated failures (environment)**: the Flutter-SDK
  compile gates (`controller_compile_test`, `presenter_compile_test`,
  `view_compile_test`, `test/templates/self_hosting/*`) invoke
  `flutter pub get` — no Flutter binary exists in this sandbox
  (`which flutter` → exit 1). Untouched by this diff.

## Cycle 6 — gates

- **Phase**: GREEN @ 2026-09-11
- **Evidence**: `dart analyze` on all 23 changed Dart files →
  `No issues found!`; `dart format .` → idempotent
  (`Formatted 2707 files (0 changed)` on re-run; the initial pass also
  caught two PRE-EXISTING drift files — `tool/generate_openwiki_cli_docs.dart`,
  `example/test/tdd/004-login-ui/u1_test.dart` — now gate-clean).
