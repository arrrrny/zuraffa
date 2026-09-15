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
//   B2 — no drift → an idempotent re-gen reuses the pair untouched
//        (guard).
//
// Born-red repair (2026-09-15, #1632 follow-up): the suite landed on
// master red — it seeded a progressed (UnimplementedError-free) subject
// the staleness guard must never clobber, declared no contract surface
// for `adaptive_layouts` to resolve, and read the flat `testPathOf`
// path while registering the namespaced one. The fixtures now mirror
// the real gen history: a guard-only pre-drift pair, a faithful
// UnimplementedError stub, and a spec.md declaring the row.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  Future<(int, String)> gen() async {
    final output = await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'gen',
      'A1',
      '--feature',
      fx.featureName,
      '--project',
      fx.root.path,
    ]);
    return (exitCode, output);
  }

  /// The guard-only pair gen renders when the traces cell resolves no
  /// declared contract row — the pre-drift on-disk state B1 simulates.
  String guardOnlyTest(String feature) =>
      '''
import 'package:test/test.dart';

import 'package:tdd_fixture/tdd/$feature/a1_subject.dart' as subject;

void main() {
  test('create entity Login with email', () {
    final result = subject.adaptiveLayouts();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';

  setUp(() async {
    fx = await TddFixture.create();
    // The declared surface the drifted traces cell resolves (#1388's
    // fingerprint hashes the lane-plan traces cell + this spec surface —
    // with nothing declared the render stays guard-only and B1's
    // precondition is unreachable).
    await Directory(fx.featureDir).create(recursive: true);
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: ${fx.featureName}

## Layer Contracts

**Function**:
- `adaptive_layouts`: `resolve(double width) -> String`
''');
    // The registry record must carry the namespaced test path gen
    // computes (the ownership preflight compares the two).
    await fx.registerBehavior(
      id: 'A1',
      description: 'create entity Login with email',
      testPath: fx.namespacedTestPathOf('A1'),
      testContent: guardOnlyTest(fx.featureName),
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
    // A faithful gen stub: the staleness mirror's progressed-artifact
    // guard never clobbers a subject past the stub stage, so the seed
    // must carry the UnimplementedError the real stub throws.
    File(
      p.join(fx.root.path, 'lib', 'tdd', fx.featureName, 'a1_subject.dart'),
    ).writeAsStringSync(
      '// GENERATED STUB — zfa tdd gen A1\n// behavior_id: A1\n'
      'throw UnimplementedError();\n',
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
      // Unlike #1633's analysis of the hand-seeded shape, this fixture arms
      // the drift through the STUB-staleness path (not the legacy-record
      // fingerprint gate): the seeded subject is a faithful UnimplementedError
      // stub and the on-disk pair is the guard-only render, so gen's
      // staleness mirror re-renders, finds the drift, and classifies it as
      // the #1320 contract-drift regeneration.
      final (code, output) = await gen();
      expect(code, 0, reason: output);

      // gen computes the NAMESPACED test layout (`test/tdd/<feature>/…`) —
      // the same path the registry record in setUp registers.
      final testFile = File(fx.namespacedTestPathOf('A1')).readAsStringSync();
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

  test('B2: no drift reuses the pair untouched (guard)', () async {
    // First gen renders the pair from the matching traces cell and arms
    // the record's reuse fingerprint.
    final (firstCode, firstOutput) = await gen();
    expect(firstCode, 0, reason: firstOutput);
    final before = File(fx.namespacedTestPathOf('A1')).readAsStringSync();
    // Second gen with nothing changed: the byte-equality short-circuit
    // reuses the pair — no regeneration note, no rewrite.
    final (secondCode, secondOutput) = await gen();
    expect(secondCode, 0, reason: secondOutput);
    expect(
      secondOutput,
      isNot(contains('traces cell gained a contract token')),
      reason: 'the registered criterion already matches the row',
    );
    expect(
      File(fx.namespacedTestPathOf('A1')).readAsStringSync(),
      before,
      reason: 'the no-drift second gen must not rewrite the pair',
    );
  });
}
