@Tags(['slow'])
// Issue #1380 — `zfa tdd reset 004-login-ui` deleted 98 TRACKED files
// owned by OTHER features (test/tdd/{072,073,074,075,078,079}-*/,
// lib/tdd/{077,078,079}-*/) despite the bug #840 "foreign files never
// deleted" contract. The drift-recovery scan matched files by BARE
// behavior id (A1/U1 — ids shared across features) plus the generated
// shape, and the foreign check only consulted live registries — files
// whose registry rows were gone (or never existed) fell through and were
// deleted.
//
// Fix under test (spec 1380-reset-namespace-guard): a drift-recovered
// candidate must live in THIS feature's namespace — the directory segment
// after the lane root (`test/tdd/<feature>/`, `lib/tdd/<feature>/`) must
// equal the feature being reset. A candidate under another feature's
// namespace is foreign even when its header names a dropped id (bare ids
// are shared across features; the header alone is not global ownership).
//
// Behaviors:
//   B1 — other features' generated files (same bare ids) survive the
//        reset of 004-login-ui.
//   B2 — this feature's own drifted owned file is still recovered and
//        deleted (the #1331 behavior unchanged).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '004-login-ui';

  /// A generated-shape file whose provenance header names [id] — the
  /// shape every feature's gen pair carries (bare ids are shared across
  /// features, which is the trap).
  Future<File> seedGeneratedShapedFile(String relativePath, String id) async {
    final file = File(p.join(fx.root.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString('''
// GENERATED TEST — `zfa tdd gen $id`.
// behavior_id: $id
library;

import 'package:test/test.dart';

void main() {
  test('$id — generated shape', () {
    expect(1, 1);
  });
}
''');
    return file;
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.registerBehavior(
      id: 'A1',
      description: 'create entity Login with email',
    );
    // Other features' generated files in the SHARED lanes: same bare
    // ids, no registry owning them (the issue's 98-file shape).
    await seedGeneratedShapedFile('test/tdd/072-crypto/a1_test.dart', 'A1');
    await seedGeneratedShapedFile('test/tdd/073-offline/u1_test.dart', 'U1');
    await seedGeneratedShapedFile('lib/tdd/077-reader/a1_subject.dart', 'A1');
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  test('B1: reset deletes only this feature\'s files — other features\' '
      'generated files survive', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'reset',
      feature,
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: output);

    expect(
      File(
        p.join(fx.root.path, 'test/tdd/072-crypto/a1_test.dart'),
      ).existsSync(),
      isTrue,
      reason: '072-crypto is another feature\'s namespace — never deleted',
    );
    expect(
      File(
        p.join(fx.root.path, 'test/tdd/073-offline/u1_test.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(fx.root.path, 'lib/tdd/077-reader/a1_subject.dart'),
      ).existsSync(),
      isTrue,
    );
    // The own pair is gone (reset worked).
    expect(
      File(p.join(fx.testPathOf('A1'))).existsSync(),
      isFalse,
      reason: output,
    );
  });

  test('B2b: a poisoned record naming another feature\'s namespace is '
      'path drift (kept + warned)', () async {
    // The registry record names a FOREIGN namespace path as this
    // feature's recorded test — the file exists, so the recorded-path
    // loop must treat it as path drift (kept), never a delete.
    final poisoned = File(
      p.join(fx.root.path, 'test/tdd/072-crypto/a1_test.dart'),
    );
    final artifactsFile = File(fx.artifactsPath);
    final doc =
        jsonDecode(artifactsFile.readAsStringSync()) as Map<String, dynamic>;
    final records = (doc['records'] as List).cast<Map<String, dynamic>>();
    for (final r in records) {
      if (r['behavior_id'] == 'A1') {
        r['test_path'] = 'test/tdd/072-crypto/a1_test.dart';
      }
    }
    await artifactsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(doc),
    );

    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'reset',
      feature,
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: output);
    expect(output, contains('path drift'), reason: output);
    expect(
      poisoned.existsSync(),
      isTrue,
      reason: 'the foreign-namespace file is never deleted',
    );
  });

  test('B2: this feature\'s own drifted file is still recovered and '
      'deleted (#1331 behavior unchanged)', () async {
    // A drifted OWN file: moved out of the namespaced dir, header still
    // names the dropped id.
    final drifted = File(
      p.join(fx.root.path, 'test', 'tdd', feature, 'a1_test.dart'),
    );
    await drifted.parent.create(recursive: true);
    await drifted.writeAsString('''
// GENERATED TEST — `zfa tdd gen A1`.
// behavior_id: A1
library;

import 'package:test/test.dart';

void main() {
  test('A1 — generated shape', () {
    expect(1, 1);
  });
}
''');

    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'reset',
      feature,
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: output);
    expect(
      drifted.existsSync(),
      isFalse,
      reason: 'the own-namespace drifted file is recovered and deleted',
    );
  });
}
