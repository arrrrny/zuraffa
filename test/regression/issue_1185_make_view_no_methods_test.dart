@Tags(['regression'])
library;

// Regression test for issue #1185.
//
// `zfa make Product --with=vpc --view --skin --no-entity` (no `--methods`)
// crashed deep in generation with `Bad state: No element` — the bare
// `Bad state` from an unguarded `List.first` in
// `PresenterPlugin._buildMethods` (presenter_plugin.dart, custom-method
// branch). Adding an explicit `--methods=get` made the same run succeed,
// which is why the shape went unnoticed: the AGENTS.md canonical examples
// never show `--with=vpc --view` WITHOUT `--methods`.
//
// Root cause: with `--no-entity` and no method set, `GeneratorConfig`
// resolves to `isCustomUseCase == true` (`methods.isEmpty || noEntity`),
// but `_buildUseCaseInfo` legitimately produces NO usecase infos for that
// shape (the synthetic custom-usecase branch requires `!config.noEntity`,
// and entity-based usecases are skipped for no-entity runs). The custom
// branch in `_buildMethods` then called `useCases.first` on the empty list.
//
// Fix (two layers, mirroring the issue's "Expected"):
//  1. Guard the unguarded `first` — the custom-method branch is skipped
//     when there is no usecase info to build from, so a bare `--no-entity`
//     VPC run emits the same scaffold the issue's own working example
//     (`--methods=get --no-entity` → "✅ Done.") emits today.
//  2. Default the method set for entity-backed view-bearing runs the way
//     spec 1002 did for the engine preset (`MakeCommand._engineDefaultMethods`),
//     applied after plan resolution so it can never change the resolved
//     plugin chain.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#1185 — vpc/view run without --methods must not crash', () {
    late Directory workspace;

    setUpAll(() async {
      await initZfaSourceBin();
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('issue_1185_');
      // Flutter flavor marker — presenters extend the zuraffa_flutter
      // `Presenter` base class; a pure-Dart pubspec makes the presenter
      // plugin skip generation entirely (Constitution VII), which would
      // hide the crash path under test.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_1185_test_app
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
    });

    tearDown(() async {
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup; a leaked temp dir must not fail the run.
      }
    });

    test(
      'plugin level: presenter with no methods + no-entity does not throw',
      () async {
        final plugin = PresenterPlugin(
          outputDir: workspace.path,
          options: const GeneratorOptions(dryRun: false, force: true),
        );

        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            // The exact crashing shape: no method set, entity suppressed.
            methods: const [],
            noEntity: true,
            generatePresenter: true,
            outputDir: workspace.path,
          ),
        );

        // The bare scaffold IS the accepted success shape — the issue's
        // own working example (`--methods=get --no-entity`) emits exactly
        // one method-less presenter for this config.
        expect(files, hasLength(1));
        expect(
          files.single.path,
          contains('presentation/pages/product/product_presenter.dart'),
        );

        final content = File(files.single.path).readAsStringSync();
        expect(content, contains('class ProductPresenter extends Presenter {'));
      },
    );

    test('plugin level: entity-backed custom usecase path still emits the '
        'synthetic <Name>UseCase method (guard must not over-skip)', () async {
      final plugin = PresenterPlugin(
        outputDir: workspace.path,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      final files = await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const [],
          // Entity present (noEntity: false) + no methods → the
          // synthetic custom-usecase branch MUST still fire.
          noEntity: false,
          generatePresenter: true,
          outputDir: workspace.path,
        ),
      );

      expect(files, hasLength(1));
      final content = File(files.single.path).readAsStringSync();
      expect(content, contains('ProductUseCase'));
    });

    test(
      'CLI level: zfa make --with=vpc --view --skin --no-entity succeeds',
      () async {
        final result = await runZfaSource([
          '-C',
          workspace.path,
          'make',
          'Product',
          '--with=vpc',
          '--view',
          '--skin',
          '--no-entity',
        ], workingDirectory: zfaProjectRoot);

        final stdout = result.stdout.toString();
        final stderr = result.stderr.toString();

        expect(
          result.exitCode,
          equals(0),
          reason:
              'issue #1185: the bare no-methods VPC run crashed with '
              '"Bad state: No element" (exit 1). It must succeed like the '
              'issue\'s own --methods=get --no-entity example.\n'
              'stdout: $stdout\nstderr: $stderr',
        );
        expect(stdout, isNot(contains('Bad state: No element')));
        expect(
          File(
            p.join(
              workspace.path,
              'lib/src/presentation/pages/product/product_presenter.dart',
            ),
          ).existsSync(),
          isTrue,
          reason: 'the presenter must be emitted for the bare VPC run',
        );
        expect(
          File(
            p.join(
              workspace.path,
              'lib/src/presentation/pages/product/product_view.dart',
            ),
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(
              workspace.path,
              'lib/src/presentation/pages/product/product_controller.dart',
            ),
          ).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'CLI level: --methods=get --no-entity keeps the bare presenter shape',
      () async {
        final result = await runZfaSource([
          '-C',
          workspace.path,
          'make',
          'Product',
          '--with=vpc',
          '--view',
          '--skin',
          '--methods=get',
          '--no-entity',
        ], workingDirectory: zfaProjectRoot);

        expect(result.exitCode, equals(0));

        final presenter = File(
          p.join(
            workspace.path,
            'lib/src/presentation/pages/product/product_presenter.dart',
          ),
        ).readAsStringSync();
        // No entity-based usecase info exists for --no-entity runs, so the
        // presenter stays method-less — the pre-#1185 success shape.
        expect(presenter, isNot(contains('getProduct')));
      },
    );

    test('CLI level: entity-backed vpc run without --methods defaults to the '
        'view method set (get/update/toggle)', () async {
      // Entity-backed run: the entity file must exist.
      final entityDir = Directory(
        p.join(workspace.path, 'lib/src/domain/entities/product'),
      );
      entityDir.createSync(recursive: true);
      File(p.join(entityDir.path, 'product.dart')).writeAsStringSync('''
class Product {
  final String id;

  const Product({required this.id});
}
''');

      final result = await runZfaSource([
        '-C',
        workspace.path,
        'make',
        'Product',
        '--with=vpc',
        '--view',
        '--skin',
      ], workingDirectory: zfaProjectRoot);

      final stdout = result.stdout.toString();
      expect(
        result.exitCode,
        equals(0),
        reason: 'stdout: $stdout\nstderr: ${result.stderr}',
      );

      final presenter = File(
        p.join(
          workspace.path,
          'lib/src/presentation/pages/product/product_presenter.dart',
        ),
      ).readAsStringSync();
      // The view-bearing default method set (same set the presenter and
      // controller plugins already apply when no method set reaches them).
      expect(presenter, contains('getProduct'));
      expect(presenter, contains('updateProduct'));
      expect(presenter, contains('toggleProduct'));
    });
  });
}
