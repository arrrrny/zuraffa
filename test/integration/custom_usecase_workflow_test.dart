import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  late Directory workspaceDir;
  late String outputDir;

  setUp(() async {
    workspaceDir = await _createWorkspace();
    outputDir = '${workspaceDir.path}/lib/src';
  });

  tearDown(() async {
    if (workspaceDir.existsSync()) {
      await workspaceDir.delete(recursive: true);
    }
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

Future<Directory> _createWorkspace() async {
  final root = Directory.current.path;
  final dir = Directory(
    '$root/.tmp_integration_${DateTime.now().microsecondsSinceEpoch}',
  );
  return dir.create(recursive: true);
}
