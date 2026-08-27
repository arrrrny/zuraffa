import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_mock_scaffolder.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_mock_scaffolder_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('XRayMockScaffolder', () {
    test('injects @XRayMock onto a get usecase', () {
      final usecasesDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'user',
      );
      final file = File(p.join(usecasesDir, 'get_user_usecase.dart'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

class GetUserUseCase extends UseCase<User, String> {
  final UserRepository _repository;
  GetUserUseCase(this._repository);

  @override
  Future<User> execute(String params) => _repository.get(params);
}
''');

      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'User');

      expect(results, hasLength(1));
      expect(results.first.injected, isTrue);
      expect(results.first.importAdded, isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('@XRayMock('));
      expect(content, contains("name: 'Valid entry'"));
      expect(content, contains("type: 'valid'"));
      expect(
        content,
        contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
      );
      // The annotation must be above the class declaration.
      final annotIdx = content.indexOf('@XRayMock(');
      final classIdx = content.indexOf('class GetUserUseCase');
      expect(annotIdx, greaterThanOrEqualTo(0));
      expect(classIdx, greaterThan(annotIdx));
    });

    test('skips files that already have @XRayMock without --force', () {
      final usecasesDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'product',
      );
      final file = File(p.join(usecasesDir, 'get_product_usecase.dart'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('''
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

@XRayMock(name: 'Existing', payload: 'test', type: 'valid')
class GetProductUseCase extends UseCase<Product, String> {
  @override
  Future<Product> execute(String params) async => Product();
}
''');

      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'Product');

      expect(results, hasLength(1));
      expect(results.first.injected, isFalse);
      expect(results.first.message, contains('already has @XRayMock'));
    });

    test('overwrites existing @XRayMock with --force', () {
      final usecasesDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'order',
      );
      final file = File(p.join(usecasesDir, 'create_order_usecase.dart'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('''
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

@XRayMock(name: 'Old', payload: 'old', type: 'valid')
class CreateOrderUseCase extends UseCase<Order, String> {
  @override
  Future<Order> execute(String params) async => Order();
}
''');

      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'Order', force: true);

      expect(results, hasLength(1));
      expect(results.first.injected, isTrue);

      final content = file.readAsStringSync();
      expect(content, contains("name: 'Create sample'"));
      expect(content, isNot(contains("name: 'Old'")));
    });

    test('dry-run does not write files', () {
      final usecasesDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'item',
      );
      final file = File(p.join(usecasesDir, 'get_item_usecase.dart'));
      file.parent.createSync(recursive: true);
      final original = '''
class GetItemUseCase extends UseCase<Item, String> {
  @override
  Future<Item> execute(String params) async => Item();
}
''';
      file.writeAsStringSync(original);

      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'Item', dryRun: true);

      expect(results, hasLength(1));
      expect(results.first.injected, isTrue);
      expect(results.first.message, contains('would inject'));

      // File unchanged.
      expect(file.readAsStringSync(), equals(original));
    });

    test('returns empty list when no usecase files match', () {
      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'Nonexistent');
      expect(results, isEmpty);
    });

    test('filters by --domain', () {
      // Create files in two domains.
      for (final domain in ['users', 'products']) {
        final dir = p.join(
          tempDir.path,
          'lib',
          'src',
          'domain',
          'usecases',
          domain,
        );
        Directory(dir).createSync(recursive: true);
        File(p.join(dir, 'get_user_usecase.dart')).writeAsStringSync(
          'class GetUserUseCase extends UseCase<User, String> {}',
        );
      }

      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'User', domain: 'users');

      expect(results, hasLength(1));
      expect(
        results.first.path,
        contains(p.join('usecases', 'users', 'get_user_usecase.dart')),
      );
    });

    test('does not add duplicate import when already present', () {
      final usecasesDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'account',
      );
      final file = File(p.join(usecasesDir, 'get_account_usecase.dart'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('''
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class GetAccountUseCase extends UseCase<Account, String> {
  @override
  Future<Account> execute(String params) async => Account();
}
''');

      final scaffolder = XRayMockScaffolder(projectRoot: tempDir.path);
      final results = scaffolder.scaffold(entityName: 'Account');

      expect(results.first.importAdded, isFalse);
      final content = file.readAsStringSync();
      // Only one import line.
      expect(
        'package:zuraffa_flutter/zuraffa_flutter.dart'
            .allMatches(content)
            .length,
        equals(1),
      );
    });
  });
}
