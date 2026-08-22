@Tags(['regression', 'slow'])
// Regression test for issue #395:
// "Generator emits wrong import depth / omits imports for referenced entities
//  (provider + service plugins)"
//
// Bug A — provider entity-import depth was 2 (../../) but providers live at
//         lib/src/data/providers/<domain>/ which needs depth 3 (../../../) to
//         reach lib/src/domain/entities/...
// Bug B — `service method` / `provider method` appended (or created) a method
//         referencing value-object --params / --returns types but never emitted
//         the imports for those types, leaving the generated Dart undefined.
//
// The test exercises the EXACT reproduction from the issue body and asserts
// every referenced entity type is imported with the correct relative path.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue_395_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('issue #395 Bug A — provider entity-import depth', () {
    test(
      'provider entity imports use ../../../ (depth 3) for nested provider path',
      () async {
        // Scaffold the entity files the generator's import resolver expects.
        await _scaffoldEntity(outputDir, 'StoreParams');
        await _scaffoldEntity(outputDir, 'ArtifactStoreResult');

        final plugin = ProviderPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        final config = GeneratorConfig(
          name: 'StoreParams',
          service: 'ArtifactService',
          domain: 'artifact',
          paramsType: 'StoreParams',
          returnsType: 'ArtifactStoreResult',
          outputDir: outputDir,
          generateData: true,
        );

        final files = await plugin.generate(config);
        expect(files.length, equals(1));

        final providerFile = File(files.first.path);
        // Provider must live at lib/src/data/providers/<domain>/<domain>_provider.dart
        expect(
          providerFile.path.contains('data/providers/artifact/'),
          isTrue,
          reason: 'provider must be written under data/providers/<domain>/',
        );
        expect(providerFile.existsSync(), isTrue);

        final content = providerFile.readAsStringSync();

        // Bug A: entity imports must use depth 3 (../../../), NOT depth 2 (../../).
        expect(
          content.contains(
            "import '../../../domain/entities/store_params/store_params.dart';",
          ),
          isTrue,
          reason: 'StoreParams entity import must use depth 3 (../../../)',
        );
        expect(
          content.contains(
            "import '../../../domain/entities/artifact_store_result/artifact_store_result.dart';",
          ),
          isTrue,
          reason:
              'ArtifactStoreResult entity import must use depth 3 (../../../)',
        );

        // Negative assertion: the buggy depth-2 form must NOT appear.
        expect(
          content.contains(
            "import '../../domain/entities/store_params/store_params.dart';",
          ),
          isFalse,
          reason:
              'depth-2 (../../) entity import is the bug — must not be emitted',
        );
        expect(
          content.contains(
            "import '../../domain/entities/artifact_store_result/artifact_store_result.dart';",
          ),
          isFalse,
          reason:
              'depth-2 (../../) entity import is the bug — must not be emitted',
        );

        // The service import in the same file already used depth 3 — entity
        // imports must match that depth (this is the exact symptom from the issue).
        expect(
          content.contains(
            "import '../../../domain/services/artifact_service.dart';",
          ),
          isTrue,
          reason: 'service import already used depth 3 — entities must match',
        );
      },
    );
  });

  group('issue #395 Bug B — service method omits param/return imports', () {
    test(
      'appending a method emits imports for its --params/--returns entity types',
      () async {
        // Scaffold the entities referenced by the method's param/return types.
        await _scaffoldEntity(outputDir, 'StoreParams');
        await _scaffoldEntity(outputDir, 'ArtifactStoreResult');

        // 1. Create the service interface first (zfa service create ArtifactService).
        //    Using name='ArtifactService' makes the auto-derived method name
        //    'artifactService' (NOT 'store'), so the subsequent `service method
        //    --name store` appends a genuinely new method.
        final servicePlugin = ServicePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        await servicePlugin.generate(
          GeneratorConfig(
            name: 'ArtifactService',
            service: 'ArtifactService',
            domain: 'artifact',
            paramsType: 'NoParams',
            returnsType: 'void',
            outputDir: outputDir,
          ),
        );

        final serviceFile = File(
          '$outputDir/domain/services/artifact_service.dart',
        );
        expect(serviceFile.existsSync(), isTrue);

        // 2. Append the `store` method with value-object param/return types
        //    (zfa service method --target ArtifactService --name store
        //     --params StoreParams --returns ArtifactStoreResult --type usecase --force).
        final methodCap = servicePlugin.capabilities.firstWhere(
          (c) => c.name == 'method',
        );
        final result = await methodCap.execute({
          'target': 'ArtifactService',
          'name': 'store',
          'params': 'StoreParams',
          'returns': 'ArtifactStoreResult',
          'type': 'usecase',
          'dryRun': false,
          'force': true,
          'verbose': false,
        });

        expect(
          result.success,
          isTrue,
          reason: result.message ?? 'append failed',
        );

        final content = serviceFile.readAsStringSync();

        // The method must be declared with the correct signature.
        expect(
          content.contains(
            'Future<ArtifactStoreResult> store(StoreParams params)',
          ),
          isTrue,
          reason: 'store method must be declared in the service interface',
        );

        // Bug B: imports for StoreParams and ArtifactStoreResult MUST be present.
        // Services live at lib/src/domain/services/, so entity imports use
        // ../entities/<snake>/<snake>.dart (depth 1, no domain/ prefix).
        expect(
          content.contains(
            "import '../entities/store_params/store_params.dart';",
          ),
          isTrue,
          reason: 'StoreParams import must be emitted for the store method',
        );
        expect(
          content.contains(
            "import '../entities/artifact_store_result/artifact_store_result.dart';",
          ),
          isTrue,
          reason:
              'ArtifactStoreResult import must be emitted for the store method',
        );
      },
    );

    test(
      'creating a service via method append emits param/return imports',
      () async {
        // When `zfa service method` targets a service that does NOT exist yet,
        // the builder creates the file. The create path must ALSO emit imports
        // for the --params / --returns entity types (Bug B create-path variant).
        await _scaffoldEntity(outputDir, 'StoreParams');
        await _scaffoldEntity(outputDir, 'ArtifactStoreResult');

        final servicePlugin = ServicePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        final methodCap = servicePlugin.capabilities.firstWhere(
          (c) => c.name == 'method',
        );
        final result = await methodCap.execute({
          'target': 'ArtifactService',
          'name': 'store',
          'params': 'StoreParams',
          'returns': 'ArtifactStoreResult',
          'type': 'usecase',
          'dryRun': false,
          'force': true,
          'verbose': false,
        });

        expect(
          result.success,
          isTrue,
          reason: result.message ?? 'create failed',
        );

        final serviceFile = File(
          '$outputDir/domain/services/artifact_service.dart',
        );
        expect(serviceFile.existsSync(), isTrue);
        final content = serviceFile.readAsStringSync();

        // The store method must be declared (return type + name); the param
        // name casing differs between the create and append code paths and is
        // not part of issue #395, so we only assert on the signature shape.
        expect(
          content.contains('Future<ArtifactStoreResult> store('),
          isTrue,
          reason: 'store method must be declared in the created service',
        );
        // Bug B create-path: imports for the value-object param/return types
        // must be present even when the service file is created fresh.
        expect(
          content.contains(
            "import '../entities/store_params/store_params.dart';",
          ),
          isTrue,
          reason: 'StoreParams import missing on freshly-created service',
        );
        expect(
          content.contains(
            "import '../entities/artifact_store_result/artifact_store_result.dart';",
          ),
          isTrue,
          reason:
              'ArtifactStoreResult import missing on freshly-created service',
        );
      },
    );

    test(
      'FULL FLOW: entities -> service create -> service method -> provider create emits correct imports for the appended method param/return types',
      () async {
        // Exact reproduction of the issue #395 scenario, end to end:
        //   zfa entity create -n StoreParams
        //   zfa entity create -n ArtifactStoreResult
        //   zfa service create ArtifactService
        //   zfa service method --target ArtifactService --name store
        //       --params StoreParams --returns ArtifactStoreResult
        //   zfa provider create --name ArtifactProvider --domain artifact --data
        //
        // After the full flow, BOTH the service file and the provider file
        // must import StoreParams + ArtifactStoreResult with the correct
        // relative depth for their respective output paths.
        await _scaffoldEntity(outputDir, 'StoreParams');
        await _scaffoldEntity(outputDir, 'ArtifactStoreResult');

        final servicePlugin = ServicePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        // 1. zfa service create ArtifactService
        await servicePlugin.generate(
          GeneratorConfig(
            name: 'ArtifactService',
            service: 'ArtifactService',
            domain: 'artifact',
            paramsType: 'NoParams',
            returnsType: 'void',
            outputDir: outputDir,
          ),
        );

        // 2. zfa service method --target ArtifactService --name store
        //    --params StoreParams --returns ArtifactStoreResult --type usecase --force
        final methodCap = servicePlugin.capabilities.firstWhere(
          (c) => c.name == 'method',
        );
        final methodResult = await methodCap.execute({
          'target': 'ArtifactService',
          'name': 'store',
          'params': 'StoreParams',
          'returns': 'ArtifactStoreResult',
          'type': 'usecase',
          'dryRun': false,
          'force': true,
          'verbose': false,
        });
        expect(methodResult.success, isTrue);

        final serviceFile = File(
          '$outputDir/domain/services/artifact_service.dart',
        );
        final serviceContent = serviceFile.readAsStringSync();
        // Bug B (service): appended method imports present at depth 1.
        expect(
          serviceContent.contains(
            "import '../entities/store_params/store_params.dart';",
          ),
          isTrue,
        );
        expect(
          serviceContent.contains(
            "import '../entities/artifact_store_result/artifact_store_result.dart';",
          ),
          isTrue,
        );

        // 3. zfa provider create --name ArtifactProvider --domain artifact --data --force
        final providerPlugin = ProviderPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final providerFiles = await providerPlugin.generate(
          GeneratorConfig(
            name: 'ArtifactStoreResult',
            service: 'ArtifactService',
            domain: 'artifact',
            paramsType: 'StoreParams',
            returnsType: 'ArtifactStoreResult',
            outputDir: outputDir,
            generateData: true,
          ),
        );
        expect(providerFiles.length, equals(1));
        final providerFile = File(providerFiles.first.path);
        expect(providerFile.path.contains('data/providers/artifact/'), isTrue);
        final providerContent = providerFile.readAsStringSync();

        // Bug A (provider): entity imports at depth 3.
        expect(
          providerContent.contains(
            "import '../../../domain/entities/store_params/store_params.dart';",
          ),
          isTrue,
        );
        expect(
          providerContent.contains(
            "import '../../../domain/entities/artifact_store_result/artifact_store_result.dart';",
          ),
          isTrue,
        );
        // Negative: the buggy depth-2 form must NOT appear.
        expect(
          providerContent.contains(
            "import '../../domain/entities/store_params/store_params.dart';",
          ),
          isFalse,
        );
      },
    );
  });
}

/// Scaffolds a minimal entity file at the canonical v5 location
/// `lib/src/domain/entities/<snake>/<snake>.dart` so that
/// `CommonPatterns.entityImports`' filesystem resolver finds it.
Future<void> _scaffoldEntity(String outputDir, String entityName) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory('$outputDir/domain/entities/$snake');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$snake.dart');
  await file.writeAsString('class $entityName {}\n');
}

String _camelToSnake(String input) {
  final out = input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
  return out.startsWith('_') ? out.substring(1) : out;
}
