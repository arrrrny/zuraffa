feature: specs/1186-tdd-plan-grammar-markers (issue #1186, branch spec/1186-tdd-plan-grammar-markers)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree @ spec/1186-tdd-plan-grammar-markers (+ this feature)
behaviors: 7
proven: 7
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 7
criteria_covered: 7
mutation_score: 6/6 detectable mutants killed # scope: spec_marker_emitter.dart (kind hard-code, fence-check removal, marker-before-header inversion) + plan_command.dart (--no-emit-markers ignored, emission hoisted above the gates, fallback-kind recording removed) — deliberate manual mutants, each applied to the working tree, each killed by the named test in plan_marker_emission_1186_test.dart, then reverted (restoration byte-diff verified; final tree re-analyzed clean and re-passed 14/14)
mutants_survived: 0
equivalent_mutants: 1 # emitter idempotency guard (`_blockDeclaresMarker` removed): UNREACHABLE — a fallback-routed scenario whose block carries a parseable `**Type**` line cannot exist (a parseable marker routes the behavior declared at rung 1, so it never lands in `wanted`), and the walks that could disagree refuse earlier (duplicate-marker / outside-scenario StateErrors at declaration-parse time). The guard stays: it is the belt-and-braces net against future walk drift between the emitter and `parseScenarioTypeMarkers`, the exact drift class this repo keeps paying for
suite: "plan_marker_emission_1186_test.dart 14/14; plan_routing_provenance_test.dart + plan_gen_contract_test.dart + plan_lanes_1000_test.dart 28/28 (071 contract unchanged); chunked fast suite: 90 chunks — 84 passed, 6 skipped (no fast-tier tests), 0 failed; dart analyze: 135 issues on branch == 135 on master (0 new; all 31 errors pre-existing examples/ Flutter-resolution); dart format .: idempotent (0 changed on re-run), git diff --stat shows only the intentional changes"

---

# TDD Verification: issue #1186 — `zfa tdd plan` emits the routing grammar markers (one-time migration, `--strict-routing` usable)

**Verdict: PASS.** The red→green cycle is real: the RED phase was captured
against the unmodified tree (11 failures: the emission suite's 7 behavioral
tests plus the 4 template-grammar tests, all failing because neither the
emission API nor the template grammar existed), and GREEN was driven by the
new `SpecMarkerEmitter` + plan wiring + template update. Six deliberate
mutants were each killed by a named test; the seventh was analyzed as an
equivalent mutant and documented. The hard constraints hold: the routing
resolver's declared/fallback semantics are untouched (071 provenance tests
pass 28/28), a refused plan still writes no artifact and now provably
mutates no file, and the strict gate still refuses genuinely undeclared
specs.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B1 — a fallback-routed scenario gets its classified `**Type**` marker persisted into spec.md after a successful plan; this run still labels the fallback honestly | PROVEN | RED captured: `expected spec contains '**Type**: widget'` failed pre-fix (the emission API did not exist — `SpecMarkerEmitter` was not importable). GREEN: run 1 exits 0, prints `[fallback: ... add \`**Type**: widget\` ...]` AND `emitted 1 \`**Type**\` marker(s) ... (issue #1186)`, and spec.md gains `   **Type**: widget` directly after the scenario header (marker index asserted > header index, inside the block). Live CLI session below. |
| B2 — the migration is one-time: the re-run routes `[declared: type marker]` with zero fallback lines | PROVEN | Second plan run: exit 0, `isNot(contains('[fallback:'))`, `contains('[declared: type marker')`, and exactly one `**Type**: widget` in the spec (idempotent — never a duplicate). |
| B3 — strict-routing becomes usable: plan (migration) then `--strict-routing` exits 0 on the same spec | PROVEN | Run 3 (live CLI + test B3): exit 0, every route `[declared:]`, no fallback. Without B1's migration run this is exactly the issue's symptom: `undeclaredStrict for behavior "A1" (strict mode)` (exit 1, asserted by B6). |
| B4 — acceptance-lane scenarios emit `**Type**: acceptance` (the classified lane, not a guess) | PROVEN | A plain business-outcome scenario (no UI verbs → acceptance lane) emits `**Type**: acceptance`. Mutant M2 (kind hard-coded to `acceptance`) killed by B1/B4 — the widget tests fail. |
| B5 — scenarios already carrying a marker are never re-declared | PROVEN | Block-level assertions prove A1 keeps only its pre-existing `**Type**: acceptance` and contains no widget marker, while A2 contains the migrated `**Type**: widget`. No duplicate-marker refusal (that refusal would exit 2). |
| B6/B7 — a refused plan never touches the spec (strict gate exit 1; skin-contract gate exit 2) | PROVEN | Byte-equality of spec.md before/after each refusal. Mutant M4 (emission hoisted above the gates) killed by B7 — the skin-contract refusal mutated the spec first. The migration only ever rides a SUCCESSFUL plan. |
| B8 — fenced scenario examples are documentation, never marked | PROVEN | A spec whose `Acceptance Scenarios` embed a fenced ```markdown example migrates only the real scenario; the fence stays marker-free across re-runs (marker count stays 1, positioned before the fence). Mutant M7 (fence check removed) killed by B8. |
| B9 — `--no-emit-markers` leaves the spec untouched | PROVEN | Byte-equality with the flag; output still labels the fallback (the labeling is unchanged — only the migration is skipped). Mutant M3 (flag ignored) killed by B9. |
| B10 — manual scenarios consume their AC number and are never marked | PROVEN | Block-level assertions prove the A1 `(manual: QA)` block contains no marker and the automated A2 block contains the migrated `**Type**: acceptance` marker. |
| T1–T4 — the speckit spec template emits the strict grammar | PROVEN | RED captured pre-fix (all 4 failed against the old template). GREEN: the template's scenario examples carry `**Type**: acceptance` with routing guidance; `## Layer Contracts` exists (bare heading — the parser's `layer contracts$` regex); the Key Entities heading is bare `### Key Entities` (the suffixed `*(include if...)*` form never matched `key entities$` — same drift family as #1183) and uses the 3-column table so entity rows register as contract rows; the FR section demonstrates `traces:` continuations. The template's own placeholder pair (FR-002 `traces: Validator` ↔ Function row `Validator`) resolves — the template is strictly routable by construction. |

