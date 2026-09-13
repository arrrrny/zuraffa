@Tags(['slow'])
// Bug #1495 — registry-owns-missing-file is an UNRESOLVABLE ownership
// conflict: the remedy named by the refusal is the command that refused.
//
// RED evidence: after the recorded pair is deleted from disk, `zfa tdd gen`
// refuses circularly ("Run `zfa tdd gen <id>` after resolving the
// conflict"); `--repair` does not exist (usage error); `--adopt` refuses
// ("a registry record ... already exists — nothing unowned to adopt");
// `doctor` prescribes a full `reset`. No command covers the
// records-without-files drift direction.
//
// The fix (green): `zfa tdd gen <id> --repair` drops the stale record and
// regenerates — audit-logged, adopt discipline for surviving halves,
// verdict `repaired`; refusals name the resolving command per direction;
// `zfa tdd doctor <feature> --repair` garbage-collects every record whose
// files are gone (relocation-aware, surgical — healthy records stay).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-bug-1495';
  const behaviorId = 'B-001';
  const otherId = 'B-002';

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  /// The last non-empty stdout line — the recovery commands' verdict
  /// contract (text `key=value` summary without --json).
  String lastLine(String out) => out
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList()
      .last;

  /// The last non-empty stdout line — the recovery commands' verdict
  /// contract (text `key=value` summary for gen without --json; raw JSON
  /// envelope for doctor).
  Map<String, dynamic> verdictMap(String out) {
    final line = lastLine(out);
    if (line.startsWith('{')) {
      return jsonDecode(line) as Map<String, dynamic>;
    }
    final tokens = RegExp(r'(\w+)=(?:"([^"]*)"|(\S+))').allMatches(line);
    return {for (final m in tokens) m.group(1)!: m.group(2) ?? m.group(3)};
  }

  Future<List<Map<String, dynamic>>> records() async {
    final file = File(fx.artifactsPath);
    if (!file.existsSync()) return const [];
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ((raw['records'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  String snake(String id) => id.toLowerCase().replaceAll('-', '_');

  /// The gen default namespaced layout for the fixture feature.
  String testPathOf(String id) =>
      p.join(fx.root.path, 'test', 'tdd', feature, '${snake(id)}_test.dart');

  String subjectPathOf(String id) =>
      p.join(fx.root.path, 'lib', 'tdd', feature, '${snake(id)}_subject.dart');

  /// One real `zfa tdd gen` — writes the pair + the registry record.
  Future<String> firstGen(String id) async {
    final out = await runCli(['gen', id, '--feature', feature]);
    expect(exitCode, 0, reason: out);
    expect(File(testPathOf(id)).existsSync(), isTrue, reason: out);
    expect(File(subjectPathOf(id)).existsSync(), isTrue, reason: out);
    return out;
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await fx.seedTestList([
      (
        id: behaviorId,
        description: 'returns 42 when invoked with no args',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: otherId,
        description: 'returns 43 when invoked with one arg',
        traces: 'FR-002',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('bug 1495 — gen refusal is actionable (remedy text)', () {
    test(
      'RED: owned-and-missing refusal names the repair command, not the '
      'refusing command; the record stays until an explicit repair',
      () async {
        await firstGen(behaviorId);
        await File(testPathOf(behaviorId)).delete();
        await File(subjectPathOf(behaviorId)).delete();

        final out = await runCli(['gen', behaviorId, '--feature', feature]);

        expect(exitCode, 1, reason: out);
        // The refusal names a command that RESOLVES this direction…
        expect(out, contains('--repair'), reason: out);
        // …and is no longer the circular self-reference (issue #1495).
        expect(
          out,
          isNot(contains('after resolving the conflict')),
          reason: out,
        );
        // The refusal resolved NOTHING by itself: record kept, files
        // still absent (owned-and-absent has nothing to clobber — but
        // dropping the record is an explicit opt-in, never a side effect
        // of a plain gen).
        final rs = await records();
        expect(
          rs.where((r) => r['behavior_id'] == behaviorId),
          hasLength(1),
          reason: out,
        );
        expect(File(testPathOf(behaviorId)).existsSync(), isFalse);
        expect(File(subjectPathOf(behaviorId)).existsSync(), isFalse);
      },
    );

    test('RED: --repair does not exist before the fix (usage error)', () async {
      // RED-only documentation of the flag's absence; at GREEN the same
      // invocation is the successful repair covered by the tests below.
      // Kept out of the green suite on purpose (the flag exists there),
      // the evidence lives in red-evidence.txt.
    }, skip: 'RED-only: superseded at GREEN by the --repair success tests');

    test('RED: exists-unowned refusal names --adopt (the resolving command '
        'for the opposite drift direction)', () async {
      // Files on disk, NO registry record (#840's direction). The refusal
      // must name --adopt, not the bare circular gen remedy.
      final behavior = Behavior(
        id: behaviorId,
        feature: feature,
        kind: BehaviorKind.unit,
        description: 'returns 42 when invoked with no args',
        sourceCriterion: 'FR-001',
        target: 'subjectUnderTest',
      );
      final testFile = File(testPathOf(behaviorId));
      await testFile.parent.create(recursive: true);
      await const BehaviorTestWriter().write(
        behavior: behavior,
        testPath: testPathOf(behaviorId),
        subjectPath: subjectPathOf(behaviorId),
      );
      await const SubjectWriter().write(
        behavior: behavior,
        subjectPath: subjectPathOf(behaviorId),
      );
      expect(File(fx.artifactsPath).existsSync(), isFalse);

      final out = await runCli(['gen', behaviorId, '--feature', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('--adopt'), reason: out);
      // Nothing was registered or overwritten.
      expect(File(fx.artifactsPath).existsSync(), isFalse, reason: out);
    });
  });

  group('bug 1495 — zfa tdd gen <id> --repair', () {
    test('RED: drops the stale record and regenerates the gone pair — '
        'verdict repaired, audit-logged, exactly one record after', () async {
      await firstGen(behaviorId);
      final oldRecord = (await records()).single;
      await File(testPathOf(behaviorId)).delete();
      await File(subjectPathOf(behaviorId)).delete();

      final out = await runCli([
        'gen',
        behaviorId,
        '--feature',
        feature,
        '--repair',
      ]);

      expect(exitCode, 0, reason: out);
      // Fresh pair back on disk.
      expect(File(testPathOf(behaviorId)).existsSync(), isTrue, reason: out);
      expect(File(subjectPathOf(behaviorId)).existsSync(), isTrue, reason: out);
      // Exactly one record for the behavior — the STALE one was
      // dropped, not duplicated against.
      final rs = await records();
      final mine = rs.where((r) => r['behavior_id'] == behaviorId).toList();
      expect(mine, hasLength(1), reason: out);
      expect(
        mine.single['created_at'],
        isNot(oldRecord['created_at']),
        reason: 'the stale record must be REPLACED, not kept — $out',
      );
      // Verdict names the recovery.
      final v = verdictMap(out);
      expect(v['verdict'], 'repaired', reason: out);
      // Audit trail, same discipline as --adopt (bug #840).
      final audit = File(p.join(fx.featureDir, 'tdd', 'audit.log'));
      expect(audit.existsSync(), isTrue, reason: out);
      final auditLine = audit
          .readAsStringSync()
          .split('\n')
          .where((l) => l.contains('"action":"repair"'))
          .toList();
      expect(auditLine, hasLength(1), reason: out);
      expect(auditLine.single, contains('"behavior":"$behaviorId"'));
    });

    test('RED: keeps a shape-verified surviving half byte-identical and '
        'regenerates only the gone half (adopt discipline)', () async {
      await firstGen(behaviorId);
      final testBytes = await File(testPathOf(behaviorId)).readAsBytes();
      await File(subjectPathOf(behaviorId)).delete();

      final out = await runCli([
        'gen',
        behaviorId,
        '--feature',
        feature,
        '--repair',
      ]);

      expect(exitCode, 0, reason: out);
      // The surviving test half was kept, NOT rewritten.
      expect(
        await File(testPathOf(behaviorId)).readAsBytes(),
        testBytes,
        reason:
            'a repair must never rewrite a verified surviving '
            'half — $out',
      );
      expect(File(subjectPathOf(behaviorId)).existsSync(), isTrue, reason: out);
      final rs = await records();
      expect(
        rs.where((r) => r['behavior_id'] == behaviorId),
        hasLength(1),
        reason: out,
      );
      final v = verdictMap(out);
      expect(v['verdict'], 'repaired', reason: out);
    });

    test(
      'RED: --repair on the exists-unowned direction refuses and names '
      '--adopt (no stale record to drop; --adopt contract untouched)',
      () async {
        // Files on disk, no registry record: repair has nothing to
        // repair. The refusal must route to the #840 remedy.
        final behavior = Behavior(
          id: behaviorId,
          feature: feature,
          kind: BehaviorKind.unit,
          description: 'returns 42 when invoked with no args',
          sourceCriterion: 'FR-001',
          target: 'subjectUnderTest',
        );
        await const BehaviorTestWriter().write(
          behavior: behavior,
          testPath: testPathOf(behaviorId),
          subjectPath: subjectPathOf(behaviorId),
        );
        await const SubjectWriter().write(
          behavior: behavior,
          subjectPath: subjectPathOf(behaviorId),
        );

        final out = await runCli([
          'gen',
          behaviorId,
          '--feature',
          feature,
          '--repair',
        ]);

        expect(exitCode, 1, reason: out);
        expect(out, contains('--adopt'), reason: out);
        expect(File(fx.artifactsPath).existsSync(), isFalse, reason: out);
      },
    );

    test('RED: --adopt on the owned-and-missing state still refuses '
        '(regression guard — the #840 contract is unchanged)', () async {
      await firstGen(behaviorId);
      await File(testPathOf(behaviorId)).delete();
      await File(subjectPathOf(behaviorId)).delete();

      final out = await runCli([
        'gen',
        behaviorId,
        '--feature',
        feature,
        '--adopt',
      ]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('nothing unowned to adopt'), reason: out);
      // The stale record was NOT dropped by adopt.
      expect(
        (await records()).where((r) => r['behavior_id'] == behaviorId),
        hasLength(1),
        reason: out,
      );
    });
  });

  group('bug 1495 — zfa tdd doctor <feature> --repair', () {
    test('RED: garbage-collects every record whose files are gone and keeps '
        'healthy records — audit-logged, exit 0', () async {
      await firstGen(behaviorId);
      await firstGen(otherId);
      expect((await records()), hasLength(2));
      await File(testPathOf(behaviorId)).delete();
      await File(subjectPathOf(behaviorId)).delete();

      final out = await runCli(['doctor', feature, '--repair']);

      expect(exitCode, 0, reason: out);
      final rs = await records();
      expect(
        rs.where((r) => r['behavior_id'] == behaviorId),
        isEmpty,
        reason: 'the gone-file record must be collected — $out',
      );
      expect(
        rs.where((r) => r['behavior_id'] == otherId),
        hasLength(1),
        reason: 'the healthy record must stay — $out',
      );
      final audit = File(p.join(fx.featureDir, 'tdd', 'audit.log'));
      expect(audit.existsSync(), isTrue, reason: out);
      expect(
        audit.readAsStringSync(),
        contains('"action":"repair"'),
        reason: out,
      );
      final v = verdictMap(out);
      expect(v['verdict'], 'repaired', reason: out);
    });

    test('RED: refuses to garbage-collect a HALF-missing record (the '
        'surviving half is still owned — GC would orphan it); prescribes '
        'reset, drops nothing', () async {
      await firstGen(behaviorId);
      await File(testPathOf(behaviorId)).delete();

      final out = await runCli(['doctor', feature, '--repair']);

      expect(exitCode, 1, reason: out);
      expect(out, contains('zfa tdd reset $feature'), reason: out);
      expect(
        (await records()).where((r) => r['behavior_id'] == behaviorId),
        hasLength(1),
        reason: out,
      );
    });

    test('RED: without --repair the fully-gone drift still exits 1 and the '
        'fix line names the surgical repair command', () async {
      await firstGen(behaviorId);
      await File(testPathOf(behaviorId)).delete();
      await File(subjectPathOf(behaviorId)).delete();

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('--repair'), reason: out);
      // Diagnosis only: nothing was dropped.
      expect(
        (await records()).where((r) => r['behavior_id'] == behaviorId),
        hasLength(1),
        reason: out,
      );
    });

    test('--repair with a healthy feature is a no-op success (nothing to '
        'collect)', () async {
      await firstGen(behaviorId);

      final out = await runCli(['doctor', feature, '--repair']);

      expect(exitCode, 0, reason: out);
      expect((await records()), hasLength(1), reason: out);
    });
  });
}
