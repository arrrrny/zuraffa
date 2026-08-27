@Tags(['integration', 'slow'])
library;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../helpers/vpc_test_utils.dart';

void main() {
  late VpcWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('orchestrator_no_usecase_workflow');
    await writeFlutterPubspec(workspace);
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

      // This workspace is a *pure-Dart* fixture (the pubspec written by
      // `writePubspec` declares no `flutter:` SDK), so per Constitution VII
      // (Engine Purity) the presenter/controller generators correctly SKIP
      // output for a pure-Dart target (see #420): both artifacts depend on
      // `zuraffa_flutter`, which is unavailable here. The presenter's
      // multi-usecase wiring (fields, methods, and imports for
      // CheckPermission / RequestPermission / OpenAppSettings) and the
      // controller's methods are verified in the `zuraffa_flutter` package
      // — see issue #431.
      final presenterPath =
          '$outputDir/presentation/pages/permissions/permissions_presenter.dart';
      final presenterFile = File(presenterPath);
      expect(
        presenterFile.existsSync(),
        isFalse,
        reason:
            'pure-Dart target must NOT generate a Flutter presenter '
            '(Constitution VII: Engine Purity)',
      );

      final controllerPath =
          '$outputDir/presentation/pages/permissions/permissions_controller.dart';
      final controllerFile = File(controllerPath);
      expect(
        controllerFile.existsSync(),
        isFalse,
        reason:
            'pure-Dart target must NOT generate a Flutter controller '
            '(Constitution VII: Engine Purity)',
      );

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
