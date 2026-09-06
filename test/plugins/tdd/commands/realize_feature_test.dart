// RED acceptance tests for spec 1193 — `zfa tdd realize <feature>
// --adapter <name> [--dry-run]`: the feature-driven MOCKED→REAL swap
// with the contract + differential gates, the hand-delta seam scaffold,
// the ladder advance, and the realization receipt.
//
// Drives the public CLI surface in-process against a TddFixture dressed
// as a complete(mocked) feature: green cycle-log evidence, a fixtures
// manifest (the simulation binding), an engine receipt naming the
// certified mock, and the generated mock DI stack with #807 receipts.
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
import 'package:zuraffa/src/plugins/tdd/services/differential_gate.dart'
    show RealizeFixtureDriver;
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/'
    'feature_provenance.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/'
    'feature_provenance_reader.dart';
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
}
''';

const mockDatasource = '''
import '../../domain/repositories/user_repository.dart';

class UserMockDataSource implements UserRepository {
  @override
  Future<Map<String, dynamic>?> getById(String id) async => null;
}
''';

/// The hand-written real adapter (the nuance the honest 90/10 expects
/// the developer to own). Implements the SAME generated interface.
const realAdapter = '''
import '../../domain/repositories/user_repository.dart';

class UserFirestoreAdapter implements UserRepository {
  @override
  Future<Map<String, dynamic>?> getById(String id) async =>
      {'id': id, 'email': 'a@b.c'};
}
''';

const subjectFile =
    '// The behavior subject (receipted).\nvoid userSubject() {}\n';

void main() {
  late TddFixture fx;

  Future<void> recordReceipt(String rel, String content) async {
    final store = ReceiptStore(projectRoot: fx.root.path);
    await store.save(
      GenerationReceipt(
        command: 'zfa gen',
        target: 'User',
        repro: 'zfa gen B-001',
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

  Future<void> seedGreenEvidence(String behaviorId) async {
    final file = File(fx.cycleLogPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('# Cycle Log\n\n');
    }
    await file.writeAsString('''
## Cycle: $behaviorId (green)

- behavior: $behaviorId
- kind: green
- criterion: FR-007
- test: ${fx.testPathOf(behaviorId)}
- command: `dart test ${fx.testPathOf(behaviorId)}`
- exit: 0
- at: 2026-09-01T00:00:00.000Z
- output:
```
All tests passed!
```

