import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('presentation_only_workflow');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'generates only presentation layer when requested',
    timeout: Timeout(Duration(minutes: 5)),
    () async {
      // Simulating: zfa make Profile view presenter controller state (with mock/di enabled in zfa.json)
      final config = GeneratorConfig(
        name: 'Profile',
        methods: const [], // Non-entity based
        generateVpcs: true,
        generateView: true,
        generatePresenter: true,
        generateController: true,
        generateState: true,
        generateMock: true, // Enabled by default in zfa.json
        generateDi: true,   // Enabled by default in zfa.json
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

      // Check Presentation layer exists
      expect(File('$outputDir/presentation/pages/profile/profile_view.dart').existsSync(), isTrue);
      expect(File('$outputDir/presentation/pages/profile/profile_presenter.dart').existsSync(), isTrue);
      expect(File('$outputDir/presentation/pages/profile/profile_controller.dart').existsSync(), isTrue);
      expect(File('$outputDir/presentation/pages/profile/profile_state.dart').existsSync(), isTrue);

      // Check Domain/Data layer DOES NOT exist
      expect(File('$outputDir/domain/repositories/profile_repository.dart').existsSync(), isFalse);
      expect(File('$outputDir/data/repositories/data_profile_repository.dart').existsSync(), isFalse);
      expect(File('$outputDir/data/datasources/profile/profile_datasource.dart').existsSync(), isFalse);
      expect(File('$outputDir/data/datasources/profile/profile_remote_datasource.dart').existsSync(), isFalse);
      
      // Check Mock files DO NOT exist (since no data layer requested)
      expect(File('$outputDir/data/mock/profile_mock_data.dart').existsSync(), isFalse);
      expect(File('$outputDir/data/datasources/profile/profile_mock_datasource.dart').existsSync(), isFalse);

      // Check DI files for Domain/Data layer DO NOT exist
      expect(File('$outputDir/di/usecases/profile_usecase_di.dart').existsSync(), isFalse);
      expect(File('$outputDir/di/repositories/profile_repository_di.dart').existsSync(), isFalse);
      expect(File('$outputDir/di/datasources/profile_remote_datasource_di.dart').existsSync(), isFalse);
      expect(File('$outputDir/di/datasources/profile_mock_datasource_di.dart').existsSync(), isFalse);
    },
  );
}
