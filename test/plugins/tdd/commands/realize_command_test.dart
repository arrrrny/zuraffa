// Acceptance tests for `zfa tdd realize` — the mock→real swap through the
// real CLI entry point (spec 913, T001: A1, A2, A6; the gate behaviors
// A3-A5 land with their phases).
//
// Drives the public CLI surface in-process against a TddFixture whose lib/
// carries the generated mock binding (GetIt registration + repository DI
// wiring) and a hand-written real adapter, with the suite runner injected
// as a fake (the CorpusDifferentialCommand injectable-spawner pattern).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/tdd_fixture.dart';

import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_gate.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

const datasourceDi = '''
// GENERATED - di datasource registration
import 'package:zuraffa/zuraffa.dart';
import '../../data/datasources/user/user_mock_datasource.dart';

void registerUserMockDataSource(GetIt getIt) {
  getIt.registerLazySingleton<UserMockDataSource>(() => UserMockDataSource());
}
''';

const repositoryDi = '''
// GENERATED - di repository registration
import 'package:zuraffa/zuraffa.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/repositories/data_user_repository.dart';
import '../../data/datasources/user/user_mock_datasource.dart';

void registerUserRepository(GetIt getIt) {
  getIt.registerLazySingleton<UserRepository>(
    () => DataUserRepository(getIt<UserMockDataSource>()),
  );
}
''';

const domainRepository = '''
abstract interface class UserRepository {
  Future<Map<String, dynamic>?> getById(String id);
}
''';

const mockDatasource = '''
import '../../domain/repositories/user_repository.dart';

class UserMockDataSource implements UserRepository {
  @override
  Future<Map<String, dynamic>?> getById(String id) async => null;
}
''';

const realAdapter = '''
import '../../domain/repositories/user_repository.dart';

class UserRealAdapter implements UserRepository {
  @override
  Future<Map<String, dynamic>?> getById(String id) async => null;
}
''';

