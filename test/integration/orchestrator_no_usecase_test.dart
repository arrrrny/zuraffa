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
    workspace = await createWorkspace('orchestrator_no_usecase_workflow');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'generates presenter with multiple usecases directly when usecase plugin is disabled',
    timeout: Timeout(Duration(minutes: 5)),
    () async {
      // Create some existing usecases in different domains
      final checkPermissionDir = Directory(
        path.join(outputDir, 'domain', 'usecases', 'auth'),
      );
      checkPermissionDir.createSync(recursive: true);
      File(
        path.join(checkPermissionDir.path, 'check_permission_usecase.dart'),
      ).writeAsStringSync('class CheckPermissionUseCase {}');

      final requestPermissionDir = Directory(
        path.join(outputDir, 'domain', 'usecases', 'permissions'),
      );
      requestPermissionDir.createSync(recursive: true);
      File(
        path.join(requestPermissionDir.path, 'request_permission_usecase.dart'),
      ).writeAsStringSync('class RequestPermissionUseCase {}');

      // Simulating: zfa make Permissions view presenter controller state di --usecases=CheckPermission,RequestPermission,OpenAppSettings
      final config = GeneratorConfig(
        name: 'Permissions',
        usecases: const [
          'CheckPermission',
          'RequestPermission',
          'OpenAppSettings',
        ],
        generateUseCase: false, // Usecase plugin NOT requested
        generateVpcs: true,
        generateView: true,
        generatePresenter: true,
        generateController: true,
        generateState: true,
        generateDi: true,
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
        disabledPluginIds: {'usecase'},
      );

      final result = await generator.generate();

      expect(result.success, isTrue);

      final presenterPath =
          '$outputDir/presentation/pages/permissions/permissions_presenter.dart';
      final presenterFile = File(presenterPath);
      expect(presenterFile.existsSync(), isTrue);

      final presenterContent = presenterFile.readAsStringSync();

      // Should NOT contain PermissionsUseCase
      expect(presenterContent, isNot(contains('PermissionsUseCase')));

      // Should contain the 3 individual usecases
      expect(presenterContent, contains('CheckPermissionUseCase'));
      expect(presenterContent, contains('RequestPermissionUseCase'));
      expect(presenterContent, contains('OpenAppSettingsUseCase'));

      // Should contain fields for each
      expect(
        presenterContent,
        contains('late final CheckPermissionUseCase _checkPermission;'),
      );
      expect(
        presenterContent,
        contains('late final RequestPermissionUseCase _requestPermission;'),
      );
      expect(
        presenterContent,
        contains('late final OpenAppSettingsUseCase _openAppSettings;'),
      );

      // Should contain methods for each (assuming custom usecase pattern)
      expect(
        presenterContent,
        contains('Future<Result<void, AppFailure>> checkPermission'),
      );
      expect(
        presenterContent,
        contains('Future<Result<void, AppFailure>> requestPermission'),
      );
      expect(
        presenterContent,
        contains('Future<Result<void, AppFailure>> openAppSettings'),
      );

      // Should contain imports for each
      expect(
        presenterContent,
        contains(
          'import \'../../../domain/usecases/auth/check_permission_usecase.dart\';',
        ),
      );
      expect(
        presenterContent,
        contains(
          'import \'../../../domain/usecases/permissions/request_permission_usecase.dart\';',
        ),
      );
      // Default domain for OpenAppSettings since it wasn't found
      expect(
        presenterContent,
        contains(
          'import \'../../../domain/usecases/permissions/open_app_settings_usecase.dart\';',
        ),
      );

      final controllerPath =
          '$outputDir/presentation/pages/permissions/permissions_controller.dart';
      final controllerFile = File(controllerPath);
      expect(controllerFile.existsSync(), isTrue);

      final controllerContent = controllerFile.readAsStringSync();

      // Controller should also have methods for each
      expect(controllerContent, contains('Future<void> checkPermission'));
      expect(controllerContent, contains('Future<void> requestPermission'));
      expect(controllerContent, contains('Future<void> openAppSettings'));

      // Domain usecase file should NOT exist
      expect(
        File(
          '$outputDir/domain/usecases/permissions/permissions_usecase.dart',
        ).existsSync(),
        isFalse,
      );
    },
  );
}
