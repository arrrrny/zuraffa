// Spec 077 / issue #1109 — service trust tier, compile bar (T013,
// behaviors A11/A12, U11).
//
// `test/plugins/service/` carries interface/method-append structural
// coverage. This suite adds the compile-level behavioral bar (FR-011):
// the generated service interface must analyze clean inside a
// self-contained pure-Dart fixture package, with its params/returns
// entity imports backed by stubs at the canonical entity paths.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

import '../../helpers/project_root.dart';

void main() {
  late Directory projectRoot;
  late String libSrc;
  late File serviceFile;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    projectRoot = await Directory.systemTemp.createTemp('zfa_svc_compile_');
    libSrc = p.join(projectRoot.path, 'lib', 'src');

    await File(p.join(projectRoot.path, 'pubspec.yaml')).writeAsString('''
name: service_compile_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');

    // The params/returns types the generated service interface imports
    // (the generator maps them onto canonical entity paths).
    await _write(
      p.join(libSrc, 'domain', 'entities', 'email_params', 'email_params.dart'),
      'class EmailParams {\n'
      '  final String address;\n'
      '  const EmailParams({required this.address});\n'
      '}\n',
    );
    await _write(
      p.join(libSrc, 'domain', 'entities', 'send_result', 'send_result.dart'),
      'class SendResult {\n'
      '  final bool ok;\n'
      '  const SendResult({required this.ok});\n'
      '}\n',
    );

    await ServicePlugin(
      outputDir: libSrc,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'SendEmail',
        methods: const [],
        service: 'Email',
        domain: 'email',
        paramsType: 'EmailParams',
        returnsType: 'SendResult',
        outputDir: libSrc,
      ),
    );
    serviceFile = File(
      p.join(libSrc, 'domain', 'services', 'email_service.dart'),
    );

    final pub = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: projectRoot.path);
    expect(
      pub.exitCode,
      0,
      reason:
          'dart pub get must succeed in the service compile fixture.\n'
          '${pub.stdout}\n${pub.stderr}',
    );
  });

  tearDownAll(() async {
    if (projectRoot.existsSync()) {
      try {
        await projectRoot.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test('structural: the service interface lands with the method signature '
      'and entity imports', () {
    expect(serviceFile.existsSync(), isTrue, reason: 'service file missing');
    final content = serviceFile.readAsStringSync();
    expect(content, contains('abstract class EmailService'));
    expect(
      content,
      contains('Future<SendResult> sendEmail(EmailParams params);'),
    );
    expect(
      content,
      contains('entities/email_params/email_params.dart'),
      reason: 'params type import must point at the canonical entity path',
    );
    expect(
      content,
      contains('entities/send_result/send_result.dart'),
      reason: 'returns type import must point at the canonical entity path',
    );
  });

  test(
    'compile: the generated service interface passes dart analyze (exit 0)',
    () async {
      final result = await Process.run('dart', [
        'analyze',
        '--no-fatal-warnings',
        'lib',
      ], workingDirectory: projectRoot.path);
      final output = '${result.stdout}${result.stderr}';
      expect(
        result.exitCode,
        0,
        reason:
            'generated service interface must analyze clean. Output:\n'
            '$output',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _write(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