## Red-phase evidence (verbatim, pre-fix tree)

```text
$ dart test test/plugins/tdd/commands/plan_marker_emission_1186_test.dart
00:00 +0 -11: Some tests failed.

Failing tests:
  ... a fallback-routed scenario gets its classified `**Type**` marker persisted ...
  ... a manual scenario consumes its AC number and is never marked ...
  ... an acceptance-lane scenario emits `**Type**: acceptance` ...
  ... scenarios already carrying a marker are never re-declared ...
  ... the migration is one-time ...
  ... strict-routing becomes usable ...
  ... --no-emit-markers leaves the spec untouched ...
  #1186: the speckit spec template emits the strict grammar (×4:
        scenario **Type** markers / ## Layer Contracts / bare
        Key Entities heading / traces: grammar)
```

(The last two behavioral tests — the strict/skin refusal-mutates-nothing pair
— were added during GREEN and are proven by the mutation cycles M4 below;
they did not exist at RED time. This is stated here rather than implied.)

## Live CLI session (post-fix, one fixture, three runs)

```text
### RUN 1 — plain plan (the one-time migration)
$ zfa tdd plan 1186-demo --project /tmp/verify1186
zfa tdd plan: emitted 1 `**Type**` marker(s) into the spec — one-time routing
  migration (issue #1186) for A1 (spec: /tmp/verify1186/specs/1186-demo/spec.md).
  Re-run `zfa tdd plan`; the migrated scenarios now carry their declared lane.
   route: A1 -> widget lane [fallback: legacy description classifier matched —
     add `**Type**: widget` to the scenario]
   route: U1 -> unit lane (func surface) [declared: contract row: Formatter, spec line 8]
   route: contract:A1 -> contract lane [declared: layer contracts section]
EXIT: 0

spec.md after run 1 (tail):
1. **Given** the app **When** it starts **Then** the page shows the settings form.
   **Type**: widget

### RUN 2 — plain re-run (zero fallback lines)
   route: A1 -> widget lane [declared: type marker, spec line 18]
   route: U1 -> unit lane (func surface) [declared: contract row: Formatter, spec line 8]
EXIT: 0

### RUN 3 — strict-routing (usable on the speckit-authored spec)
$ zfa tdd plan 1186-demo --project /tmp/verify1186 --strict-routing
   route: A1 -> widget lane [declared: type marker, spec line 18]
   route: U1 -> unit lane (func surface) [declared: contract row: Formatter, spec line 8]
EXIT: 0

### The issue's symptom, still honest on an UN-migrated spec:
$ zfa tdd plan 1186-demo --project /tmp/verify1186b --strict-routing
zfa tdd plan: undeclaredStrict for behavior "A1" (strict mode).
behavior "A1" has no routing declaration (strict mode): no `**Type**` marker,
  no contract-row trace, no test-list kind declaration.
   --> fix: add `**Type**: unit` (or widget/ffi/...) to the scenario, or trace
     it to a declared contract row.
EXIT: 1
```

## Mutation results (deliberate manual mutants, real apply→test→revert cycles)

