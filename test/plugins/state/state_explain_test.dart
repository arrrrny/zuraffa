// Spec 1126 (order 3) — `--explain` on `zfa state create`.
//
// `--explain` prints INSTEAD of generating: which state class is
// output (`<Entity>State`), the output file, which state members the
// builder generates (copyWith, isLoading, hasError, ==, hashCode,
// toString), and which derivation methods are included — each
// requested method mapped to the `is<Continuous>` state member it
// generates (the same `StringUtils.toContinuous` derivation the
// builder feeds, so explain cannot drift from emission). The
// datasource (spec #1131) and service (SPEC 1127) precedent.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_state_expl_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: state_explain_ws
publish_to: none
environment:
  sdk: ^3.11.0
''');
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() async {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  test(
    'SC-1126-m: --explain outputs the plan block without generating',
    () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'create',
        '--name',
        'Product',
        '--methods',
        'get,getList',
        '--explain',
      ]);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason: 'explain is a successful describe',
      );
      expect(
        output,
        contains('ProductState'),
        reason: 'the output state class name',
      );
      expect(output, contains('product_state.dart'), reason: 'the output file');
      expect(
        output,
        contains('copyWith'),
        reason: 'the generated state members are listed',
      );
      expect(output, contains('hasError'));
      expect(output, contains('isLoading'));

      // The derivation mapping: each method → the state member it
      // generates.
      expect(output, contains('get'), reason: output);
      expect(
        output,
        contains('isGetting'),
        reason: 'get → isGetting (toContinuous derivation)',
      );
      expect(
        output,
        contains('isGettingList'),
        reason: 'getList → isGettingList',
      );

      // Describe, never generate.
      final stateFile = File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'presentation',
          'pages',
          'product',
          'product_state.dart',
        ),
      );
      expect(
        stateFile.existsSync(),
        isFalse,
        reason: '--explain must not write the state file',
      );
      expect(
        Directory(p.join(workspace.path, '.zfa')).existsSync(),
        isFalse,
        reason: '--explain must not write receipts',
      );
    },
  );

  test('SC-1126-n: --explain with --json emits the envelope with the '
      'explain block, verdict skip, as the last stdout line', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'state',
      'create',
      '--name',
      'Product',
      '--methods',
      'get,getList',
      '--explain',
      '--json',
    ]);

    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final last = lines.last;
    expect(last, startsWith('{'), reason: 'last stdout line must be JSON');
    expect(last, contains('zuraffa.verdict.v1'));
    expect(last, contains('"skip"'), reason: 'nothing was generated');
    expect(
      last,
      contains('explain'),
      reason: 'the explain block rides the envelope',
    );
    expect(last, contains('ProductState'));
    expect(last, contains('isGettingList'));
  });
}
