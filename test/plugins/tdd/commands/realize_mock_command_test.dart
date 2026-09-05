// Acceptance tests for `zfa tdd realize-mock <Entity> --against=firestore`
// — the Tier-1 vs Tier-2 differential gate (issue #1009, ZIKZAK-REBUILD).
//
// Drives the public CLI surface in-process against a TddFixture whose
// registry names the Login entity and whose committed fixtures carry the
// Tier-1 oracle (`mockOutput`) + the Tier-2 seed, with the suite runner
// and the Tier-2 provider injectable (the realize command's test
// pattern). The exit criteria under test:
//   SC-1  realize-mock Login --against=firestore exits 0 with a clean
//         receipt,
//   SC-2  a deliberately divergent method (wrong type) exits 1 with the
//         mismatched method named,
//   SC-3  the receipt is machine-readable and parseable by
//         `zfa proof check`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/tdd_fixture.dart';

import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_mock_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/tier2_firestore/tier2_mock_provider.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

/// A Tier-2 adapter that returns the WRONG TYPE for `getById`: the
/// Tier-1 oracle holds the int `42`, this adapter returns the string
/// `'42'` (issue #1009's deliberately divergent method).
class _WrongTypedGetById extends Tier2MockProvider {
  _WrongTypedGetById({required super.entity});

