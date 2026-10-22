@Tags(['slow'])
// Regression test for zuraffa#1974: `zfa tdd compose` on a MISSING composed
// subject must report the doctor's drift verdict — the NAMED drift line and
// the doctor's `-->` fix line — instead of a bare `runner-error` that carries
// no reason and no recovery path.
//
// (the `slow` tier matches the sibling compose suite — same fixture)
//
// The pre-fix symptom: the summary line was
//   compose: behavior=A1 outcome=runner-error feature=<feature>
// with no drift line and no `-->` fix line, so the recovery path was not
// discoverable from the command itself.
//
// The contract asserted here:
//   1. the drift line is the one `zfa tdd doctor <feature>` prints for the
//      same file: `drift: <id>: <path> is recorded but missing from disk`;
//   2. the `-->` fix line is the doctor's own prescription for that state
//      (`zfa tdd doctor <feature> --repair` when the record is fully gone,
//      `zfa tdd reset <feature>` when a surviving half keeps it);
//   3. the machine verdict carries BOTH (the `drifts` and `fix` fields).
//
// The review round added two more states, both of which the pre-fix code
// got wrong — and both of which the doctor already classified:
//   4. the RELOCATED registry (issue #1397) — the recorded paths name a
//      foreign project root while the artifacts sit at the same
//      project-relative location. The doctor's remedy is the path rewrite
//      (`migrate-paths`), never the destructive reset the fallback
//      prescribed;
//   5. the UNOWNED generated file (bug #840) — the doctor prescribes the
//      adoption FIRST, so a compose that prescribed the reset would send
//      the operator down the destructive road.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The gen-shaped acceptance stub compose rewrites.
String acceptanceStub(String id) =>
    '''
// GENERATED STUB — `zfa tdd gen $id`.
library;

/// Scenario runner for behavior $id.
void subject_${id.toLowerCase().replaceAll('-', '_')}() =>
    throw UnimplementedError('subject not implemented');
''';

/// A compiling anchor subject defining the default target symbol.
String anchorSubject(String id) =>
    '''
library;

int subject_${id.toLowerCase().replaceAll('-', '_')}() => 0;
''';

/// Seed the canonical compose fixture: an acceptance target certified red
/// and one green unit with an existing subject file (the composition anchor).
Future<void> seedComposeFixture(TddFixture fx) async {
  await fx.seedTestList([
    (
      id: 'A-001',
      description: 'the signup flow completes and the account is usable',
      traces: 'FR-007',
      state: 'PENDING',
      kind: 'acceptance',
    ),
    (
      id: 'U-001',
      description: 'unit behavior backing A-001',
      traces: 'FR-007',
      state: 'PENDING',
      kind: 'unit',
    ),
  ]);
  await fx.seedCertifiedRed(
    id: 'A-001',
    description: 'the signup flow completes and the account is usable',
    subjectContent: acceptanceStub('A-001'),
  );
  await fx.registerBehavior(id: 'U-001', description: 'unit behavior one');
  await fx.seedGreenEvidence('U-001');
  await File(fx.subjectPathOf('U-001')).writeAsString(anchorSubject('U-001'));
}

/// The last stdout line, parsed as the versioned verdict envelope.
Map<String, dynamic> verdictMap(String out) {
  final lines = out
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return jsonDecode(lines.last) as Map<String, dynamic>;
}

/// Rewrite a registry record's recorded paths — the stored FORM, exactly
/// as a registry committed on another machine carries it (issue #1397).
Future<void> rewriteRecordedPaths(
  TddFixture fx,
  String id, {
  required String testPath,
  required String subjectPath,
}) async {
  final raw =
      jsonDecode(await File(fx.artifactsPath).readAsString())
          as Map<String, dynamic>;
  final records = (raw['records'] as List).cast<Map<String, dynamic>>();
  final record = records.firstWhere((r) => r['behavior_id'] == id);
  record['test_path'] = testPath;
  record['subject_path'] = subjectPath;
  await File(fx.artifactsPath).writeAsString(jsonEncode(raw));
}

/// A generated-shape file under the gen default layout that NO registry
/// owns — the doctor-grade adopt state (bug #840).
Future<void> seedUnownedGeneratedFile(
  TddFixture fx, {
  required String id,
  String fileName = 'ghost_subject.dart',
}) async {
  final file = File(p.join(fx.root.path, 'lib', 'tdd', fileName));
  await file.parent.create(recursive: true);
  await file.writeAsString('''
// GENERATED STUB — `zfa tdd gen $id`.
// behavior_id: $id
library;
''');
}

