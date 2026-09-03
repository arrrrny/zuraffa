/// U7 for spec 0806-zfa-replay: `zfa tdd func` is a convergent fixed point
/// on implemented subjects — the stale generated doc comment that merely
/// *mentions* `UnimplementedError` ("Throws [UnimplementedError] until the
/// real implementation lands.") must not trip the refusal, while a subject
/// with a genuine unrecognized `throw UnimplementedError(` still refuses.
///
/// This is the exact shape every scaffolded subject in
/// `examples/todo_tdd` has AFTER its recorded `tdd func` step ran — the
/// todo example's replay re-runs `tdd func <id>` against that tree.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await Directory('${fx.root.path}/lib').create(recursive: true);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> runFunc({String? id = 'B-001'}) {
    final runner = CliRunner(exitOnCompletion: false);
    final args = <String>['tdd', 'func', ?id, '--project', fx.root.path];
    return runner.runCapturing(args);
  }

  test('U7: an implemented subject whose doc comment mentions '
      'UnimplementedError is already-implemented, exit 0', () async {
    await fx.registerBehavior(
      id: 'B-001',
      description:
          'render returns a non-empty string for a fully '
          'populated task',
    );
    // The post-scaffold shape: implemented body + the stub header's
    // stale doc comment (exactly examples/todo_tdd's lib/tdd/*_subject.dart).
    final before = '''
// GENERATED STUB — `zfa tdd gen B-001` (spec 044-test-tdd-generation).
library;

/// Subject for behavior B-001.
///
/// Throws [UnimplementedError] until the real implementation lands.
String subject_b_001() {
  return 'subject_b_001';
}
''';
    await File(fx.subjectPathOf('B-001')).writeAsString(before);

    final out = await runFunc();

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains(
        'func: behavior=B-001 outcome=already-implemented '
        'feature=${fx.featureName}',
      ),
    );
    expect(await File(fx.subjectPathOf('B-001')).readAsString(), before);
  });

  test('U7: a genuine unrecognized throw still refuses with exit 1 '
      '(never guess at a shape func did not generate)', () async {
    await fx.registerBehavior(
      id: 'B-001',
      description:
          'render returns a non-empty string for a fully '
          'populated task',
    );
    await File(fx.subjectPathOf('B-001')).writeAsString('''
library;

/// Subject for behavior B-001.
String subject_b_001() {
  if (true) {
    throw UnimplementedError('hand-written, multi-line');
  }
}
''');

    final out = await runFunc();

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('func: behavior=B-001 outcome=runner-error'));
  });
}
