// Fast unit tests for `FuncCommand` — the plain-function generator
// surface (bug #657).
//
// Drives the public CLI surface (`zfa tdd func`) in-process against a
// TddFixture carrying the gen artifacts (registry record + the exact
// UnimplementedError subject stub SubjectWriter emits). Mirrors the
// wire_command_test.dart conventions:
//   U-F1: a gen-shaped stub for a render-type behavior is rewritten to
//         the derived return type + minimal no-argument implementation (no
//         UnimplementedError, non-empty string returned).
//   U-F2: "returns 42"-style descriptions derive an int return type and
//         a `return 42;` body.
//   U-F3: boolean descriptions derive a bool signature.
//   U-F4: idempotent — an already-implemented subject reports
//         already-implemented and exits 0.
//   U-F5: a missing subject file is a hard runner-error (gen first).
//   U-F6: an unknown behavior id is a hard runner-error.
//   U-F7: an unrecognized UnimplementedError shape is refused, never
//         guessed at.
//   U-F8: the paired test file is never touched (044 ownership).
//   U-F9: only the matched stub declaration is replaced; surrounding source
//         content is preserved.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The gen-shaped stub SubjectWriter emits for a unit behavior
/// (function name = the behavior's target).
String genStyleStub(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation).
library;

/// Subject for behavior $id.
int subject_$symbol() => throw UnimplementedError('subject_$symbol not implemented');
''';
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    // The subject's parent dir (registerBehavior records lib/ paths but
    // the fixture only creates specs/ and bin/).
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

  test('U-F1: a gen-shaped stub for a render-type behavior is rewritten to '
      'the derived return type + minimal no-argument implementation', () async {
    await fx.registerBehavior(
      id: 'B-001',
      description:
          'render returns a non-empty string for a fully populated '
          'task',
    );
    await File(fx.subjectPathOf('B-001')).writeAsString(genStyleStub('B-001'));

    final out = await runFunc();

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains(
        'func: behavior=B-001 outcome=scaffolded feature=${fx.featureName}',
      ),
    );
    final subject = await File(fx.subjectPathOf('B-001')).readAsString();
    expect(subject, isNot(contains('UnimplementedError')));
    // Only the return type is derived; the generated no-argument shape stays.
    expect(subject, contains('String subject_b_001()'));
    // The minimal implementation satisfies the described contract:
    // a non-empty string.
    expect(subject, isNot(contains("''")));
  });

  test('U-F2: a "returns 42" description derives an int signature with a '
      '`return 42;` body', () async {
    await fx.registerBehavior(
      id: 'B-002',
      description: 'returns 42 when invoked with no args',
    );
    await File(fx.subjectPathOf('B-002')).writeAsString(genStyleStub('B-002'));

    final out = await runFunc(id: 'B-002');

    expect(exitCode, 0, reason: 'out: $out');
    final subject = await File(fx.subjectPathOf('B-002')).readAsString();
    expect(subject, contains('int subject_b_002()'));
    expect(subject, contains('return 42;'));
    expect(subject, isNot(contains('UnimplementedError')));
  });

  test('U-F3: a boolean description derives a bool signature', () async {
    await fx.registerBehavior(
      id: 'B-003',
      description: 'return true when the task is fully populated',
    );
    await File(fx.subjectPathOf('B-003')).writeAsString(genStyleStub('B-003'));

    final out = await runFunc(id: 'B-003');

    expect(exitCode, 0, reason: 'out: $out');
    final subject = await File(fx.subjectPathOf('B-003')).readAsString();
    expect(subject, contains('bool subject_b_003()'));
    expect(subject, contains('return true;'));
    expect(subject, isNot(contains('UnimplementedError')));
  });

  test(
    'U-F4: an already-implemented subject is a no-op '
    '(already-implemented, exit 0) so a resumed pipeline stays green',
    () async {
      await fx.registerBehavior(
        id: 'B-001',
        description:
            'render returns a non-empty string for a fully populated '
            'task',
      );
      final before = 'library;\n\nString subject_b_001() => \'done\';\n';
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
      final after = await File(fx.subjectPathOf('B-001')).readAsString();
      expect(after, before, reason: 'an implemented subject is left untouched');
    },
  );

  test('U-F5: a missing subject file is a hard runner-error naming the gen '
      'remediation', () async {
    await fx.registerBehavior(
      id: 'B-001',
      description: 'render returns a non-empty string',
      // registerBehavior records subject_path but writes no subject file.
    );

    final out = await runFunc();

    expect(exitCode, isNot(0), reason: 'out: $out');
    expect(
      out,
      contains(
        'func: behavior=B-001 outcome=runner-error feature=${fx.featureName}',
      ),
    );
    expect(out, contains('zfa tdd gen'));
  });

  test('U-F6: an unknown behavior id is a hard runner-error', () async {
    final out = await runFunc(id: 'B-999');

    expect(exitCode, isNot(0), reason: 'out: $out');
    expect(out, contains('unknown behavior id'));
    // Same convention as `zfa tdd wire` U-W6: an unresolvable id has no
    // feature context.
    expect(out, contains('func: behavior=B-999 outcome=runner-error'));
  });

  test('U-F7: an unrecognized UnimplementedError shape is refused, never '
      'guessed at', () async {
    await fx.registerBehavior(
      id: 'B-001',
      description: 'render returns a non-empty string',
    );
    await File(fx.subjectPathOf('B-001')).writeAsString('''
