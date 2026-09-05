import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_contract_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/tier2_firestore_adapter_writer.dart';

/// Spec 1009 (issue #1009) — the Tier-2 Firestore-shaped adapter writer:
/// the differential gate's subject must implement the SAME interface as
/// the Tier-1 mock (mixins included), route through the fake
/// FirebaseFirestore, and swap into the committed contract test with
/// byte-identical pins.
void main() {
  late Directory tempDir;
  late String outputDir;

  const loginEntity = '''
import 'package:zuraffa/mock.dart';

class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});

  Login copyWith({String? id, String? username}) => Login(
        id: id ?? this.id,
        username: username ?? this.username,
      );

  Login copyWithField(Field<Login, dynamic> field, dynamic value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'username':
        return copyWith(username: value as String);
      default:
        throw ArgumentError.value(field.name, 'field');
    }
  }
}

class LoginPatch {
  Login applyTo(Login entity) => entity;
}
''';

  const loginInterface = '''
import 'package:zuraffa/zuraffa.dart';
import '../../../domain/entities/login/login.dart';

abstract class LoginDataSource with Loggable, FailureHandler {
  Future<Login> get(QueryParams<Login> params);
  Future<Login> update(UpdateParams<String, LoginPatch> params);
  Future<Login> toggle(ToggleParams<String, Field<Login, dynamic>> params);
}
''';

  const committedTest = '''
// GENERATED - DO NOT EDIT
import 'package:test/test.dart';
import 'package:zuraffa/mock.dart';
import '../../../lib/src/domain/entities/login/login.dart';
import '../../../lib/src/data/datasources/login/login_datasource.dart';
import '../../../lib/src/data/datasources/login/login_mock_datasource.dart';
import '../../../lib/src/data/mock/login_mock_data.dart';

void main() {
  final LoginDataSource dataSource =
      LoginMockDataSource();

  group('Login mock contract (spec 1001)', () {
    test('get: exists, returns Future<Login>', () async {
      final Future<Login> Function(QueryParams<Login>) get\$ =
          dataSource.get;
      final value = await dataSource.get(QueryParams<Login>());
      expect(value, isA<Login>());
    });
  });
}
''';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_tier2_writer_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'login'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'login.dart')).writeAsString(loginEntity);
    final dsDir = Directory(p.join(outputDir, 'data', 'datasources', 'login'));
    await dsDir.create(recursive: true);
    await File(
      p.join(dsDir.path, 'login_datasource.dart'),
    ).writeAsString(loginInterface);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<List<ContractMethod>> contract() async {
    final methods = await const MockContractTestWriter().extractContract(
      'Login',
      outputDir,
    );
    if (methods == null) {
      throw StateError('contract extraction failed in the test fixture');
    }
    return methods;
  }

  group('adapter rendering', () {
    test('implements the interface with the framework mixins', () async {
      final source = const Tier2FirestoreAdapterWriter().render(
        entityName: 'Login',
        methods: await contract(),
        outputDir: outputDir,
      );

      expect(
        source,
        contains(
          'class LoginTier2MockProvider with Loggable, FailureHandler '
          'implements LoginDataSource {',
        ),
        reason:
            'the interface mixes in Loggable + FailureHandler — the '
            'adapter must satisfy them the same way the Tier-1 mock does',
      );
      expect(source, contains("import 'dart:async';"));
      expect(
        source,
        contains("import '../../mock/login_mock_data.dart';"),
        reason: 'seeded from the same mock data the Tier-1 mock serves',
      );
      expect(source, contains('class FakeFirebaseFirestore'));
      expect(source, contains('FakeCollectionReference'));
      expect(source, contains('FakeDocumentReference'));
      expect(source, contains('FakeDocumentSnapshot'));
    });

    test(
      'every interface method is overridden and routed through the fake',
      () async {
        final source = const Tier2FirestoreAdapterWriter().render(
          entityName: 'Login',
          methods: await contract(),
          outputDir: outputDir,
        );

        expect(
          source,
          contains('Future<Login> get(QueryParams<Login> params) async =>'),
        );
        expect(
          source,
          contains(
            'Future<Login> update(UpdateParams<String, LoginPatch> params) '
            'async =>',
          ),
        );
        expect(
          source,
          contains(
            'Future<Login> toggle('
            'ToggleParams<String, Field<Login, dynamic>> params) async =>',
          ),
        );
        expect(source, contains('_firstRecord();'));
        expect(
          source,
          contains('_firestore.collection(_collectionPath)'),
          reason: 'the adapter routes through the fake Firestore',
        );
        // Only the helpers the method set uses are emitted.
        expect(source, contains('Future<Login> _firstRecord()'));
        expect(
          source,
          isNot(contains('_watchAll()')),
          reason: 'no watch method in the contract → helper not emitted',
        );
      },
    );

    test('the seed derives doc ids from the entity id field', () async {
      final source = const Tier2FirestoreAdapterWriter().render(
        entityName: 'Login',
        methods: await contract(),
        outputDir: outputDir,
      );
      expect(source, contains("record.id: record"));
      expect(source, contains("{'id': id}"));
    });

    test(
      '--diverge injects a wrong-typed return on the named method only',
      () async {
        final methods = await contract();
        final source = const Tier2FirestoreAdapterWriter().render(
          entityName: 'Login',
          methods: methods,
          outputDir: outputDir,
          divergeMethod: 'get',
        );

        expect(source, contains('_divergentValue as Login'));
        expect(
          source,
          contains(
            'Future<Login> update(UpdateParams<String, LoginPatch> params) '
            'async =>\n      _firstRecord();',
          ),
          reason: 'the non-divergent methods keep their conforming bodies',
        );
      },
    );
  });

  group('subject swap (the committed contract test)', () {
    test('swaps the import + the single construction site', () {
      final swapped = Tier2FirestoreAdapterWriter.swapSubject(
        entityName: 'Login',
        contractTestSource: committedTest,
      );

      expect(
        swapped,
        contains(
          "import '../../../lib/src/data/datasources/login/"
          "login_tier2_firestore_mock_provider.dart';",
        ),
      );
      expect(swapped, isNot(contains('login_mock_datasource.dart')));
      expect(swapped, contains('LoginTier2MockProvider()'));
      expect(swapped, isNot(contains('LoginMockDataSource()')));
      // The pins stay byte-identical: only the subject changed.
      expect(
        swapped,
        contains('final Future<Login> Function(QueryParams<Login>) get\$ ='),
      );
      expect(swapped, contains('dataSource.get;'));
    });

    test('refuses when the construction site count is not exactly one', () {
      expect(
        () => Tier2FirestoreAdapterWriter.swapSubject(
          entityName: 'Login',
          // Zero construction sites: another subject entirely.
          contractTestSource:
              'void main() { final dataSource = OtherSubject(); }',
        ),
        throwsStateError,
        reason: 'zero construction sites — refuse to guess',
      );
      expect(
        () => Tier2FirestoreAdapterWriter.swapSubject(
          entityName: 'Login',
          contractTestSource: committedTest.replaceFirst(
            'LoginMockDataSource()',
            'LoginMockDataSource(); final b = LoginMockDataSource()',
          ),
        ),
        throwsStateError,
        reason: 'two construction sites — refuse to guess',
      );
    });
  });

  test('the adapter path mirrors the datasource layout', () {
    expect(
      Tier2FirestoreAdapterWriter.adapterRelPath('Login'),
      'lib/src/data/datasources/login/'
      'login_tier2_firestore_mock_provider.dart',
    );
    expect(
      Tier2FirestoreAdapterWriter.providerClassName('Login'),
      'LoginTier2MockProvider',
    );
  });
}
