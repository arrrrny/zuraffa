// Issue #1388 — `zfa tdd gen` reuses a stale guard-only pair even after
// the traces migration: the recovery loop the vacuous-guard stop
// prescribes (add `traces:` → re-run plan → gen → run) could not take
// effect because gen's reuse decision ignored the changed traces cell.
//
// Fix under test (spec 1388-gen-traces-fingerprint): when the current
// lane-plan traces cell differs from the record's registered criterion,
// the pair is REGENERATED (the #1320 note path) — the stale guard-only
// test carries the new declared routing afterwards.
//
// Behaviors:
//   B1 — traces drift (record 'FR-007' vs row 'FR-007, adaptive_layouts')
//        → the regenerated test carries the new routing in its group.
//   B2 — no drift (record criterion == row traces) → the pair is reused
//        untouched (guard).

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    // The registry record must carry the namespaced test path gen
    // computes (the ownership preflight compares the two).
    await fx.registerBehavior(
      id: 'A1',
      description: 'create entity Login with email',
      testPath: p.join(
        fx.root.path,
        'test',
        'tdd',
        fx.featureName,
        'a1_test.dart',
      ),
    );
    // Re-align the record's subject path to the namespaced layout gen
    // computes (registerBehavior records the flat lib/ form).
    final artifactsFile = File(fx.artifactsPath);
    final doc =
        jsonDecode(artifactsFile.readAsStringSync()) as Map<String, dynamic>;
    for (final r in (doc['records'] as List).cast<Map<String, dynamic>>()) {
      if (r['behavior_id'] == 'A1') {
        r['subject_path'] = 'lib/tdd/${fx.featureName}/a1_subject.dart';
      }
    }
    await artifactsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(doc),
    );
    Directory(
      p.join(fx.root.path, 'lib', 'tdd', fx.featureName),
    ).createSync(recursive: true);
    File(
      p.join(fx.root.path, 'lib', 'tdd', fx.featureName, 'a1_subject.dart'),
    ).writeAsStringSync(
      '// GENERATED STUB — zfa tdd gen A1\n// behavior_id: A1\n',
    );
    await File(p.join(fx.featureDir, 'tdd', 'test-list.md')).writeAsString(
      '# Test List: ${fx.featureName}\n\n'
      '## Inner loop: unit behaviors\n\n'
      'One per functional requirement in spec.md.\n\n'
      '| id | behavior | traces | state |\n'
      '| -- | -------- | ------ | ----- |\n'
      '| A1 | create entity Login with email | FR-007, adaptive_layouts | PENDING |\n',
    );
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  test(
    'B1: traces drift forces regeneration carrying the new routing',
    () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'tdd',
        'gen',
        'A1',
        '--feature',
        fx.featureName,
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: output);

      final testFile = File(fx.testPathOf('A1')).readAsStringSync();
      expect(
        testFile,
        contains('adaptive_layouts'),
        reason:
            'the regenerated test carries the NEW declared routing '
            '(the record criterion was FR-007 only)',
      );
      expect(
        output,
        contains('traces cell gained a contract token'),
        reason: 'the #1320 note names the traces-driven regeneration',
      );
    },
  );

  test('B2: no traces drift reuses the pair untouched (guard)', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'gen',
      'A1',
      '--feature',
      fx.featureName,
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: output);
    expect(
      output,
      isNot(contains('traces cell gained a contract token')),
      reason: 'the registered criterion already matches the row',
    );
  });
}
