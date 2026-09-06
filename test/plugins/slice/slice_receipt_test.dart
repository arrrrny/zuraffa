@Tags(['slow'])
/// Spec 1116 (issue #1116): the slice receipt — one receipt, five
/// sub-receipts, the merge gate.
///
/// Behaviors:
///   R1: `zfa slice id <feature-id>` prints the FeatureContract id,
///       stable across re-compositions.
///   R2: `zfa slice compose` writes the empty slice.receipt.json
///       skeleton (every section pending).
///   R3: `zfa slice verify <feature-id>` over a slice whose five
///       sub-receipts are green: exits 0, writes slice.receipt.json
///       with the aggregated JSON (engine/skin/cert/xray/journal
///       sections carrying the issue's field names).
///   R4: a mutated sub-receipt (engine method uncertified) flips the
///       verdict: exits 1, names the violator, prints the exact
///       re-run command.
///   R5: a missing sub-receipt (no journal) is red, names journal,
///       prints its re-run command.
///   R6: the merge gate — `zfa slice merge <feature-id>` refuses to
///       merge a red slice, pointing at `zfa slice verify`.
///   R7: the receipt schema carries the issue's exact field names
///       (feature_id, generated_at, engine.{status,n_methods,
///       n_mocks_certified}, skin.{status,n_routes,n_contract_rows,
///       n_platforms_audited}, cert.{uncertified_entities,
///       differential_passed}, xray.{layers,violations},
///       journal.{cycles,violations,final_state}).
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import 'helpers/capture_output.dart';
import 'helpers/feature_slice_fixture.dart';

