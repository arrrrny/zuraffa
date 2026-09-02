# Cycle log — tdd-platform-channel-fake (#831)

Session-driven bug TDD cycle (red → green → verify) on branch
`fix/831-tdd-platform-channel-harness`, base `bd535c07`.

## Cycle 0 — RED (the bug, observed)

- Command: `dart test --preset=all test/plugins/tdd/services/channel_scenario_test.dart
  test/plugins/tdd/red_classifier_test.dart test/plugins/tdd/services/test_list_reader_test.dart
  test/plugins/tdd/commands/fake_command_test.dart test/plugins/tdd/commands/gen_command_platform_test.dart`
- Outcome: **12 failed / 0 passed** (the load-error files cover every pin they
  contain; the full red evidence is saved verbatim at
  `scripts/831-red-evidence.log` outside the repo — untracked by the repo's
  `*.log` gitignore policy; counts and reasons quoted below).
- The failures are the bug, for the right reason:
  - `zfa tdd fake` does not exist — the tdd subcommand list has no `fake`
    entry, so every fake-command pin fails with "does not contain '--feature'"
    against the group help (remediation 1 impossible);
  - `Could not find 'package:zuraffa/src/plugins/tdd/models/channel_scenario.dart'`
    — no scenario-script infrastructure exists (remediation 3 impossible);
  - `Member not found: 'platform'` on `BehaviorKind` — the reader has no
    `## Platform harness` section and no `platform` kind cell, so a platform
    row is rejected as "table row outside an outer/inner loop behavior
    section" and gen cannot express platform-backed behaviors (remediation 2
    impossible);
  - `Member not found: 'channelTimeout'` on `RedClassification` — verify-red
    has no channel-timeout class; a channel failure lumps into runner-error
    (remediation 4 impossible).

## Cycle 1 — GREEN (certified fake + platform harness)

- Command: same five suites after implementing
  `models/channel_scenario.dart` (schema law + loud default),
  `models/behavior.dart` (+platform), `models/red_classification.dart`
  (+channelTimeout), `services/red_classifier.dart` (channel signatures,
  after assertion, before pump), `services/test_list_reader.dart`
  (`## Platform harness` + `platform` cell), `services/channel_fake_writer.dart`
  (emitted certified fake), `services/platform_harness_context.dart` +
  `platform_harness_test_writer.dart` + `platform_harness_subject_writer.dart`
  (three-proof harness pair), `commands/fake_command.dart` (+ registration in
  `commands/tdd_command.dart`), `commands/gen_command.dart`
  (`_resolvePlatformContext` + `_writersFor` platform branch, both call sites).
- Outcome: **82 passed / 0 failed** across the five suites (16 fake-command
  pins incl. analyzer parse pins, 4 gen-platform pins incl. emitted-Dart parse
  pins, 11 scenario-schema pins, 3 reader pins, 7 classifier pins + the
  extended taxonomy pin, plus all pre-existing pins in the touched files).
- Mid-loop findings fixed during the loop (observed red, then green):
  - the emitted fake's drift-check message interpolated the WRITER's
    `channel` string parameter instead of the EMITTED class constant —
    compile error caught by the first test run, fixed by baking the literal;
  - the scenario JSON pins asserted inline array formatting that
    `JsonEncoder.withIndent` never produces — pins re-pointed at the parsed
    JSON (contract, not formatting);
  - the verdict pin asserted `"kind": "platform"` with a space;
    `jsonEncode` is compact — pin corrected to the actual machine contract.

## Regression evidence

- `dart analyze`: 47 issues — the master baseline at `bd535c07`, 0 on touched
  files.
- `dart format`: clean on every touched file (17 formatted, 0 remaining
  drift; the two pre-existing drift files called out by #836 are untouched).
- Full fast tier via `tools/run_tests_chunked.sh` (chunked per directory,
  kernel caches cleared): see `.specify/bugs/tdd-platform-channel-fake/tdd/verification.md`
  for the final counts and the pre-existing-failure accounting.
