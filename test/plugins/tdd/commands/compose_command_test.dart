// Tests for `ComposeCommand` (spec 052-acceptance-make-composition,
// T006: A3..A8 acceptance + U9..U16 unit behaviors).
//
// Drives the public CLI surface (`zfa tdd compose`) in-process via
// `CliRunner` against a real temp fixture project (the sc_001–sc_012
// pattern): the fixture root is passed explicitly via `--project`, so
// this suite never mutates the process-global Directory.current.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

List<String> composeArgs(TddFixture fx, {String? id, String? feature}) {
  final args = <String>['tdd', 'compose', '--project', fx.root.path];
  if (feature != null) args.addAll(['--feature', feature]);
  if (id != null) args.add(id);
  return args;
}

/// The gen-shaped subject stub compose rewrites (wire's stub signature).
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

/// Seed the canonical compose fixture: acceptance target certified red,
/// one green unit with an existing subject file.
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

void main() {
  late TddFixture fx;
  final runner = CliRunner(exitOnCompletion: false);

  setUp(() async {
    fx = await TddFixture.create(featureName: '052-compose');
    await seedComposeFixture(fx);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('US2 — the composition surface', () {
    test('A4: compose wires the acceptance subject against the green unit '
        'subjects, exit 0, summary line final', () async {
      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));

      expect(exitCode, 0, reason: out);
      final lines = out
          .split('\n')
          .map((l) => l.trimRight())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(
        lines.last,
        'compose: behavior=A-001 outcome=composed '
        'feature=${fx.featureName}',
      );
      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      expect(subject, isNot(contains('UnimplementedError')));
    });

    test('A3: the composed subject is stamped, anchored, and leaves the '
        'test file untouched', () async {
      final testTreeBefore = fx.checksumTestTree();
      final anchorFileBefore = await File(
        fx.subjectPathOf('U-001'),
      ).readAsString();

      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));
      expect(exitCode, 0, reason: out);

      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      // GENERATED stamp naming the compose command + behavior.
      expect(subject, contains('GENERATED IMPLEMENTATION'));
      expect(subject, contains('zfa tdd compose A-001'));
      expect(subject, contains('behavior_id: A-001'));
      // The anchor: the green unit subject is imported and referenced.
      expect(
        subject,
        contains('package:tdd_fixture/${_libRel(fx.subjectPathOf('U-001'))}'),
      );
      expect(subject, contains('subject_u_001'));
      // The anchor file itself is untouched, and no test file changed.
      expect(
        await File(fx.subjectPathOf('U-001')).readAsString(),
        anchorFileBefore,
      );
      expect(fx.checksumTestTree(), testTreeBefore);
    });

    test('A5/U14: re-compose is idempotent (already-composed, exit 0, '
        'file byte-identical)', () async {
      await runner.runCapturing(composeArgs(fx, id: 'A-001'));
      expect(exitCode, 0);
      final composed = await File(fx.subjectPathOf('A-001')).readAsString();

      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'compose: behavior=A-001 outcome=already-composed '
          'feature=${fx.featureName}',
        ),
      );
      expect(await File(fx.subjectPathOf('A-001')).readAsString(), composed);
    });

    test('A6: no green unit subjects → no-green-units, exit 1, no '
        'rewrite', () async {
      // Strip the unit's green evidence: rewrite the cycle log without it.
      final log = await File(fx.cycleLogPath).readAsString();
      await File(
        fx.cycleLogPath,
      ).writeAsString(log.replaceAll('kind: green', 'kind: red-x'));
      final stubBefore = await File(fx.subjectPathOf('A-001')).readAsString();

      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));

      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains(
          'compose: behavior=A-001 outcome=no-green-units '
          'feature=${fx.featureName}',
        ),
      );
      expect(out.toLowerCase(), contains('no green unit subjects'));
      expect(await File(fx.subjectPathOf('A-001')).readAsString(), stubBefore);
    });

    test('A7: a green unit with a missing subject file → runner-error '
        'naming the missing artifact', () async {
      await File(fx.subjectPathOf('U-001')).delete();
      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=runner-error'));
      expect(out, contains(fx.subjectPathOf('U-001')));
    });

    test(
      'A8: the paired test file is byte-identical on every outcome',
      () async {
        final before = fx.checksumTestTree();

        await runner.runCapturing(composeArgs(fx, id: 'A-001'));
        expect(exitCode, 0);
        expect(fx.checksumTestTree(), before);

        await runner.runCapturing(composeArgs(fx, id: 'A-001'));
        expect(exitCode, 0);
        expect(fx.checksumTestTree(), before);

        // Failure paths never touch the test tree either.
        final log = await File(fx.cycleLogPath).readAsString();
        await File(
          fx.cycleLogPath,
        ).writeAsString(log.replaceAll('kind: green', 'kind: red-x'));
        await runner.runCapturing(composeArgs(fx, id: 'A-001'));
        expect(exitCode, isNot(0));
        expect(fx.checksumTestTree(), before);
      },
    );

    test('U9: unknown id names the gen remediation', () async {
      final out = await runner.runCapturing(composeArgs(fx, id: 'NOPE'));

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('NOPE'));
      expect(out, contains('zfa tdd gen NOPE'));
      expect(out, contains('outcome=runner-error'));
    });

    test(
      'U10: an id registered in multiple features demands --feature',
      () async {
        // A second feature registry under the same project root holding the
        // same behavior id.
        final otherFeature = Directory(
          p.join(fx.root.path, 'specs', '052-compose-other'),
        );
        await Directory(
          p.join(otherFeature.path, 'tdd'),
        ).create(recursive: true);
        await File(
          p.join(otherFeature.path, 'tdd', 'artifacts.json'),
        ).writeAsString(
          '{"feature": "052-compose-other", "records": [{"behavior_id": '
          '"A-001", "feature": "052-compose-other", "source_criterion": '
          '"FR-007", "test_path": "test/a1_test.dart", "subject_path": '
          '"lib/a1_subject.dart", "runnable_test_name": "t::A-001::x", '
          '"test_ownership": "created", "subject_ownership": "created", '
          '"created_at": "2026-08-30T00:00:00.000Z"}]}',
        );

        final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('ambiguous'));
        expect(out, contains('052-compose-other'));
        expect(out, contains('--feature'));

        // With --feature the resolution succeeds.
        final out2 = await runner.runCapturing(
          composeArgs(fx, id: 'A-001', feature: fx.featureName),
        );
        expect(exitCode, 0, reason: out2);
      },
    );

    test(
      'U11: no certified-red evidence → not-certified-red, exit 1',
      () async {
        // Rebuild the fixture with an acceptance target that has NO red
        // evidence.
        final fx2 = await TddFixture.create(featureName: '052-compose-nored');
        await seedComposeFixture(fx2);
        final log = await File(fx2.cycleLogPath).readAsString();
        await File(
          fx2.cycleLogPath,
        ).writeAsString(log.replaceAll('kind: red', 'kind: red-x'));

        final out = await runner.runCapturing(composeArgs(fx2, id: 'A-001'));

        expect(exitCode, isNot(0), reason: out);
        expect(
          out,
          contains(
            'compose: behavior=A-001 outcome=not-certified-red '
            'feature=${fx2.featureName}',
          ),
        );
        expect(out, contains('verify-red'));
        fx2.dispose();
      },
    );

    test('U12: a missing subject artifact stops before any write', () async {
      await File(fx.subjectPathOf('A-001')).delete();
      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=runner-error'));
      expect(out, contains(fx.subjectPathOf('A-001')));
      expect(out, contains('zfa tdd gen'));
    });

    test('U13: the composed body is stamped and anchored (int + void '
        'subjects)', () async {
      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));
      expect(exitCode, 0, reason: out);

      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      expect(subject, contains("library;"));
      expect(subject, contains('import'));
      expect(subject, contains('as anchor0'));
      expect(subject, contains('anchor0.subject_u_001'));
      expect(subject, contains('void subject_a_001() {'));
      expect(subject, contains('composedUnitAnchors'));
    });

    test('U15: an unrecognized stub shape is refused, not rewritten', () async {
      await File(fx.subjectPathOf('A-001')).writeAsString('''
class Weird {
  void fail() => throw UnimplementedError('inside a class');
}
''');
      final before = await File(fx.subjectPathOf('A-001')).readAsString();

      final out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=runner-error'));
      expect(out.toLowerCase(), contains('unrecognized'));
      expect(await File(fx.subjectPathOf('A-001')).readAsString(), before);
    });

    test(
      'U16: the summary line is the final stdout line on every outcome',
      () async {
        // Success path.
        var out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));
        var lines = out
            .split('\n')
            .map((l) => l.trimRight())
            .where((l) => l.isNotEmpty)
            .toList();
        expect(lines.last, startsWith('compose: behavior=A-001 outcome='));

        // already-composed path.
        out = await runner.runCapturing(composeArgs(fx, id: 'A-001'));
        lines = out
            .split('\n')
            .map((l) => l.trimRight())
            .where((l) => l.isNotEmpty)
            .toList();
        expect(lines.last, startsWith('compose: behavior=A-001 outcome='));

        // Failure paths.
        out = await runner.runCapturing(composeArgs(fx, id: 'NOPE'));
        lines = out
            .split('\n')
            .map((l) => l.trimRight())
            .where((l) => l.isNotEmpty)
            .toList();
        expect(lines.last, startsWith('compose: behavior=NOPE outcome='));
      },
    );
  });
}

/// The `package:<pubspec-name>/...` import path for a file under lib/.
String _libRel(String subjectPath) {
  // subjectPath: <root>/lib/<rest> → <rest> with forward slashes.
  final libIdx = subjectPath.indexOf('${Platform.pathSeparator}lib');
  final rest = subjectPath.substring(libIdx + 5);
  return rest.replaceAll(Platform.pathSeparator, '/');
}
