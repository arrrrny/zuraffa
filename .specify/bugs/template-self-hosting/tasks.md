# Tasks: template-self-hosting (bug #912)

Delivery tasks for the five template/command defects live in the fix branch
(`fix/912-template-self-hosting`); this file records the TDD-verification
remediation findings (verdict: PASS_WITH_GAPS,
`.specify/bugs/template-self-hosting/tdd/verification.md`, verified at
`452d1b72`).

## Phase 1: TDD remediation

- [ ] 1. (MED, finding 1) Add a focused make-flow test that drives
      `zfa tdd make` to `outcome=scaffolded` for a widget test carrying the
      `zfa:tdd: scaffolded` marker, asserting exit 1 and that NO green entry is
      appended to the cycle log. Prove with:
      `dart test test/plugins/tdd/commands/ --plain-name "scaffolded"` once the
      test exists (a make-command harness may need to be introduced first).
- [ ] 2. (MED, finding 2) Migrate the bug-912 gen CLI fixtures in
      `test/plugins/tdd/commands/bug_912_widget_shell_and_finders_test.dart`
      (`seedWidgetBehavior`) from the deprecated 6-column test-list dialect to
      the canonical 4-column shape. Prove with:
      `dart test test/plugins/tdd/commands/bug_912_widget_shell_and_finders_test.dart`
      with no "deprecated 6-column" warning in the output.
- [ ] 3. (LOW, finding 3) Append a `tdd/cycle-log.md` entry to this bug dir
      recording the red commands and their failure output from the fix session,
      so the next `/speckit.tdd.verify` can corroborate test-first ordering from
      repository evidence instead of the session transcript.