| # | Mutant (file) | Change | Killed by | Result |
| --- | --- | --- | --- | --- |
| M1 | spec_marker_emitter.dart | duplicate-marker guard removed (`_blockDeclaresMarker` → always false) | — | EQUIVALENT (unreachable: a parseable marker in a fallback-routed block cannot exist — it would route the behavior declared at rung 1; walk disagreements refuse earlier). Guard kept as walk-drift insurance. |
| M2 | spec_marker_emitter.dart | classified kind ignored — every emission hard-codes `acceptance` | B1, B4 (+1 more) | KILLED |
| M3 | plan_command.dart | `--no-emit-markers` ignored (`if (true)`) | B9 | KILLED |
| M4 | plan_command.dart | emission block hoisted above the strict gate (refusals mutate the spec) | B7 (skin-contract refusal) | KILLED |
| M5 | plan_command.dart | fallback kinds never recorded (`fallbackKinds[b.id] = decision` removed) | B1 (+6 more) | KILLED |
| M6 | spec_marker_emitter.dart | marker emitted BEFORE the header line (outside the scenario block → parser refusal) | B1 (+4 more) | KILLED |
| M7 | spec_marker_emitter.dart | fence check removed (fenced example receives a marker) | B8 | KILLED |

Score: 6/6 detectable mutants killed, 0 survived, 1 equivalent documented.
Restoration after each cycle verified by byte-diff against pre-mutation
copies; the final tree re-passes `dart analyze` (No issues on the changed
files) and the 14/14 feature suite.

## Test-smell rubric (self-check)

- **Test-after / no-test**: none — 11 of 14 tests existed in RED form
  (failing) before the implementation files were created; the 3 added during
  GREEN (strict-refusal, skin-refusal, fenced-example) are each proven to
  have teeth by a killed mutant (M4, M4, M7).
- **Assertion shopping**: assertions pin exact contracts (byte-equality on
  refusals, marker counts, marker-inside-block position, exit codes,
  absence/presence of `[fallback:`), not loose `contains` on incidental
  output.
- **Tautology**: none — B2 re-proves the declared route through the REAL
  resolver (not the emitter's opinion), and the mutants each changed
  observable behavior a specific assertion caught.
- **Shared mutable fixtures**: every test builds its own temp project
  (`Directory.systemTemp.createTempSync`) and deletes it in `finally`.
- **Over-mocking**: none — tests drive the real `CliRunner` against real
  files on disk; no fakes on the path under test.

## Acceptance-criteria coverage

| Criterion (issue #1186 deliverable) | Covered by |
| --- | --- |
| plan emits markers post-classification (fallback → one-time migration) | B1, B2, B4, B5, B9, B10 + live RUN 1/RUN 2 |
| speckit template emits `**Type**` + `## Layer Contracts` | T1–T4 (+ bare Key Entities heading, same drift family) |
| `--strict-routing` works (usable on speckit-authored specs) | B3 + live RUN 3; the unmigrated refusal (exit 1) stays honest |
| refusals never mutate the spec (071 round-2 fix 3a extended) | B6, B7 (M4 killed) |
| fenced/manual scenarios never mis-declared | B8, B10 (M7 killed) |

7/7 behaviors covered, 0 gaps. `zfa tdd plan`'s own traceability hash is
unaffected by the migration: `SpecContractHash` hashes the requirement
statement lines only, and an inserted `**Type**` marker is not a statement —
the hash is identical pre/post migration, so verify/corpus drift checks stay
exact.

## Constraints audit

- **One PR**: all work lands as a single PR closing #1186.
- **Routing semantics unchanged**: `RoutingResolver`, `SpecParser` walks, the
  strict gate codes (`undeclaredStrict`), and the `[fallback: ...]` label
  text are untouched; 071's provenance suite passes 28/28. The migration is
  strictly additive: ONE inserted line per undeclared scenario, everything
  else byte-preserved.
- **Errors-are-an-API preserved for the exercised refusal paths**: the strict
  and skin-contract refusals happen before any write, and B6/B7 prove byte
  equality of spec.md before and after those refusals.
- **U-lane honesty**: unit behaviors are NOT migrated (a classifier cannot
  invent a contract-row name — a wrong guess would dangle or misroute);
  their fallback line keeps the `trace FR to a declared contract row` hint,
  and the template now teaches the `traces:` grammar from birth.

## Suite health (this session)

- `plan_marker_emission_1186_test.dart`: **16/16** (14 original checks plus
  output-failure and reconciled-ID regressions).
- `plan_routing_provenance_test.dart` + `plan_gen_contract_test.dart` +
  `plan_lanes_1000_test.dart` (the 071 regression core): **28/28**.
- `tools/run_tests_chunked.sh` (fast suite, run chunk-wise): **90/90 chunks
  — 84 passed, 6 skipped (no fast-tier tests), 0 failed**.
- `dart analyze`: 135 issues on the branch == 135 on master (0 new; all 31
  `error -` lines are the pre-existing `examples/` Flutter-SDK-resolution
  failures documented in bug #942's verification).
- `dart format .`: idempotent (0 changed on re-run); `git diff --stat` after
  formatting shows only the intentional changes
  (spec-template.md, plan_command.dart) plus the two new files.
