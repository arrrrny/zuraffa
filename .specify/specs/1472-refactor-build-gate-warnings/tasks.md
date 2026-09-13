# Tasks: 1472-refactor-build-gate-warnings

MVP-first: the deadlock (SC-1..SC-4) ships before the opt-out (SC-5) and the
binary pin (SC-6). Test tasks are mandatory and ordered before the behaviour
they prove (TDD extension).

## 1. MVP — the deadlock fix (SC-1..SC-4)

- [ ] T001 (test, RED) `test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`
      unit behaviors U-1472-1..U-1472-7 through the fake `ProcessExecutor`:
      warnings-only refusal continues (format+fix run); errors refuse; other
      failure classes refuse; message/parser disagreement refuses;
      `warningsBlocking` opt-in refuses; timeout and spawn-failure refuse;
      accurate-counts log line asserted via captured `print`.
- [ ] T002 (test, RED) acceptance A-1472-1 through `TddFixture` + `CliRunner`:
      green preflight + fake zfa `build` printing the warnings-only refusal
      with exit 1 → refactor completes outcome=(clean|refactored) exit 0 and
      the fix pass runs (pre-fix: outcome=runner-error exit 1).
- [ ] T003 (code, GREEN) `refactor_passes.dart`: warnings-only gate
      reinterpretation in `RefactorPasses.run()` (verdict-line regex +
      `BuildCommand.analyzeReportsError` cross-check + timeout/spawn guards +
      accurate-counts logger); `warningsBlocking` constructor switch (default
      errors-only).
- [ ] T004 (code, GREEN) `refactor_command.dart`: read the TDD profile
      `analyze-gate:` key (Keys block → frontmatter, #1407 resolution order)
      and pass `warningsBlocking` into `RefactorPasses`.

## 2. Binary pinning (SC-6)

- [ ] T005 (test, RED) U-1472-8..U-1472-10 with fake PATH zfa scripts + real
      executor: stale version pins to the driving entrypoint; equal version
      keeps the #717 candidate; unprovable version keeps the #717 candidate.
- [ ] T006 (code, GREEN) `refactor_passes.dart`: `zfaBuildCommand` version
      probe + pin (silence rules; override untouched; StateError fail-open).

## 3. Non-behavioural

- [ ] T007 Update the library doc comment of `refactor_passes.dart` (the
      registry's misfire-stop contract now carries the #1472 errors-only arm)
      and the `build`-pass doc in `defaultPassSpecs`/`zfaBuildCommand`.
- [ ] T008 CHANGELOG entry under the unreleased bug-fix section referencing
      #1472 (mirrors the #1407 entry shape).

## Verification gates (every task must keep them green)

- `dart analyze` — no new warnings on changed files.
- Existing suites: `refactor_passes_test.dart`, `refactor_command_test.dart`,
  `build_command_unit_test.dart`, `bug_1407_make_gate_errors_only_test.dart`
  unchanged in their pinned contracts (SC-7).
