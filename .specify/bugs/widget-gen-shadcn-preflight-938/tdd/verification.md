feature: widget-gen-shadcn-preflight-938 (bug #938)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: e52739d8
behaviors: 1 (the widget-lane gen preflight; 4 acceptance scenarios + 7 unit pins)
proven: 1
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 1
criteria_covered: 1
mutation_score: null # no mutation tool wired (profile); deliberate-mutant sampling: 3/3 caught
mutants_survived: 0
suite: 68/68 chunks, 0 failures (chunked fast suite) + 11/11 bug-938 pins
---

# TDD Verification: widget gen shadcn preflight (bug #938)

**Verdict: PASS_WITH_GAPS.** The single behavior — `zfa tdd gen` (widget kind,
shadapp shell) must refuse with a machine-parseable `--> fix:` line before any
artifact when the project pubspec does not declare `shadcn_ui` — is pinned
through the real CLI entry point, the red is repo-recorded BEFORE the fix
(history corroborates the ordering; no squash), no HIGH smells, and all three
sampled deliberate mutants were caught. Gaps: mutation was sampled, not
measured, and this audit was produced by the same session that wrote the tests,
so it is not independent.

## Test-first evidence

Git history is the corroborating source (the rubric's strongest shape —
tests-only commit, then source commit):

- `041cce12` — tests + bug records ONLY (acceptance CLI pins + unit pins +
  `.specify/bugs/widget-gen-shadcn-preflight-938/{issue,assessment,red-evidence}.md`).
- `e52739d8` — the lib fix (`gen_command.dart` + `widget_scaffold.dart`).

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| Widget-lane gen preflights `shadcn_ui` and refuses with `--> fix:` before writing | PROVEN | cycle-log records the red run AT the tests-only tree (lib stashed): acceptance pin failed runtime-red (`Expected: not <0> / Actual: <0>`, `+3 -1`) and the unit pins compile-red (`Undefined name 'WidgetShadcnPreflight'`); green `+11` at the fix commit. The pre-fix CLI ground truth (gen emitted the pair; analyzer `uri_does_not_exist` at the emitted line 21) is in `red-evidence.md` |

Existing-test diff check: none touched. No assertion was weakened, no test
renamed/skipped, no threshold lowered. The three pre-existing pin tests in the
new acceptance file (declare-shadcn → success, materialapp → success,
no-pubspec → success) deliberately pin the UNCHANGED paths so the preflight
cannot over-refuse.

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | The `run` flow consumes gen's refusal as a generic step failure: the loop stops at `gen` with the fix line in the step log, but `run_command` does not parse `--> fix:` into a structured remedy hint. Stopping earlier-and-honestly is the intended behavior (issue #938 acceptance), yet surfacing the fix line as a first-class run outcome would be a follow-up improvement | `lib/src/plugins/tdd/commands/run_command.dart` (spawns gen as a step) |
| 2 | MED | Theme-kind behaviors boot shadcn shells too (`theme_harness_test_writer.dart` emits the shadcn_ui import) but are NOT covered by this preflight — deliberate scope: the issue names the widget lane and one-PR-per-bug; the theme harness documents its prerequisites in the emitted header. If issue #841's lane wants the same guard, it is a separate change | `lib/src/plugins/tdd/services/theme_harness_test_writer.dart:115-128` |
| 3 | LOW | The acceptance fixture seeds the DEPRECATED 6-column test-list dialect (same as the bug-830 fixtures it was modeled on), so each CLI pin emits a deprecation warning line | `test/plugins/tdd/commands/bug_938_widget_shadcn_preflight_test.dart` (`seedWidgetBehavior`) |

No HIGH smells. The two test files read cold: the hostile input (the exact
pubspec of a fresh zfa project) is a visible fixture; sentence test names match
the suite's conventions; no doubles at the entry point (real CliRunner, real
temp projects, real pubspec files); deterministic (temp dirs, no sleeps, no
network, no Flutter SDK needed). The probe is a pure function of the pubspec
text — refactoring-insensitive by construction.

## Mutation results

No mutation tool is wired (`.specify/memory/tdd-profile.md`), so per the rubric
Phase 4 fell back to deliberate-mutant sampling. All three target the new
logic's decision points. Each was applied, run, expected to fail, restored with
`git checkout --`, and the restore was verified by re-running both pin files
green (`+11`).

| Mutant | Guard it attacks | Survived | Judgment |
| ------ | ---------------- | -------- | -------- |
| `widget_scaffold.dart`: `projectDeclaresShadcnUi` returns `true` unconditionally (preflight neutered) | the refusal itself | No | caught (+3 −1: the acceptance pin gets exit 0 and written artifacts) |
| `gen_command.dart`: the `print(WidgetShadcnPreflight.fixLine)` removed | machine-parseable fix line on stdout | No | caught (+3 −1: verdict refuses but the `--> fix:` assertion fails) |
| `widget_scaffold.dart`: a pubspec with NO `dependencies:` section satisfies the probe | the empty-dependencies edge | No | caught (+5 −2: unit pins fail) |

The materialapp opt-out and the no-pubspec pass-through were not mutated (they
are one-line predicates directly asserted by their own pins).

## Traceability

Criterion = the issue's acceptance test: "on a shadcn_ui-less project, a
widget-lane gen stops with the named fix (exit non-zero, `--> fix:` line)
instead of emitting a test that can only die at compile."

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| Acceptance — refuse with `--> fix:`, zero artifacts, no registry append | `bug_938_widget_shadcn_preflight_test.dart` (shadcn-less pin) | Yes (CliRunner `zfa tdd gen`, real pubspec + registry asserted absent) |
| Determinism pins — declare-shadcn succeeds / materialapp exempt / no-pubspec unchanged | `bug_938_widget_shadcn_preflight_test.dart` (3 pins) | Yes (CliRunner gen; emitted content asserted) |
| Probe + fix-line contract | `bug_938_shadcn_preflight_unit_test.dart` (7 pins: declared/absent/empty/dev-deps/no-pubspec/fix-line shape/shell predicate) | Yes (real pubspec files on disk) |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The pre-existing analyzer diagnostics (all in `examples/`, Flutter-dependent):
  unrelated to this fix; branch errors are a strict subset of master's (33 →
  22, cache-dependent), none touch the changed files.
- The slow-tier folders excluded by the chunked fast suite by design
  (dart_test.yaml): not re-verified here.
- Mutation was a sample (3/3 on the new decision points), not a measurement.
- No fresh-context subagent was used for the smell pass; the audit is the
  author's own and reads as NOT independent.
- `zfa tdd init` adding shadcn_ui for Flutter baselines (the issue's "and/or"
  remediation): intentionally NOT implemented — the gen preflight alone
  satisfies the acceptance test; adding an init-time dependency write would
  widen this PR beyond the bug's one-fix scope.
