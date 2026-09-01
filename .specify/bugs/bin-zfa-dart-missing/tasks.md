# Tasks: bin-zfa-dart-missing (bug #717)

## Phase 1: TDD remediation

- [ ] T001 (finding 2, LOW) Reorder `StepRunner.resolveEntrypoint` so the
      system-`zfa`-on-PATH tier precedes the package-config tier for ALL
      consumers (make/gen/verify/tdd run), matching the contract the refactor
      build pass now implements — out of scope for #717 by the "fix ONLY the
      refactor pass" constraint. Prove with:
      `dart test test/plugins/tdd/services/step_runner_test.dart test/plugins/tdd/services/refactor_passes_test.dart`
- [ ] T002 (finding 3, LOW) Run `dart format examples/mcp_demo/lib/src/mcp/tools.dart`
      in a separate formatting-only commit; it drifts at base HEAD and is
      deliberately untouched by the #717 PR. Prove with:
      `dart format --set-exit-if-changed --output=none examples/mcp_demo/lib/src/mcp/tools.dart`
- [ ] T003 (finding 1, MED) Record bug-fix red/green evidence in
      `.specify/bugs/<slug>/tdd/cycle-log.md` for future bug fixes so the loop's
      evidence chain matches the spec-048 feature flow. Prove with:
      the file exists and its first entry cites the pre-fix failing command.
