// Acceptance tests for `zfa tdd realize --diff-only` — the standalone
// differential replay (spec 1195, SC-5): the harness replays the committed
// fixtures through mock + real WITHOUT rebinding, without the contract
// suite, and without the state transition — the receipt (mode diff-only)
// and an era-tagged cycle-log entry are the only writes.
//
// Drives the public CLI surface in-process against a TddFixture whose lib/
// carries the generated mock binding (the realize_command_test pattern).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/version.dart';

import '../helpers/tdd_fixture.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_harness.dart';
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
  /// provenance baseline the embedded realize flow's nuance gate
  /// detects drift against — the realize_command_test pattern).
  Future<void> recordReceipt(String rel, String content) async {
    final store = ReceiptStore(projectRoot: fx.root.path);
    await store.save(
      GenerationReceipt(
        command: 'zfa di',
        target: 'User',
        repro: 'zfa di User',
        at: DateTime.now().toUtc(),
        generatorVersion: version,
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
    // baseline the embedded flow's nuance gate requires (B-013 runs the
    // full realize, not just --diff-only).
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

  /// Runs `zfa tdd realize User --diff-only` with the fixture driver
  /// injected (the fast-tier pattern) and the suite runner poisoned to
  /// FAIL if ever invoked — diff-only must never touch the suite.
  Future<String> runDiffOnly({RealizeFixtureDriver? fixtureDriver}) async {
    var suiteCalls = 0;
    final cmd = RealizeCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async {
        suiteCalls++;
        return (exitCode: 1, output: 'SUITE MUST NOT RUN IN --diff-only');
      },
      fixtureDriver: fixtureDriver,
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final lines = <String>[];
    await runZoned(
      () => runner.run([
        'realize',
        'User',
        '--diff-only',
        '--project',
        fx.root.path,
        '--feature',
        fx.featureName,
      ]),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    expect(suiteCalls, 0, reason: '--diff-only must not run the suite');
    return lines.join('\n');
  }

  Future<void> writeFixtures() async {
    final dir = Directory(p.join(fx.featureDir, 'tdd', 'fixtures'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'signup.json')).writeAsString(
      jsonEncode({
        'schema': 'realize-diff.v1',
        'id': 'signup-u2',
        'input': {'op': 'signup', 'email': 'x@y.z'},
        'mockOutput': {'id': 'u2', 'email': 'x@y.z', 'state': 'ACTIVE'},
      }),
    );
  }

  test(
    'B-011: --diff-only runs ONLY the differential — tree untouched, '
    'receipt mode diff-only, era-tagged entry, no state transition',
    () async {
      await writeFixtures();

      final out = await runDiffOnly(
        fixtureDriver: (binding, entity, input) async => binding == 'mock'
            ? {'id': 'u2', 'email': 'x@y.z', 'state': 'ACTIVE'}
            : {'id': 'u9', 'email': 'x@y.z', 'state': 'ACTIVE'},
      );

      // The mock binding is NOT rebound — the DI bytes are untouched.
      final datasourceDiFile = await File(
        p.join(
          fx.root.path,
          'lib/src/di/datasources',
          'user_mock_datasource_di.dart',
        ),
      ).readAsString();
      expect(datasourceDiFile, datasourceDi);
      expect(datasourceDiFile.contains('UserRealAdapter'), isFalse);

      // No state transition, no realize-state.json — diff-only never
      // promotes.
      expect(
        File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
        isFalse,
      );

      // The receipt lands in the feature's tdd/ directory, mode diff-only.
      final receiptFile = File(
        p.join(fx.featureDir, 'tdd', 'differential-receipt.json'),
      );
      expect(receiptFile.existsSync(), isTrue, reason: 'out: $out');
      final doc =
          jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>;
      expect(doc['mode'], 'diff-only');
      expect(doc['verdict'], 'pass');
      expect(doc['journal']['gate_state'], 'green');

      // The era-tagged cycle-log entry (kind realize-diff) is the only
      // other write.
      final cycleLog = await File(
        p.join(fx.featureDir, 'tdd', 'cycle-log.md'),
      ).readAsString();
      expect(cycleLog, contains('kind: realize-diff'));

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('result=diff-clean'));
    },
  );

  test('B-012: --diff-only divergence exits 1 and prints the named row; '
      'pass exits 0 — and the tree is never touched', () async {
    await writeFixtures();

    final out = await runDiffOnly(
      fixtureDriver: (binding, entity, input) async => binding == 'mock'
          ? {'id': 'u2', 'email': 'x@y.z', 'state': 'ACTIVE'}
          : {'id': 'u9', 'email': 'x@y.z', 'state': 'PENDING'},
    );

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('differential=divergence'));
    expect(out, contains('result=diff-divergence'));
    // The named row is on stdout: input, mock output, real output, clause.
    expect(out, contains('signup-u2'));
    expect(out, contains('state'));
    expect(out, contains('ACTIVE'));
    expect(out, contains('PENDING'));
    expect(out, contains('state transition'));

    // Divergence still never touches the tree.
    final datasourceDiFile = await File(
      p.join(
        fx.root.path,
        'lib/src/di/datasources',
        'user_mock_datasource_di.dart',
      ),
    ).readAsString();
    expect(datasourceDiFile, datasourceDi);
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );

    // The receipt records the red gate state for the journal.
    final doc =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', 'differential-receipt.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(doc['journal']['gate_state'], 'red');
    expect(doc['journal']['violations'], ['signup-u2/state']);
  });

  test('B-013: embedded realize — a divergence rolls the rebind back and '
      'prints the named row; rows within a raised threshold pass but are '
      'still named', () async {
    await writeFixtures();
    await File(p.join(fx.root.path, '.zfa.json')).writeAsString(
      jsonEncode({
        'tdd': {'realizeDifferentialThreshold': 0.9},
      }),
    );

    // The real adapter's state diverges — one row of two compared fields
    // (0.5) is within the 0.9 threshold: the swap proceeds, but the row
    // is still named on stdout and in the receipt.
    var suiteCalls = 0;
    final cmd = RealizeCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async {
        suiteCalls++;
        return (exitCode: 0, output: 'call $suiteCalls');
      },
      fixtureDriver: (binding, entity, input) async => binding == 'mock'
          ? {'id': 'u2', 'email': 'x@y.z', 'state': 'ACTIVE'}
          : {'id': 'u9', 'email': 'x@y.z', 'state': 'PENDING'},
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final lines = <String>[];
    await runZoned(
      () => runner.run([
        'realize',
        'User',
        '--adapter',
        'UserRealAdapter',
        '--project',
        fx.root.path,
        '--feature',
        fx.featureName,
      ]),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    final out = lines.join('\n');
    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));
    expect(out, contains('differential=pass'));
    // The within-threshold row is still NAMED (never silenced).
    expect(out, contains('signup-u2/state'));
    final state =
        jsonDecode(
              await File(
                p.join(fx.featureDir, 'tdd', 'realize-state.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(state['transitions'].first['evidence']['differential'], 'pass');
  });
}

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}