''', mode: FileMode.append);
  }

  /// DRESS the fixture as a complete(mocked) feature: green behaviors,
  /// simulation binding (fixtures manifest), engine receipt naming the
  /// certified mock, receipted mock-era surface.
  Future<void> dressMockedFeature({bool withAdapter = false}) async {
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
    if (withAdapter) {
      _write(
        p.join(
          fx.root.path,
          'lib/src/data/datasources/user',
          'user_firestore_adapter.dart',
        ),
        realAdapter,
      );
    }
    _write(p.join(fx.root.path, 'lib', 'b_001_subject.dart'), subjectFile);
    await fx.registerBehavior(
      id: 'B-001',
      description: 'create entity User with email',
    );
    // The provenance reader derives coverage from project-relative
    // subject paths (the spec-070 convention); TddFixture registers
    // absolute ones. Normalize before the receipts land.
    await _relativizeSubjectPaths(fx);
    await seedGreenEvidence('B-001');
    // The engine receipt: the certified mock behind the behavior's
    // interface (issue #1110 v2 shape).
    await File(
      p.join(fx.featureDir, 'tdd', 'engine.receipt.json'),
    ).writeAsString(
      jsonEncode({
        'schema': 'engine.receipt.v2',
        'entity': 'User',
        'methods': [
          {
            'name': 'getById',
            'mock_certified': true,
            'mock_class': 'UserMockDataSource',
          },
        ],
        'source_files': [
          'lib/src/data/datasources/user/user_mock_datasource.dart',
        ],
      }),
    );
    // The simulation binding: the fixtures manifest (the complete(mocked)
    // marker) + the committed mock-era fixture.
    final fixturesDir = Directory(p.join(fx.featureDir, 'tdd', 'fixtures'));
    await fixturesDir.create(recursive: true);
    await File(
      p.join(fixturesDir.path, 'manifest.json'),
    ).writeAsString(jsonEncode({'families': [], 'digest': 'seed'}));
    await File(p.join(fixturesDir.path, 'get_by_id.json')).writeAsString(
      jsonEncode({
        'schema': 'realize-diff.v1',
        'id': 'get-by-id-u1',
        'input': {'op': 'getById', 'id': 'u1'},
        'mockOutput': {'id': 'u1', 'email': 'a@b.c'},
      }),
    );
    // The mocked ladder: B-001 sits at the MOCKED tier.
    await File(p.join(fx.featureDir, 'tdd', 'run-state.json')).writeAsString(
      jsonEncode({
        'feature': fx.featureName,
        'behavior_states': {'B-001': 'mocked'},
      }),
    );
    // The generated surface carries its #807 receipts (provenance
    // baseline: complete(mocked) needs receipt-covered subjects).
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
    await recordReceipt('lib/b_001_subject.dart', subjectFile);
  }

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// Run the feature-mode realize through the real CLI entry point with
  /// the suite runner + fixture driver injected (the 913 test pattern).
  Future<String> runRealize({
    required String adapter,
    List<int> exitSequence = const [0, 0],
    RealizeFixtureDriver? fixtureDriver,
    bool dryRun = false,
    List<String> handDeltas = const [],
    String? handDeltaReason,
    String target = '090-tdd-fixture',
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
      '--adapter',
      adapter,
      if (dryRun) '--dry-run',
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

  Future<FeatureProvenance> provenanceOf(String feature) async {
    final rows = await FeatureProvenanceReader(fx.root.path).read();
    return rows.firstWhere((row) => row.feature == feature);
  }

  Map<String, String> hashTestFiles() {
    final hashes = <String, String>{};
    final dir = Directory(p.join(fx.root.path, 'test'));
    if (dir.existsSync()) {
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        hashes[p.relative(file.path, from: fx.root.path)] = crypto.sha256
            .convert(file.readAsBytesSync())
            .toString();
      }
    }
    return hashes;
  }

  test('A1 (SC-1): a complete(mocked) feature realizes to complete(real) '
      'with zero test edits', () async {
    await dressMockedFeature(withAdapter: true);
    final before = hashTestFiles();
    expect(
      (await provenanceOf(fx.featureName)).state,
      FeatureRealizationState.completeMocked,
      reason: 'the fixture must start at complete(mocked)',
    );

    final out = await runRealize(
      adapter: 'firestore',
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));
    expect(out, contains('ladder=MOCKED->REAL->DONE'));

    // SC-1: the provenance derivation flipped to complete(real).
    expect(
      (await provenanceOf(fx.featureName)).state,
      FeatureRealizationState.completeReal,
    );

    // Zero test edits: every test byte identical.
    expect(hashTestFiles(), before);

    // The DI binding is swapped behind the same interface.
    final datasourceDiFile = await File(
      p.join(
        fx.root.path,
        'lib/src/di/datasources',
        'user_mock_datasource_di.dart',
      ),
    ).readAsString();
    expect(
      RegExp(r'\bUserMockDataSource\b').hasMatch(datasourceDiFile),
      isFalse,
    );
    expect(datasourceDiFile, contains('UserFirestoreAdapter'));

    // The simulation binding is retired (manifest gone, fixture kept).
    expect(
      await File(
        p.join(fx.featureDir, 'tdd', 'fixtures', 'manifest.json'),
      ).exists(),
      isFalse,
    );
    expect(
      await File(
        p.join(fx.featureDir, 'tdd', 'fixtures', 'get_by_id.json'),
      ).exists(),
      isTrue,
    );

    // The era crossed to REAL, persisted with gate evidence.
    final stateFile = File(p.join(fx.featureDir, 'tdd', 'realize-state.json'));
    expect(stateFile.existsSync(), isTrue, reason: 'out: $out');
    final state =
        jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
    expect(state['era'], 'REAL');
    expect(state['adapter'], 'UserFirestoreAdapter');
    expect(state['transitions'].first['from'], 'MOCKED');
    expect(state['transitions'].first['to'], 'REAL');

    // The behavior ladder advanced to the terminal tier.
    final runState =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', 'run-state.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(runState['behavior_states']['B-001'], 'done');

    // The unified journal entry landed in the cycle log.
    final cycleLog = await File(fx.cycleLogPath).readAsString();
    expect(cycleLog, contains('## Realization: ${fx.featureName}'));
    expect(cycleLog, contains('- kind: realize'));
    expect(cycleLog, contains('- era: REAL'));
  });

  test('A1b (SC-3): the receipt records the swap — files, digests, gate '
      'outcome, ratios — parseable as proof.v1', () async {
    await dressMockedFeature(withAdapter: true);

    final out = await runRealize(
      adapter: 'firestore',
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );
    expect(exitCode, 0, reason: 'out: $out');

    final receiptFile = File(
      p.join(
        fx.root.path,
        '.zfa',
        'receipts',
        'realize.${fx.featureName}.firestore.receipt.json',
      ),
    );
    expect(receiptFile.existsSync(), isTrue, reason: 'out: $out');
    final doc =
        jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>;

    // proof.v1 envelope.
    expect(doc['schema'], 'proof.v1');
    expect(doc['command'], 'zfa tdd realize');
    expect(doc['target'], fx.featureName);

    // Gate outcome.
    expect(doc['gates']['contract'], 'green');
    expect(doc['gates']['differential']['verdict'], 'pass');

    // The rebind files + the retired manifest, digests re-derivable.
    final files = (doc['files'] as List).cast<Map<String, dynamic>>();
    expect(files, isNotEmpty);
    final deleted = files.where((f) => f['action'] == 'delete').toList();
    expect(deleted, hasLength(1));
    expect(
      deleted.first['path'],
      'specs/${fx.featureName}/tdd/fixtures/manifest.json',
    );
    for (final entry in files.where((f) => f['action'] != 'delete')) {
      final bytes = await File(
        p.join(fx.root.path, entry['path'] as String),
      ).readAsBytes();
      expect(
        crypto.sha256.convert(bytes).toString(),
        entry['sha256'],
        reason: 'digest drift on ${entry['path']}',
      );
    }

    // The generated/mock/hand ratios.
    expect(doc['ratios'], isA<Map>());
    expect(doc['ratios']['generated'], greaterThan(0));

    // The ladder transitions.
    expect(doc['ladder']['B-001'], ['MOCKED', 'REAL', 'DONE']);

    // Parses through the receipt store (what proof check reads).
    final receipt = GenerationReceipt.fromJson(doc);
    expect(receipt.files, isNotEmpty);
  });

  test('A2 (SC-2): a failing differential gate blocks REAL — rollback, '
      'MOCKED era, simulation binding kept', () async {
    await dressMockedFeature(withAdapter: true);

    final out = await runRealize(
      adapter: 'firestore',
      // One field of two drifts; the default threshold is 0.0.
      fixtureDriver: (binding, entity, input) async => binding == 'mock'
          ? {'id': 'u1', 'email': 'a@b.c'}
          : {'id': 'u1', 'email': 'drifted@z.c'},
    );

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('differential=drift'));
    expect(out, contains('result=blocked'));

    // The rebind was rolled back: mock-era bytes restored.
    expect(
      await File(
        p.join(
          fx.root.path,
          'lib/src/di/datasources',
          'user_mock_datasource_di.dart',
        ),
      ).readAsString(),
      datasourceDi,
    );
    // The era never crossed to REAL.
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );
    // The ladder stays MOCKED.
    final runState =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', 'run-state.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(runState['behavior_states']['B-001'], 'mocked');
    // The simulation binding stays: still complete(mocked).
    expect(
      (await provenanceOf(fx.featureName)).state,
      FeatureRealizationState.completeMocked,
    );
    // No receipt was written for a blocked swap.
    expect(
      File(
        p.join(
          fx.root.path,
          '.zfa',
          'receipts',
          'realize.${fx.featureName}.firestore.receipt.json',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('A3 (FR-002): a missing adapter is scaffolded behind the same '
      'interface as a receipted hand-delta seam (never generated)', () async {
    await dressMockedFeature(withAdapter: false);

    // Baseline (mock binding) green, real-binding run red: the
    // scaffold's UnimplementedError bodies do not satisfy the
    // contract yet — the honest gates block the swap, but the
    // scaffold lands as the developer's starting point.
    final out = await runRealize(
      adapter: 'firestore',
      exitSequence: [0, 1],
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );
    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('result=blocked'));
    expect(out, contains('scaffolded'));

    // The scaffold exists with the seam contract...
    final scaffoldFile = File(
      p.join(
        fx.root.path,
        'lib/src/data/datasources/user/user_firestore_adapter.dart',
      ),
    );
    expect(scaffoldFile.existsSync(), isTrue, reason: 'out: $out');
    final text = await scaffoldFile.readAsString();
    expect(text, contains('HAND-DELTA SEAM'));
    expect(
      text,
      contains('class UserFirestoreAdapter implements UserRepository'),
    );
    expect(text, contains('getById(String id)'));
    expect(text, contains('UnimplementedError'));

    // The blocked swap rolled the bindings back to the mock era.
    expect(
      await File(
        p.join(
          fx.root.path,
          'lib/src/di/datasources',
          'user_mock_datasource_di.dart',
        ),
      ).readAsString(),
      datasourceDi,
    );

    // The nuance ledger gated the scaffold at creation time.
    final ledgerFile = File(
      p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
    );
    expect(ledgerFile.existsSync(), isTrue);
    final ledger =
        jsonDecode(await ledgerFile.readAsString()) as Map<String, dynamic>;
    final entries = (ledger['entries'] as List)
        .where(
          (e) =>
              (e as Map<String, dynamic>)['file'] ==
              'lib/src/data/datasources/user/user_firestore_adapter.dart',
        )
        .toList();
    expect(entries, isNotEmpty);
    expect(
      (entries.first as Map<String, dynamic>)['reason'],
      contains('adapter scaffold seam'),
    );

    // Never pretended generated: no proof.v1 receipt carries the
    // scaffold path.
    final receipts = await ReceiptStore(projectRoot: fx.root.path).loadAll();
    for (final record in receipts) {
      for (final file in record.receipt.files) {
        expect(
          file.path,
          isNot(contains('user_firestore_adapter')),
          reason: 'the scaffold must never be generation-receipted',
        );
      }
    }
  });

  test('A3b (FR-002): after the dev fills the seam in, a gated hand-delta '
      'realizes the feature', () async {
    await dressMockedFeature(withAdapter: false);

    // First run: the scaffold lands (blocked by the honest gates —
    // the UnimplementedError bodies fail the contract re-run).
    final first = await runRealize(
      adapter: 'firestore',
      exitSequence: [0, 1],
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );
    expect(exitCode, 1, reason: 'out: $first');
    final scaffoldRel =
        'lib/src/data/datasources/user/user_firestore_adapter.dart';

    // The developer writes the real nuance (a hand-delta over the
    // receipted scaffold bytes).
    await File(p.join(fx.root.path, scaffoldRel)).writeAsString(realAdapter);

    final out = await runRealize(
      adapter: 'firestore',
      handDeltas: [scaffoldRel],
      handDeltaReason: 'filled in the real firestore nuance',
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );
    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));
    expect(
      (await provenanceOf(fx.featureName)).state,
      FeatureRealizationState.completeReal,
    );
  });

  test('A4 (FR-007): --dry-run prints the plan and writes NOTHING', () async {
    await dressMockedFeature(withAdapter: false);

    final out = await runRealize(adapter: 'firestore', dryRun: true);

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=planned'));
    expect(out, contains(fx.featureName));
    expect(out, contains('User'));
    expect(out, contains('UserFirestoreAdapter'));

    // No scaffold.
    expect(
      File(
        p.join(
          fx.root.path,
          'lib/src/data/datasources/user',
          'user_firestore_adapter.dart',
        ),
      ).existsSync(),
      isFalse,
    );
    // No rebind.
    expect(
      await File(
        p.join(
          fx.root.path,
          'lib/src/di/datasources',
          'user_mock_datasource_di.dart',
        ),
      ).readAsString(),
      datasourceDi,
    );
    // No state, no ladder write.
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );
    expect(
      jsonDecode(
        await File(
          p.join(fx.featureDir, 'tdd', 'run-state.json'),
        ).readAsString(),
      )['behavior_states']['B-001'],
      'mocked',
    );
    // The manifest stays.
    expect(
      File(
        p.join(fx.featureDir, 'tdd', 'fixtures', 'manifest.json'),
      ).existsSync(),
      isTrue,
    );
    // No receipt.
    expect(
      File(
        p.join(
          fx.root.path,
          '.zfa',
          'receipts',
          'realize.${fx.featureName}.firestore.receipt.json',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('A5 (FR-003): re-realizing the same adapter is an already-real '
      'no-op', () async {
    await dressMockedFeature(withAdapter: true);
    await runRealize(
      adapter: 'firestore',
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );
    final stateFile = File(p.join(fx.featureDir, 'tdd', 'realize-state.json'));
    final transitionsAfterFirst =
        ((jsonDecode(await stateFile.readAsString()) as Map)['transitions']
                as List)
            .length;

    final out = await runRealize(
      adapter: 'firestore',
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=already-real'));
    expect(
      ((jsonDecode(await stateFile.readAsString()) as Map)['transitions']
              as List)
          .length,
      transitionsAfterFirst,
      reason: 'an idempotent re-run appends no transition',
    );
  });

  test(
    'A6 (FR-001): an uncertified mock blocks with the exact certify fix',
    () async {
      await dressMockedFeature(withAdapter: true);
      await File(
        p.join(fx.featureDir, 'tdd', 'engine.receipt.json'),
      ).writeAsString(
        jsonEncode({
          'schema': 'engine.receipt.v2',
          'entity': 'User',
          'methods': [
            {
              'name': 'getById',
              'mock_certified': false,
              'mock_class': 'UserMockDataSource',
            },
          ],
          'source_files': [],
        }),
      );

      final out = await runRealize(adapter: 'firestore');

      expect(exitCode, 1, reason: 'out: $out');
      expect(out, contains('result=blocked'));
      expect(out, contains('zfa mock create User --certify'));
      // Nothing was rebound.
      expect(
        await File(
          p.join(
            fx.root.path,
            'lib/src/di/datasources',
            'user_mock_datasource_di.dart',
          ),
        ).readAsString(),
        datasourceDi,
      );
    },
  );

  test('A7 (FR-005): the #832 manifest and mock-cert receipts are skipped '
      'by the differential gate, never a runner-error', () async {
    await dressMockedFeature(withAdapter: true);
    // A mock-cert receipt parked in the fixtures dir (the #1001
    // convention): metadata, not a differential fixture.
    await File(
      p.join(fx.featureDir, 'tdd', 'fixtures', 'mock-cert.User.json'),
    ).writeAsString(jsonEncode({'entity': 'User', 'green': true}));

    final out = await runRealize(
      adapter: 'firestore',
      fixtureDriver: (binding, entity, input) async => {
        'id': 'u1',
        'email': 'a@b.c',
      },
    );

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));
    expect(out, isNot(contains('differential=runner-error')));
  });
}

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

/// Normalize the registry's subject paths to project-relative POSIX (the
/// spec-070 provenance convention).
Future<void> _relativizeSubjectPaths(TddFixture fx) async {
  final file = File(fx.artifactsPath);
  final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final records = (map['records'] as List).cast<Map<String, dynamic>>();
  for (final record in records) {
    final subject = record['subject_path'] as String;
    if (p.isAbsolute(subject)) {
      record['subject_path'] = p.posix
          .normalize(p.relative(subject, from: fx.root.path))
          .replaceAll('\\', '/');
    }
  }
  await file.writeAsString(jsonEncode(map));
}
