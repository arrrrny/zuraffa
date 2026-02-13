import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/commands/test_command.dart';

void main() {
  group('TestCommand', () {
    late Directory workspace;
    late String outputDir;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_test_command_');
      outputDir = '${workspace.path}/lib/src';
      await Directory(outputDir).create(recursive: true);
      await File(
        '${workspace.path}/pubspec.yaml',
      ).writeAsString('name: zuraffa_test');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    Future<void> writeUseCase(
      String domain,
      String fileName,
      String content,
    ) async {
      final file = File(
        '${workspace.path}/lib/src/domain/usecases/$domain/$fileName',
      );
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    test('generates custom test with repository dependency', () async {
      await writeUseCase('account', 'fetch_user_usecase.dart', '''
import 'package:zuraffa/zuraffa.dart';

class FetchUserUseCase extends UseCase<User, NoParams> {
  final UserRepository _repository;

  FetchUserUseCase(this._repository);

  @override
  Future<User> execute(NoParams params, CancelToken? cancelToken) async {
    throw UnimplementedError();
  }
}
''');

      final result = await TestCommand().execute([
        'FetchUser',
        '--output',
        outputDir,
        '--domain',
        'account',
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      expect(result.files.length, equals(1));
      final content = result.files.first.content ?? '';
      expect(content, contains('class MockUserRepository'));
      expect(content, contains('FetchUserUseCase'));
    });

    test('generates stream test with service dependency', () async {
      await writeUseCase('orders', 'watch_orders_usecase.dart', '''
import 'package:zuraffa/zuraffa.dart';

class WatchOrdersUseCase extends StreamUseCase<Order, NoParams> {
  final OrderService _service;

  WatchOrdersUseCase(this._service);

  @override
  Stream<Order> execute(NoParams params, CancelToken? cancelToken) {
    return const Stream.empty();
  }
}
''');

      final result = await TestCommand().execute([
        'WatchOrders',
        '--output',
        outputDir,
        '--domain',
        'orders',
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      expect(result.files.length, equals(1));
      final content = result.files.first.content ?? '';
      expect(content, contains('class MockOrderService'));
      expect(content, contains('should emit values from stream'));
    });

    test('generates orchestrator test with composed usecases', () async {
      await writeUseCase('checkout', 'process_checkout_usecase.dart', '''
import 'package:zuraffa/zuraffa.dart';

class ProcessCheckoutUseCase extends UseCase<Order, CheckoutParams> {
  final ValidateCartUseCase _validateCart;
  final CreateOrderUseCase _createOrder;

  ProcessCheckoutUseCase(this._validateCart, this._createOrder);

  @override
  Future<Order> execute(
    CheckoutParams params,
    CancelToken? cancelToken,
  ) async {
    throw UnimplementedError();
  }
}
''');

      final result = await TestCommand().execute([
        'ProcessCheckout',
        '--output',
        outputDir,
        '--domain',
        'checkout',
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      expect(result.files.length, equals(1));
      final content = result.files.first.content ?? '';
      expect(content, contains('class MockValidateCartUseCase'));
      expect(content, contains('class MockCreateOrderUseCase'));
      expect(content, contains('should orchestrate all usecases'));
    });
  });
}
