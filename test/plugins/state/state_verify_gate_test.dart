// Spec 1126 (order 1) — `zfa state verify <Entity>`, the drift gate.
//
// Compares the CURRENT state class against the receipt
// (`zfa state create`'s stable `state-<entity>.json` document):
// which contract methods match, which are stale (the entity changed
// and the state was not regenerated; the bytes were hand-edited), and
// which are missing. Exit 0 on clean; exit 1 with `--> fix:` lines on
// drift; exit 2 on usage. `--json` emits ONE canonical
// `zuraffa.verdict.v1` envelope as the last stdout line (SPEC 1105).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory workspace;
  late CliRunner runner;
  late File entityFile;
  late File stateFile;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_state_vrfy_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: state_verify_ws
publish_to: none
environment:
  sdk: ^3.11.0
''');
    // The entity source: state generation binds its hash.
    entityFile = File(
      p.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'entities',
        'product',
        'product.dart',
      ),
    );
    await entityFile.create(recursive: true);
    await entityFile.writeAsString('''
class Product {
  final String id;
  const Product({required this.id});
}
''');
    stateFile = File(
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

  Future<String> create() => runner.runCapturing([
    '-C',
    workspace.path,
    'state',
    'create',
    '--name',
    'Product',
    '--methods',
    'get,getList',
  ]);

  group('clean', () {
    test('SC-1126-o: a fresh create verifies clean (exit 0)', () async {
      final output = await create();
      expect(output, isNot(contains('❌')), reason: output);

      final output2 = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'verify',
        'Product',
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0, reason: output2);
      expect(output2, contains('isGetting'), reason: output2);
      expect(output2, isNot(contains('--> fix:')), reason: output2);
      // Match/stale classification strength (mutation-checked): a clean
      // run must classify BOTH contract methods as matched, not merely
      // avoid findings — a flipped digest comparison would still exit 0
      // while silently demoting every method to stale.
      expect(output2, contains('2 match'), reason: output2);
      expect(output2, contains('0 stale'), reason: output2);
      expect(output2, contains('0 missing'), reason: output2);
    });
  });

  group('drift', () {
    test(
      'SC-1126-p: hand-edited state bytes → exit 1 with a --> fix: line',
      () async {
        await create();
        await stateFile.writeAsString(
          '// hand-edited drift\n${stateFile.readAsStringSync()}',
        );

        final output = await runner.runCapturing([
          '-C',
          workspace.path,
          'state',
          'verify',
          'Product',
        ]);
        expect(CliRunner.lastDispatchedExitCode, 1, reason: output);
        expect(output, contains('--> fix:'), reason: output);
        expect(output, contains('product_state.dart'), reason: output);
      },
    );

    test(
      'SC-1126-q: entity changed after create → stale-entity finding',
      () async {
        await create();
        await entityFile.writeAsString('''
class Product {
  final String id;
  final String title;
  const Product({required this.id, required this.title});
}
''');

        final output = await runner.runCapturing([
          '-C',
          workspace.path,
          'state',
          'verify',
          'Product',
        ]);
        expect(CliRunner.lastDispatchedExitCode, 1, reason: output);
        expect(output, contains('--> fix:'), reason: output);
        expect(output, contains('entity'), reason: output);
      },
    );

    test(
      'SC-1126-r: a missing contract member → missing-method finding',
      () async {
        await create();
        // Rename every occurrence of the get-derived member so the class
        // no longer declares isGetting (bytes AND conformance drift).
        await stateFile.writeAsString(
          stateFile.readAsStringSync().replaceAll('isGetting', 'isGettingOld'),
        );

        final output = await runner.runCapturing([
          '-C',
          workspace.path,
          'state',
          'verify',
          'Product',
        ]);
        expect(CliRunner.lastDispatchedExitCode, 1, reason: output);
        expect(output, contains('missing'), reason: output);
        expect(output, contains('isGetting'), reason: output);
      },
    );

    test('SC-1126-s: no receipt → exit 1 with the create fix', () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'verify',
        'Product',
      ]);
      expect(CliRunner.lastDispatchedExitCode, 1, reason: output);
      expect(output, contains('--> fix:'), reason: output);
      expect(output, contains('zfa state create'), reason: output);
    });
  });

  group('machine surface', () {
    test('SC-1126-t: --json emits one canonical envelope (clean)', () async {
      await create();
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'verify',
        'Product',
        '--json',
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0, reason: output);

      final lines = output
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final envelope = jsonDecode(lines.last) as Map<String, dynamic>;
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['verdict'], 'pass');
      expect(envelope['exit_class'], 0);
      expect((envelope['subject'] as Map)['kind'], 'state');
      expect((envelope['subject'] as Map)['id'], 'Product');
    });

    test('SC-1126-u: --json emits verdict fail + findings on drift', () async {
      await create();
      await stateFile.writeAsString(
        '// hand-edited drift\n${stateFile.readAsStringSync()}',
      );

      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'verify',
        'Product',
        '--json',
      ]);
      expect(CliRunner.lastDispatchedExitCode, 1, reason: output);

      final lines = output
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final envelope = jsonDecode(lines.last) as Map<String, dynamic>;
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['verdict'], 'fail');
      final findings = envelope['findings'] as List;
      expect(findings, isNotEmpty);
      expect(
        (findings.first as Map)['fix'],
        contains('--> fix:'),
        reason: 'every finding carries the machine-actionable fix line',
      );
    });

    test('SC-1126-v: usage — no entity → exit 2', () async {
      await runner.runCapturing(['-C', workspace.path, 'state', 'verify']);
      expect(CliRunner.lastDispatchedExitCode, 2);
    });
  });
}
