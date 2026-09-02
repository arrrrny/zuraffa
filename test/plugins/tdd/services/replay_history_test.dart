/// Unit behaviors U1–U5 for spec 066-zfa-replay (tdd/test-list.md).
///
/// All fixture histories are seeded through the REAL `CycleLog.append`
/// writer so the machine format (schema-1 chain lines) is byte-exact by
/// construction; tamper tests mutate the log text the way an injected
/// mutation would.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';
import 'package:zuraffa/src/plugins/tdd/services/replay_history.dart';

import '../helpers/replay_fixture.dart';

void main() {
  group('ReplayHistory', () {
    test('U1: entries group by behavior in file order', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendCycle('066-b1', marker: 'm1');
      await fx.appendCycle('066-b2', marker: 'm2');

      final behaviors = await ReplayHistory.load(fx.featureDir);

      expect(behaviors.map((b) => b.id).toList(), ['066-b1', '066-b2']);
      final b1 = behaviors.first;
      expect(b1.red, isNotNull);
      expect(b1.green, isNotNull);
      expect(b1.refactors, isEmpty);
      expect(b1.entries.map((e) => e.kind), ['red', 'green']);
    });

    test('U1: zero parseable sections yields an empty list', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await File(fx.cycleLogPath).writeAsString(
        '# Cycle Log\n\n## Baseline\n\n- suite: narrative prose only, no '
        'behavior fields recorded\n',
      );

      final behaviors = await ReplayHistory.load(fx.featureDir);

      expect(behaviors, isEmpty);
    });

    test('U2: generation steps parse from the green block', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendCycle(
        '066-b1',
        marker: 'm1',
        genSteps: [
          genStep(fx.genCommandOf('066-b1')),
          genStep('zfa build', purpose: 'build the sandbox'),
        ],
      );

      final behaviors = await ReplayHistory.load(fx.featureDir);

      final steps = behaviors.single.genSteps;
      expect(steps, hasLength(2));
      expect(steps[0].command, fx.genCommandOf('066-b1'));
      expect(steps[0].exitCode, 0);
      expect(steps[0].purpose, 'gen');
      expect(steps[1].command, 'zfa build');
      expect(steps[1].purpose, 'build the sandbox');
    });

    test('U2: a (none) generation block yields empty steps', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendCycle('066-b1', marker: 'm1');

      final behaviors = await ReplayHistory.load(fx.featureDir);

      expect(behaviors.single.genSteps, isEmpty);
      // A green entry always makes verify replayable (the command IS
      // recorded), but with no generation block gen is not.
      final b = behaviors.single;
      expect(b.canReplayGen, isFalse);
      expect(b.canReplayVerify, isTrue);
    });

    test('U3: the recorded chain verifies', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendCycle('066-b1', marker: 'm1');

      final b = (await ReplayHistory.load(fx.featureDir)).single;
      final out = await ReplayHistory.verifyIntegrity(
        b,
        projectRoot: fx.root.path,
      );

      expect(out.ok, isTrue, reason: out.reason);
      expect(out.unverifiedKinds, isEmpty);
    });

    test('U3: a tampered certified fact breaks, named', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendCycle('066-b1', marker: 'm1');
      // Injected mutation: flip the green entry's recorded exit 0 -> 1.
      final log = File(fx.cycleLogPath);
      final tampered = (await log.readAsString()).replaceFirst(
        '- exit: 0\n',
        '- exit: 1\n',
      );
      await log.writeAsString(tampered);

      final b = (await ReplayHistory.load(fx.featureDir)).single;
      final out = await ReplayHistory.verifyIntegrity(
        b,
        projectRoot: fx.root.path,
      );

      expect(out.ok, isFalse);
      expect(out.brokenEntryKind, 'green');
      expect(out.reason, contains('chain mismatch'));
    });

    test('U3: a spliced prev-hash breaks with a linkage divergence', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendCycle('066-b1', marker: 'm1');
      // Build a SELF-CONSISTENT green entry over a wrong prev link: the
      // recorded hash recomputes cleanly, but the recorded prev-hash no
      // longer chains to the behavior's red hash.
      final wrongPrev = CycleLog.genesisHash;
      final payload = CycleLog.payloadFromFields(
        behaviorId: '066-b1',
        kind: 'green',
        exit: '0',
        command: fx.greenCommandOf('066-b1'),
        criterion: 'FR-004',
        test: fx.testPathOf('066-b1'),
        timestamp: '2026-09-03T00:00:01.000Z',
        prevHash: wrongPrev,
      );
      final forged = sha256.convert(utf8.encode(payload)).toString();
      final log = File(fx.cycleLogPath);
      final raw = await log.readAsString();
      // The writer renders `- prev-hash:` then `- hash:` per entry; the
      // red entry's hash is the first, the green's the second.
      final hashes = RegExp(r'- hash: ([0-9a-f]{64})').allMatches(raw).toList();
      final redHash = hashes[0].group(1)!;
      final greenHash = hashes[1].group(1)!;
      final spliced = raw
          .replaceFirst('- prev-hash: $redHash', '- prev-hash: $wrongPrev')
          .replaceFirst('- hash: $greenHash', '- hash: $forged');
      await log.writeAsString(spliced);

      final b = (await ReplayHistory.load(fx.featureDir)).single;
      final out = await ReplayHistory.verifyIntegrity(
        b,
        projectRoot: fx.root.path,
      );

      expect(out.ok, isFalse);
      expect(out.reason, contains('linkage'));
    });

    test(
      'U3: hash-less schema-0 entries are unverified, never failed',
      () async {
        final fx = await ReplayFixture.create();
        addTearDown(() => fx.root.delete(recursive: true));
        await fx.appendCycle('066-b1', marker: 'm1');
        // A legacy hand-appended section with no hash lines.
        await File(fx.cycleLogPath).writeAsString(
          '\n## Cycle: 066-legacy (red)\n\n- behavior: 066-legacy\n'
          '- kind: red\n- classification: assertionFailure\n'
          '- criterion: FR-001\n- test: ${fx.testPathOf('066-b1')}\n'
          '- command: `dart test`\n- exit: 1\n- at: 2026-08-01T00:00:00.000Z\n'
          '- output:\n```\nold failure\n```\n\n',
          mode: FileMode.append,
        );

        final behaviors = await ReplayHistory.load(fx.featureDir);
        final legacy = behaviors.firstWhere((b) => b.id == '066-legacy');
        final out = await ReplayHistory.verifyIntegrity(
          legacy,
          projectRoot: fx.root.path,
        );

        expect(out.ok, isTrue, reason: out.reason);
        expect(out.unverifiedKinds, ['red']);
      },
    );

    test('U4: a red test path missing from the tree diverges', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendRedOnly('066-b1');
      // The recorded test path must exist in the real tree; delete it.
      await File(fx.testPathOf('066-b1')).delete();

      final b = (await ReplayHistory.load(fx.featureDir)).single;
      final out = await ReplayHistory.verifyIntegrity(
        b,
        projectRoot: fx.root.path,
      );

      expect(out.ok, isFalse);
      expect(out.reason, contains('red-missing-test-artifact'));
    });

    test('U4: a red entry recorded with exit 0 diverges', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await File(fx.testPathOf('066-b1')).parent.create(recursive: true);
      await File(fx.testPathOf('066-b1')).writeAsString('// test\n');
      // Hand-written red recorded with a zero exit (the dishonest shape).
      await File(fx.cycleLogPath).writeAsString(
        '\n## Cycle: 066-b1 (red)\n\n- behavior: 066-b1\n'
        '- kind: red\n- classification: assertionFailure\n'
        '- criterion: FR-001\n- test: ${fx.testPathOf('066-b1')}\n'
        '- command: `dart test`\n- exit: 0\n- at: 2026-08-01T00:00:00.000Z\n'
        '- output:\n```\nold failure\n```\n\n',
        mode: FileMode.append,
      );

      final b = (await ReplayHistory.load(fx.featureDir)).single;
      final out = await ReplayHistory.verifyIntegrity(
        b,
        projectRoot: fx.root.path,
      );

      expect(out.ok, isFalse);
      expect(out.reason, contains('red-exit-zero'));
    });

    test('U4: a red entry without a classification diverges', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await File(fx.testPathOf('066-b1')).parent.create(recursive: true);
      await File(fx.testPathOf('066-b1')).writeAsString('// test\n');
      await File(fx.cycleLogPath).writeAsString(
        '\n## Cycle: 066-b1 (red)\n\n- behavior: 066-b1\n'
        '- kind: red\n- criterion: FR-001\n'
        '- test: ${fx.testPathOf('066-b1')}\n'
        '- command: `dart test`\n- exit: 1\n- at: 2026-08-01T00:00:00.000Z\n'
        '- output:\n```\nold failure\n```\n\n',
        mode: FileMode.append,
      );

      final b = (await ReplayHistory.load(fx.featureDir)).single;
      final out = await ReplayHistory.verifyIntegrity(
        b,
        projectRoot: fx.root.path,
      );

      expect(out.ok, isFalse);
      expect(out.reason, contains('red-no-classification'));
    });

    test('U4: a valid red passes', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendRedOnly('066-b1');

      final b = (await ReplayHistory.load(fx.featureDir)).single;
      final out = await ReplayHistory.verifyIntegrity(
        b,
        projectRoot: fx.root.path,
      );

      expect(out.ok, isTrue, reason: out.reason);
    });

    test('U5: replayability derives from what was recorded', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      // Only-red behavior.
      await fx.appendRedOnly('066-b1');
      // Green without a recorded command (hand-written, hash-less).
      await File(fx.testPathOf('066-b2')).parent.create(recursive: true);
      await File(fx.testPathOf('066-b2')).writeAsString('// test\n');
      await File(fx.cycleLogPath).writeAsString(
        '\n## Cycle: 066-b2 (green)\n\n- behavior: 066-b2\n'
        '- kind: green\n- criterion: FR-001\n- test: ${fx.testPathOf('066-b2')}\n'
        '- exit: 0\n- at: 2026-08-01T00:00:00.000Z\n'
        '- output:\n```\npassed\n```\n\n',
        mode: FileMode.append,
      );
      // Fully recorded behavior (gen steps + green command).
      await fx.appendCycle(
        '066-b3',
        marker: 'm3',
        genSteps: [genStep(fx.genCommandOf('066-b3'))],
      );

      final behaviors = await ReplayHistory.load(fx.featureDir);
      final onlyRed = behaviors.firstWhere((b) => b.id == '066-b1');
      final noCommand = behaviors.firstWhere((b) => b.id == '066-b2');
      final full = behaviors.firstWhere((b) => b.id == '066-b3');

      expect(onlyRed.canReplayGen, isFalse);
      expect(onlyRed.canReplayVerify, isFalse);
      expect(noCommand.canReplayGen, isFalse);
      expect(noCommand.canReplayVerify, isFalse);
      expect(full.canReplayGen, isTrue);
      expect(full.canReplayVerify, isTrue);
    });
  });
}
