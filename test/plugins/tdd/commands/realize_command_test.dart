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
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/tdd_fixture.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_command.dart';
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

  setUp(() async {
    fx = await TddFixture.create();
    _write(p.join(fx.root.path, 'lib/src/di/datasources',
        'user_mock_datasource_di.dart'), datasourceDi);
    _write(p.join(fx.root.path, 'lib/src/di/repositories',
        'user_repository_di.dart'), repositoryDi);
    _write(p.join(fx.root.path, 'lib/src/domain/repositories',
        'user_repository.dart'), domainRepository);
    _write(p.join(fx.root.path, 'lib/src/data/datasources/user',
        'user_mock_datasource.dart'), mockDatasource);
    _write(p.join(fx.root.path, 'lib/src/data/datasources/user',
        'user_real_adapter.dart'), realAdapter);
    await fx.registerBehavior(
      id: 'B-001',
      description: 'create entity User with email',
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
  }) async {
    final cmd = RealizeCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async => (exitCode: 0, output: 'green'),
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final args = <String>[
      'realize',
      target,
      '--project',
      fx.root.path,
      if (adapter != null) ...['--adapter', adapter],
      if (feature != null) ...['--feature', feature],
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

  test('A1: full green path rebinds DI, transitions era, persists state',
      () async {
    final out = await runRealize(adapter: 'UserRealAdapter');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=realized'));

    // The DI binding is swapped behind the same interface.
    final datasourceDiFile = await File(p.join(fx.root.path, 'lib/src/di',
        'datasources', 'user_mock_datasource_di.dart')).readAsString();
    expect(RegExp(r'\bUserMockDataSource\b').hasMatch(datasourceDiFile), isFalse);
    expect(datasourceDiFile, contains('UserRealAdapter'));

    // The state transition MOCKED -> REAL is persisted.
    final stateFile = File(p.join(
        fx.featureDir, 'tdd', 'realize-state.json'));
    expect(stateFile.existsSync(), isTrue, reason: 'out: $out');
    final state = jsonDecode(await stateFile.readAsString())
        as Map<String, dynamic>;
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
  });

  test('A2: --adapter is required — a swap without a real adapter is refused',
      () async {
    final out = await runRealize(adapter: null);

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('--adapter'));
    // Nothing was rebound.
    final datasourceDiFile = await File(p.join(fx.root.path, 'lib/src/di',
        'datasources', 'user_mock_datasource_di.dart')).readAsString();
    expect(datasourceDiFile, contains('UserMockDataSource'));
    expect(
      File(p.join(fx.featureDir, 'tdd', 'realize-state.json')).existsSync(),
      isFalse,
    );
  });

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
    final datasourceDiFile = await File(p.join(fx.root.path, 'lib/src/di',
        'datasources', 'user_mock_datasource_di.dart')).readAsString();
    expect(RegExp(r'\bUserMockDataSource\b').hasMatch(datasourceDiFile), isFalse);
  });
}

void _write(String path, String content) {
  File(path)..createSync(recursive: true)..writeAsStringSync(content);
}
