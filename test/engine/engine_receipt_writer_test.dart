// Spec 1002 — EngineReceiptWriter unit tests.
//
// The engine preset auto-writes `engine.receipt.json` with the entity
// digest, the methods generated, per-method mock certification, DI wiring,
// and the file paths of the generated slice (issue #1002, deliverable 3).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/engine/engine_receipt_writer.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_engine_receipt_');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test('writes .zfa/engine.receipt.json with the engine.v1 schema', () async {
    final entityFile = File(
      p.join(workspace.path, 'lib/src/domain/entities/login/login.dart'),
    );
    await entityFile.parent.create(recursive: true);
    await entityFile.writeAsString('class Login {}');

    final writer = EngineReceiptWriter(projectRoot: workspace.path);
    final file = await writer.write(
      command: 'zfa make engine Login',
      entityName: 'Login',
      entityPath: 'lib/src/domain/entities/login/login.dart',
      methods: const ['get', 'getList', 'create', 'update', 'delete'],
      mockCertified: const {
        'get': true,
        'getList': true,
        'create': true,
        'update': true,
        'delete': true,
      },
      mockDatasourcePath:
          'lib/src/data/datasources/login/login_mock_datasource.dart',
      mockDataPath: 'lib/src/data/mock/login_mock_data.dart',
      diFiles: const [
        'lib/src/di/usecases/get_login_usecase_di.dart',
        'lib/src/di/repositories/login_repository_di.dart',
      ],
      getItTypes: const ['LoginRepository', 'LoginRemoteDataSource'],
      engineCheckPassed: true,
      engineCheckFailures: const [],
      generatedFiles: const [
        'lib/src/domain/entities/login/login.dart',
        'lib/src/data/datasources/login/login_mock_datasource.dart',
      ],
    );

    expect(file.path, p.join(workspace.path, '.zfa', 'engine.receipt.json'));

    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(decoded['schema'], 'engine.v1');
    expect(decoded['command'], 'zfa make engine Login');
    expect(decoded['target'], 'Login');
    expect(decoded['at'], isNotNull);

    final entity = decoded['entity'] as Map<String, dynamic>;
    expect(entity['name'], 'Login');
    expect(entity['path'], 'lib/src/domain/entities/login/login.dart');
    expect(entity['digest'], isNotNull);
    expect(entity['digest'], hasLength(64), reason: 'sha256 hex digest');

    final methods = decoded['methods'] as List;
    expect(methods, hasLength(5));
    for (final entry in methods.cast<Map<String, dynamic>>()) {
      expect(
        entry['mock_certified'],
        isTrue,
        reason: 'every method lists mock_certified: true',
      );
      expect(entry['method'], isNotNull);
    }
    expect((methods.first as Map<String, dynamic>)['method'], 'get');

    final mocks = decoded['mocks'] as Map<String, dynamic>;
    expect(mocks['datasource'], isNotNull);
    expect(mocks['data'], isNotNull);
    expect(mocks['certified'], isTrue);

    final di = decoded['di_wired'] as Map<String, dynamic>;
    expect(di['di_files'], hasLength(2));
    expect(
      di['getit_types'],
      containsAll(['LoginRepository', 'LoginRemoteDataSource']),
    );
    expect(di['getit_types_resolved'], 2);

    final engineCheck = decoded['engine_check'] as Map<String, dynamic>;
    expect(engineCheck['passed'], isTrue);
    expect(engineCheck['failures'], isEmpty);

    expect(decoded['files'], hasLength(2));
  });

  test(
    'records uncertified methods and engine check failures honestly',
    () async {
      final entityFile = File(
        p.join(workspace.path, 'lib/src/domain/entities/login/login.dart'),
      );
      await entityFile.parent.create(recursive: true);
      await entityFile.writeAsString('class Login {}');

      final writer = EngineReceiptWriter(projectRoot: workspace.path);
      final file = await writer.write(
        command: 'zfa make engine Login',
        entityName: 'Login',
        entityPath: 'lib/src/domain/entities/login/login.dart',
        methods: const ['get', 'delete'],
        mockCertified: const {'get': true, 'delete': false},
        mockDatasourcePath:
            'lib/src/data/datasources/login/login_mock_datasource.dart',
        mockDataPath: null,
        diFiles: const [],
        getItTypes: const [],
        engineCheckPassed: false,
        engineCheckFailures: const [
          EngineCheckFailure(
            code: EngineFindingCode.uncertifiedMock,
            message: 'method "delete" not certified on the mock datasource',
          ),
        ],
        generatedFiles: const [],
      );

      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final methods = (decoded['methods'] as List).cast<Map<String, dynamic>>();
      expect(
        methods.firstWhere((m) => m['method'] == 'get')['mock_certified'],
        isTrue,
      );
      expect(
        methods.firstWhere((m) => m['method'] == 'delete')['mock_certified'],
        isFalse,
      );
      expect((decoded['mocks'] as Map<String, dynamic>)['certified'], isFalse);
      expect(
        (decoded['engine_check'] as Map<String, dynamic>)['passed'],
        isFalse,
      );
      final recordedFailures =
          ((decoded['engine_check'] as Map<String, dynamic>)['failures']
                  as List)
              .cast<Map<String, dynamic>>();
      expect(recordedFailures, hasLength(1));
      expect(recordedFailures.first['message'], contains('delete'));
      expect(recordedFailures.first['code'], 'uncertifiedMock');
    },
  );

  test(
    'overwrites a previous engine receipt for the same run target',
    () async {
      final entityFile = File(
        p.join(workspace.path, 'lib/src/domain/entities/login/login.dart'),
      );
      await entityFile.parent.create(recursive: true);
      await entityFile.writeAsString('class Login {}');
      final writer = EngineReceiptWriter(projectRoot: workspace.path);

      await writer.write(
        command: 'zfa make engine Login',
        entityName: 'Login',
        entityPath: 'lib/src/domain/entities/login/login.dart',
        methods: const ['get'],
        mockCertified: const {'get': true},
        mockDatasourcePath: null,
        mockDataPath: null,
        diFiles: const [],
        getItTypes: const [],
        engineCheckPassed: true,
        engineCheckFailures: const [],
        generatedFiles: const [],
      );
      await writer.write(
        command: 'zfa make engine Login',
        entityName: 'Login',
        entityPath: 'lib/src/domain/entities/login/login.dart',
        methods: const ['get', 'update'],
        mockCertified: const {'get': true, 'update': true},
        mockDatasourcePath: null,
        mockDataPath: null,
        diFiles: const [],
        getItTypes: const [],
        engineCheckPassed: true,
        engineCheckFailures: const [],
        generatedFiles: const [],
      );

      final receipts = Directory(p.join(workspace.path, '.zfa'))
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('engine.receipt.json'))
          .toList();
      expect(receipts, hasLength(1), reason: 'one canonical engine receipt');
      final decoded =
          jsonDecode(await receipts.first.readAsString())
              as Map<String, dynamic>;
      expect(decoded['methods'], hasLength(2));
    },
  );
}