  @override
  Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (method == 'getById') {
      return <String, dynamic>{'id': args['id'], 'attempts': '42'};
    }
    return super.invoke(method, args);
  }
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await fx.registerBehavior(
      id: 'B-101',
      description: 'create entity Login with email',
    );
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// Runs the command in-process with the zone print override (the
  /// realize command test pattern) and returns the captured output.
  Future<String> runRealizeMock({
    String entity = 'Login',
    String? against,
    String? feature,
    int tier1SuiteExit = 0,
    RealizeMockTier1Driver? tier1Driver,
    Tier2ProviderFactory? tier2ProviderFactory,
    bool jsonMode = false,
  }) async {
    final cmd = RealizeMockCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async =>
          (exitCode: tier1SuiteExit, output: 'suite exit $tier1SuiteExit'),
      tier1Driver: tier1Driver,
      tier2ProviderFactory: tier2ProviderFactory,
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final args = <String>[
      'realize-mock',
      entity,
      '--project',
      fx.root.path,
      if (against != null) ...['--against', against],
      if (feature != null) ...['--feature', feature],
      if (jsonMode) '--json',
    ];
    final lines = <String>[];
    await runZoned(
      () => runner.run(args),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    return lines.join('\n');
  }

  /// Writes one contract fixture (the realize-diff.v1 shape the committed
  /// contract cases follow).
  Future<void> writeFixture(
    String name, {
    required Map<String, dynamic> input,
    Map<String, dynamic>? mockOutput,
    List<Map<String, dynamic>>? seed,
  }) async {
    final dir = Directory(p.join(fx.featureDir, 'tdd', 'fixtures'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, name)).writeAsString(
      jsonEncode(<String, dynamic>{
        'schema': 'realize-diff.v1',
        'id': name.replaceAll('.json', ''),
        'input': input,
        'mockOutput': ?mockOutput,
        'seed': ?seed,
      }),
    );
  }

  /// The certified three-method contract surface for Login.
  Future<void> writeLoginContract() async {
    await writeFixture(
      'get-by-id.json',
      input: const <String, dynamic>{'op': 'getById', 'id': 'u1'},
      mockOutput: const <String, dynamic>{
        'id': 'u1',
        'email': 'a@b.c',
        'attempts': 42,
      },
      seed: const <Map<String, dynamic>>[
        {'id': 'u1', 'email': 'a@b.c', 'attempts': 42},
      ],
    );
    await writeFixture(
      'save.json',
      input: const <String, dynamic>{
        'op': 'saveLogin',
        'id': 'u2',
        'email': 'd@e.f',
      },
      mockOutput: const <String, dynamic>{'id': 'u2'},
    );
    await writeFixture(
      'get-all.json',
      input: const <String, dynamic>{'op': 'getAllLogins'},
      mockOutput: const <String, dynamic>{
        'items': [
          {'id': 'u1', 'email': 'a@b.c', 'attempts': 42},
        ],
      },
      seed: const <Map<String, dynamic>>[
        {'id': 'u1', 'email': 'a@b.c', 'attempts': 42},
      ],
    );
  }

  String receiptPath() => p.join(
    fx.root.path,
    '.zfa',
    'receipts',
    'realize.Login.firestore.receipt.json',
  );

  test(
    'SC-1: Login --against=firestore exits 0 with a clean receipt',
    () async {
      await writeLoginContract();

      final out = await runRealizeMock(against: 'firestore');

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('tier-1 contract test green'));
      expect(out, contains('result=certified'));
      expect(out, contains('methods=3 mismatch=0'));

      // The receipt exists, is JSON, and carries the per-method records.
      final receiptFile = File(receiptPath());
      expect(receiptFile.existsSync(), isTrue, reason: 'out: $out');
      final receipt =
          jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>;
      expect(receipt['schema'], 'proof.v1');
      expect(receipt['command'], 'zfa tdd realize-mock');
      expect(receipt['target'], 'Login');
      expect(
        receipt['repro'],
        'zfa tdd realize-mock Login --against=firestore',
      );
      expect(receipt['verdict'], 'certified');
      final methods = receipt['methods'] as List;
      expect(methods, hasLength(3));
      for (final record in methods.cast<Map<String, dynamic>>()) {
        expect(
          record.keys,
          containsAll(['method', 'tier1_result', 'tier2_result', 'diff']),
        );
        expect(
          record['diff'],
          'none',
          reason: 'every method must certify: $record',
        );
      }
      expect(methods.map((m) => (m as Map)['method']).toSet(), {
        'getById',
        'saveLogin',
        'getAllLogins',
      });
      // The certified pair for the read case, verbatim in the receipt.
      final getById = methods.cast<Map<String, dynamic>>().firstWhere(
        (m) => m['method'] == 'getById',
      );
      expect(getById['tier1_result'], getById['tier2_result']);
      expect(getById['tier1_result'], containsPair('attempts', 42));

      // The era-tagged evidence lands in the cycle log (era MOCKED — the
      // differential certifies mock-era parity, it never crosses eras).
      final cycleLog = await File(
        p.join(fx.featureDir, 'tdd', 'cycle-log.md'),
      ).readAsString();
      expect(cycleLog, contains('- kind: realize-mock'));
      expect(cycleLog, contains('- era: MOCKED'));
      expect(
        RegExp(r'^- hash: [0-9a-f]{64}$', multiLine: true).hasMatch(cycleLog),
        isTrue,
      );
    },
  );

  test('SC-2: a divergent method (wrong type) exits 1 and is named', () async {
    await writeLoginContract();

    final out = await runRealizeMock(
      against: 'firestore',
      tier2ProviderFactory: (entity) => _WrongTypedGetById(entity: entity),
    );

    expect(exitCode, 1, reason: 'out: $out');
    // The mismatched method is named.
    expect(out, contains('DIFFERENTIAL GATE MISMATCH'));
    expect(out, contains('getById'));
    expect(out, contains('result=mismatch'));
    expect(out, contains('mismatch=1'));

    // The receipt records the mismatch with both tiers' values.
    final receipt =
        jsonDecode(await File(receiptPath()).readAsString())
            as Map<String, dynamic>;
    expect(receipt['verdict'], 'mismatch');
    final methods = receipt['methods'] as List;
    expect(
      methods,
      hasLength(3),
      reason:
          'the gate is per-entity: every '
          'method runs and is recorded, even after a mismatch',
    );
    final divergent = methods.cast<Map<String, dynamic>>().firstWhere(
      (m) => m['method'] == 'getById',
    );
    expect(divergent['diff'], 'mismatch');
    expect((divergent['tier1_result'] as Map)['attempts'], 42);
    expect((divergent['tier2_result'] as Map)['attempts'], '42');
    // The other methods still certified.
    expect(
      methods
          .cast<Map<String, dynamic>>()
          .where((m) => m['method'] != 'getById')
          .every((m) => m['diff'] == 'none'),
      isTrue,
    );
  });

  test('SC-2b: the divergence is caught through the genuine Firestore '
      'type semantics too (int oracle vs double store)', () async {
    // The Tier-1 oracle records attempts: 42 (int). The Tier-2 seed holds
    // 42.0 — Firestore keeps integerValue and doubleValue distinct, so
    // the default provider reads back a double and the gate fails.
    await writeFixture(
      'get-by-id.json',
      input: const <String, dynamic>{'op': 'getById', 'id': 'u1'},
      mockOutput: const <String, dynamic>{'id': 'u1', 'attempts': 42},
      seed: const <Map<String, dynamic>>[
        {'id': 'u1', 'attempts': 42.0},
      ],
    );

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('getById'));
    expect(out, contains('result=mismatch'));
    final receipt =
        jsonDecode(await File(receiptPath()).readAsString())
            as Map<String, dynamic>;
    final divergent = (receipt['methods'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((m) => m['method'] == 'getById');
    expect((divergent['tier2_result'] as Map)['attempts'], 42.0);
    expect(divergent['diff'], 'mismatch');
  });

  test('SC-3: the receipt is parseable by zfa proof check (counted, '
      'zero findings)', () async {
    await writeLoginContract();
    final out = await runRealizeMock(against: 'firestore');
    expect(exitCode, 0, reason: 'out: $out');

    // The receipt store (what `zfa proof check` reads) parses it as a
    // proof.v1 generation receipt.
    final store = ReceiptStore(projectRoot: fx.root.path);
    final records = await store.loadAll();
    expect(records, hasLength(1));
    expect(records.single.fileName, 'realize.Login.firestore.receipt.json');
    expect(records.single.receipt.command, 'zfa tdd realize-mock');
    expect(records.single.receipt.target, 'Login');

    // The full proof check runs clean: the differential receipt produces
    // no findings (it proves the run, not a tree artifact).
    final report = await ProofChecker(projectRoot: fx.root.path).check();
    expect(report.receipts, 1, reason: 'the differential receipt counts');
    expect(report.findings, isEmpty);
    expect(report.ok, isTrue);
  });

  test('A: --against is required — a differential without a target shape '
      'is refused', () async {
    final out = await runRealizeMock(against: null);

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('--against'));
    expect(out, contains('result=usage-error'));
    expect(File(receiptPath()).existsSync(), isFalse);
  });

  test('B: an unsupported --against value is rejected by the option '
      'contract (misfire-stop)', () async {
    final cmd = RealizeMockCommand(TddPlugin());
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final lines = <String>[];
    Object? caught;
    await runZoned(
      () async {
        try {
          await runner.run([
            'realize-mock',
            'Login',
            '--project',
            fx.root.path,
            '--against',
            'postgres',
          ]);
        } on UsageException catch (e) {
          caught = e;
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    // The option contract rejected the value before run() executed.
    expect(caught, isA<UsageException>());
    expect('$caught', contains('postgres'));
    expect(File(receiptPath()).existsSync(), isFalse);
  });

  test(
    'C: no committed fixtures — an empty surface is never certified',
    () async {
      final out = await runRealizeMock(against: 'firestore');

      expect(exitCode, 1, reason: 'out: $out');
      expect(out, contains('no committed contract cases'));
      expect(out, contains('result=blocked'));
      expect(File(receiptPath()).existsSync(), isFalse);
    },
  );

  test('D: a red Tier-1 contract test blocks the differential '
      '(the mock era is blamed, nothing is certified)', () async {
    await writeLoginContract();

    final out = await runRealizeMock(against: 'firestore', tier1SuiteExit: 1);

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('tier-1 contract test RED'));
    expect(out, contains('result=tier1-red'));
    // No receipt: a broken baseline certifies nothing.
    expect(File(receiptPath()).existsSync(), isFalse);
  });

  test('F: a fixture without a recorded oracle runs through the tier-1 '
      'driver protocol; a driver failure fails closed', () async {
    await writeFixture(
      'get-by-id.json',
      input: const <String, dynamic>{'op': 'getById', 'id': 'u1'},
      seed: const <Map<String, dynamic>>[
        {'id': 'u1', 'email': 'a@b.c'},
      ],
    );

    // A driver that answers the oracle side: certified.
    final certified = await runRealizeMock(
      against: 'firestore',
      tier1Driver: (entity, input) async => const <String, dynamic>{
        'id': 'u1',
        'email': 'a@b.c',
      },
    );
    expect(exitCode, 0, reason: 'out: $certified');
    expect(certified, contains('result=certified'));

    // A failing driver: the differential fails closed, runner-error.
    final failed = await runRealizeMock(
      against: 'firestore',
      tier1Driver: (entity, input) async => throw StateError('boom'),
    );
    expect(exitCode, 1, reason: 'out: $failed');
    expect(failed, contains('tier-1 driver failed'));
    expect(failed, contains('result=runner-error'));
  });

  test(
    'G: --json emits the receipt document as the final stdout line',
    () async {
      await writeLoginContract();

      final out = await runRealizeMock(against: 'firestore', jsonMode: true);

      expect(exitCode, 0, reason: 'out: $out');
      final lastLine = out.split('\n').last;
      final envelope = jsonDecode(lastLine) as Map<String, dynamic>;
      expect(envelope['schema'], 'proof.v1');
      expect(envelope['verdict'], 'certified');
      expect(envelope['methods'], isA<List<dynamic>>());
      expect(
        (envelope['methods'] as List).cast<Map<String, dynamic>>().every(
          (m) => m['diff'] == 'none',
        ),
        isTrue,
      );
    },
  );

  test('H: an unknown entity is refused with the registry hint', () async {
    final out = await runRealizeMock(entity: 'Ghost', against: 'firestore');

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('unknown entity "Ghost"'));
    expect(out, contains('--feature'));
    expect(out, contains('result=usage-error'));
  });
}