void main() {
  late TddFixture fx;

  /// Receipt the current bytes of [rel] as a #807 generation run (the
  /// provenance baseline realize detects drift against).
  Future<void> recordReceipt(String rel, String content) async {
    final store = ReceiptStore(projectRoot: fx.root.path);
    await store.save(
      GenerationReceipt(
        command: 'zfa di',
        target: 'User',
        repro: 'zfa di User',
        at: DateTime.now().toUtc(),
        generatorVersion: '6.1.0',
        input: const {},
        files: [
          GenerationReceiptFile(
            path: rel,
            action: 'create',
            sha256: crypto.sha256.convert(content.codeUnits).toString(),
            bytes: content.length,
          ),
        ],
      ),
    );
  }

  setUp(() async {
    fx = await TddFixture.create();
    _write(
      p.join(
        fx.root.path,
        'lib/src/di/datasources',
        'user_mock_datasource_di.dart',
      ),
      datasourceDi,
    );
    _write(
      p.join(
        fx.root.path,
        'lib/src/di/repositories',
        'user_repository_di.dart',
      ),
      repositoryDi,
    );
    _write(
      p.join(
        fx.root.path,
        'lib/src/domain/repositories',
        'user_repository.dart',
      ),
      domainRepository,
    );
    _write(
      p.join(
        fx.root.path,
        'lib/src/data/datasources/user',
        'user_mock_datasource.dart',
      ),
      mockDatasource,
    );
    _write(
      p.join(
        fx.root.path,
        'lib/src/data/datasources/user',
        'user_real_adapter.dart',
      ),
      realAdapter,
    );
    await fx.registerBehavior(
      id: 'B-001',
      description: 'create entity User with email',
    );
    // The generated surface carries its #807 receipts — the provenance
    // baseline the nuance gate detects drift against (the real `zfa di`
    // and `zfa mock` runs write these).
    await recordReceipt(
      'lib/src/di/datasources/user_mock_datasource_di.dart',
      datasourceDi,
    );
    await recordReceipt(
      'lib/src/di/repositories/user_repository_di.dart',
      repositoryDi,
    );
    await recordReceipt(
      'lib/src/data/datasources/user/user_mock_datasource.dart',
      mockDatasource,
    );
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// A green fake suite runner: the MOCK-era suite passes against both
  /// bindings (contract gate scope). Output is captured with the zone
  /// print override (the benchmark command test pattern).
  Future<String> runRealize({
    String target = 'User',
    String? adapter,
    String? feature,
    List<int> exitSequence = const [0, 0],
    RealizeFixtureDriver? fixtureDriver,
    List<String> handDeltas = const [],
    String? handDeltaReason,
  }) async {
    var call = 0;
    final cmd = RealizeCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async {
        final exit = call < exitSequence.length
            ? exitSequence[call]
            : exitSequence.last;
        call++;
        return (exitCode: exit, output: 'call $call exit $exit');
      },
      fixtureDriver: fixtureDriver,
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final args = <String>[
      'realize',
      target,
      '--project',
      fx.root.path,
      if (adapter != null) ...['--adapter', adapter],
      if (feature != null) ...['--feature', feature],
      for (final delta in handDeltas) ...['--hand-delta', delta],
      if (handDeltaReason != null) ...['--reason', handDeltaReason],
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

  Future<void> writeFixtures() async {
    final dir = Directory(p.join(fx.featureDir, 'tdd', 'fixtures'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'get_by_id.json')).writeAsString(
      jsonEncode({
        'schema': 'realize-diff.v1',
        'id': 'get-by-id-u1',
        'input': {'op': 'getById', 'id': 'u1'},
        'mockOutput': {'id': 'u1', 'email': 'a@b.c'},
      }),
    );
  }

  test(
    'A1: full green path rebinds DI, transitions era, persists state',
    () async {
      final out = await runRealize(adapter: 'UserRealAdapter');

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('result=realized'));

      // The DI binding is swapped behind the same interface.
      final datasourceDiFile = await File(
        p.join(
          fx.root.path,
          'lib/src/di',
          'datasources',
          'user_mock_datasource_di.dart',
        ),
      ).readAsString();
      expect(
        RegExp(r'\bUserMockDataSource\b').hasMatch(datasourceDiFile),
        isFalse,
      );
      expect(datasourceDiFile, contains('UserRealAdapter'));

      // The state transition MOCKED -> REAL is persisted.
      final stateFile = File(
        p.join(fx.featureDir, 'tdd', 'realize-state.json'),
      );
      expect(stateFile.existsSync(), isTrue, reason: 'out: $out');
      final state =
          jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
      expect(state['era'], 'REAL');
      expect(state['entity'], 'User');
      expect(state['adapter'], 'UserRealAdapter');
      expect(state['transitions'], isNotEmpty);
      expect(state['transitions'].first['from'], 'MOCKED');
      expect(state['transitions'].first['to'], 'REAL');

      // The mock-era suite ran unchanged against the real binding (the
      // injected runner was invoked with the registered test paths).
      // Asserted structurally: the contract evidence names the suite.
      expect(out, contains('contract=green'));

      // The era-tagged evidence lands in the cycle log (T005): the REAL
      // era entry, hash-chained.
      final cycleLog = await File(
        p.join(fx.featureDir, 'tdd', 'cycle-log.md'),
      ).readAsString();
      expect(cycleLog, contains('- kind: realize'));
      expect(cycleLog, contains('- era: REAL'));
      expect(cycleLog, contains('- schema: 1'));
      expect(
        RegExp(r'^- hash: [0-9a-f]{64}$', multiLine: true).hasMatch(cycleLog),
        isTrue,
      );
    },
  );

  test(
    'A2: --adapter is required — a swap without a real adapter is refused',
    () async {
      final out = await runRealize(adapter: null);

      expect(exitCode, 1, reason: 'out: $out');
      expect(out, contains('--adapter'));
      // Nothing was rebound.
      final datasourceDiFile = await File(
        p.join(
          fx.root.path,
          'lib/src/di',
          'datasources',
          'user_mock_datasource_di.dart',
        ),
      ).readAsString();
      expect(datasourceDiFile, contains('UserMockDataSource'));
      expect(
        File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
        isFalse,
      );
    },
  );

  test('A6: a behavior id target resolves through the registry', () async {
    final out = await runRealize(target: 'B-001', adapter: 'UserRealAdapter');

    expect(exitCode, 0, reason: 'out: $out');
    final stateFile = File(p.join(fx.featureDir, 'tdd', 'realize-state.json'));
    expect(stateFile.existsSync(), isTrue, reason: 'out: $out');
    final state =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    // The behavior's description ("create entity User with email")
    // resolved the entity the registry recorded.
    expect(state['entity'], 'User');
    final datasourceDiFile = await File(
      p.join(
        fx.root.path,
        'lib/src/di',
        'datasources',
        'user_mock_datasource_di.dart',
      ),
    ).readAsString();
    expect(
      RegExp(r'\bUserMockDataSource\b').hasMatch(datasourceDiFile),
      isFalse,
    );
  });

  test('A3: a red real-binding run blocks the swap, rolls the rebind back, '
      'and the verdict names the side', () async {
    // Baseline (mock binding) green, real-binding run red — the real impl
    // broke the contract.
    final out = await runRealize(
      adapter: 'UserRealAdapter',
      exitSequence: [0, 1],
    );

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('contract=real-broke-contract'));
    expect(out, contains('result=blocked'));
    expect(out, contains('real impl broke the contract'));

    // The rebind was ROLLED BACK: the binding file is byte-identical to
    // the mock-era content again.
    final datasourceDiFile = await File(
      p.join(
        fx.root.path,
        'lib/src/di',
        'datasources',
        'user_mock_datasource_di.dart',
      ),
    ).readAsString();
    expect(
      datasourceDiFile,
      datasourceDi,
      reason: 'a blocked swap must restore the pre-rebind bytes',
    );
    final repoDiFile = await File(
      p.join(
        fx.root.path,
        'lib/src/di',
        'repositories',
        'user_repository_di.dart',
      ),
    ).readAsString();
    expect(repoDiFile, repositoryDi);

    // The era never crossed to REAL.
    final stateFile = File(p.join(fx.featureDir, 'tdd', 'realize-state.json'));
    expect(
      stateFile.existsSync(),
      isFalse,
      reason: 'a blocked swap must not persist a REAL transition',
    );
  });

  test('A3b: a red baseline (mock era already broken) blocks before any '
      'rebind and blames the mock side', () async {
    final out = await runRealize(adapter: 'UserRealAdapter', exitSequence: [1]);

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('contract=mock-broke-contract'));
    expect(out, contains('result=blocked'));
    expect(out, contains('mock'));

    // Nothing was rebound — the baseline runs BEFORE the rebind.
    final datasourceDiFile = await File(
      p.join(
        fx.root.path,
        'lib/src/di',
        'datasources',
        'user_mock_datasource_di.dart',
      ),
    ).readAsString();
    expect(datasourceDiFile, datasourceDi);
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );
  });

  test('A4a: drift within the .zfa.json threshold passes with a drift '
      'report', () async {
    await writeFixtures();
    await File(p.join(fx.root.path, '.zfa.json')).writeAsString(
      jsonEncode({
        'tdd': {'realizeDifferentialThreshold': 0.9},
      }),
    );

    // A driver whose REAL side drifts one field of two.
    final out = await runRealize(
      adapter: 'UserRealAdapter',
      fixtureDriver: (binding, entity, input) async => binding == 'mock'
          ? {'id': 'u1', 'email': 'a@b.c'}
          : {'id': 'u1', 'email': 'drifted@z.c'},
    );

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('differential=pass'));
    expect(out, contains('drift=0.5'));
    expect(out, contains('result=realized'));
    expect(
      File(
        p.join(fx.featureDir, 'tdd', 'differential-report.json'),
      ).existsSync(),
      isTrue,
      reason: 'a passing gate still writes the drift report',
    );
    // The drift is carried into the transition evidence.
    final state =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', 'realize-state.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(state['transitions'].first['evidence']['differential'], 'pass');
  });

  test('A4b: drift beyond the .zfa.json threshold blocks the transition '
      'and rolls the rebind back', () async {
    await writeFixtures();
    await File(p.join(fx.root.path, '.zfa.json')).writeAsString(
      jsonEncode({
        'tdd': {'realizeDifferentialThreshold': 0.0},
      }),
    );

    final out = await runRealize(
      adapter: 'UserRealAdapter',
      fixtureDriver: (binding, entity, input) async => binding == 'mock'
          ? {'id': 'u1', 'email': 'a@b.c'}
          : {'id': 'u1', 'email': 'drifted@z.c'},
    );

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('differential=drift'));
    expect(out, contains('result=blocked'));
    // The rebind was rolled back and no REAL transition persisted.
    final datasourceDiFile = await File(
      p.join(
        fx.root.path,
        'lib/src/di',
        'datasources',
        'user_mock_datasource_di.dart',
      ),
    ).readAsString();
    expect(
      datasourceDiFile,
      datasourceDi,
      reason: 'a drift-blocked swap restores the mock-era bytes',
    );
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );
  });

  test('A5: ungated hand-deltas block the swap; gated deltas are recorded '
      'and the swap proceeds', () async {
    const rel = 'lib/src/di/datasources/user_mock_datasource_di.dart';
    // The binding file was generated (receipted) and then hand-edited.
    await recordReceipt(rel, datasourceDi);
    await File(
      p.join(fx.root.path, rel),
    ).writeAsString('$datasourceDi\n// hand-tuned for the demo');

    // Ungated: the swap is blocked before anything is rebound.
    final blocked = await runRealize(
      adapter: 'UserRealAdapter',
      handDeltas: const [],
    );
    expect(exitCode, 1, reason: 'out: $blocked');
    expect(blocked, contains('hand-delta'));
    expect(blocked, contains(rel));
    expect(blocked, contains('result=blocked'));
    final stillMocked = await File(p.join(fx.root.path, rel)).readAsString();
    expect(
      stillMocked,
      contains('// hand-tuned for the demo'),
      reason: 'a blocked swap leaves the tree untouched',
    );

    // Gated: the delta is recorded with (file, reason, diff-hash) and
    // the swap proceeds.
    final out = await runRealize(
      adapter: 'UserRealAdapter',
      handDeltas: [rel],
      handDeltaReason: 'hand-tuned for the demo fixture',
    );
    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));

    final ledgerFile = File(
      p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
    );
    expect(ledgerFile.existsSync(), isTrue);
    final ledger =
        jsonDecode(await ledgerFile.readAsString()) as Map<String, dynamic>;
    final entries = (ledger['entries'] as List)
        .where((e) => (e as Map<String, dynamic>)['file'] == rel)
        .toList();
    expect(entries, isNotEmpty);
    final entry = entries.first as Map<String, dynamic>;
    expect(entry['reason'], 'hand-tuned for the demo fixture');
    expect(entry['diffHash'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(entry['adapter'], 'UserRealAdapter');
  });
}

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}
