# Tasks: CI Referee + Provenance Dashboards

## Phase 1: Implementation (done — see tdd/cycle-log.md)

- [x] Implement the CI referee per spec.md (US1–US4, FR-001–FR-015)
      — committed as the feature's implementation commit.

## Phase 2: TDD remediation

From `tdd/verification.md` (audit at 1efa9a8a, verdict PASS_WITH_GAPS).
One task per finding; each phrased as a verifiable change with the
command that proves it done.

- [ ] T1 (MED, finding 1): Re-record red evidence for the poster and
      command behaviors with CAPTURED runner output. Delete the
      narrative-only red entries in `tdd/cycle-log.md` for U12–U16,
      stub the implementation, run `dart test
      test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart
      test/plugins/tdd/commands/referee_command_test.dart` to capture
      the real failure output, and append fresh red entries carrying
      it. Proves done: the two files' newest red entries contain
      literal `Some tests failed` runner output.
- [ ] T2 (LOW, finding 2): Extract the duplicated `writeFeature` /
      `writeReceipt` fixture builders from the four ci_referee test
      files into
      `test/plugins/tdd/services/ci_referee/helpers/referee_fixtures.dart`,
      mirroring `test/plugins/tdd/helpers/corpus_fixture.dart`. Proves
      done: `dart test test/plugins/tdd/services/ci_referee/
      test/plugins/tdd/commands/referee_command_test.dart` passes with
      the helper imported and no per-file builder copies remain.
- [ ] T3 (LOW, finding 3): Replace the
      `'specs/f-hand/ttd/cycle-log.md'.replaceAll('ttd', 'tdd')`
      construction in `provenance_rollup_test.dart` with the literal
      correct path. Proves done: `dart test
      test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart`
      passes and no `replaceAll('ttd'` call remains in the file.
- [ ] T4 (LOW, finding 4): Add an explicit concurrent-receipt-writes
      test: two receipts for the same path (older then newer), assert
      the reader's verdict reflects the LATEST receipt's digest. Proves
      done: `dart test
      test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart`
      includes a passing two-receipt case.
