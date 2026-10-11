# TDD verification — bug 1260 (tdd certified vocabulary not emitted)

- **Verdict: `passed`** (exit 0)
- Generated FRESH from the actual run in this session (2026-09-07,
  Dart 3.13.3 stable, branch `fix/1260-tdd-certified-vocabulary-not-emitted`).
- Engine detection (speckit.tdd.verify Step 0): `zfa --version` →
  `zfa v6.1.0`; repo root carries **no `.zfa.json`** → the deterministic
  `zfa tdd verify --feature` dispatch is unavailable for this BUG-slug
  context (the resolver reads `specs/<feature>/tdd/test-list.md`); the
  audit below is the command's sanctioned FALLBACK path: test-first
  evidence, red-phase evidence, test-smell rubric, mutation testing on the
  changed files, acceptance-criteria coverage.

## 1. Test-first evidence (git history)

- `f5b40905` — `test(1260): pin the certified vocabulary red …` — the three
  failing test files + the bug records, committed BEFORE any fix code.
- `f71879cd` — `fix(1260): emit and require zuraffa_ui / ZuraffaApp …` —
  the minimal fix, committed after the red was recorded.

`git log --oneline` proves the tests existed and failed before the
implementation. Red-phase transcript: `red-evidence.md` (13 failures /
4 pre-#1260 pins green, each failing for the RIGHT reason — missing
option, shadapp fallback, absent preflight — never a compile error).

## 2. Final suite state (this session)

- New bug-1260 suites: **17/17 pass**
  (`bug_1260_zuraffaapp_widget_shell_test.dart` 8,
  `bug_1260_skin_dependency_patcher_test.dart` 4,
  `bug_1260_app_shell_zuraffa_app_test.dart` 5).
- Regression sweep over every chunk touched by the change (kernel cache
  cleared between chunks; the chunked-runner discipline from
  `tools/run_tests_chunked.sh`): config 10, cli 204, app_shell 88,
  tdd/commands 343, tdd/corpus_economics 53, tdd/models 81, tdd/theater
  15, tdd/services 746, tdd root 377, commands 306 — **2223 passed, 0
  new failures**. Untouched chunks were not run (cloud-agent rule: only
  test what you changed).
- `dart analyze` on all 8 changed/new lib files: **No issues found**.
- `dart format`: **0 remaining diffs** on all changed/new files (3
  pre-existing spec-1142 evidence files flagged by the newer dart_style
  were deliberately REVERTED — committed evidence is not reformatted).

## 3. Test-smell rubric (new suites)

| Smell | Verdict |
|---|---|
| Vacuous assertions (green by a bare SizedBox / trivially true) | none — every acceptance asserts emitted content (`pumpWidget(ZuraffaApp(`, `package:zuraffa_ui` import, `Router.withConfig`, pubspec entry, exit codes) |
| Asserting on mocks only / tautologies | none — fixtures are real temp projects, the real `CliRunner` dispatches real commands, real pubspec bytes are patched |
| Change-detector / over-specified byte pins | controlled — `contains` on the contract-relevant emission only; byte-compat pins use `isNot(contains)` on the OLD surface (regression guards, not change detectors) |
| Hidden ordering / shared state | none — every test builds its own `Directory.systemTemp` fixture with `addTearDown`/`tearDown` cleanup |
| Non-hermetic (network, cwd mutation, global exit code) | none — `CliRunner(exitOnCompletion: false)` + `--project`/`--root` flags; `runCapturing` hermeticity contract (spec 1008) |
| Right-reason reds | verified — each red failure message names the missing certified surface (see red-evidence.md) |

## 4. Mutation testing (changed files — real run, 4/4 killed)

| Mutant | File | Mutation | Target suite | Result |
|---|---|---|---|---|
| M1 | `widget_scaffold.dart` | `parse('zuraffaapp')` collapses into the `_ => shadapp` fallback | bug_1260 widget shell | **KILLED** (exit 1) |
| M2 | `gen_command.dart` | skin-lane default `return WidgetAppShell.zuraffaapp` deleted (`if (false)`) | bug_1260 widget shell | **KILLED** (exit 1) |
| M3 | `pubspec_skin_dependency_patcher.dart` | certified constraint `'^0.1.0'` → `'^9.9.9'` | bug_1260 patcher | **KILLED** (exit 1) |
| M4 | `app_shell_builder.dart` | `zuraffaApp ? certifiedShell : …` → `false ? certifiedShell : …` | bug_1260 app shell | **KILLED** (exit 1) |

No surviving mutants; no remediation tasks appended. Kill transcripts:
`/tmp/mutant_M{1..4}_run.log` (session artifacts).

## 5. Acceptance-criteria coverage (assessment remediation)

| Remediation point | Covered by |
|---|---|
| 1a. `--widget-shell` gains `zuraffaapp` (accepts the option, emits `ZuraffaApp` + `package:zuraffa_ui` import) | bug_1260 widget shell: `explicit --widget-shell zuraffaapp` |
| 1b. skin-lane projects DEFAULT to the certified shell | bug_1260 widget shell: `skin-lane project … DEFAULT`; M2 kills the regression |
| 1c. certified gen refuses (machine-parseable `--> fix:`) when the target lacks `zuraffa_ui` | bug_1260 widget shell: `project without zuraffa_ui: refuses BEFORE writing` |
| 1d. `.zfa.json tdd.widgetShell: "zuraffaapp"` honored | bug_1260 widget shell: config-default test |
| 1e. pre-#1260 shells unchanged (shadapp default / materialapp opt-out) | bug_1260 pins + bug_912 suite (green) |
| 2a. `zfa tdd init --skin` adds `zuraffa_ui ^0.1.0` under `dependencies:` | bug_1260 patcher: `--skin adds zuraffa_ui` (runtime, not dev) |
| 2b. idempotent; explicit opt-in (no forced dependency) | bug_1260 patcher: idempotency + `WITHOUT --skin` pins |
| 2c. loud pure-Dart misfire naming the dependency | bug_1260 patcher: pure-Dart test |
| 3a. `zfa app shell --zuraffa-app` emits the certified shell (GoRouter functional beneath via `Router.withConfig`) | bug_1260 app shell: mount test (+ M4) |
| 3b. preflight `zuraffa_ui` before any write | bug_1260 app shell: refusal test |
| 3c. `--skin-audit` / `--xray` compose; flagless emission byte-compat | bug_1260 app shell: compose tests + no-regression pin |
| Hard constraint: `zuraffa_ui` reachable from the toolchain | `grep -r zuraffa_ui lib/src` now hits 7 files: widget_scaffold.dart, behavior_test_writer.dart, gen_command.dart, init_command.dart, pubspec_skin_dependency_patcher.dart, app_shell_command.dart, app_shell_builder.dart (verified by byte-level scan this session) |

## Gate

**passed** — test-first discipline proven by git history, honest reds,
no test smells, 4/4 mutants killed, acceptance criteria covered, suite
green (2223 regression + 17 new), analyzer and formatter clean.
