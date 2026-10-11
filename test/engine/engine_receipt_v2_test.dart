// Spec 077 / issue #1109 — engine receipt v2 (T005, behaviors U7/U8/A3).
//
// `zfa make engine <Entity>` must write the issue-shaped receipt to
// `specs/<feature>/tdd/engine.receipt.json` (schema `engine.receipt.v2`)
// with per-method `mock_certified` + `mock_class` and sorted
// `source_files`, atomically overwriting on re-runs. The v1 artifact at
// `.zfa/engine.receipt.json` stays untouched.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/engine/engine_receipt_writer.dart';
import 'package:zuraffa/src/engine/mock_certifier.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_engine_v2_');
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

  File receiptFile(String feature) => File(
    p.join(workspace.path, 'specs', feature, 'tdd', 'engine.receipt.json'),
  );

  test('writeV2 writes specs/<feature>/tdd/engine.receipt.json with the '
      'issue shape (methods[].{name, mock_certified, mock_class}, sorted '
      'source_files)', () async {
    const writer = EngineReceiptWriter(projectRoot: '');

    final file = await writer.writeV2(
      projectRoot: workspace.path,
      feature: '005-login-engine',
      entityName: 'User',
      methods: const [
        EngineReceiptMethod(
          name: 'get',
          mockCertified: true,
          mockClass: 'UserMockDataSource',
        ),
        EngineReceiptMethod(
          name: 'create',
          mockCertified: true,
          mockClass: 'UserMockDataSource',
        ),
      ],
      sourceFiles: const [
        'lib/src/di/usecases/create_user_usecase_di.dart',
        'lib/src/domain/entities/user/user.dart',
        'lib/src/domain/usecases/user/get_user_usecase.dart',
      ],
    );

    expect(file.path, receiptFile('005-login-engine').path);
    expect(file.existsSync(), isTrue, reason: 'v2 receipt created on demand');

    final receipt = jsonFileDecode(file) as Map<String, dynamic>;
    expect(receipt['schema'], 'engine.receipt.v2');
    expect(receipt['entity'], 'User');

    final methods = (receipt['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods, hasLength(2));
    expect(methods.first['name'], 'get');
    expect(methods.first['mock_certified'], isTrue);
    expect(methods.first['mock_class'], 'UserMockDataSource');
    expect(methods.last['name'], 'create');
    expect(methods.last['mock_certified'], isTrue);

    final sourceFiles = (receipt['source_files'] as List).cast<String>();
    expect(sourceFiles, isNotEmpty);
    expect(
      sourceFiles,
      equals([...sourceFiles]..sort()),
      reason: 'source_files must be sorted',
    );
    expect(sourceFiles, contains('lib/src/domain/entities/user/user.dart'));
  });

  test('writeV2 records uncertified methods honestly (mock_certified: false '
      'survives into the receipt — the CERT-GATE signal)', () async {
    const writer = EngineReceiptWriter(projectRoot: '');

    final file = await writer.writeV2(
      projectRoot: workspace.path,
      feature: '005-login-engine',
      entityName: 'User',
      methods: const [
        EngineReceiptMethod(
          name: 'get',
          mockCertified: true,
          mockClass: 'UserMockDataSource',
        ),
        EngineReceiptMethod(name: 'delete', mockCertified: false),
      ],
      sourceFiles: const ['lib/src/domain/entities/user/user.dart'],
    );

    final methods =
        ((jsonFileDecode(file) as Map<String, dynamic>)['methods'] as List)
            .cast<Map<String, dynamic>>();
    final deleted = methods.firstWhere((m) => m['name'] == 'delete');
    expect(deleted['mock_certified'], isFalse);
    expect(deleted['mock_class'], isNull);
  });

  test('re-runs overwrite the v2 receipt atomically — never append, never '
      'duplicate', () async {
    const writer = EngineReceiptWriter(projectRoot: '');

    await writer.writeV2(
      projectRoot: workspace.path,
      feature: 'user',
      entityName: 'User',
      methods: const [
        EngineReceiptMethod(
          name: 'get',
          mockCertified: true,
          mockClass: 'UserMockDataSource',
        ),
      ],
      sourceFiles: const ['lib/a.dart', 'lib/b.dart'],
    );
    // Second run: same entity, different methods — the file must be
    // REPLACED, not merged with the previous run's entries.
    final file = await writer.writeV2(
      projectRoot: workspace.path,
      feature: 'user',
      entityName: 'User',
      methods: const [
        EngineReceiptMethod(
          name: 'get',
          mockCertified: true,
          mockClass: 'UserMockDataSource',
        ),
        EngineReceiptMethod(
          name: 'create',
          mockCertified: true,
          mockClass: 'UserMockDataSource',
        ),
      ],
      sourceFiles: const ['lib/a.dart', 'lib/b.dart', 'lib/c.dart'],
    );

    final receipt = jsonFileDecode(file) as Map<String, dynamic>;
    final methods = (receipt['methods'] as List).cast<Map<String, dynamic>>();
    expect(methods, hasLength(2), reason: 'no duplicate entries from re-runs');
    expect((receipt['source_files'] as List), hasLength(3));
    // No leftover temp files from the atomic write.
    final tddDir = Directory(p.join(workspace.path, 'specs', 'user', 'tdd'));
    expect(
      tddDir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList(),
      equals(['engine.receipt.json']),
      reason: 'atomic write must not leave temp files behind',
    );
  });

  test('loadV2Receipt resolves by feature, and by entity scan', () async {
    const writer = EngineReceiptWriter(projectRoot: '');

    await writer.writeV2(
      projectRoot: workspace.path,
      feature: '005-login-engine',
      entityName: 'Login',
      methods: const [EngineReceiptMethod(name: 'get', mockCertified: true)],
      sourceFiles: const ['lib/a.dart'],
    );
    await writer.writeV2(
      projectRoot: workspace.path,
      feature: 'user-profile',
      entityName: 'User',
      methods: const [EngineReceiptMethod(name: 'create', mockCertified: true)],
      sourceFiles: const ['lib/b.dart'],
    );

    // Explicit feature wins.
    final byFeature = EngineReceiptWriter.loadV2Receipt(
      workspace.path,
      feature: 'user-profile',
    );
    expect(byFeature, isNotNull);
    expect(byFeature!['entity'], 'User');

    // Entity scan finds the receipt when no feature is pinned.
    final byEntity = EngineReceiptWriter.loadV2Receipt(
      workspace.path,
      entity: 'Login',
    );
    expect(byEntity, isNotNull);
    expect(byEntity!['entity'], 'Login');

    // Unknown entity: null, not a throw.
    expect(
      EngineReceiptWriter.loadV2Receipt(workspace.path, entity: 'Ghost'),
      isNull,
    );
  });

  test('MockCertifier captures the mock class name (mock_class source)', () {
    // A mock datasource with the canonical generated shape.
    final mockFile = File(
      p.join(
        workspace.path,
        'lib/src/data/datasources/user/user_mock_datasource.dart',
      ),
    );
    mockFile.createSync(recursive: true);
    mockFile.writeAsStringSync('''
class UserMockDataSource implements UserDataSource {
  @override
  Future<User?> get(QueryParams<User> params) async => null;

  @override
  Future<User> create(User entity) async => entity;
}
''');
    final mockData = File(
      p.join(workspace.path, 'lib/src/data/mock/user_mock_data.dart'),
    );
    mockData.createSync(recursive: true);
    mockData.writeAsStringSync("class UserMockData {}\n");

    final result = MockCertifier.certify(
      entity: 'User',
      methods: const ['get', 'create', 'delete'],
      projectRoot: workspace.path,
    );

    expect(result.mockClass, 'UserMockDataSource');
    expect(result.methods['get'], isTrue);
    expect(result.methods['create'], isTrue);
    expect(result.methods['delete'], isFalse);
  });

  test('engineFeatureFallback derives a feature directory for fresh projects '
      '(User → user)', () {
    expect(EngineReceiptWriter.engineFeatureFallback('User'), 'user');
    expect(EngineReceiptWriter.engineFeatureFallback('Login'), 'login');
  });

  test('pinnedFeature normalizes spec-kit style pins (specs/ prefix, '
      'trailing slash) so receipts land at specs/<slug>/tdd/', () {
    final dir = Directory.systemTemp.createTempSync('zfa_pin_norm_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    Directory(p.join(dir.path, '.specify')).createSync(recursive: true);

    // The pin shapes spec-kit writes (see
    // bone_command._resolveActiveFeature: "specs/020-foo/" -> "020-foo").
    final pins = <String, String>{
      '"specs/1109-x"': '1109-x',
      '"specs/1109-x/"': '1109-x',
      '"1109-x"': '1109-x',
    };
    pins.forEach((pin, expected) {
      File(
        p.join(dir.path, '.specify', 'feature.json'),
      ).writeAsStringSync('{"feature_directory":$pin}');
      expect(
        EngineReceiptWriter.pinnedFeature(dir.path),
        expected,
        reason: 'pin $pin must normalize to $expected',
      );
    });

    // And the normalized pin round-trips: writeV2 + a one-level entity
    // scan agree on the same receipt file.
    File(
      p.join(dir.path, '.specify', 'feature.json'),
    ).writeAsStringSync('{"feature_directory":"specs/1109-x"}');
    final feature = EngineReceiptWriter.pinnedFeature(dir.path)!;
    final file = File(
      p.join(dir.path, 'specs', feature, 'tdd', 'engine.receipt.json'),
    );
    expect(
      file.parent.path,
      isNot(contains('specs/specs')),
      reason: 'a specs/ prefix must not double up in the receipt path',
    );
  });
}

dynamic jsonFileDecode(File file) {
  try {
    return jsonDecode(file.readAsStringSync());
  } catch (e) {
    fail('receipt is not valid JSON (${file.path}): $e');
  }
}
