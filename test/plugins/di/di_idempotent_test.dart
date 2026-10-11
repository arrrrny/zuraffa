// Issue #1102 — idempotent DI (pilot lesson 4): generated registrations
// are unregister-first, and resetDependencies() is generated alongside
// setupDependencies() (full regeneration, merge path, day-zero
// bootstrap).
library;

import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/builders/registration_builder.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/cli/writers/tdd/app_module_writer.dart';

void main() {
  group('issue #1102 — RegistrationBuilder unregister-first guards', () {
    const builder = RegistrationBuilder();

    test('registeredTypes emits the guard before the registration', () {
      final src = builder.buildRegistrationFile(
        functionName: 'registerProductRemoteDataSource',
        imports: const ['package:zuraffa/zuraffa.dart'],
        registeredTypes: const ['ProductRemoteDataSource'],
        body: Block(
          (b) => b
            ..statements.add(
              refer('getIt')
                  .property('registerLazySingleton<ProductRemoteDataSource>')
                  .call([
                    Method(
                      (m) => m
                        ..lambda = true
                        ..body = refer('ProductRemoteDataSource').call([]).code,
                    ).closure,
                  ])
                  .statement,
            ),
        ),
      );
      expect(
        src,
        contains('if (getIt.isRegistered<ProductRemoteDataSource>())'),
      );
      expect(src, contains('getIt.unregister<ProductRemoteDataSource>();'));
    });

    test('multiple registeredTypes get one guard each, registration order', () {
      final src = builder.buildRegistrationFile(
        functionName: 'registerAllTheThings',
        imports: const [],
        registeredTypes: const ['A', 'B'],
        body: Block((b) => b..statements.add(Code(''))),
      );
      expect(src, contains('getIt.isRegistered<A>()'));
      expect(src, contains('getIt.isRegistered<B>()'));
    });

    test('no registeredTypes -> no guard tokens (byte-compat callers)', () {
      final src = builder.buildRegistrationFile(
        functionName: 'registerPlain',
        imports: const [],
        body: Block((b) => b..statements.add(Code(''))),
      );
      expect(src, isNot(contains('isRegistered')));
    });
  });

  group('issue #1102 — resetDependencies alongside setupDependencies', () {
    const builder = RegistrationBuilder();

    test('buildIndexFile emits resetDependencies(GetIt getIt)', () {
      final src = builder.buildIndexFile(
        functionName: 'setupDependencies',
        registrations: [
          refer('registerAllUseCases').call([refer('getIt')]).statement,
        ],
      );
      expect(src, contains('void setupDependencies(GetIt getIt)'));
      expect(src, contains('void resetDependencies(GetIt getIt)'));
      expect(src, contains('getIt.reset();'));
    });

    test('the day-zero bootstrap barrel ships resetDependencies', () {
      final src = const BootstrapDiIndexWriter().render();
      expect(src, contains('void setupDependencies(GetIt getIt)'));
      expect(src, contains('void resetDependencies(GetIt getIt)'));
      expect(src, contains('getIt.reset();'));
    });
  });

  group('issue #1102 — DiPlugin emission sites carry the guards', () {
    late Directory tempDir;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_di_1102_');
      outputDir = Directory('${tempDir.path}/lib/src').path;
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'datasource + repository registrations are unregister-first',
      () async {
        final plugin = DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: false,
            verbose: false,
          ),
        );
        await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            generateData: true,
            generateDi: true,
            outputDir: outputDir,
          ),
        );

        final remoteFile = File(
          '$outputDir/di/datasources/product_remote_datasource_di.dart',
        );
        final repoFile = File(
          '$outputDir/di/repositories/product_repository_di.dart',
        );
        expect(remoteFile.existsSync(), isTrue);
        expect(repoFile.existsSync(), isTrue);

        final remoteSrc = remoteFile.readAsStringSync();
        expect(
          remoteSrc,
          contains('if (getIt.isRegistered<ProductRemoteDataSource>())'),
        );
        expect(
          remoteSrc,
          contains('getIt.unregister<ProductRemoteDataSource>();'),
        );
        // The registration itself still lands after the guard.
        expect(remoteSrc, contains('ProductRemoteDataSource('));

        final repoSrc = repoFile.readAsStringSync();
        // The repository registers the DOMAIN interface
        // (registerLazySingleton<ProductRepository> with a
        // DataProductRepository factory) — the guard matches the
        // REGISTERED type, which is what get_it refuses twice.
        expect(
          repoSrc,
          contains('if (getIt.isRegistered<ProductRepository>())'),
        );
        expect(repoSrc, contains('getIt.unregister<ProductRepository>();'));
      },
    );

    test('the main DI index regenerates with resetDependencies', () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: false,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateData: true,
        generateDi: true,
        outputDir: outputDir,
      );
      await plugin.generate(config);

      final indexFile = File('$outputDir/di/index.dart');
      expect(indexFile.existsSync(), isTrue);
      final src = indexFile.readAsStringSync();
      expect(src, contains('void setupDependencies(GetIt getIt)'));
      expect(src, contains('void resetDependencies(GetIt getIt)'));

      // Second generation: the file exists and !force takes the
      // AST-merge path — a pre-1102 index (resetDependencies
      // stripped to simulate an older zfa) must gain the hook.
      indexFile.writeAsStringSync(
        src.replaceFirst(
          RegExp(r'/// Test-lane hook[\s\S]*$'),
          '// END GENERATED',
        ),
      );
      await plugin.generate(config);
      final merged = indexFile.readAsStringSync();
      expect(merged, contains('void resetDependencies(GetIt getIt)'));
      expect(merged, contains('getIt.reset();'));
      // And the merge is idempotent: a third run injects nothing new.
      final third = indexFile.readAsStringSync();
      await plugin.generate(config);
      expect(
        indexFile.readAsStringSync().replaceAll(RegExp(r'\s'), ''),
        third.replaceAll(RegExp(r'\s'), ''),
      );
    });
  });
}
