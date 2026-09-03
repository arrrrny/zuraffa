# Cycle Log

Baseline seeded at tasks commit `7661604a` (2026-09-03). Baseline suite:
`dart test test/plugins/tdd` fast tier — to be recorded by T001 before any
behavior work (expected green at `37a46c5b`; any pre-existing red is a Phase-0
escape hatch and stops the loop).

Behaviors: 8 (A1–A4 outer, U1–U4 inner) — all PENDING. Driven one at a time,
test task first (RED recorded here), then the implementation tasks that flip it
(GREEN recorded here), per the test-list task mapping.

## Cycle: T001 baseline

- command: `dart test test/plugins/tdd`
- exit: 0 — `02:09 +879: All tests passed!`
- at: 2026-09-03 (tree at 37a46c5b, branch 071-declared-intent-routing)

## Cycle: U1 (red -> green)

- behavior: U1 — RoutingResolver ladder (precedence, per-aspect, refusals, strict, determinism)
- criterion: FR-001, FR-009, FR-011
- test: test/plugins/tdd/services/routing_resolver_test.dart
- red: 2026-09-03 — load failure pre-implementation (new API surface; missing routing.dart/RoutingResolver), `+0 -1: Some tests failed.`
- green: 2026-09-03 — `00:00 +15: All tests passed!` after T002 (models/routing.dart), T003 (Signature.parse), T004 (RoutingResolver)
- tasks ticked: T002, T003, T004, T005

## Cycle: U2 (red -> green)

- behavior: U2 — scenario `**Type**` marker parsing
- criterion: FR-002
- test: test/plugins/tdd/services/spec_parser_declarations_test.dart
- red: 2026-09-03 — `+0 -1` load failure (parseScenarioTypeMarkers absent)
- green: 2026-09-03 — `+6: All tests passed!` (T008; two initial line-number expectations off by one — Dart strips the multiline-string leading newline; fixed the TEST arithmetic, implementation unchanged)
- tasks ticked: T006, T008

## Cycle: A1 (red -> green)

