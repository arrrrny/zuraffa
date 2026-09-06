// RED tests for spec 1193 B-002 — the REAL adapter scaffold service.
//
// The scaffold is the MOCKED→REAL seam: it derives the adapter class
// name from the entity + adapter family, reads the SAME interface from
// the certified mock's declaration, and emits a hand-delta-seam file
// (never pretended generated).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/adapter_scaffold.dart';

const mockWithImplements = '''
import '../../domain/repositories/user_repository.dart';

/// In-memory mock.
class UserMockDataSource implements UserRepository {
  @override
  Future<Map<String, dynamic>?> getById(String id) async => null;

  @override
  Future<List<Map<String, dynamic>>> getAll() async => const [];

  @override
  set email(String value) {}
}
''';

const mockMultiLineSignature = '''
import 'user_repository.dart';

class UserMockDataSource implements UserRepository {
  UserMockDataSource({Map<String, dynamic>? seed}) : _store = {};

  final Map<String, dynamic> _store;

  void _seed() {}

  static const String tag = 'user-mock';

  @override
  Future<Map<String, dynamic>?> getById(
    String id, {
    bool includeDeleted = false,
  }) async =>
      _store[id];
}
''';

const mockNoImplements = '''
class UserMockDataSource {
  Future<Map<String, dynamic>?> getById(String id) async => null;
}
''';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scaffold_test_');
    await Directory(
      p.join(root.path, 'lib', 'src', 'data', 'datasources', 'user'),
    ).create(recursive: true);
    await File(
      p.join(
        root.path,
        'lib',
        'src',
        'data',
        'datasources',
        'user',
        'user_mock_datasource.dart',
      ),
    ).writeAsString(mockWithImplements);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('adapterClassFor naming matrix (entity + family → class)', () {
    expect(
      AdapterScaffold.adapterClassFor('User', 'firestore'),
      'UserFirestoreAdapter',
    );
    expect(AdapterScaffold.adapterClassFor('User', 'Real'), 'UserRealAdapter');
    expect(
      AdapterScaffold.adapterClassFor('User', 'UserRealAdapter'),
      'UserRealAdapter',
    );
    expect(
      AdapterScaffold.adapterClassFor('User', 'UserReal'),
      'UserRealAdapter',
    );
    expect(
      AdapterScaffold.adapterClassFor('Product', 'sqlite'),
      'ProductSqliteAdapter',
    );
  });

  test('plan() reads the SAME interface off the mock declaration', () async {
    final scaffold = AdapterScaffold(projectRoot: root.path);
    final plan = await scaffold.plan(
      entity: 'User',
      adapterName: 'firestore',
      mockFile: p.join(
        root.path,
        'lib',
        'src',
        'data',
        'datasources',
        'user',
        'user_mock_datasource.dart',
      ),
    );

    expect(plan.entity, 'User');
    expect(plan.adapterName, 'firestore');
    expect(plan.adapterClass, 'UserFirestoreAdapter');
    expect(plan.mockClass, 'UserMockDataSource');
    expect(plan.classTail, contains('implements UserRepository'));
    // The scaffold file lives beside the mock it replaces in the binding.
    expect(p.basename(plan.adapterFile), 'user_firestore_adapter.dart');
    expect(
      p.dirname(plan.adapterFile),
      p.dirname(
        p.join(
          root.path,
          'lib',
          'src',
          'data',
          'datasources',
          'user',
          'user_mock_datasource.dart',
        ),
      ),
    );
    // The contract surface: every @override member of the mock.
    expect(
      plan.memberSignatures,
      contains(
        'Future<Map<String, dynamic>?> '
        'getById(String id)',
      ),
    );
    expect(
      plan.memberSignatures,
      contains('Future<List<Map<String, dynamic>>> getAll()'),
    );
    expect(plan.memberSignatures, contains('set email(String value)'));
  });

  test('plan() normalizes multi-line signatures and skips constructor, '
      'private helpers and statics', () async {
    final mockFile = p.join(
      root.path,
      'lib',
      'src',
      'data',
      'datasources',
      'user',
      'user_mock_datasource.dart',
    );
    await File(mockFile).writeAsString(mockMultiLineSignature);

    final plan = await AdapterScaffold(
      projectRoot: root.path,
    ).plan(entity: 'User', adapterName: 'api', mockFile: mockFile);

    expect(
      plan.memberSignatures,
      contains(
        'Future<Map<String, dynamic>?> getById(String id, '
        '{bool includeDeleted = false})',
      ),
    );
    // The constructor, _seed, and the static const are not contract
    // members — the scaffold carries only the interface surface.
    expect(
      plan.memberSignatures.where((s) => s.contains('UserMockDataSource')),
      isEmpty,
    );
    expect(plan.memberSignatures.where((s) => s.startsWith('_')), isEmpty);
    expect(plan.memberSignatures.where((s) => s.contains('tag')), isEmpty);
    // A single @override member: only getById is part of the contract.
    expect(plan.memberSignatures, hasLength(1));
  });

  test(
    'write() emits the hand-delta seam file behind the same interface',
    () async {
      final scaffold = AdapterScaffold(projectRoot: root.path);
      final plan = await scaffold.plan(
        entity: 'User',
        adapterName: 'firestore',
        mockFile: p.join(
          root.path,
          'lib',
          'src',
          'data',
          'datasources',
          'user',
          'user_mock_datasource.dart',
        ),
      );
      final file = await scaffold.write(plan);

      expect(await file.exists(), isTrue);
      final text = await file.readAsString();
      // The seam is NAMED, never silent.
      expect(text, contains('HAND-DELTA SEAM'));
      expect(text, contains('issue #1193'));
      // Behind the SAME interface as the mock.
      expect(
        text,
        contains('class UserFirestoreAdapter implements UserRepository'),
      );
      // The mock's import is carried over (same directory, valid relative).
      expect(
        text,
        contains(
          "import '../../domain/repositories/"
          "user_repository.dart';",
        ),
      );
      // Every contract member present, throwing honestly.
      expect(text, contains('@override'));
      expect(text, contains('getById(String id)'));
      expect(text, contains('UnimplementedError'));
      // NOT generated code — no GENERATED marker, no generation branding.
      expect(text, isNot(contains('GENERATED')));
    },
  );

  test('a mock without an implements clause refuses honestly', () async {
    final mockFile = p.join(
      root.path,
      'lib',
      'src',
      'data',
      'datasources',
      'user',
      'user_mock_datasource.dart',
    );
    await File(mockFile).writeAsString(mockNoImplements);

    await expectLater(
      AdapterScaffold(
        projectRoot: root.path,
      ).plan(entity: 'User', adapterName: 'firestore', mockFile: mockFile),
      throwsA(
        isA<AdapterScaffoldException>().having(
          (e) => e.message,
          'message',
          contains('implements'),
        ),
      ),
    );
  });

  test('a mock file missing the entity class refuses honestly', () async {
    final otherFile = p.join(
      root.path,
      'lib',
      'src',
      'data',
      'datasources',
      'user',
      'other.dart',
    );
    await File(otherFile).writeAsString(mockWithImplements);

    await expectLater(
      AdapterScaffold(
        projectRoot: root.path,
      ).plan(entity: 'Product', adapterName: 'firestore', mockFile: otherFile),
      throwsA(isA<AdapterScaffoldException>()),
    );
  });
}