void main() {
  late String projectRoot;
  late CommandRunner<void> runner;
  late SliceCommand command;

  setUp(() async {
    projectRoot = buildLoginProbe(
      await Directory.systemTemp.createTemp('zfa1116-').then((d) => d.path),
    );
    command = SliceCommand(projectRoot: projectRoot);
    runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
  });

  tearDown(() {
    Directory(projectRoot).deleteSync(recursive: true);
  });

  String sliceRoot([String featureId = 'login']) =>
      p.join(projectRoot, '.zfa', 'slices', featureId);

  String receiptPath([String featureId = 'login']) =>
      p.join(sliceRoot(featureId), 'slice.receipt.json');

  Future<Map<String, dynamic>> compose() async {
    await captureOutput(() => runner.run(['slice', 'compose', 'login']));
    return _readJson(receiptPath());
  }

  /// Writes the five green sub-receipts the aggregator reads, from the
  /// same shapes the real producers write (engine.receipt.v2 #1109,
  /// mock-cert #1001/#1110, skin.v1 #1005/#1111, journal #1113).
  Future<void> writeGreenSubReceipts() async {
    final root = sliceRoot();

    // — engine: engine.receipt.json (v2, per #1109) — the slice layout
    //   the issue's directory schema names, plus the specs/ mount copy
    //   the lane writes in the worktree.
    const engineReceipt = '''
{
  "schema": "engine.receipt.v2",
  "entity": "User",
  "methods": [
    {"name": "login", "mock_certified": true, "mock_class": "MockLogin"},
    {"name": "logout", "mock_certified": true, "mock_class": "MockLogout"}
  ],
  "source_files": ["lib/src/domain/entities/user/user.dart"]
}
''';
    writeFile(root, p.join('engine', 'engine.receipt.json'), engineReceipt);
    writeFile(
      root,
      p.join('specs', 'login', 'tdd', 'engine.receipt.json'),
      engineReceipt,
    );

    // — cert: per-entity certs (mock-cert.<Entity>.json, #1001/#1110) —
    writeFile(
      root,
      p.join('engine', 'mock-cert', 'mock-cert.User.json'),
      _certJson('User', satisfied: true, testsFailed: 0),
    );
    writeFile(
      root,
      p.join('engine', 'mock-cert', 'mock-cert.Session.json'),
      _certJson('Session', satisfied: true, testsFailed: 0),
    );

    // — skin: skin.receipt.json (skin.v1, #1005/#1111) —
    writeFile(
      root,
      p.join('skin', 'skin.receipt.json'),
      _skinReceipt(contractRows: 6, platforms: ['ios', 'android', 'web']),
    );

    // — journal: the unified journal (#1113) —
    writeFile(
      root,
      p.join('specs', 'login', 'tdd', 'journal.json'),
      _journal(gateStates: ['green', 'green']),
    );
  }

  group('slice id (R1)', () {
    test('prints the resolved FeatureContract id', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'id', 'login']),
      );
      expect(command.exitCode, equals(0), reason: output);
      expect(output.trim(), equals('login'));
    });

    test('is stable across re-compositions', () async {
      final before = await captureOutput(
        () => runner.run(['slice', 'id', 'login']),
      );
      await captureOutput(() => runner.run(['slice', 'compose', 'login']));
      await captureOutput(
        () => runner.run(['slice', 'compose', 'login', '--force']),
      );
      final after = await captureOutput(
        () => runner.run(['slice', 'id', 'login']),
      );
      expect(after.trim(), equals(before.trim()));
      expect(after.trim(), equals('login'));
    });
  });

  group('compose skeleton (R2)', () {
    test('compose writes the empty slice.receipt.json skeleton', () async {
      final receipt = await compose();
      expect(receipt['feature_id'], equals('login'));
      expect(receipt['verdict'], equals('pending'));
      for (final section in ['engine', 'skin', 'cert', 'xray', 'journal']) {
        expect(
          (receipt[section] as Map)['status'],
          equals('pending'),
          reason: 'section $section should be pending in the skeleton',
        );
      }
    });
  });

  group('slice verify aggregation (R3, R7)', () {
    test('all sub-receipts green: exit 0 + aggregated JSON', () async {
      await compose();
      await writeGreenSubReceipts();

      final output = await captureOutput(
        () => runner.run(['slice', 'verify', 'login']),
      );

      expect(command.exitCode, equals(0), reason: output);
      // One-line status.
      expect(output, contains('green'));

      final receipt = _readJson(receiptPath());
      expect(receipt['schema'], equals('slice.receipt.v1'));
      expect(receipt['feature_id'], equals('login'));
      expect(receipt['verdict'], equals('green'));
      expect(receipt['generated_at'], isA<String>());

      // The issue's exact section fields (R7).
      final engine = receipt['engine'] as Map;
      expect(engine['status'], equals('green'));
      expect(engine['n_methods'], equals(2));
      expect(engine['n_mocks_certified'], equals(2));

      final skin = receipt['skin'] as Map;
      expect(skin['status'], equals('green'));
      expect(skin['n_routes'], equals(2));
      expect(skin['n_contract_rows'], equals(6));
      expect(skin['n_platforms_audited'], equals(3));

      final cert = receipt['cert'] as Map;
      expect(cert['status'], equals('green'));
      expect(cert['uncertified_entities'], isEmpty);
      expect(cert['differential_passed'], isTrue);

      final xray = receipt['xray'] as Map;
      expect(xray['status'], equals('green'));
      expect((xray['layers'] as Map)['engine'], isA<int>());
      expect((xray['layers'] as Map)['skin'], isA<int>());
      expect(xray['violations'], isEmpty);

      final journal = receipt['journal'] as Map;
      expect(journal['status'], equals('green'));
      expect(journal['cycles'], equals(2));
      expect(journal['violations'], equals(0));
      expect(journal['final_state'], equals('green'));
    });
  });

  group('slice verify gating (R4, R5)', () {
    test(
      'mutated engine sub-receipt: exit 1, names violator + re-run',
      () async {
        await compose();
        await writeGreenSubReceipts();
        // Mutate: one engine method loses certification.
        final engineFile = File(
          p.join(sliceRoot(), 'engine', 'engine.receipt.json'),
        );
        final mutated = (await engineFile.readAsString()).replaceFirst(
          '"mock_certified": true, "mock_class": "MockLogout"',
          '"mock_certified": false, "mock_class": "MockLogout"',
        );
        await engineFile.writeAsString(mutated);

        final output = await captureOutput(
          () => runner.run(['slice', 'verify', 'login']),
        );

        expect(command.exitCode, equals(1), reason: output);
        final receipt = _readJson(receiptPath());
        expect(receipt['verdict'], equals('red'));
        expect((receipt['engine'] as Map)['status'], equals('red'));
        // Names the violator and prints the exact re-run command.
        expect(output, contains('engine'));
        expect(output, contains('MockLogout'));
        expect(output, contains('zfa engine check User'));
        // Green sections stay green (the receipt is honest per section).
        expect((receipt['skin'] as Map)['status'], equals('green'));
        expect((receipt['journal'] as Map)['status'], equals('green'));
      },
    );

    test('uncertified entity flips cert red with the certify re-run', () async {
      await compose();
      await writeGreenSubReceipts();
      // Session was never certified — the cert gate must refuse.
      File(
        p.join(sliceRoot(), 'engine', 'mock-cert', 'mock-cert.Session.json'),
      ).deleteSync();

      final output = await captureOutput(
        () => runner.run(['slice', 'verify', 'login']),
      );

      expect(command.exitCode, equals(1), reason: output);
      final receipt = _readJson(receiptPath());
      expect(receipt['verdict'], equals('red'));
      expect(
        (receipt['cert'] as Map)['uncertified_entities'],
        contains('Session'),
      );
      expect((receipt['cert'] as Map)['status'], equals('red'));
      expect(output, contains('cert'));
      expect(output, contains('Session'));
      expect(output, contains('zfa mock certify Session'));
    });

    test(
      'missing journal sub-receipt: exit 1, names journal + re-run',
      () async {
        await compose();
        await writeGreenSubReceipts();
        File(
          p.join(sliceRoot(), 'specs', 'login', 'tdd', 'journal.json'),
        ).deleteSync();

        final output = await captureOutput(
          () => runner.run(['slice', 'verify', 'login']),
        );

        expect(command.exitCode, equals(1), reason: output);
        final receipt = _readJson(receiptPath());
        expect((receipt['journal'] as Map)['status'], equals('red'));
        expect(output, contains('journal'));
        expect(output, contains('zfa tdd run login'));
      },
    );

    test('xray violation (outside-slice file): exit 1, names xray', () async {
      await compose();
      await writeGreenSubReceipts();
      // An un-owned file outside the composed base — the boundary audit
      // (xray.check) must flag it.
      writeFile(sliceRoot(), 'engine/rogue.dart', 'class Rogue {}\n');

      final output = await captureOutput(
        () => runner.run(['slice', 'verify', 'login']),
      );

      expect(command.exitCode, equals(1), reason: output);
      final receipt = _readJson(receiptPath());
      expect((receipt['xray'] as Map)['status'], equals('red'));
      expect((receipt['xray'] as Map)['violations'], isNotEmpty);
      expect(output, contains('xray'));
      expect(output, contains('zfa slice check login'));
    });
  });

  group('merge gate (R6)', () {
    test('merge refuses a red slice and points at slice verify', () async {
      await compose();
      await writeGreenSubReceipts();
      final engineFile = File(
        p.join(sliceRoot(), 'engine', 'engine.receipt.json'),
      );
      await engineFile.writeAsString(
        (await engineFile.readAsString()).replaceFirst(
          '"mock_certified": true, "mock_class": "MockLogout"',
          '"mock_certified": false, "mock_class": "MockLogout"',
        ),
      );

      final output = await captureOutput(
        () => runner.run(['slice', 'merge', 'login']),
      );

      expect(command.exitCode, equals(1), reason: output);
      expect(output, contains('merge gate'));
      expect(output, contains('zfa slice verify login'));
    });

    test('merge proceeds when the slice receipt is green', () async {
      await compose();
      await writeGreenSubReceipts();
      await captureOutput(() => runner.run(['slice', 'verify', 'login']));

      final output = await captureOutput(
        () => runner.run(['slice', 'merge', 'login', '--yes']),
      );

      expect(command.exitCode, equals(0), reason: output);
    });
  });
}

