// Transported from the pure-Dart `zuraffa` core package (issue #431).
//
// Integration coverage for the presentation-only workflow. The core's
// `test/integration/presentation_only_workflow_test.dart` runs against a
// *pure-Dart* fixture, where VPC generation is now correctly skipped
// (Constitution VII: Engine Purity, see #420) — so the view/presenter/
// controller assertions were transported into THIS package where the fixture
// pubspec declares `flutter:` and the VPC generators actually run. The core
// keeps the pure-Dart behaviour: the state file IS generated, no domain/data
// layer files leak into a presentation-only request, and VPC output is
// skipped.
//
// Simulates: zfa make Profile view presenter controller state
// (with mock/di enabled in zfa.json)
//
// See: test/integration/presentation_only_workflow_test.dart (core),
// https://github.com/arrrrny/zuraffa/issues/431.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import 'vpc_test_utils.dart';

void main() {
  late VpcWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('presentation_only_vpc_');
    await writeFlutterPubspec(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'generates only presentation layer when requested (Flutter target)',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final config = GeneratorConfig(
        name: 'Profile',
        methods: const [], // Non-entity based
        generateVpcs: true,
        generateView: true,
        generatePresenter: true,
        generateController: true,
        generateState: true,
        generateMock: true, // Enabled by default in zfa.json
        generateDi: true, // Enabled by default in zfa.json
        generateUseCase: false,
        generateRepository: false,
        generateDataSource: false,
        generateData: false,
        outputDir: outputDir,
      );

      final generator = CodeGenerator(
        config: config,
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
        disabledPluginIds: {'usecase', 'repository', 'datasource', 'provider'},
      );

      final result = await generator.generate();

      expect(result.success, isTrue);

      // Check Presentation layer exists — the fixture pubspec declares
      // `flutter:`, so the VPC generators run (they are skipped only for
      // pure-Dart targets, see #420).
      expect(
        File(
          '$outputDir/presentation/pages/profile/profile_view.dart',
        ).existsSync(),
        isTrue,
        reason: 'profile_view.dart should be generated for a Flutter target',
      );
      expect(
        File(
          '$outputDir/presentation/pages/profile/profile_presenter.dart',
        ).existsSync(),
        isTrue,
        reason:
            'profile_presenter.dart should be generated for a Flutter target',
      );
      expect(
        File(
          '$outputDir/presentation/pages/profile/profile_controller.dart',
        ).existsSync(),
        isTrue,
        reason:
            'profile_controller.dart should be generated for a Flutter target',
      );
      expect(
        File(
          '$outputDir/presentation/pages/profile/profile_state.dart',
        ).existsSync(),
        isTrue,
        reason: 'profile_state.dart should be generated',
      );

      // Check Domain/Data layer DOES NOT exist
      expect(
        File(
          '$outputDir/domain/repositories/profile_repository.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          '$outputDir/data/repositories/data_profile_repository.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          '$outputDir/data/datasources/profile/profile_datasource.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          '$outputDir/data/datasources/profile/profile_remote_datasource.dart',
        ).existsSync(),
        isFalse,
      );

      // Check Mock files DO NOT exist (since no data layer requested)
      expect(
        File('$outputDir/data/mock/profile_mock_data.dart').existsSync(),
        isFalse,
      );
      expect(
        File(
          '$outputDir/data/datasources/profile/profile_mock_datasource.dart',
        ).existsSync(),
        isFalse,
      );

      // Check DI files for Domain/Data layer DO NOT exist
      expect(
        File('$outputDir/di/usecases/profile_usecase_di.dart').existsSync(),
        isFalse,
      );
      expect(
        File(
          '$outputDir/di/repositories/profile_repository_di.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          '$outputDir/di/datasources/profile_remote_datasource_di.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          '$outputDir/di/datasources/profile_mock_datasource_di.dart',
        ).existsSync(),
        isFalse,
      );
    },
  );
}
