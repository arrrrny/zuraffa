import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';
import 'package:zuraffa/src/utils/string_utils.dart';

/// Spec 980 / FR-006 — `_parseUseCaseFile` uses the analyzer package
/// instead of regexes, behavior-neutral on the existing fixtures.
///
/// The expected values below are the snapshot of the REGEX-era behavior
/// (test_plugin.dart `_parseUseCaseFile` before the analyzer swap): every
/// fixture must resolve to exactly the same repo/service/usecases/flavor
/// after the rewrite — that is the parity proof.
void main() {
  late Directory workspace;
  late String outputDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_ucparse_');
    outputDir = path.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
  });

  tearDown(() async {
    if (workspace.existsSync()) await workspace.delete(recursive: true);
  });

  Future<void> writeUseCase(
    String domain,
    String fileName,
    String source,
  ) async {
    final file = File(
      path.join(outputDir, 'domain', 'usecases', domain, fileName),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(source);
  }

  group('dependency extraction parity (U13, U15)', () {
    test('repository usecase resolves repo + plain flavor', () async {
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

      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final config = await plugin.buildConfigFromUseCase(
        'FetchUser',
        outputDir,
        'account',
        dryRun: false,
        force: false,
        verbose: false,
      );

      expect(config, isNotNull);
      expect(config!.repo, 'UserRepository');
      expect(config.service, isNull);
      expect(config.useCaseType, 'usecase');
      expect(config.usecases, isEmpty);
    });

    test('service usecase resolves service + stream flavor', () async {
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

      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final config = await plugin.buildConfigFromUseCase(
        'WatchOrders',
        outputDir,
        'orders',
        dryRun: false,
        force: false,
        verbose: false,
      );

      expect(config, isNotNull);
      expect(config!.service, 'OrderService');
      expect(config.repo, isNull);
      expect(config.useCaseType, 'stream');
    });

    test('orchestrator usecase resolves composed usecases (U15)', () async {
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

      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final config = await plugin.buildConfigFromUseCase(
        'ProcessCheckout',
        outputDir,
        'checkout',
        dryRun: false,
        force: false,
        verbose: false,
      );

      expect(config, isNotNull);
      // isOrchestrator feeds `usecases` into the generated config.
      expect(config!.usecases, ['ValidateCart', 'CreateOrder']);
      expect(config.repo, isNull);
      expect(config.service, isNull);
    });

    test(
      'mixed repo + service usecase resolves both, not orchestrator',
      () async {
        await writeUseCase('billing', 'charge_billing_usecase.dart', '''
import 'package:zuraffa/zuraffa.dart';

class ChargeBillingUseCase extends UseCase<Billing, NoParams> {
  final BillingRepository _repository;
  final BillingService _service;

  ChargeBillingUseCase(this._repository, this._service);

  @override
  Future<Billing> execute(NoParams params, CancelToken? cancelToken) async {
    throw UnimplementedError();
  }
}
''');

        final plugin = TestPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(),
        );
        final config = await plugin.buildConfigFromUseCase(
          'ChargeBilling',
          outputDir,
          'billing',
          dryRun: false,
          force: false,
          verbose: false,
        );

        expect(config, isNotNull);
        expect(config!.repo, 'BillingRepository');
        expect(config.service, 'BillingService');
        // Not an orchestrator: repos/services present -> no composed usecases.
        expect(config.usecases, isEmpty);
      },
    );
  });

  group('flavor resolution parity (U14)', () {
    Future<String> resolveFlavor(String className, String superclass) async {
      final snake = StringUtils.camelToSnake(
        className.replaceAll('UseCase', ''),
      );
      await writeUseCase('flavors', '${snake}_usecase.dart', '''
class $className extends $superclass<Thing, NoParams> {
  final ThingRepository _repository;

  $className(this._repository);
}
''');
      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final config = await plugin.buildConfigFromUseCase(
        className.replaceAll('UseCase', ''),
        outputDir,
        'flavors',
        dryRun: false,
        force: false,
        verbose: false,
      );
      expect(config, isNotNull, reason: '$className must be found');
      return config!.useCaseType;
    }

    test('maps every canonical superclass to its flavor', () async {
      expect(await resolveFlavor('PlainThingUseCase', 'UseCase'), 'usecase');
      expect(
        await resolveFlavor('StreamThingUseCase', 'StreamUseCase'),
        'stream',
      );
      expect(await resolveFlavor('SyncThingUseCase', 'SyncUseCase'), 'sync');
      expect(
        await resolveFlavor('BackgroundThingUseCase', 'BackgroundUseCase'),
        'background',
      );
      expect(
        await resolveFlavor('OsThingUseCase', 'OsBackgroundTaskUseCase'),
        'os_background',
      );
    });
  });

  group('analyzer precision (improvement over regex)', () {
    test('a local variable named like a repo is NOT a dependency', () async {
      // The old regex (`final\s+(\w+)Repository\s+(\w+)`) matched local
      // variables and any textual occurrence. The analyzer must only read
      // actual class fields.
      await writeUseCase('local', 'scoped_lookup_usecase.dart', '''
class ScopedLookupUseCase extends UseCase<Thing, NoParams> {
  ScopedLookupUseCase();

  @override
  Future<Thing> execute(NoParams params, CancelToken? cancelToken) async {
    final PhantomRepository trap = _makePhantom();
    throw UnimplementedError('\$trap');
  }

  dynamic _makePhantom() => null;
}
''');

      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final config = await plugin.buildConfigFromUseCase(
        'ScopedLookup',
        outputDir,
        'local',
        dryRun: false,
        force: false,
        verbose: false,
      );

      expect(config, isNotNull);
      expect(
        config!.repo,
        isNull,
        reason: 'local variables are not dependencies',
      );
      expect(config.useCaseType, 'usecase');
    });
  });

  group('no regex usecase parsing remains (A11)', () {
    test('test_plugin.dart contains no RegExp usage', () {
      final source = File(
        path.joinAll([
          ...path.split(Directory.current.path),
          'lib',
          'src',
          'plugins',
          'test',
          'test_plugin.dart',
        ]),
      ).readAsStringSync();

      expect(
        source,
        isNot(contains('RegExp(')),
        reason:
            'usecase parsing must go through the analyzer package '
            '(spec 980: kill regex parsing)',
      );
    });
  });
}
