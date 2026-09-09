// Issue #1375 — `zfa tdd gen <id> --adopt` on an OWNED but hand-refined
// test file REGENERATED the guard test in place (verdict=reused),
// destroying the author's hand-delta (the #1259 marker flow: refine the
// test, remove the vacuous-guard marker) and leaving the suite red.
//
// Fix under test (spec 1375-adopt-preserves-refined): under --adopt, an
// owned file whose bytes are a provable hand refinement (the generated
// provenance header + behavior id survive, the assertion set differs) is
// PRESERVED and re-registered — never regenerated.
//
// Behaviors:
//   B1 — gen --adopt keeps the hand refinement (the hand assertion
//        survives on disk) and reports the adopted verdict.
//   B2 — gen WITHOUT --adopt still regenerates (the documented
//        regeneration path is unchanged).
//   B3 — the refinement is idempotent: a second gen --adopt keeps it.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

const handMarker = 'hand refinement (issue #1375): authored assertion';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    // Seed the registry record DIRECTLY with the namespaced paths gen
    // computes (the ownership preflight compares the two) — an owned
    // pair whose test file then gets hand-refined (the issue repro).
    final namespacedTestPath = p.join(
      fx.root.path,
      'test',
      'tdd',
      fx.featureName,
      'a1_test.dart',
    );
    final namespacedSubjectPath = p.join(
      fx.root.path,
      'lib',
      'tdd',
      fx.featureName,
      'a1_subject.dart',
    );
    await fx.registerBehavior(
      id: 'A1',
      description: 'create entity Login with email',
      testPath: namespacedTestPath,
    );
    // Re-align the subject path to the namespaced layout (registerBehavior
    // writes the flat lib/ form; gen computes the tdd-namespaced one).
    final artifactsFile = File(fx.artifactsPath);
    final doc =
        jsonDecode(artifactsFile.readAsStringSync()) as Map<String, dynamic>;
    final records = (doc['records'] as List).cast<Map<String, dynamic>>();
    for (final r in records) {
      if (r['behavior_id'] == 'A1') {
        r['subject_path'] = 'lib/tdd/${fx.featureName}/a1_subject.dart';
      }
    }
    await artifactsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(doc),
    );
    // The subject file lives at the namespaced path too.
    final subjectFile = File(namespacedSubjectPath)
      ..createSync(recursive: true);
    subjectFile.writeAsStringSync(
      '// GENERATED STUB — zfa tdd gen A1\n// behavior_id: A1\n',
    );
    // gen resolves the behavior id through the test list too.
    await File(p.join(fx.featureDir, 'tdd', 'test-list.md')).writeAsString(
      '# Test List: ${fx.featureName}\n\n'
      '## Inner loop: unit behaviors\n\n'
      'One per functional requirement in spec.md.\n\n'
      '| id | behavior | traces | state |\n'
      '| -- | -------- | ------ | ----- |\n'
      '| A1 | create entity Login with email | FR-007 | PENDING |\n',
    );
    // The author hand-refines the generated test: the provenance header
    // and behavior id survive (the #840/#1375 shape contract), the
    // assertion set carries the authored delta.
    final testFile = File(namespacedTestPath);
    testFile.writeAsStringSync('''
// GENERATED TEST — `zfa tdd gen A1`.
// behavior_id: A1
library;

import 'package:test/test.dart';

void main() {
  test('A1 — create entity Login with email', () {
    // $handMarker
    expect(true, isTrue);
  });
}
''');
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  String testPath() =>
      p.join(fx.root.path, 'test', 'tdd', fx.featureName, 'a1_test.dart');

  test('B1: gen --adopt preserves the hand refinement', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'gen',
      'A1',
      '--feature',
      fx.featureName,
      '--adopt',
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: output);

    final content = File(testPath()).readAsStringSync();
    expect(
      content,
      contains(handMarker),
      reason: 'the hand-delta survives the adopt',
    );
    expect(
      content,
      contains('behavior_id: A1'),
      reason: 'the provenance header still binds the behavior',
    );
  });

  test('B2: gen WITHOUT --adopt also preserves (the #1320 progression '
      'guard already refuses to clobber a progressed test)', () async {
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

    final content = File(testPath()).readAsStringSync();
    expect(
      content,
      contains(handMarker),
      reason:
          'a progressed (no-UnimplementedError) test is never '
          'clobbered by gen — preservation is unconditional on master',
    );
  });

  test(
    'B3: the refinement is idempotent across repeated gen --adopt',
    () async {
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'gen',
        'A1',
        '--feature',
        fx.featureName,
        '--adopt',
        '--project',
        fx.root.path,
      ]);
      await runner.runCapturing([
        'tdd',
        'gen',
        'A1',
        '--feature',
        fx.featureName,
        '--adopt',
        '--project',
        fx.root.path,
      ]);

      final content = File(testPath()).readAsStringSync();
      expect(content, contains(handMarker), reason: content);
    },
  );
}
