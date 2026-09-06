// Acceptance tests for the spec 1193 additions to `zfa tdd realize` — the
// MOCKED→REAL swap with gates and receipts (issue #1193, part of #908 P1).
//
// What spec 1193 adds on top of spec 913's swap:
//
//   1. the certified mock behind the behavior's interface is LOCATED (the
//      #1110 cert registry is consulted; a red certification blocks),
//   2. a missing real adapter can be SCAFFOLDED behind the SAME interface
//      (--scaffold — the hand-delta seam: receipted in the provenance
//      ledger, never pretended generated),
//   3. --dry-run previews the whole swap with ZERO writes,
//   4. the unified journal (#1113) records the ladder advance
//      MOCKED → REAL → DONE (behavior state mocked → done in
//      tdd/run-state.json, era in realize-state.json),
//   5. a hand-delta receipt (realize-receipt.v1) records the swap: files,
//      digests, gate outcomes, and generated/mock/hand ratios.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/journal.dart';
import 'package:zuraffa/src/plugins/tdd/services/run_state_store.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

import '../helpers/tdd_fixture.dart';

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
  Future<void> save(Map<String, dynamic> user);
}
''';

const mockDatasource = '''
import '../../domain/repositories/user_repository.dart';

class UserMockDataSource implements UserRepository {
  @override
  Future<Map<String, dynamic>?> getById(String id) async => null;
  @override
  Future<void> save(Map<String, dynamic> user) async {}
}
''';

const realAdapter = '''
import '../../domain/repositories/user_repository.dart';