- behavior: A1 — declared lanes route end-to-end; prose never overrides a declaration; reworded prose routes identically; undeclared keeps legacy fallback
- criterion: FR-001, FR-013, SC-001
- test: test/plugins/tdd/commands/plan_routing_provenance_test.dart
- red: 2026-09-03 — `+2 -2`: marker-unit + "renders the widget" prose routed acceptance (declaration ignored); marker-widget + non-UI prose routed acceptance; the two fallback-window pins were green pre-change as required
- green: 2026-09-03 — `+10: All tests passed!` (T009: `_extractAcceptance` consults `parseScenarioTypeMarkers` before the #830 classifier; T010 needed NO change — the plan render is already kind-driven (bug #830 machinery), so declared kinds flow to the widget section through the parse)
- tasks ticked: T007, T009, T010, T011

## Cycle: U3 (red -> green)

- behavior: U3 — `**Function**` Layer Contracts bullet parses into function-kind rows with declared signatures; malformed signature refuses naming the row
- criterion: FR-003, FR-005
- test: test/plugins/tdd/services/function_contracts_parsing_test.dart
- red: 2026-09-03 — `+0 -1` load failure (parseContractRows absent)
- green: 2026-09-03 — `+4: All tests passed!` (T014; one iteration: domain rows declare `->` signatures too per the #919 grammar, so signature parsing covers every layer row with the malformed-refusal scoped to function rows)
- tasks ticked: T012, T014

## Cycle: A2 (red -> green)

- behavior: A2 — generation surfaces/signatures/entity attribution from declared contract rows; undeclared keeps legacy routing
- criterion: FR-004, FR-005, FR-007
- test: test/plugins/tdd/services/generation_planner_declared_test.dart + test/plugins/tdd/commands/func_declared_signature_test.dart
- red: 2026-09-03 — planner pins `+0 -1` load failure (BehaviorSummary lacked traces/declarations); func pin `+0 -1` for the right reason (subject scaffolded `String` by prose, declared `bool`)
- green: 2026-09-03 — planner `+5: All tests passed!` (T015: resolver-first in plan(), surface-keyed declared plans, legacy branches as labeled fallback); func `+10: All tests passed!` across both files (T016: DeclaredRouting.declaredSignatureFor feeds the declared signature; deriver demoted to fallback); services regression 526 green; #950/#835 planner pins re-green
- notes: one pin fixed its own expectation (U-id dispatch precedes description branches per #718 — used a non-U id to exercise the description-keyed legacy branch); make wiring of declarations lands with strict mode (T027) per tasks.md
- tasks ticked: T013, T015, T016, T017

## Cycle: U4 (red -> green)

- behavior: U4 — persistence marking from declarations (`[persistent]` tag, storage-dependency trace); storage vocabulary without a declaration stays unmarked
- criterion: FR-006
- test: test/plugins/tdd/commands/persistence_declaration_test.dart
- red: 2026-09-03 — `+1 -2`: tag unparsed, keyword-marked vocabulary (AC2 violated); the storage-trace pin was green pre-change only via the 'offline' keyword — coincidence, replaced by the declaration trigger
- green: 2026-09-03 — `+3: All tests passed!` (T019: parsePersistenceDeclarations + tag stripping in _extractUnit; T020: _marked consults declarations, keyword trigger retired per spec AC2)
- CONTRACT CHANGE (spec-sanctioned, not a weakened pin): plan_persistence_marking_833_test.dart re-pointed to the declared contract — its keyword-wording pins now declare `[persistent]`; added an explicit vocabulary-unmarked pin; mark shape/idempotency/non-persistence default unchanged (#833 family 14/14 green). matchesKeywords remains exported (read-side extract unchanged); its removal is a follow-up.
- tasks ticked: T018, T019, T020, T021

## Cycle: A3 (red -> green)

- behavior: A3 — per-behavior routing provenance (stdout route: lines + persisted artifact block)
- criterion: FR-008, SC-003
- test: test/plugins/tdd/commands/plan_routing_provenance_test.dart (A3 group)
- red: 2026-09-03 — `+4 -3`: no route: lines existed
- green: 2026-09-03 — `+7: All tests passed!` (T023: plan_command parses declarations, resolves per behavior via RoutingResolver, renders declared/fallback lines + `## Routing provenance` artifact block); commands fast tier 150 green
- fixes during green: provenance emitted via print (runCapturing intercepts zone print, not stdout.writeln); parse-time sniffer kind is NOT passed to the resolver as rung-3 declared kind (only the marker is — the sniffer outcome is the fallback being labeled)
- tasks ticked: T022, T023, T024

## Cycle: A4 (red -> green)

- behavior: A4 — strict mode: --strict-routing refuses undeclared intent (plan + make); declared specs run clean
- criterion: FR-010, FR-011, SC-004, SC-002
- test: test/plugins/tdd/commands/plan_routing_provenance_test.dart (A4 group) + test/plugins/tdd/make_command_strict_071_test.dart
- red: 2026-09-03 — `+7 -2`: `Could not find an option named "--strict-routing"` (flag absent)
- green: 2026-09-03 — plan pins `+9: All tests passed!`; make strict pin `+1: All tests passed!`; full fast tier 923 green (+44 new); #939/#950 slow widget suites 5/5; analyze clean
- design refinements during green (recorded): (1) strict passes through plan_command to resolver.resolve (initially omitted — refusals never armed); (2) parse-time sniffer kind is never resolver-declared (it IS the fallback); (3) widget rows are exempt from the strict surface requirement — a declared widget lane routes to the view builder (issue #939), whose unexpressible-primary-plan is routing, not a strict failure; make's strict gate therefore refuses only resolver failures (reason carries `--> fix:`); (4) make parses spec declarations fail-closed (missing spec = empty declarations = everything undeclared under strict)
- tasks ticked: T025, T026, T027, T028

## Cycle: quickstart validation (T031)

- Scenarios 1-5 of quickstart.md executed against a scratch project (/tmp/qs071):
  declared widget+renders -> widget lane [declared: type marker, spec line 19];
  function row -> func surface [declared: contract row: Formatter]; storage-free
  vocabulary unmarked; strict flip on undeclared U2 -> exit 1 with `--> fix:`;
  dangling trace + undeclared -> BOTH refusals printed, exit 1.
- BUG FOUND BY VALIDATION: multiple strict refusals collided on a shared
  '__refused__' key (last overwrote first). Fixed: refusals accumulate. Full
  fast tier re-green after fix.
- tasks ticked: T031

## Cycle: T032 final sweep

- `dart test test/plugins/tdd` — 923/923 green (post-format)
- `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` — no issues
- `dart format` — touched files clean

## Cycle: review fixes (CodeRabbit #958)

- 4 review findings applied to the branch:
  1. routing_resolver.dart — a method-qualified trace naming an undeclared method now refuses (danglingReference + fix line) instead of silently using the row's first signature; pinned (U14).
  2. make_command.dart — the CLI-surface happy path for declared routing is now pinned (make_command_declared_071_test.dart), and the pin immediately caught TWO real wiring gaps: (a) make never passed the row's trace tokens into the summary (added `_rowTraces`), (b) parseContractRows read Key Entities as bullets instead of the zuraffa-1.0 TABLE form. Both fixed.
  3. declared_routing.dart — feature dir built with p.join.
  4. func_command.dart — the prose deriver runs only on the fallback branch.
- post-fix sweep: fast tier 924/924, slow widget suites 5/5, analyze clean, format clean
