import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/di/capabilities/verify_capability.dart';

/// SPEC 0974 (issue #974, order 2): `zfa di verify` resolves every
/// `getIt<T>()` / `getIt.registerXxx<T>()` call in generated registrations
/// against classes on disk; a dangling binding fails the verdict (exit 1 at
/// the CLI) and names the class plus the expected file with a `--> fix:`
/// hint — the exact failure #284/#410 fixed by hand, made a gate.
void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_di_verify_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  DiPlugin buildPlugin() =>
      DiPlugin(outputDir: outputDir, options: const GeneratorOptions());

  DiVerifyCapability buildCapability() =>
      DiVerifyCapability(buildPlugin(), projectRoot: projectRoot);

  void writeSource(String relative, String content) {
    final file = File(p.join(projectRoot, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  test('A2 positive: clean registrations verify green', () async {
    // Real class on disk, real import, real registration — the gate must
    // pass and report what it checked.
    writeSource(
      'lib/src/domain/usecases/general/get_product_usecase.dart',
      'class GetProductUseCase {\n'
          '  final ProductRepository repository;\n'
          '  GetProductUseCase(this.repository);\n'
          '}\n',
    );
    writeSource(
      'lib/src/data/repositories/product_repository.dart',
      'abstract class ProductRepository {}\n',
    );
    writeSource(
      'lib/src/di/usecases/get_product_usecase_di.dart',
      "import 'package:get_it/get_it.dart';\n"
          "import '../../domain/usecases/general/get_product_usecase.dart';\n"
          "import '../../data/repositories/product_repository.dart';\n"
          '\n'
          'void registerGetProductUseCase(GetIt getIt) {\n'
          '  getIt.registerFactory<GetProductUseCase>(\n'
          '    () => GetProductUseCase(getIt<ProductRepository>()),\n'
          '  );\n'
          '}\n',
    );

    final result = await buildCapability().execute({});

    expect(result.success, isTrue, reason: 'clean tree must verify green');
    expect(result.files, contains(endsWith('get_product_usecase_di.dart')));
    expect(result.data?['bindings_checked'], greaterThanOrEqualTo(2));
  });

  test(
    'A2 negative: dangling getIt<Missing>() registration fails with fix hint',
    () async {
      // The registration below binds two classes that exist NOWHERE on
      // disk — the #284/#410 failure mode. The verdict must fail and name
      // each class with a `--> fix:` pointing at the expected file.
      writeSource(
        'lib/src/di/usecases/missing_usecase_di.dart',
        "import 'package:get_it/get_it.dart';\n"
            '\n'
            'void registerMissingUseCase(GetIt getIt) {\n'
            '  getIt.registerFactory<MissingUseCase>(\n'
            '    () => MissingUseCase(getIt<MissingRepository>()),\n'
            '  );\n'
            '}\n',
      );

      final result = await buildCapability().execute({});

      expect(
        result.success,
        isFalse,
        reason: 'a dangling binding must fail the verify gate',
      );
      expect(result.message, isNotNull);
      expect(result.message, contains('MissingUseCase'));
      expect(result.message, contains('MissingRepository'));
      expect(result.message, contains('--> fix:'));
      expect(result.message, contains('missing_usecase.dart'));
      expect(result.data?['findings'], isA<List<dynamic>>());
      expect((result.data?['findings'] as List).length, 2);
    },
  );

  test('U2: a missing di/ tree verifies green (nothing to check)', () async {
    final result = await buildCapability().execute({});
    expect(result.success, isTrue);
  });

  test('U3: a dead import URI in a DI file is reported as a finding', () async {
    // #410's uri_does_not_exist mode: the registration's import points at
    // a file that is not on disk, even though the class name would be
    // conventional.
    writeSource(
      'lib/src/di/repositories/order_repository_di.dart',
      "import 'package:get_it/get_it.dart';\n"
          "import '../../data/repositories/order_repository.dart';\n"
          '\n'
          'void registerOrderRepository(GetIt getIt) {\n'
          '  getIt.registerLazySingleton<OrderRepository>(\n'
          '    () => DataOrderRepository(),\n'
          '  );\n'
          '}\n',
    );

    final result = await buildCapability().execute({});

    expect(result.success, isFalse);
    expect(result.message, contains('order_repository.dart'));
    expect(result.message, contains('--> fix:'));
  });

  test('A2 wiring: the verify capability is registered as a di subcommand', () {
    final names = buildPlugin().capabilities.map((c) => c.name).toList();
    expect(names, contains('verify'));
  });
}
