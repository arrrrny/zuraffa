// Spec 976 (issue #976) — state create ≡ make --state drift gate.
//
// `zfa state create` and `zfa make --state` are two entry points into
// the same StateBuilder. Whatever reaches the disk must be IDENTICAL
// for the same config: if the two entry points diverge (different
// defaults, different import resolution, different formatting), the
// ecosystem forks — 104 production `*_state.dart` files were generated
// through both. This gate byte-compares the state artifact each entry
// point produces for the same entity + explicit method set (SC-4,
// AC-4).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const _statePath = 'lib/src/presentation/pages/product/product_state.dart';

const _methodSets = <List<String>>[
  ['get', 'update'],
  ['get', 'getList'],
  ['create', 'update', 'delete', 'watch'],
];

void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_state_drift_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: state_drift_ws
publish_to: none
environment:
  sdk: ^3.11.0
''');
    // `zfa make` fails fast without an entity source file (#496).
    final entityDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  const Product({required this.id});
}
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

  for (final methods in _methodSets) {
    test('SC-4: state create ≡ make --state for methods '
        '[${methods.join(',')}]', () async {
      final args = methods.join(',');

      // Entry point 1: the plugin's own create verb.
      final createState = await runner.runCapturing([
        '-C',
        workspace.path,
        'state',
        'create',
        '--name',
        'Product',
        '--methods',
        args,
      ]);
      expect(
        createState,
        isNot(contains('❌')),
        reason: 'state create must succeed:\n$createState',
      );
      final viaCreate = File(p.join(workspace.path, _statePath));
      expect(viaCreate.existsSync(), isTrue);
      final createBytes = await viaCreate.readAsBytes();
      await viaCreate.delete();

      // Entry point 2: the make orchestrator with --state.
      final makeState = await runner.runCapturing([
        '-C',
        workspace.path,
        'make',
        'Product',
        '--state',
        '--methods',
        args,
      ]);
      expect(
        makeState,
        isNot(contains('❌ Error')),
        reason: 'make --state must succeed:\n$makeState',
      );
      final viaMake = File(p.join(workspace.path, _statePath));
      expect(viaMake.existsSync(), isTrue);
      final makeBytes = await viaMake.readAsBytes();

      // The gate: byte-identical output, no normalization — the two
      // entry points must never diverge.
      expect(
        createBytes,
        equals(makeBytes),
        reason:
            'state create and make --state produced different bytes for '
            'the same config — the entry points have drifted:\n'
            '--- state create ---\n${utf8.decode(createBytes)}\n'
            '--- make --state ---\n${utf8.decode(makeBytes)}',
      );
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