void main() {
  late TddFixture fx;
  final runner = CliRunner(exitOnCompletion: false);

  List<String> composeArgs({String? id, String? feature, bool json = false}) {
    final args = <String>['tdd', 'compose', '--project', fx.root.path];
    if (json) args.add('--json');
    if (feature != null) args.addAll(['--feature', feature]);
    if (id != null) args.add(id);
    return args;
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: '1974-compose');
    await seedComposeFixture(fx);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('#1974 — compose reports the doctor drift verdict', () {
    test('a missing composed subject names the drift and the doctor\'s '
        'reset prescription (the test half still survives)', () async {
      await File(fx.subjectPathOf('A-001')).delete();

      final out = await runner.runCapturing(composeArgs(id: 'A-001'));

      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
      // The drift line is the one doctor prints for the same file.
      expect(
        out,
        contains(
          'drift: A-001: lib/a_001_subject.dart is recorded but missing '
          'from disk',
        ),
        reason: out,
      );
      // A half-missing record keeps the heavier reset as its remedy.
      expect(
        out,
        contains('--> fix: zfa tdd reset ${fx.featureName}'),
        reason: out,
      );
      // The outcome is the NAMED drift, not an opaque runner-error.
      expect(
        out,
        contains(
          'compose: behavior=A-001 outcome=drift feature=${fx.featureName}',
        ),
        reason: out,
      );
    });

    test(
      'a fully-gone record prescribes the doctor\'s surgical repair',
      () async {
        await File(fx.subjectPathOf('A-001')).delete();
        await File(fx.testPathOf('A-001')).delete();

        final out = await runner.runCapturing(composeArgs(id: 'A-001'));

        expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
        expect(
          out,
          contains(
            'drift: A-001: lib/a_001_subject.dart is recorded but missing '
            'from disk',
          ),
          reason: out,
        );
        expect(
          out,
          contains('--> fix: zfa tdd doctor ${fx.featureName} --repair'),
          reason: out,
        );
        expect(
          out,
          contains(
            'compose: behavior=A-001 outcome=drift feature=${fx.featureName}',
          ),
          reason: out,
        );
      },
    );

    test('the machine verdict carries the drift AND the fix line', () async {
      await File(fx.subjectPathOf('A-001')).delete();

      final out = await runner.runCapturing(
        composeArgs(id: 'A-001', json: true),
      );

      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
      final v = verdictMap(out);
      expect(v['verdict'], 'fail', reason: out);
      expect(v['exit_class'], 'drift', reason: out);
      expect(
        (v['drifts'] as List).cast<String>(),
        contains(
          'A-001: lib/a_001_subject.dart is recorded but missing from disk',
        ),
        reason: out,
      );
      expect(v['fix'], 'zfa tdd reset ${fx.featureName}', reason: out);
    });

    test('the doctor and compose agree on the SAME drift for the SAME '
        'file', () async {
      await File(fx.subjectPathOf('A-001')).delete();

      final composeOut = await runner.runCapturing(composeArgs(id: 'A-001'));
      final doctorOut = await runner.runCapturing([
        'tdd',
        'doctor',
        fx.featureName,
        '--project',
        fx.root.path,
      ]);

      final driftLine = RegExp(
        r'drift: (A-001: .*missing from disk)',
      ).firstMatch(composeOut)?.group(1);
      expect(driftLine, isNotNull, reason: composeOut);
      expect(doctorOut, contains(driftLine!), reason: doctorOut);

      final fixLine = RegExp(
        r'--> fix: (zfa tdd \S+)',
      ).firstMatch(composeOut)?.group(1);
      expect(fixLine, isNotNull, reason: composeOut);
      expect(doctorOut, contains(fixLine!), reason: doctorOut);
    });

    test('a healthy compose is unaffected', () async {
      final out = await runner.runCapturing(composeArgs(id: 'A-001'));

      expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
      expect(
        out,
        contains(
          'compose: behavior=A-001 outcome=composed feature=${fx.featureName}',
        ),
        reason: out,
      );
      expect(out, isNot(contains('drift:')), reason: out);
    });
  });

  group('#1974 review — the relocated registry and the adoption order', () {
    test(
      'a relocated registry prescribes the path rewrite, never the reset',
      () async {
        // Issue #1397: the recorded paths name a project root that is not
        // on this machine, while the artifacts sit at the same
        // project-relative location under the current root.
        await rewriteRecordedPaths(
          fx,
          'A-001',
          testPath: '/foreign/root/test/a_001_test.dart',
          subjectPath: '/foreign/root/lib/a_001_subject.dart',
        );

        final out = await runner.runCapturing(composeArgs(id: 'A-001'));

        expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
        // The relocated drift — path-FORM drift, not a missing artifact.
        expect(
          out,
          contains(
            'drift: A-001: the recorded machine-absolute path names a '
            'project root that is not on this machine, but the artifacts '
            'sit at test/a_001_test.dart / lib/a_001_subject.dart under '
            'the current root — a relocated registry',
          ),
          reason: out,
        );
        // The remedy is the path rewrite; the reset would drop the
        // certified behaviors over a path FORM.
        expect(
          out,
          contains(
            '--> fix: zfa tdd migrate-paths --feature ${fx.featureName}',
          ),
          reason: out,
        );
        expect(out, isNot(contains('zfa tdd reset')), reason: out);
        expect(
          out,
          contains(
            'compose: behavior=A-001 outcome=drift feature=${fx.featureName}',
          ),
          reason: out,
        );
      },
    );

    test('the doctor and compose agree on the relocated registry', () async {
      await rewriteRecordedPaths(
        fx,
        'A-001',
        testPath: '/foreign/root/test/a_001_test.dart',
        subjectPath: '/foreign/root/lib/a_001_subject.dart',
      );

      final composeOut = await runner.runCapturing(composeArgs(id: 'A-001'));
      final doctorOut = await runner.runCapturing([
        'tdd',
        'doctor',
        fx.featureName,
        '--project',
        fx.root.path,
      ]);

      final driftLine = RegExp(
        r'drift: (A-001: the recorded machine-absolute path.*)',
      ).firstMatch(composeOut)?.group(1);
      expect(driftLine, isNotNull, reason: composeOut);
      expect(doctorOut, contains(driftLine!), reason: doctorOut);

      final fixLine = RegExp(
        r'--> fix: (zfa tdd \S+ \S+ \S+)',
      ).firstMatch(composeOut)?.group(1);
      expect(fixLine, isNotNull, reason: composeOut);
      expect(doctorOut, contains(fixLine!), reason: doctorOut);
    });

    test(
      'an unowned generated file prescribes the adoption, never the reset',
      () async {
        // The missing subject sends compose into the diagnosis; the
        // doctor diagnoses the UNOWNED file FIRST (bug #840), so the
        // prescription is the adoption.
        await File(fx.subjectPathOf('A-001')).delete();
        await seedUnownedGeneratedFile(fx, id: 'GHOST-001');

        final out = await runner.runCapturing(composeArgs(id: 'A-001'));

        expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
        expect(
          out,
          contains(
            'drift: unowned generated file(s) for "GHOST-001": '
            'lib/tdd/ghost_subject.dart',
          ),
          reason: out,
        );
        expect(
          out,
          contains(
            '--> fix: zfa tdd gen GHOST-001 --adopt --feature '
            '${fx.featureName}',
          ),
          reason: out,
        );
        // The destructive remedy is NOT prescribed for this state.
        expect(out, isNot(contains('zfa tdd reset')), reason: out);
      },
    );

    test('the doctor and compose agree on the unowned-file state', () async {
      await File(fx.subjectPathOf('A-001')).delete();
      await seedUnownedGeneratedFile(fx, id: 'GHOST-001');

      final composeOut = await runner.runCapturing(composeArgs(id: 'A-001'));
      final doctorOut = await runner.runCapturing([
        'tdd',
        'doctor',
        fx.featureName,
        '--project',
        fx.root.path,
      ]);

      final driftLine = RegExp(
        r'drift: (unowned generated file\(s\).*)',
      ).firstMatch(composeOut)?.group(1);
      expect(driftLine, isNotNull, reason: composeOut);
      expect(doctorOut, contains(driftLine!), reason: doctorOut);

      final fixLine = RegExp(
        r'--> fix: (zfa tdd gen GHOST-001 --adopt --feature \S+)',
      ).firstMatch(composeOut)?.group(1);
      expect(fixLine, isNotNull, reason: composeOut);
      expect(doctorOut, contains(fixLine!), reason: doctorOut);
    });
  });
}