// GENERATED STUB
library;

int subject_b_001() {
  throw UnimplementedError('odd shape');
}
''');

    final out = await runFunc();

    expect(exitCode, isNot(0), reason: 'out: $out');
    expect(out, contains('unrecognized'));
    expect(out, contains('UnimplementedError'));
    expect(
      out.trim().split('\n').last,
      'func: behavior=B-001 outcome=runner-error feature=${fx.featureName}',
    );
  });

  test('U-F8: the paired test file is never touched (044 ownership)', () async {
    await fx.registerBehavior(
      id: 'B-001',
      description: 'render returns a non-empty string',
    );
    await File(fx.subjectPathOf('B-001')).writeAsString(genStyleStub('B-001'));
    final testBefore = await File(fx.testPathOf('B-001')).readAsString();

    await runFunc();

    final testAfter = await File(fx.testPathOf('B-001')).readAsString();
    expect(testAfter, testBefore);
  });

  test('U-F9: scaffolding replaces only the matched stub declaration and '
      'preserves surrounding source', () async {
    await fx.registerBehavior(
      id: 'B-001',
      description: 'render returns a non-empty string',
    );
    const import = "import 'dart:math' as math;";
    const helper = 'int helper() => math.max(1, 2);';
    await File(fx.subjectPathOf('B-001')).writeAsString('''
library;

$import

const marker = 'keep me';
int subject_b_001() => throw UnimplementedError('subject_b_001 not implemented');
$helper
''');

    final out = await runFunc();

    expect(exitCode, 0, reason: 'out: $out');
    final subject = await File(fx.subjectPathOf('B-001')).readAsString();
    expect(subject, contains(import));
    expect(subject, contains("const marker = 'keep me';"));
    expect(subject, contains(helper));
    expect(subject, contains('String subject_b_001()'));
    expect(subject, isNot(contains('UnimplementedError')));
  });

  test(
    'U-1603c: a missing subject recorded on the CANONICAL side of a '
    'symlinked root reports "missing subject file", never "outside the '
    'project root" (#1603)',
    () async {
      await fx.registerBehavior(
        id: 'B-001',
        description: 'render returns a non-empty string',
        // registerBehavior records subject_path but writes no subject
        // file — the missing-artifact case exactly.
      );
      // Simulate a legacy registry where gen recorded the CANONICAL
      // absolute subject path (Directory.current is canonicalized on
      // macOS): the record travels the resolved side of the root symlink
      // while `--project` travels the raw side (issue #1603).
      final canonicalRoot = await Directory(
        fx.root.path,
      ).resolveSymbolicLinks();
      final registryFile = File(fx.artifactsPath);
      final registry =
          jsonDecode(await registryFile.readAsString()) as Map<String, dynamic>;
      final records = (registry['records'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final record in records) {
        if (record['behavior_id'] == 'B-001') {
          record['subject_path'] = p.join(
            canonicalRoot,
            'lib',
            'b_001_subject.dart',
          );
          record['test_path'] = p.join(
            canonicalRoot,
            'test',
            'b_001_test.dart',
          );
        }
      }
      await registryFile.writeAsString(jsonEncode(registry));

      // Alias the root through a symlink and pass the ALIAS as --project:
      // the raw cwd then canonicalizes to a different prefix — macOS's
      // /var → /private/var shape, reproduced deterministically here.
      final aliasPath = p.join(
        Directory.systemTemp.path,
        'tdd_alias_1603c_${DateTime.now().microsecondsSinceEpoch}',
      );
      await Link(aliasPath).create(fx.root.path);
      addTearDown(() => Link(aliasPath).deleteSync());

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'func',
        'B-001',
        '--project',
        aliasPath,
      ]);

      expect(exitCode, isNot(0), reason: 'out: $out');
      expect(out, contains('runner-error'));
      expect(out, contains('missing subject file'));
      expect(out, contains('zfa tdd gen B-001'));
      expect(
        out,
        isNot(contains('outside the project root')),
        reason:
            'the project\'s own recorded subject is never outside the '
            'root — the two path strings only disagreed because one side '
            'of the root symlink is canonical and the other is raw (#1603)',
      );
    },
    onPlatform: {'windows': const Skip('symlink creation may need privileges')},
  );
}
