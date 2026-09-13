# Tasks: 1472-refactor-build-gate-warnings

MVP-first: the deadlock (SC-1..SC-4) ships before the opt-out (SC-5) and the
binary pin (SC-6). Test tasks are mandatory and ordered before the behaviour
they prove (TDD extension).

## 1. MVP — the deadlock fix (SC-1..SC-4)

- [x] T001 (test, RED) `test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`
      unit behaviors U-1472-1..U-1472-10 and U-1472-18 through the fake
      `ProcessExecutor`: warnings-only refusal continues (format+fix run);
      errors refuse; other failure classes refuse; message/parser
      disagreement refuses; `warningsBlocking` opt-in refuses; timeout and
      spawn-failure refuse (U-1472-8/9); the arm is build-only (U-1472-10);
      accurate-counts log line asserted via captured `print`; the
      >10-warning cap and its `... N more warning(s)` remainder (U-1472-18).
- [x] T002 (test, RED) acceptance A-1472-1 through `TddFixture` + `CliRunner`:
      green preflight + fake zfa `build` printing the warnings-only refusal
      with exit 1 → refactor completes outcome=refactored exit 0, `pass:
      format` and `pass: fix` reach the transcript, and the seeded unused
      import makes `applied>=1` (pre-fix: outcome=runner-error exit 1).
- [x] T003 (code, GREEN) `refactor_passes.dart`: warnings-only gate
      reinterpretation in `RefactorPasses.run()` (verdict-line verdict +
      shared `BuildCommand` parser cross-check + timeout/spawn guards +
      accurate-counts logger); `warningsBlocking` constructor switch (default
      errors-only).
- [x] T004 (code, GREEN) `refactor_command.dart`: read the TDD profile
      `analyze-gate:` key and pass `warningsBlocking` into `RefactorPasses`.

## 2. Binary pinning (SC-6)

- [x] T005 (test, RED) U-1472-11..U-1472-17 with fake PATH zfa scripts (the
      driving entrypoint injected): a proven different version pins to the
      driving entrypoint (U-1472-11); equal version keeps the #717 candidate
      (U-1472-12); unprovable candidate keeps it (U-1472-13); a replacement
      that proves a different version, or an unprovable one, keeps it
      (U-1472-14/15); an identical driving entrypoint is a no-op (U-1472-16);
      a `StateError` resolving it fails open (U-1472-17).
- [x] T006 (code, GREEN) `refactor_passes.dart`: `zfaBuildCommand` version
      probe + pin (silence rules in BOTH directions — candidate and
      replacement; override untouched; StateError fail-open).

## 3. Non-behavioural

- [x] T007 Update the library doc comment of `refactor_passes.dart` (the
      registry's misfire-stop contract now carries the #1472 errors-only arm)
      and the `build`-pass doc in `defaultPassSpecs`/`zfaBuildCommand`.
- [x] T008 CHANGELOG entry under the unreleased bug-fix section referencing
      #1472 (mirrors the #1407 entry shape).

## Verification gates (every task must keep them green)

- `dart analyze` — no new warnings on changed files.
- Existing suites: `refactor_passes_test.dart`, `refactor_command_test.dart`,
  `build_command_unit_test.dart`, `bug_1407_make_gate_errors_only_test.dart`
  unchanged in their pinned contracts (SC-7).