Map<String, dynamic> _readJson(String path) {
  final raw = File(path).readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('receipt at $path is not a JSON object');
  }
  return decoded;
}

String _certJson(
  String entity, {
  required bool satisfied,
  required int testsFailed,
}) =>
    '''
{
  "schema": 1,
  "spec": 1001,
  "entity": "$entity",
  "interface": "${entity}Repository",
  "subject": "lib/src/domain/repositories/${entity.toLowerCase()}_repository.dart",
  "contract_test": "test/mock_cert/${entity.toLowerCase()}_contract_test.dart",
  "contract_digest": "abc123",
  "methods": [
    {"name": "login", "satisfied": $satisfied}
  ],
  "sandbox": {
    "runner": "dart",
    "analyze_issues": 0,
    "analyze_errors": 0,
    "tests_passed": 1,
    "tests_failed": $testsFailed
  },
  "certified_at": "2026-09-06T00:00:00.000Z"
}
''';

String _skinReceipt({
  required int contractRows,
  required List<String> platforms,
}) =>
    '''
{
  "schema": "skin.v1",
  "feature": "login",
  "command": "zfa tdd run-skin login",
  "behaviors": [
    {
      "behavior": "W1",
      "conformance": true,
      "test": "test/skin/login_w1_test.dart",
      "subject": "lib/src/presentation/views/login_view.dart",
      "platform_slot_fills": [${platforms.map((s) => '"$s"').join(', ')}]
    }
  ],
  "platform_slot_fills": [${platforms.map((s) => '"$s"').join(', ')}],
  "hand_edits": [],
  "skin_event_trace_digest": "digest123",
  "red_witness": true,
  "generated_at": "2026-09-06T00:00:00.000Z",
  "contract_schema_version": "skin-contract.v1",
  "contract_rows_audited": $contractRows
}
''';

String _journal({required List<String> gateStates}) {
  final entries = <String>[];
  for (var i = 0; i < gateStates.length; i++) {
    entries.add('''
    {
      "feature": "login",
      "cycle": "${i.isEven ? 'engine' : 'skin'}",
      "phase": "drive",
      "started_at": "2026-09-06T0$i:00:00.000Z",
      "finished_at": "2026-09-06T0$i:30:00.000Z",
      "gate_state": "${gateStates[i]}",
      "receipts": [],
      "violations": [],
      "refs": {"engine_receipt": null, "skin_receipt": null, "contract_schema": null}
    }''');
  }
  return '''
{
  "schema": 1,
  "feature": "login",
  "entries": [${entries.join(',')}]
}
''';
}
