import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

@Timeout(Duration(minutes: 2))
void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('custom_usecase_workflow');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('generates custom usecase with service and provider', () async {
    final config = GeneratorConfig(
      name: 'SendEmail',
      methods: const [],
      service: 'Email',
      domain: 'email',
      paramsType: 'EmailParams',
      returnsType: 'SendResult',
      generateData: true,
    );
    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final result = await generator.generate();

    expect(result.success, isTrue);
    expect(
      File('$outputDir/domain/services/email_service.dart').existsSync(),
      isTrue,
    );
    expect(
      File('$outputDir/data/providers/email/email_provider.dart').existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/domain/usecases/email/send_email_usecase.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
