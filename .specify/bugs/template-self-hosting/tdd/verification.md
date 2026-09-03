---
feature: template-self-hosting (bug #912)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 452d1b72
behaviors: 5
proven: 0
likely: 5
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: null # no mutation tool wired (profile); deliberate-mutant sampling: 3/3 caught
mutants_survived: 0
suite: 2494 passed, 0 failed (62 chunks, 5 slow-tier-only skips) + 20/20 pin tests in 3.8s
---

# TDD Verification: template self-hosting (bug #912)

**Verdict: PASS_WITH_GAPS.** All five defects are pinned by tests that drive the
real CLI/`RouteBuilder` entry points, no HIGH smells, every criterion covered,
and all three sampled deliberate mutants were caught — but the test-first
evidence is session-recorded rather than repo-recorded (no cycle-log.md existed
for a bug-driven fix), mutation was sampled rather than measured, and this audit
was produced by the same session that wrote the tests, so it is not independent.

## Test-first evidence

Red evidence was generated in the working session BEFORE any fix was applied
(9 runtime failures across the migrate-paths + route-dry-run pins, plus 2
compile-failing pin files for the new API surface), but the feature branch's
history carries the fix commit (`3c78362d`) BEFORE the test commit
(`7eb82dd7`) — an artifact of splitting the delivery by file type. History
therefore cannot corroborate the ordering; per the rubric the classification
fails to `LIKELY`, not `PROVEN`.

| Behavior (defect) | Class  | Evidence |
| ----------------- | ------ | -------- |
| D1 apostrophe/literal safety | LIKELY | red: `bug_912_literal_safety_test.dart` compile-failed (`escapeDartString` absent) + persistence template produced unterminated literals; green: 5/5 at `452d1b72` |
| D2 MaterialApp vs ShadApp | LIKELY | red: shell pins compile-failed (`WidgetAppShell` absent); the default-shell expectation is behavior-red against the old template (MaterialApp hardcoded); green: 8/8 |
| D3 findsOneWidget placeholder | LIKELY | red: scaffold-marker + scenario-finder pins compile-failed; green: marker + `find.text` assertions asserted at `452d1b72`; make guard refuses scaffolded green (`MakeOutcome.scaffolded`) |
| D4 migrate-paths package URIs | LIKELY | red: 4/4 runtime failures (flat URI left dangling; no repair; false `migrated=1`; doctor said healthy); green: 4/4 |
| D5 route dry-run omission | LIKELY | red: 3/3 runtime failures (route-table test absent from dry-run changes list); green: 3/3 |

Existing-test diff check: `test/plugins/route/route_table_test_builder_test.dart`
"dry run does not write the route-table test" was rewritten to "dry run reports
the route-table test without writing it" — the old test pinned the DEFECT (the
omission this bug reports); the new assertion is strictly stronger
(`hasLength(1)` for the planned change) and keeps the no-write assertion. No
assertion was weakened, no test skipped, no threshold lowered.

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | make's scaffolded guard (the contract-green accounting exclusion) is only indirectly covered: `contentIsScaffolded` is unit-tested and the writer pins the marker, but no test drives `zfa tdd make` to `outcome=scaffolded` (no make-flow harness exists in the repo) | `lib/src/plugins/tdd/commands/make_command.dart` (guard), `lib/src/plugins/tdd/services/widget_scaffold.dart` |
| 2 | MED | the bug-912 gen CLI fixtures seed the DEPRECATED 6-column test-list dialect (copied from the bug-830 fixture), so every CLI pin emits a deprecation warning | `test/plugins/tdd/commands/bug_912_widget_shell_and_finders_test.dart` (`seedWidgetBehavior`) |
| 3 | LOW | the red/green evidence for this fix lives in the session transcript, not in the repo's evidence chain; a `tdd/cycle-log.md` entry in the bug dir would make the next audit independent | `.specify/bugs/template-self-hosting/` |

No HIGH smells. The four test files read cold: named constants for the hostile
corpus, sentence test names matching the profile's conventions, fixtures visible
in-file, no doubles at the entry points (CliRunner / RoutePlugin / RouteBuilder /
real registries), deterministic (temp dirs, no sleeps, no network).

## Mutation results

No mutation tool is wired (`.specify/memory/tdd-profile.md`), so per the rubric
Phase 4 fell back to deliberate-mutant sampling. Sampled 3 of 5 behaviors (the
escape function, the migrate rewrite, the dry-run discovery — the highest-risk
new logic). One small change each; each was run, expected to fail, restored
exactly, and the restore was verified by re-running the pin suites green.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `behavior_test_writer.dart`: drop the backslash escape case in `escapeDartString` | D1 | No | caught (+4 −1: trailing-backslash literal-safety pin fails to parse) |
| `migrate_paths_command.dart`: drop the package-URI rewrite in `_rewriteMovedTestReferences` | D4 | No | caught (+3 −1: package-URI rewrite pin fails) |
| `route_builder.dart`: drop `pendingModules` from `_generateRouteTableTest` | D5 | No | caught (+0 −3: every dry-run pin fails) |

D2 and D3 were NOT mutation-sampled (their new logic is template string
assembly; the content pins assert the emitted source directly).

## Traceability

Criteria are the five defects of the live defect register
(`.specify/bugs/template-self-hosting/issue.md`); each is tested through the
real entry point (CliRunner-driven `zfa tdd gen/migrate-paths/doctor` or the
`RoutePlugin`/`RouteBuilder` API — the same surface production uses).

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| Required 1 — escaping/literal-safety pin per template | `bug_912_literal_safety_test.dart` (4 template pins + escape-axis pin) | Yes (writer renders, analyzer parses) |
| Required 2 — shell-configurable widget template, ShadApp default | `bug_912_widget_shell_and_finders_test.dart` (writer + CLI + .zfa.json pins) | Yes (CliRunner gen) |
| Required 2 — scenario-derived finders, scaffolded excluded from contract-green | `bug_912_widget_shell_and_finders_test.dart` (finder + marker pins); make guard: indirect (finding 1) | Partially (finding 1) |
| Required 3 — migration self-check + doctor drift | `bug_912_migrate_paths_package_uris_test.dart` (rewrite/repair/refusal pins + doctor drift pin) | Yes (CliRunner migrate-paths/doctor) |
| Required 4 / defect 5 — dry-run changes list includes the route-table test | `bug_912_route_dry_run_route_table_test.dart` (builder + capability plan pins) | Yes (RouteBuilder + capability plan) |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The pre-existing `examples/` analyzer errors (22, Flutter-dependent) and the
  pre-existing `entity_help_test.dart` unused-import warning: unrelated to this
  fix, not audited (flagged as pre-existing on master).
- D2/D3 deliberate mutants were not sampled (see above); mutation was a sample,
  not a measurement.
- The 5 slow-tier-only folders (benchmark, core/dependencies, integration,
  plugins/tdd/scenarios, property) were skipped by the chunked fast-tier run by
  design (dart_test.yaml); their behavior is not re-verified here.
- No fresh-context subagent was used for the smell pass; the audit is the
  author's own and reads as NOT independent.
- Performance/latency of the changed paths: not assessed (no criterion).
