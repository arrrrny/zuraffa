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
