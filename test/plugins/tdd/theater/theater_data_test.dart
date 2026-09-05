/// Unit behaviors U1–U5 for `lib/src/plugins/tdd/services/theater_data.dart`
/// (spec 1006-tdd-theater-replay-tui, tdd/test-list.md).
///
/// Fixtures carry the real file contracts: the registry
/// (`specs/<feature>/tdd/artifacts.json`), the test-list, a cycle-log
/// seeded through the REAL `CycleLog.append` writer, and #807 generation
/// receipts (`proof.v1`) in both the flat `.zfa/receipts/` store and the
/// per-feature `.zfa/receipts/<feature>/` layout the issue names.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/theater_data.dart';

import 'theater_fixture.dart';

void main() {
  group('theater data (U-rows)', () {
    test('U1: behaviors load with cycle-derived status', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));

      final snapshot = await TheaterData.load(
        feature: fx.featureName,
        projectRoot: fx.root.path,
      );

      expect(snapshot.feature, fx.featureName);
      expect(snapshot.behaviors, hasLength(3));
      // Registry order preserved.
      expect(snapshot.behaviors.map((b) => b.id), ['A1', 'A2', 'A3']);

      final a1 = snapshot.behaviors[0];
      expect(a1.criterion, 'FR-001');
      expect(a1.description, contains('login form renders'));
      expect(a1.status, TheaterProofStatus.green);
      expect(a1.testPath, fx.testRel('A1'));
      expect(a1.subjectPath, fx.subjectRel('A1'));

      // A2 has red evidence only.
      expect(snapshot.behaviors[1].status, TheaterProofStatus.red);
      // A3 has no cycle-log entry: pending, never an error.
      expect(snapshot.behaviors[2].status, TheaterProofStatus.pending);

      // An empty description cell in the test list falls back to the
      // registry's own description segment (never an empty card).
      final fallback = await TheaterFixture.create();
      addTearDown(() => fallback.root.delete(recursive: true));
      final testList = File(p.join(fallback.featureDir, 'tdd', 'test-list.md'));
      await testList.writeAsString('''
---
feature: ${fallback.featureName}
---

# Test List

## Outer loop: acceptance behaviors

| id  | behavior | traces | state |
| --- | -------- | ------ | ---- |
| A1  |   | FR-001 | done |
| A2  |   | FR-002 | red |
| A3  |   | FR-003 | pending |
''');
      final fallbackSnapshot = await TheaterData.load(
        feature: fallback.featureName,
        projectRoot: fallback.root.path,
      );
      expect(
        fallbackSnapshot.behaviors[0].description,
        contains('login form renders'),
      );
    });

    test(
      'U2: receipts load from per-feature and flat layouts, latest-wins',
      () async {
        final flat = await TheaterFixture.create();
        addTearDown(() => flat.root.delete(recursive: true));
        final flatSnapshot = await TheaterData.load(
          feature: flat.featureName,
          projectRoot: flat.root.path,
        );
        // Flat store attributed by the registry's subject/test paths.
        expect(flatSnapshot.receiptCount, 2);
        // A1 + A2 carry #807 backing on their receipt cards.
        expect(flatSnapshot.behaviors[0].receipt.receiptAction, 'create');
        expect(flatSnapshot.behaviors[1].receipt.receiptAction, 'create');
        // A3's card exists but has no #807 receipt covering its subject.
        expect(flatSnapshot.behaviors[2].receipt, isNotNull);
        expect(flatSnapshot.behaviors[2].receipt.receiptAction, isNull);

        final perFeature = await TheaterFixture.create(
          perFeatureReceipts: true,
        );
        addTearDown(() => perFeature.root.delete(recursive: true));
        final pfSnapshot = await TheaterData.load(
          feature: perFeature.featureName,
          projectRoot: perFeature.root.path,
        );
        expect(pfSnapshot.receiptCount, 2);
        expect(pfSnapshot.behaviors[0].receipt.receiptAction, 'create');
        expect(pfSnapshot.behaviors[1].receipt.receiptAction, 'create');

        // Latest-wins: a LATER flat receipt covering A1's subject with a
        // different action supersedes the earlier one.
        final later = DateTime.parse('2026-09-05T23:59:00.000000Z');
        final subjectAbs = File(
          '${perFeature.root.path}/${perFeature.subjectRel('A1')}',
        );
        final receiptFile = File(
          '${perFeature.root.path}/.zfa/receipts/'
          '2099-01-01T00-00-00.000000Z-zfa_tdd_gen-A1.json',
        );
        await receiptFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'schema': 'proof.v1',
            'command': 'zfa tdd gen',
            'target': 'A1',
            'repro': 'zfa tdd gen A1 --feature 004-login-ui',
            'at': later.toIso8601String(),
            'generator_version': '6.1.0',
            'input': {'behavior': 'A1'},
            'files': [
              {
                'path': perFeature.subjectRel('A1'),
                'action': 'update',
                'sha256': 'deadbeef',
                'bytes': subjectAbs.lengthSync(),
              },
            ],
          }),
        );
        final latest = await TheaterData.load(
          feature: perFeature.featureName,
          projectRoot: perFeature.root.path,
        );
        expect(latest.receiptCount, 3);
        final a1Receipt = latest.behaviors[0].receipt;
        expect(a1Receipt.receiptAction, 'update');
        expect(a1Receipt.sha256, 'deadbeef');
        // The older per-feature receipt for A2 still resolves.
        expect(latest.behaviors[1].receipt, isNotNull);

        // Attribution also fires on the TEST path alone (a receipt that
        // covers only the paired test file still backs the behavior),
        // and path normalization tolerates windows-style separators.
        final testPathOnly = await TheaterFixture.create();
        addTearDown(() => testPathOnly.root.delete(recursive: true));
        final tpoReceipt = File(
          '${testPathOnly.root.path}/.zfa/receipts/'
          '2099-01-01T00-00-00.000000Z-zfa_tdd_gen-A3.json',
        );
        await tpoReceipt.writeAsString(
          jsonEncode({
            'schema': 'proof.v1',
            'command': 'zfa tdd gen',
            'target': 'A3',
            'repro': 'zfa tdd gen A3 --feature 004-login-ui',
            'at': '2026-09-05T12:00:00.000000Z',
            'generator_version': '6.1.0',
            'input': const <String, dynamic>{},
            'files': [
              // Backslash separators normalize to the registry's POSIX
              // shape on both sides of the attribution match.
              {
                'path': 'test\\login\\a3_test.dart',
                'action': 'create',
                'sha256': 'c0ffee',
                'bytes': 42,
              },
            ],
          }),
        );
        final tpoSnapshot = await TheaterData.load(
          feature: testPathOnly.featureName,
          projectRoot: testPathOnly.root.path,
        );
        // The flat store's subject-backed receipts + the test-path-only
        // document all attribute.
        expect(tpoSnapshot.receiptCount, 3);
        final a3Receipt = tpoSnapshot.behaviors[2].receipt;
        expect(a3Receipt.receiptAction, 'create');
        expect(a3Receipt.sha256, 'c0ffee');
        expect(a3Receipt.bytes, 42);

        // Tie-break: two receipts at the SAME timestamp covering the
        // same path resolve to the lexicographically-LAST file name
        // (latest-wins is deterministic). The 'zzz' document lives in
        // the per-feature store (processed first), the 'aaa' document in
        // the flat store (processed second) — so the file-name
        // tie-break, never insertion order, is what makes 'zzz' win.
        final tie = await TheaterFixture.create(perFeatureReceipts: true);
        addTearDown(() => tie.root.delete(recursive: true));
        final tieDoc = {
          'schema': 'proof.v1',
          'command': 'zfa tdd gen',
          'repro': 'zfa tdd gen',
          'at': '2026-09-05T12:00:00.000000Z',
          'generator_version': '6.1.0',
          'input': const <String, dynamic>{},
          'files': [
            {'path': tie.subjectRel('A1'), 'sha256': '00feed', 'bytes': 7},
          ],
        };
        await File(
          '${tie.root.path}/.zfa/receipts/${tie.featureName}/'
          '2099-01-01T00-00-00.000000Z-zzz.json',
        ).writeAsString(
          jsonEncode({
            ...tieDoc,
            'target': 'zzz',
            'files': [
              {
                'path': tie.subjectRel('A1'),
                'action': 'zzz',
                'sha256': '00feed',
                'bytes': 7,
              },
            ],
          }),
        );
        await File(
          '${tie.root.path}/.zfa/receipts/'
          '2099-01-01T00-00-00.000000Z-aaa.json',
        ).writeAsString(
          jsonEncode({
            ...tieDoc,
            'target': 'aaa',
            'files': [
              {
                'path': tie.subjectRel('A1'),
                'action': 'aaa',
                'sha256': '00feed',
                'bytes': 7,
              },
            ],
          }),
        );
        final tieSnapshot = await TheaterData.load(
          feature: tie.featureName,
          projectRoot: tie.root.path,
        );
        expect(tieSnapshot.behaviors[0].receipt.receiptAction, 'zzz');
      },
    );

    test('U3: the cycle parser captures the full journal row', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));

      final snapshot = await TheaterData.load(
        feature: fx.featureName,
        projectRoot: fx.root.path,
      );

      expect(snapshot.cycles, hasLength(3));
      // File order: A1 red, A1 green, A2 red.
      final a1Red = snapshot.cycles[0];
      expect(a1Red.behaviorId, 'A1');
      expect(a1Red.kind, 'red');
      expect(a1Red.classification, 'assertionFailure');
      expect(a1Red.redEvidence, 'email and password fields render');
      expect(a1Red.criterion, 'FR-001');
      expect(a1Red.test, 'test/login/a1_test.dart::A1');
      expect(a1Red.command, contains('--plain-name'));
      expect(a1Red.exitCode, 1);
      expect(a1Red.at, '2026-09-05T10:00:00.000000Z');
      expect(a1Red.output, contains('Expected: exactly 2 input fields'));
      expect(a1Red.schema, '1');
      expect(a1Red.prevHash, 'genesis');
      expect(a1Red.hash, isNotNull);

      final a1Green = snapshot.cycles[1];
      expect(a1Green.kind, 'green');
      expect(a1Green.exitCode, 0);
      expect(a1Green.generationSteps, hasLength(1));
      expect(
        a1Green.generationSteps.first.command,
        'zfa tdd gen A1 --feature 004-login-ui',
      );
      expect(
        a1Green.generationSteps.first.purpose,
        'render the login form subject',
      );

      final a2Red = snapshot.cycles[2];
      expect(a2Red.behaviorId, 'A2');
      expect(a2Red.classification, 'loadError');

      // Edge shapes parsed from a hand-written log: refactor entries
      // with actions, a no-op refactor, a truncated output marker (no
      // fence follows), and an unterminated fence (no closing line).
      final edge = await TheaterFixture.create(withCycleLog: false);
      addTearDown(() => edge.root.delete(recursive: true));
      await File(edge.cycleLogPath).writeAsString('''
# Cycle Log

## Cycle: A1 (refactor)

- behavior: A1
- kind: refactor
- criterion: FR-001
- test: test/plugins/tdd/
- command: `dart format .`
- exit: 0
- at: 2026-09-05T12:00:00.000000Z
- output:
```
0 files changed
```
actions:
- action: extract-widget
  command: `dart fix --apply`
  exit: 0
  changed: lib/a.dart, lib/b.dart

- schema: 1
- prev-hash: genesis
- hash: ${'a' * 64}

## Cycle: A1 (refactor)

- behavior: A1
- kind: refactor
- criterion: FR-001
- test: test/plugins/tdd/
- command: `dart analyze`
- exit: 0
- at: 2026-09-05T12:30:00.000000Z
- no-op: true
- output:
```
No issues found!
```

- schema: 1
- prev-hash: ${'a' * 64}
- hash: ${'b' * 64}

## Cycle: A2 (red)

- behavior: A2
- kind: red
- criterion: FR-002
- test: test/login/a2_test.dart::A2
- command: `dart test test/login/a2_test.dart`
- exit: 1
- at: 2026-09-05T13:00:00.000000Z
- output:

## Cycle: A2 (red)

- behavior: A2
- kind: red
- criterion: FR-002
- command: `dart test test/login/a2_test.dart`
- exit: 1
- output:
```
unterminated fence output

## Cycle: A3 (green)

- behavior: A3
- kind: green
- criterion: FR-003
- command: `dart test test/login/a3_test.dart`
- exit: 0
- output:
```
00:00 +1: all green
```
''');
      final edgeSnapshot = await TheaterData.load(
        feature: edge.featureName,
        projectRoot: edge.root.path,
      );
      expect(edgeSnapshot.cycles, hasLength(5));
      final refactor = edgeSnapshot.cycles[0];
      expect(refactor.kind, 'refactor');
      expect(refactor.refactorActions, hasLength(1));
      expect(refactor.refactorActions.first.name, 'extract-widget');
      expect(refactor.refactorActions.first.command, 'dart fix --apply');
      expect(refactor.refactorActions.first.exitCode, 0);
      expect(refactor.refactorActions.first.changed, 'lib/a.dart, lib/b.dart');
      expect(refactor.output, '0 files changed');
      final noOp = edgeSnapshot.cycles[1];
      expect(noOp.isNoOp, isTrue);
      expect(noOp.output, 'No issues found!');
      // A truncated output marker (nothing fenced after `- output:`)
      // yields an empty block, never a crash.
      expect(edgeSnapshot.cycles[2].output, isEmpty);
      // An unterminated fence yields the body up to the section end.
      expect(
        edgeSnapshot.cycles[3].output,
        contains('unterminated fence output'),
      );
      // A3's green carries no generation block: still a cycle row.
      expect(edgeSnapshot.cycles[4].kind, 'green');

      // Missing-field honesty: the last A2 red carries no classification,
      // test or at lines — the derived receipt renders the honest '-'
      // placeholders, never invented values.
      expect(edgeSnapshot.cycles[3].test, isNull);
      expect(edgeSnapshot.cycles[3].at, isNull);
      expect(edgeSnapshot.behaviors[1].receipt.evidence, 'red - exit 1 at -');

      // A green entry with no test/at lines renders the same honest
      // placeholders on the satisfied receipt.
      expect(edgeSnapshot.behaviors[2].status, TheaterProofStatus.green);
      expect(edgeSnapshot.behaviors[2].receipt.evidence, 'test - exit 0 at -');

      // A mis-shaped output marker (a NON-fence line directly after
      // `- output:`, then a fence) is NOT an output block: the honest
      // parse yields '' rather than scavenging the later fence's body.
      // And a trailing `- output:` with no fence and no final newline
      // (the log's last line) also yields '' without a range crash.
      final misShaped = await TheaterFixture.create(withCycleLog: false);
      addTearDown(() => misShaped.root.delete(recursive: true));
      await File(misShaped.cycleLogPath).writeAsString('''
# Cycle Log

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: test/login/a1_test.dart::A1
- command: `dart test test/login/a1_test.dart`
- exit: 1
- at: 2026-09-05T14:00:00.000000Z
- output:
narrative line, not a fence
```
scavenged body
```

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: loadError
- criterion: FR-002
- test: test/login/a2_test.dart::A2
- command: `dart test test/login/a2_test.dart`
- exit: 1
- at: 2026-09-05T14:30:00.000000Z
- output:''');
      final misShapedSnapshot = await TheaterData.load(
        feature: misShaped.featureName,
        projectRoot: misShaped.root.path,
      );
      expect(misShapedSnapshot.cycles, hasLength(2));
      expect(misShapedSnapshot.cycles[0].output, isEmpty);
      expect(misShapedSnapshot.cycles[1].output, isEmpty);
    });

    test('U4: receipts derive action/evidence/file honestly', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));

      final snapshot = await TheaterData.load(
        feature: fx.featureName,
        projectRoot: fx.root.path,
      );

      // A1: green evidence -> satisfied, with the green test + exit and
      // the #807 receipt's action/bytes/sha256 on the file line.
      final a1 = snapshot.behaviors[0].receipt;
      expect(a1.action, 'satisfied');
      expect(a1.evidence, contains('test/login/a1_test.dart'));
      expect(a1.evidence, contains('exit 0'));
      expect(a1.evidence, contains('at 2026-09-05T10:05:00.000000Z'));
      expect(a1.file, fx.subjectRel('A1'));
      expect(a1.receiptAction, 'create');
      expect(a1.bytes, greaterThan(0));
      expect(a1.sha256, hasLength(64));

      // A2: red evidence only -> red action with the classification.
      final a2 = snapshot.behaviors[1].receipt;
      expect(a2.action, 'red');
      expect(a2.evidence, contains('loadError'));
      expect(a2.evidence, contains('exit 1'));
      expect(a2.evidence, contains('at 2026-09-05T11:00:00.000000Z'));

      // A3: no evidence at all -> pending, honest absence.
      final a3 = snapshot.behaviors[2].receipt;
      expect(a3.action, 'pending');
      expect(a3.evidence, contains('no recorded evidence'));
      expect(a3.file, fx.subjectRel('A3'));
      expect(a3.receiptAction, isNull);
    });

    test(
      'U5: the classifier verdict maps to RedClassification vocabulary',
      () async {
        final fx = await TheaterFixture.create();
        addTearDown(() => fx.root.delete(recursive: true));

        final snapshot = await TheaterData.load(
          feature: fx.featureName,
          projectRoot: fx.root.path,
        );

        // A1's red was an assertion failure: kebab-case label + hint.
        final a1Verdict = snapshot.behaviors[0].verdict;
        expect(a1Verdict, isNotNull);
        expect(a1Verdict!.classificationLabel, 'assertion');
        expect(a1Verdict.remediationHint, isNotEmpty);
        expect(a1Verdict.evidence, 'email and password fields render');

        // A2's red was a load error: load-error + its remediation hint.
        final a2Verdict = snapshot.behaviors[1].verdict;
        expect(a2Verdict, isNotNull);
        expect(a2Verdict!.classificationLabel, 'load-error');
        expect(a2Verdict.remediationHint, contains('restore the missing'));

        // A3 has no red: no verdict, no invented remediation.
        expect(snapshot.behaviors[2].verdict, isNull);

        // An UNMAPPED classification renders the raw label with no
        // invented remediation (forward-compat honesty).
        final unmapped = await TheaterFixture.create();
        addTearDown(() => unmapped.root.delete(recursive: true));
        await File(unmapped.cycleLogPath).writeAsString('''
# Cycle Log

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: someFutureClass
- criterion: FR-001
- test: test/login/a1_test.dart::A1
- command: `dart test test/login/a1_test.dart`
- exit: 1
- at: 2026-09-05T10:00:00.000000Z
- output:
```
boom
```
''');
        final unmappedSnapshot = await TheaterData.load(
          feature: unmapped.featureName,
          projectRoot: unmapped.root.path,
        );
        final verdict = unmappedSnapshot.behaviors[0].verdict;
        expect(verdict, isNotNull);
        expect(verdict!.classificationLabel, 'someFutureClass');
        expect(verdict.remediationHint, isEmpty);

        // Vocabulary completeness: EVERY key in the shared map resolves
        // to the classification whose own label (or kebab twin) it
        // names — the defensive kebab-case spellings are part of the
        // contract, not dead weight.
        const vocab = TheaterData.classificationVocabulary;
        expect(vocab['assertionFailure'], RedClassification.assertion);
        expect(vocab['compileError'], RedClassification.compileError);
        expect(vocab['loadError'], RedClassification.loadError);
        expect(vocab['skipped'], RedClassification.skipped);
        expect(vocab['unexpectedGreen'], RedClassification.unexpectedGreen);
        expect(vocab['runnerError'], RedClassification.runnerError);
        expect(vocab['channelTimeout'], RedClassification.channelTimeout);
        expect(vocab['kindMismatch'], RedClassification.kindMismatch);
        expect(vocab['assertion'], RedClassification.assertion);
        expect(vocab['compile-error'], RedClassification.compileError);
        expect(vocab['load-error'], RedClassification.loadError);
        expect(vocab['unexpected-green'], RedClassification.unexpectedGreen);
        expect(vocab['runner-error'], RedClassification.runnerError);
        expect(vocab['channel-timeout'], RedClassification.channelTimeout);
        expect(vocab['kind-mismatch'], RedClassification.kindMismatch);
        // Every vocabulary label round-trips: a kebab-case label written
        // into a cycle-log maps to the same classification.
        for (final entry in vocab.entries) {
          expect(entry.value.label, isNotEmpty);
          expect(
            vocab[entry.value.label] ?? vocab[entry.key],
            entry.value,
            reason: 'label ${entry.value.label} must resolve in the map',
          );
        }
      },
    );
  });
}
