# Quickstart: Validate Declared-Intent Routing

End-to-end validation scenarios for feature 071. Prerequisites: the zuraffa CLI
built (`dart run bin/zfa.dart --version` or a `zfa` on PATH), a scratch project
with the TDD plugin initialized (`zfa tdd init`), and a spec in the zuraffa-1.1
shape exercising the declarations below.

Full commands and expected outcomes live in the feature's tests
(`test/plugins/tdd/services/routing_resolver_test.dart`,
`test/plugins/tdd/commands/plan_routing_provenance_test.dart`); this guide is the
manual walk-through of the same scenarios.

## Scenario 1 — Prose never decides (the #950/#936 replay)

1. Write a spec whose scenario says `**Then** the widget renders "Order placed".`
   with a `**Type**: widget` marker.
2. Run `zfa tdd plan <feature> --strict-routing`.
3. Expect: the behavior routes to the widget lane, provenance says
   `[declared: type marker, …]`; the func surface is never planned — despite
   `renders` being a function verb.
4. Reword the scenario (past tense, synonyms: "rendered", "displayed") without
   touching declarations, re-plan: the `route:` lines are identical.

## Scenario 2 — Contract rows decide surfaces and signatures (the #920 replay)

1. Declare a function contract row `format: format(Template) -> String` and trace
   an FR to it.
2. Run `zfa tdd gen <behavior>` / `zfa tdd func <behavior>`.
3. Expect: the scaffolded subject returns the declared `String` — never the
   heuristic-integer placeholder; provenance names the contract row.

## Scenario 3 — Persistence only by declaration (the #833 replay)

1. Write FR-A: "caches the result for display" (no declaration) and FR-B:
   "[persistent] The cart survives an app restart."
2. Run `zfa tdd plan <feature>`.
3. Expect: FR-B's row carries the ` [persistence]` mark with declared provenance;
   FR-A is unmarked despite the storage word.

## Scenario 4 — Provenance and the strict flip

1. Plan a mixed spec WITHOUT `--strict-routing`: every behavior prints a `route:`
   line; legacy-keyword routes read `[fallback: … matched — declare …]`.
2. Re-run with `--strict-routing` while one behavior remains undeclared: expect a
   refusal naming the spec line and `--> fix:` with the marker/trace to add.
3. Declare that behavior, re-run strict: exit 0; every route reads `[declared: …]`.

## Scenario 5 — Conflicts and dangling rows refuse loudly

1. Give one scenario both a `**Type**: widget` marker and a trace to an entity
   row → plan must refuse: `declaration-conflict` naming both lines.
2. Trace a scenario to `NonexistentRow` → refuse: `dangling-reference` naming the
   reference and line.

## Regression guards

- A zuraffa-1.0 spec with no new declarations routes as today (plus `[fallback:]`
  provenance) — the migration-window contract (SC-005).
- Structural parsing unaffected: existing suites
  (`test/plugins/tdd/services/spec_parser_test.dart`, `test_list_reader` suites,
  `generation_planner_test.dart`) stay green.
