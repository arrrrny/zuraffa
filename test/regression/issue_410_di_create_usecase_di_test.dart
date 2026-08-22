// Regression test for issue #410:
// https://github.com/arrrrny/zuraffa/issues/410
//
// `zfa di create <Entity>` used to build a GeneratorConfig with no `methods`,
// so the DI dispatcher fell into `_generateCustomUseCaseDI` and emitted
// `<entity>_usecase_di.dart` importing `<entity>_usecase.dart` and referencing
// `<Entity>UseCase` — neither of which the usecase plugin ever generates for
// entity-based flows. The fix routes the entity-based case to
// `_generateEntityUseCaseDIFiles` (per-method DI files matching the per-method
// usecases that `zfa usecase create <Entity>` emits).
//
// These tests pin the fix by exercising `CreateDiCapability` directly (the
// `zfa di create` code path) AND by cross-checking against the actual usecase
// files that `CreateUseCaseCapability` emits, so the DI imports resolve to real
// files and real classes.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/di/capabilities/create_di_capability.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/capabilities/create_usecase_capability.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue_410_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('issue #410 — zfa di create <Entity>', () {
    test(
      'entity-based default emits per-method usecase DI (get/update) '
      'referencing real GetXUseCase / UpdateXUseCase classes',
      () async {
        final diPlugin = DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(),
        );
        final capability = CreateDiCapability(diPlugin);

        final result = await capability.execute({'name': 'MyEntity'});

        expect(result.success, isTrue);
        final files =
            (result.data?['generatedFiles'] as List)
                .map((f) => (f as dynamic).path as String)
                .toList();

        // Per-method DI files for the default methods get + update.
        final getDi = File('$outputDir/di/usecases/get_my_entity_usecase_di.dart');
        final updateDi =
            File('$outputDir/di/usecases/update_my_entity_usecase_di.dart');
        expect(getDi.existsSync(), isTrue,
            reason: 'get_my_entity_usecase_di.dart must be generated');
        expect(updateDi.existsSync(), isTrue,
            reason: 'update_my_entity_usecase_di.dart must be generated');

        // The broken unified file must NOT be generated.
        final brokenDi = File('$outputDir/di/usecases/my_entity_usecase_di.dart');
        expect(brokenDi.existsSync(), isFalse,
            reason: 'my_entity_usecase_di.dart referencing non-existent '
                'MyEntityUseCase must NOT be generated for entity-based flows');
        expect(files.any((p) => p.split('/').last == 'my_entity_usecase_di.dart'), isFalse,
            reason: 'the broken unified my_entity_usecase_di.dart must not '
                'appear in the generated files list (per-method files like '
                'get_my_entity_usecase_di.dart are fine)');

        final getContent = getDi.readAsStringSync();
        final updateContent = updateDi.readAsStringSync();

        // Imports must point at the real per-method usecase files that
        // `zfa usecase create MyEntity` emits.
        expect(
          getContent.contains(
            "import '../../domain/usecases/my_entity/get_my_entity_usecase.dart';",
          ),
          isTrue,
        );
        expect(
          updateContent.contains(
            "import '../../domain/usecases/my_entity/update_my_entity_usecase.dart';",
          ),
          isTrue,
        );

        // Registrations must reference the real per-method usecase classes.
        expect(
          getContent.contains('registerLazySingleton<GetMyEntityUseCase>'),
          isTrue,
        );
        expect(
          getContent.contains('() => GetMyEntityUseCase('),
          isTrue,
        );
        expect(
          updateContent.contains('registerLazySingleton<UpdateMyEntityUseCase>'),
          isTrue,
        );
        expect(
          updateContent.contains('() => UpdateMyEntityUseCase('),
          isTrue,
        );

        // And the unified/non-existent type must not be referenced anywhere.
        // Use a word-boundary regex so `GetMyEntityUseCase` / `UpdateMyEntityUseCase`
        // (which contain `MyEntityUseCase` as a substring) do NOT trigger a
        // false positive — only a standalone `MyEntityUseCase` token would.
        final standaloneEntityUseCase = RegExp(r'\bMyEntityUseCase\b');
        expect(
          standaloneEntityUseCase.hasMatch(getContent),
          isFalse,
          reason: 'get_my_entity_usecase_di.dart must not reference the '
              'non-existent unified MyEntityUseCase type',
        );
        expect(
          standaloneEntityUseCase.hasMatch(updateContent),
          isFalse,
          reason: 'update_my_entity_usecase_di.dart must not reference the '
              'non-existent unified MyEntityUseCase type',
        );
      },
    );

    test(
      'DI imports resolve to the actual usecase files emitted by '
      '`zfa usecase create <Entity>`',
      () async {
        // 1. Generate the usecases the way `zfa usecase create MyEntity` does.
        final usecasePlugin = UseCasePlugin(outputDir: outputDir);
        final usecaseCapability = CreateUseCaseCapability(usecasePlugin);
        final usecaseResult = await usecaseCapability.execute({'name': 'Task'});

        expect(usecaseResult.success, isTrue);
        final generatedUsecasePaths =
            (usecaseResult.data?['generatedFiles'] as List)
                .map((f) => (f as dynamic).path as String)
                .where((p) => p.contains('/domain/usecases/'))
                .where((p) => p.endsWith('_usecase.dart'))
                .toList();

        // The usecase plugin emits get_task_usecase.dart + update_task_usecase.dart
        // for the default entity-based flow (matching the DI default methods).
        expect(
          generatedUsecasePaths.any((p) => p.endsWith('get_task_usecase.dart')),
          isTrue,
        );
        expect(
          generatedUsecasePaths.any(
            (p) => p.endsWith('update_task_usecase.dart'),
          ),
          isTrue,
        );

        // 2. Generate the DI the way `zfa di create Task` does.
        final diPlugin = DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(),
        );
        final diCapability = CreateDiCapability(diPlugin);
        final diResult = await diCapability.execute({'name': 'Task'});

        expect(diResult.success, isTrue);

        // 3. Every DI usecase import must resolve to a file the usecase
        //    plugin actually emitted.
        final diUsecaseFiles = Directory('$outputDir/di/usecases')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_usecase_di.dart'))
            .toList();

        expect(diUsecaseFiles, isNotEmpty);

        final importPattern = RegExp(
          r"import '\.\./\.\./domain/usecases/[^']+\.dart';",
        );
        for (final diFile in diUsecaseFiles) {
          final content = diFile.readAsStringSync();
          for (final match in importPattern.allMatches(content)) {
            final importLine = match.group(0)!;
            // Extract the relative path and resolve it against the DI file.
            final relative = importLine
                .replaceAll("import '", '')
                .replaceAll("';", '');
            // Resolve `relative` against the DI file's location the way the
            // Dart compiler would — `Uri.resolve` handles the `../` segments
            // correctly (relative to the file, not its parent directory).
            final resolved = diFile.uri.resolve(relative).toFilePath();
            expect(
              File(resolved).existsSync(),
              isTrue,
              reason: 'DI import "$importLine" in ${diFile.path} must resolve '
                  'to a real usecase file emitted by `zfa usecase create`.',
            );
          }
        }
      },
    );

    test('explicit --methods overrides the default', () async {
      final diPlugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final capability = CreateDiCapability(diPlugin);

      await capability.execute({
        'name': 'Document',
        'methods': ['get', 'create', 'delete'],
      });

      final getDi = File(
        '$outputDir/di/usecases/get_document_usecase_di.dart',
      );
      final createDi = File(
        '$outputDir/di/usecases/create_document_usecase_di.dart',
      );
      final deleteDi = File(
        '$outputDir/di/usecases/delete_document_usecase_di.dart',
      );
      final updateDi = File(
        '$outputDir/di/usecases/update_document_usecase_di.dart',
      );

      expect(getDi.existsSync(), isTrue);
      expect(createDi.existsSync(), isTrue);
      expect(deleteDi.existsSync(), isTrue);
      expect(updateDi.existsSync(), isFalse,
          reason: 'update was not requested via --methods');

      expect(
        createDi.readAsStringSync().contains('CreateDocumentUseCase'),
        isTrue,
      );
      expect(
        deleteDi.readAsStringSync().contains('DeleteDocumentUseCase'),
        isTrue,
      );
    });

    test(
      'custom-usecase path (--no-entity) still emits the unified '
      '<name>_usecase_di.dart referencing <Name>UseCase',
      () async {
        final diPlugin = DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(),
        );
        final capability = CreateDiCapability(diPlugin);

        // Hand-written single usecase (e.g. `zfa di create Login --no-entity`).
        await capability.execute({'name': 'Login', 'noEntity': true});

        final unifiedDi = File('$outputDir/di/usecases/login_usecase_di.dart');
        expect(unifiedDi.existsSync(), isTrue,
            reason: 'custom-usecase path must still emit the unified DI file');

        final content = unifiedDi.readAsStringSync();
        expect(
          content.contains("import '../../domain/usecases/login/login_usecase.dart';"),
          isTrue,
        );
        expect(content.contains('registerLazySingleton<LoginUseCase>'), isTrue);
        expect(content.contains('() => LoginUseCase()'), isTrue);
      },
    );

    test(
      'custom-usecase path (--repo) still emits unified DI '
      '(preserved backward-compat)',
      () async {
        final diPlugin = DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(),
        );
        final capability = CreateDiCapability(diPlugin);

        await capability.execute({
          'name': 'Profile',
          'domain': 'auth',
          'repo': 'AuthRepository',
        });

        final unifiedDi =
            File('$outputDir/di/usecases/profile_usecase_di.dart');
        expect(unifiedDi.existsSync(), isTrue);

        final content = unifiedDi.readAsStringSync();
        expect(content.contains('ProfileUseCase'), isTrue);
        expect(
          content.contains("import '../../domain/repositories/auth_repository.dart';"),
          isTrue,
        );
      },
    );
  });
}