class UserRealAdapter implements UserRepository {
  @override
  Future<Map<String, dynamic>?> getById(String id) async => null;
  @override
  Future<void> save(Map<String, dynamic> user) async {}
}
''';

void main() {
  late TddFixture fx;

  /// Receipt the current bytes of [rel] as a #807 generation run (the
  /// provenance baseline the nuance gate detects drift against).
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
    await fx.registerBehavior(
      id: 'B-001',
      description: 'create entity User with email',
    );
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

  /// Drive realize in-process with a green injected suite runner and a
  /// fixture driver whose real side agrees with the mock side (the
  /// contract-relevant shape holds).
  Future<String> runRealize({
    String target = 'User',
    String? adapter,
    bool withAdapter = false,
    bool scaffold = false,
    bool dryRun = false,
    bool diffOnly = false,
    bool writeFixtures = true,
    int suiteExitCode = 0,
  }) async {
    if (withAdapter) {
      _write(
        p.join(
          fx.root.path,
          'lib/src/data/datasources/user',
          'user_real_adapter.dart',
        ),
        realAdapter,
      );
    }
    if (writeFixtures) {
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
    final cmd = RealizeCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async => (
        exitCode: suiteExitCode,
        output: suiteExitCode == 0 ? 'suite green' : 'suite red',
      ),
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final args = <String>[
      'realize',
      target,
      '--project',
      fx.root.path,
      if (adapter != null) ...['--adapter', adapter],
      if (scaffold) '--scaffold',
      if (dryRun) '--dry-run',
      if (diffOnly) '--diff-only',
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

  // ------------------------------------------------------------------
  // --dry-run: the preview that writes NOTHING (issue #1193 step 0).
  // ------------------------------------------------------------------
  test(
    'DRY-1: --dry-run previews the swap and leaves the tree untouched',
    () async {
      final bindingBefore = await File(
        p.join(
          fx.root.path,
          'lib/src/di/datasources/user_mock_datasource_di.dart',
        ),
      ).readAsString();

      final out = await runRealize(
        adapter: 'UserRealAdapter',
        withAdapter: true,
        dryRun: true,
      );

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('result=dry-run'));
      // The plan is NAMED: what would be rebound, run, replayed.
      expect(out, contains('dry-run'));
      expect(out, contains('would rebind'));
      expect(out, contains('user_mock_datasource_di.dart'));

      // ZERO writes: no era transition, no journal, no receipts, no
      // cycle-log entry, and the binding file is byte-identical.
      expect(
        File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
        isFalse,
        reason: 'a dry-run must not persist a REAL transition',
      );
      expect(
        File(p.join(fx.featureDir, 'tdd', 'journal.json')).existsSync(),
        isFalse,
        reason: 'a dry-run must not write the unified journal',
      );
      expect(
        File(p.join(fx.featureDir, 'tdd', 'realize-receipt.json')).existsSync(),
        isFalse,
        reason: 'a dry-run must not write the swap receipt',
      );
      expect(
        File(
          p.join(fx.featureDir, 'tdd', 'differential-receipt.json'),
        ).existsSync(),
        isFalse,
        reason: 'a dry-run must not write the differential receipt',
      );
      expect(
        File(p.join(fx.featureDir, 'tdd', 'cycle-log.md')).existsSync(),
        isFalse,
        reason: 'a dry-run must not append to the cycle log',
      );
      final bindingAfter = await File(
        p.join(
          fx.root.path,
          'lib/src/di/datasources/user_mock_datasource_di.dart',
        ),
      ).readAsString();
      expect(bindingAfter, bindingBefore, reason: 'dry-run writes nothing');
    },
  );

  test('DRY-2: --dry-run and --diff-only are mutually exclusive', () async {
    final out = await runRealize(
      adapter: 'UserRealAdapter',
      withAdapter: true,
      dryRun: true,
      diffOnly: true,
      writeFixtures: false,
    );

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('result=runner-error'));
    expect(out, contains('--dry-run'));
    expect(out, contains('--diff-only'));
  });

  test(
    'DRY-3: a dry-run that would be refused exits 1 and names why',
    () async {
      // No adapter on disk and no --scaffold: the plan is refused.
      final out = await runRealize(adapter: 'UserRealAdapter', dryRun: true);

      expect(exitCode, 1, reason: 'out: $out');
      expect(out, contains('result=dry-run'));
      expect(out, contains('would refuse'));
      expect(out, contains('UserRealAdapter'));
    },
  );

  // ------------------------------------------------------------------
  // --scaffold: the hand-delta seam (issue #1193 step 2).
  // ------------------------------------------------------------------
  test('SCAF-1: --scaffold scaffolds the real adapter behind the SAME '
      'interface and records the hand-delta receipt', () async {
    final out = await runRealize(adapter: 'UserRealAdapter', scaffold: true);

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));
    expect(out, contains('scaffolded'));

    // The scaffold file exists, co-located with the mock datasource, and
    // declares the adapter implementing the SAME generated interface.
    final scaffoldFile = File(
      p.join(
        fx.root.path,
        'lib/src/data/datasources/user',
        'user_real_adapter.dart',
      ),
    );
    expect(scaffoldFile.existsSync(), isTrue, reason: 'out: $out');
    final content = await scaffoldFile.readAsString();
    expect(
      content,
      contains('class UserRealAdapter implements UserRepository'),
    );
    // Every interface method is stubbed with an honest UnimplementedError.
    expect(content, contains('getById'));
    expect(content, contains('save'));
    expect(content, contains('UnimplementedError'));
    // NEVER pretended generated: the scaffold is stamped as the hand seam.
    expect(content, contains('hand-delta seam'));
    expect(content, isNot(contains('// GENERATED')));

    // The scaffold is receipted in the provenance ledger as a hand-delta
    // (the hand-delta seam — receipted, never pretended generated).
    final ledger =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final entries = (ledger['entries'] as List)
        .map((e) => e as Map<String, dynamic>)
        .where((e) => (e['file'] as String).endsWith('user_real_adapter.dart'))
        .toList();
    expect(entries, isNotEmpty, reason: 'the scaffold must be receipted');
    expect(entries.first['reason'], contains('hand-delta seam'));
    expect(entries.first['diffHash'], matches(RegExp(r'^[0-9a-f]{64}$')));

    // And the DI rebind still landed behind the same interface.
    final binding = await File(
      p.join(
        fx.root.path,
        'lib/src/di/datasources/user_mock_datasource_di.dart',
      ),
    ).readAsString();
    expect(binding, contains('UserRealAdapter'));
    expect(RegExp(r'\bUserMockDataSource\b').hasMatch(binding), isFalse);
  });

  test('SCAF-2: a missing adapter WITHOUT --scaffold is still refused '
      '(realize never silently generates real implementations)', () async {
    final out = await runRealize(adapter: 'UserRealAdapter');

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('--scaffold'));
    expect(
      File(
        p.join(
          fx.root.path,
          'lib/src/data/datasources/user',
          'user_real_adapter.dart',
        ),
      ).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );
  });

  test(
    'SCAF-3: a refused scaffold leaves no adapter or ledger receipt',
    () async {
      final out = await runRealize(
        adapter: 'UserRealAdapter',
        scaffold: true,
        suiteExitCode: 1,
      );

      expect(exitCode, 1, reason: 'out: $out');
      expect(out, contains('contract gate RED'));
      expect(
        File(
          p.join(
            fx.root.path,
            'lib/src/data/datasources/user',
            'user_real_adapter.dart',
          ),
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  // ------------------------------------------------------------------
  // The journal advance (issue #1193 step 6): MOCKED → REAL → DONE in
  // the unified journal.
  // ------------------------------------------------------------------
  test('JRN-1: a realized swap appends the unified journal entry and '
      'advances the behavior ladder to DONE', () async {
    // The feature was driven to complete(mocked): the behavior is in the
    // mocked state in tdd/run-state.json.
    final store = RunStateStore(fx.featureDir);
    await store.save(
      RunState.empty(fx.featureName).advance('B-001', BehaviorState.mocked),
    );

    final out = await runRealize(adapter: 'UserRealAdapter', withAdapter: true);

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));

    // The unified journal entry: cycle meta, gate green, result realized,
    // the behavior listed, schema-valid.
    final journalFile = File(p.join(fx.featureDir, 'tdd', 'journal.json'));
    expect(journalFile.existsSync(), isTrue, reason: 'out: $out');
    final journal =
        jsonDecode(await journalFile.readAsString()) as Map<String, dynamic>;
    final entries = (journal['entries'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final realizeEntries = entries
        .where(
          (e) =>
              e['result'] == 'realized' &&
              (e['behaviors'] as List).contains('B-001'),
        )
        .toList();
    expect(realizeEntries, isNotEmpty, reason: 'out: $out');
    final entry = realizeEntries.last;
    expect(entry['cycle'], 'meta');
    expect(entry['gate_state'], 'green');
    expect(JournalSchema.validateEntry(entry), isEmpty);

    // The behavior's ladder state advanced MOCKED → DONE (REAL is the era
    // metadata realize-state.json already carries).
    final runState = await RunStateStore(fx.featureDir).load();
    expect(runState!.behaviorStates['B-001'], BehaviorState.done);

    // The era crossed to REAL (the ladder's REAL tier).
    final state =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', 'realize-state.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(state['era'], 'REAL');
  });

  test('JRN-2: only mocked behaviors advance — pending stays honest', () async {
    final store = RunStateStore(fx.featureDir);
    await store.save(
      RunState.empty(fx.featureName)
          .advance('B-001', BehaviorState.mocked)
          .advance('B-002', BehaviorState.pending),
    );

    final out = await runRealize(adapter: 'UserRealAdapter', withAdapter: true);

    expect(exitCode, 0, reason: 'out: $out');
    final runState = await RunStateStore(fx.featureDir).load();
    expect(runState!.behaviorStates['B-001'], BehaviorState.done);
    expect(
      runState.behaviorStates['B-002'],
      BehaviorState.pending,
      reason: 'a behavior the swap did not cover never advances',
    );
  });

  // ------------------------------------------------------------------
  // The hand-delta receipt with ratios (issue #1193 step 6).
  // ------------------------------------------------------------------
  test('RCPT-1: the swap writes realize-receipt.json — files, digests, '
      'gate outcome, and generated/mock/hand ratios', () async {
    final out = await runRealize(adapter: 'UserRealAdapter', withAdapter: true);

    expect(exitCode, 0, reason: 'out: $out');
    final receiptFile = File(
      p.join(fx.featureDir, 'tdd', 'realize-receipt.json'),
    );
    expect(receiptFile.existsSync(), isTrue, reason: 'out: $out');
    final receipt =
        jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>;

    expect(receipt['schema'], 'realize-receipt.v1');
    expect(receipt['entity'], 'User');
    expect(receipt['adapter'], 'UserRealAdapter');

    // The ladder advance is recorded honestly.
    final ladder = receipt['ladder'] as Map<String, dynamic>;
    expect(ladder['from'], 'MOCKED');
    expect(ladder['to'], 'REAL');

    // The gate outcomes are recorded.
    final gates = receipt['gates'] as Map<String, dynamic>;
    expect(gates['contract'], 'green');
    expect(gates['differential'], 'pass');

    // The swap's files with digests: every rebound binding file + the
    // mock implementation + the adapter.
    final files = (receipt['files'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(f['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(f['bucket'], isIn(['generated', 'mock', 'hand']));
    }
    expect(
      files.any(
        (f) => (f['path'] as String).endsWith('user_mock_datasource_di.dart'),
      ),
      isTrue,
      reason: 'the rebound binding files are receipted',
    );
    expect(
      files.any((f) => f['bucket'] == 'mock'),
      isTrue,
      reason: 'the mock implementation side is receipted in the mock bucket',
    );

    // The generated/mock/hand ratios.
    final ratios = receipt['ratios'] as Map<String, dynamic>;
    expect(ratios['generated'], isA<int>());
    expect(ratios['mock'], isA<int>());
    expect(ratios['hand'], isA<int>());
    expect(ratios['generated'], greaterThan(0));
    expect(ratios['mock'], greaterThan(0));
    expect(ratios['cell'], matches(RegExp(r'^\d+%/\d+%/\d+%$')));
  });

  // ------------------------------------------------------------------
  // The certified-mock location (issue #1193 step 1).
  // ------------------------------------------------------------------
  test(
    'CERT-1: a certified mock is located and counted in the receipt',
    () async {
      await _writeCert(fx.root.path, satisfied: true);

      final out = await runRealize(
        adapter: 'UserRealAdapter',
        withAdapter: true,
      );

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('certified'));
      final receipt =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'realize-receipt.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final mocks = receipt['mocks'] as Map<String, dynamic>;
      expect(mocks['total'], 1);
      expect(mocks['certified'], 1);
    },
  );

  test('CERT-2: a RED certification blocks the swap — the honest ladder '
      'never crosses on an unsatisfied mock', () async {
    await _writeCert(fx.root.path, satisfied: false);

    final out = await runRealize(adapter: 'UserRealAdapter', withAdapter: true);

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('certification'));
    expect(out, contains('result=blocked'));
    // Nothing crossed: no era transition, no journal advance.
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(fx.featureDir, 'tdd', 'journal.json')).existsSync(),
      isFalse,
    );
  });
}

/// Write a #1110 mock-cert receipt for User (fresh, methods per
/// [satisfied]).
Future<void> _writeCert(String root, {required bool satisfied}) async {
  final certDir = Directory(p.join(root, 'test', 'mock', 'user'));
  await certDir.create(recursive: true);
  await File(p.join(certDir.path, 'mock-cert.User.json')).writeAsString(
    jsonEncode({
      'schema': 1,
      'entity': 'User',
      'interface': 'UserDataSource',
      'subject': 'lib/src/data/datasources/user/user_mock_datasource.dart',
      'contract_test': 'test/mock/user/user_mock_contract_test.dart',
      'contract_digest': 'a' * 64,
      'methods': [
        {'name': 'getById', 'satisfied': satisfied},
      ],
      'sandbox': {'analyze': 'pass', 'test': satisfied ? 'pass' : 'fail'},
      'certified_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );
}

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}
