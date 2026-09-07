# TDD Cycle Log — tdd-reset-done-state-phantom (#1264)

Deterministic fixture per cycle: a temp project from `TddFixture.create`
(pubspec, tdd-profile, fake-zfa step binary, test list with U-001/U-002),
seeded with the issue's completed-feature state: registered test+subject
files on disk, red+green evidence in the cycle log, a done run-state, and a
green engine receipt — everything reset owns plus the evidence that survives
it. Every invocation below is the real CLI in-process
(`CliRunner.runCapturing(['tdd', ...args, '--project', fixtureRoot])`).

## Cycle 1 — A1/A2/A3/A4/A5 (the bug)

**RED (pre-fix tree, all five pins failing for the right reasons):**

```
$ dart test --preset=all test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart

00:00 +0 -1: bug 1264 (c): doctor ... doctor reports the phantom done-state as a drift ... [E]
  Expected: <1>
    Actual: <0>
  zfa tdd doctor: feature 090-bug-1264 (specs/090-bug-1264/tdd)
    stores agree — no drift detected
  {"command":"doctor","feature":"090-bug-1264","verdict":"healthy","prescription":"none","drifts":[]}

00:01 +1 -3: bug 1264 (b): run re-drives ... [E]
  Expected: ['gen U-001', 'verify-red U-001', 'make U-001', 'refactor U-001',
             'gen U-002', 'verify-red U-002', 'make U-002', 'refactor U-002']
    Actual: []
  zfa tdd run: feature 090-bug-1264 — 2 behavior(s)
     2 already done — skipping
  run: feature=090-bug-1264 result=complete pending=0 red=0 green=0 done=2

00:02 +1 -4: bug 1264 (d): status ... [E]
  Expected: contains 'engine=red'
    Actual: 'status: feature=090-bug-1264 engine=green skin=absent\n'
              '090-bug-1264 | engine ✅ 2/2 | skin — absent (0 platforms) | mocks 0/0 certified | 0 violations\n'

(fails for the right reason: reset writes no journal tombstone — journal.json
absent after reset; A3 doctor-healthy control passed pre-fix as expected)
```

The RED run reproduces the issue verbatim: doctor `healthy` on a tree with
zero artifacts, run `2 already done — skipping` with an empty step log, and
status `engine ✅ 2/2` on nonexistent tests.

**GREEN (fix applied, same session, same fixture):**

```
$ dart test --preset=all test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart
00:08 +5: All tests passed!
```

- A1 (a): reset appends the journal tombstone — `journal.json` exists with one
  entry where `phase == 'reset'`, `cycle == 'meta'`, `result == 'reset'`,
  `behaviors == ['U-001', 'U-002']`; prior entries preserved (append-only).
- A2 (c): doctor on the post-reset tree — exit 1, drift lines begin with
  `evidence-without-artifact:`, `--> fix: zfa tdd run 090-bug-1264`,
  verdict `drift`, prescription `resume` (exactly one recovery).
- A3 (control): doctor on the completed feature BEFORE reset — exit 0,
  verdict `healthy` (evidence backed by files is not drift).
- A4 (b): run on the post-reset tree — full re-drive
  `gen U-001, verify-red U-001, make U-001, refactor U-001, gen U-002,
  verify-red U-002, make U-002, refactor U-002`; output contains no
  `already done`; exit 0.
- A5 (d): status on the post-reset tree — `status: feature=090-bug-1264
  engine=red skin=absent`, an `evidence-without-artifact:` note naming the
  stale behaviors and the one recovery, exit 1.

## Cycle 2 — regression guard (touched surfaces, post-fix)

Real runs on the fix HEAD (Dart 3.13.3 stable, linux-x64, kernel-cache
cleanup between chunks per the repo's cloud-agent protocol):

```
$ dart test --preset=all test/plugins/tdd/run_command_test.dart
05:02 +49: All tests passed!                       (bug-682 bootstrap intact)

$ dart test --preset=all test/plugins/tdd/unified_journal_commands_test.dart
01:20 +12: All tests passed!

$ dart test --preset=all test/plugins/tdd/commands/run_engine_command_test.dart \
           test/plugins/tdd/commands/run_skin_command_test.dart
00:33 +17: All tests passed!

$ dart test --preset=all test/plugins/tdd/tdd_command_smoke_test.dart \
           test/plugins/tdd/bug_911_version_skew_contract_test.dart
00:02 +11: All tests passed!

$ dart test --preset=all test/plugins/tdd/bug_840_recovery_commands_test.dart
+4 -5  (identical to the stashed pre-fix baseline on this machine — the 5
        failures are pre-existing environment failures, see verification.md)

$ dart test --preset=all test/plugins/tdd/two_cycle_run_commands_test.dart \
           test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart
+28 -4  (baseline: +28 -4 — identical)

$ dart test --preset=all test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart \
           test/plugins/tdd/bug_969_json_verdict_envelope_test.dart \
           test/plugins/tdd/explain_flag_test.dart
+47 -4  (baseline: +47 -4 — identical)
```

`dart analyze lib/src/plugins/tdd test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart`
→ No issues found! `dart format --output=none --set-exit-if-changed lib/
test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart` → exit 0.
