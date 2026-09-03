// Fast unit tests for `DiRebinder` — the mock→real binding swap behind
// the same generated interface (spec 913, T001: U4-U7).
//
//   U4: scan finds the GetIt-style mock binding sites for an entity.
//   U5: rebind swaps the mock class symbol for the adapter at binding
//       sites only, drops the mock import, adds the adapter import, and
//       never touches the domain/ interface layer (byte-identical).
//   U6: rebind refuses when no file in lib/ declares the adapter class —
//       realize never auto-generates real implementations.
//   U7: rebind refuses when there is no mock binding to swap (not a
//       mock-era project).
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/di_rebind.dart';

const mockDatasourceDi = '''
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
// GENERATED - the SAME interface the swap must preserve
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
  late Directory temp;
  late String root;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('di_rebind_');
    root = temp.path;
    _write(
      p.join(root, 'lib/src/di/datasources/user_mock_datasource_di.dart'),
      mockDatasourceDi,
    );
    _write(
      p.join(root, 'lib/src/di/repositories/user_repository_di.dart'),
      repositoryDi,
    );
    _write(
      p.join(root, 'lib/src/domain/repositories/user_repository.dart'),
      domainRepository,
    );
    _write(
      p.join(root, 'lib/src/data/datasources/user/user_mock_datasource.dart'),
      mockDatasource,
    );
    _write(
      p.join(root, 'lib/src/data/datasources/user/user_real_adapter.dart'),
      realAdapter,
    );
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  DiRebinder rebinder() => DiRebinder(projectRoot: root);

  test('U4: scan finds the mock binding sites for the entity', () async {
    final sites = await rebinder().scan(entity: 'User');

    expect(sites, isNotEmpty);
    final paths = sites.map((s) => p.normalize(s.file)).toList();
    expect(
      paths,
      contains(
        p.normalize(
          p.join(root, 'lib/src/di/datasources/user_mock_datasource_di.dart'),
        ),
      ),
    );
    expect(
      paths,
      contains(
        p.normalize(
          p.join(root, 'lib/src/di/repositories/user_repository_di.dart'),
        ),
      ),
    );
    final datasourceSite = sites.firstWhere(
      (s) => s.file.endsWith(
        p.normalize('lib/src/di/datasources/user_mock_datasource_di.dart'),
      ),
    );
    expect(
      datasourceSite.occurrences,
      2,
      reason:
          'registerLazySingleton<UserMockDataSource>(() => '
          'UserMockDataSource()) is two references',
    );
  });

  test(
    'U5: rebind swaps symbols, fixes imports, keeps domain untouched',
    () async {
      final domainFile = File(
        p.join(root, 'lib/src/domain/repositories/user_repository.dart'),
      );
      final domainBefore = crypto.sha256
          .convert(await domainFile.readAsBytes())
          .toString();

      final result = await rebinder().rebind(
        entity: 'User',
        adapterClass: 'UserRealAdapter',
      );

      expect(result.mockClass, 'UserMockDataSource');
      expect(result.adapterClass, 'UserRealAdapter');
      expect(p.basename(result.adapterFile), 'user_real_adapter.dart');
      expect(result.sites, hasLength(2));

      final datasourceDi = await File(
        p.join(root, 'lib/src/di/datasources/user_mock_datasource_di.dart'),
      ).readAsString();
      expect(RegExp(r'\bUserMockDataSource\b').hasMatch(datasourceDi), isFalse);
      expect(datasourceDi, contains('registerLazySingleton<UserRealAdapter>('));
      expect(datasourceDi, contains('() => UserRealAdapter())'));
      expect(datasourceDi, isNot(contains('user_mock_datasource.dart')));
      expect(datasourceDi, contains('user_real_adapter.dart'));

      final repoDi = await File(
        p.join(root, 'lib/src/di/repositories/user_repository_di.dart'),
      ).readAsString();
      expect(RegExp(r'\bUserMockDataSource\b').hasMatch(repoDi), isFalse);
      expect(repoDi, contains('getIt<UserRealAdapter>()'));
      expect(repoDi, isNot(contains('user_mock_datasource.dart')));
      expect(repoDi, contains('user_real_adapter.dart'));

      // The interface layer is byte-identical — the swap happened behind the
      // SAME generated interface, never through it.
      final domainAfter = crypto.sha256
          .convert(await domainFile.readAsBytes())
          .toString();
      expect(domainAfter, domainBefore);
      expect(result.interfaceFilesUntouched, isNotEmpty);
      expect(
        result.interfaceFilesUntouched.map((f) => p.basename(f)),
        contains('user_repository.dart'),
      );

      // The mock datasource itself is untouched: unbound, not deleted.
      final mock = await File(
        p.join(root, 'lib/src/data/datasources/user/user_mock_datasource.dart'),
      ).readAsString();
      expect(mock, contains('class UserMockDataSource'));
    },
  );

  test(
    'U6: rebind refuses when the adapter class does not exist in lib/',
    () async {
      expect(
        () => rebinder().rebind(entity: 'User', adapterClass: 'UserFirestore'),
        throwsA(
          isA<DiRebindException>().having(
            (e) => e.message,
            'message',
            allOf(contains('UserFirestore'), contains('never generates')),
          ),
        ),
      );
    },
  );

  test('U7: rebind refuses when there is no mock binding to swap', () async {
    // A project with no mock references anywhere.
    Directory(p.join(root, 'lib/src/di')).deleteSync(recursive: true);
    Directory(
      p.join(root, 'lib/src/data/datasources/user'),
    ).deleteSync(recursive: true);

    expect(
      () => rebinder().rebind(entity: 'User', adapterClass: 'UserRealAdapter'),
      throwsA(
        isA<DiRebindException>().having(
          (e) => e.message,
          'message',
          contains('no mock binding'),
        ),
      ),
    );
  });
}

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}
