// Issue #1889 — a blocked contract whose trace head names a non-entity
// production type (repository, usecase, controller, provider, …) must not be
// handed the `zfa entity create -n <Name>` prerequisite: `zfa tdd wire
// --entity <Name>` can never succeed for a type that is not a domain entity.
//
// The detector has two signals (issue #1889 review):
//
//   1. a known non-entity name suffix, and
//   2. a source file under `lib/` OUTSIDE the entities directory that
//      actually DECLARES the type — a coincidentally named file must not
//      flip the classification.
//
// Fast tier: pure filesystem helpers, no CLI spawn (kernel-cache-safe
// fixture rule).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/hand_surface.dart';

const feature = '004-calculator';

void main() {
  group('isNonEntityProductionType: name suffixes (issue #1889)', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tdd_1889_suffix_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    bool isNonEntity(String name) => HandSurface.isNonEntityProductionType(
      entityName: name,
      projectRoot: root.path,
    );

    for (final name in [
      'UserRepository',
      'AddUserUseCase',
      'UserController',
      'AuthProvider',
      'PaymentService',
      'RemoteDataSource',
      'ApiClient',
      'UserNotifier',
      'LoginCubit',
    ]) {
      test('$name is a non-entity production type', () {
        expect(isNonEntity(name), isTrue);
      });
    }

    test('an entity-like name with no suffix and no file stays an entity', () {
      expect(isNonEntity('Calculator'), isFalse);
      expect(isNonEntity('Order'), isFalse);
    });

    test('a bare suffix name is NOT a match (nothing precedes the suffix)', () {
      expect(isNonEntity('Repository'), isFalse);
      expect(isNonEntity('Service'), isFalse);
    });

    test('blank names are never classified', () {
      expect(isNonEntity(''), isFalse);
      expect(isNonEntity('   '), isFalse);
    });
  });

  group('isNonEntityProductionType: the filesystem signal (issue #1889)', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tdd_1889_file_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    bool isNonEntity(String name) => HandSurface.isNonEntityProductionType(
      entityName: name,
      projectRoot: root.path,
    );

    void seed(String relativePath, String source) {
      File(p.join(root.path, relativePath))
        ..createSync(recursive: true)
        ..writeAsStringSync(source);
    }

    test('a source file DECLARING the type outside entities flips it', () {
      seed(
        'lib/src/domain/invoice/invoice_validator.dart',
        'class InvoiceValidator {\n  bool isValid() => true;\n}\n',
      );

      expect(isNonEntity('InvoiceValidator'), isTrue);
    });

    test('abstract class, mixin and enum declarations all count', () {
      seed(
        'lib/src/domain/ledger/ledger_port.dart',
        'abstract class LedgerPort {\n  void post();\n}\n',
      );
      seed('lib/src/domain/audit/auditable.dart', 'mixin Auditable {}\n');
      seed(
        'lib/src/domain/invoice/invoice_state.dart',
        'enum InvoiceState { draft, sent }\n',
      );

      expect(isNonEntity('LedgerPort'), isTrue);
      expect(isNonEntity('Auditable'), isTrue);
      expect(isNonEntity('InvoiceState'), isTrue);
    });

    test('a coincidentally named file that never declares the type is NOT '
        'a signal', () {
      seed(
        'lib/src/features/orders/order.dart',
        '// Order helpers live here.\nint lineTotal() => 0;\n',
      );

      expect(
        isNonEntity('Order'),
        isFalse,
        reason: 'the basename alone must not suppress the entity-create hint',
      );
    });

    test('a declaration in the entities directory stays an entity', () {
      seed(
        'lib/src/domain/entities/order/order.dart',
        'class Order {\n  const Order();\n}\n',
      );

      expect(isNonEntity('Order'), isFalse);
    });
  });

  group('hintLine: non-entity trace head degrades to hand-implement', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tdd_1889_hint_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    String hintFor(String contract) => HandSurface.hintLine(
      behaviorId: 'contract:A1',
      seamPath: 'lib/tdd/$feature/contract_a1_subject.dart',
      contract: contract,
      projectRoot: root.path,
    );

    test('a repository trace head never prescribes `zfa entity create`', () {
      final hint = hintFor('UserRepository.findById');

      expect(hint, contains('implement the declared contract'));
      expect(hint, contains('by hand'), reason: hint);
      expect(hint, isNot(contains('zfa entity create')), reason: hint);
      expect(hint, isNot(contains('zfa tdd wire')), reason: hint);
    });

    test('the hand-implement wording does not assume a production method '
        'already exists', () {
      final hint = hintFor('UserController.login');

      expect(
        hint,
        isNot(contains('delegating to the existing production method')),
        reason: hint,
      );
    });

    test('an entity-like trace head keeps the entity-create prerequisite', () {
      final hint = hintFor('Calculator.add');

      expect(hint, contains('zfa entity create -n Calculator'), reason: hint);
    });
  });
}
