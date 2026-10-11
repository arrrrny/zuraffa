@Tags(['slow'])
library;

import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  group('FeatureCommand', () {
    late Directory workspace;
    late String outputDir;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_feature_command_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_feature_test
environment:
  sdk: ^3.11.0
''');
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'feature scaffold resolves through the same normalized plan as make',
      () async {
        final runner = CliRunner(exitOnCompletion: false);

        final makeOutput = await runner.runCapturing([
          '-C',
          workspace.path,
          'make',
          'Product',
          '--preset=feature',
          '--methods=get,update',
          '--without=test',
          '--plan',
          '--format=json',
          '--output',
          outputDir,
        ]);

        final featureOutput = await runner.runCapturing([
          '-C',
          workspace.path,
          'feature',
          'scaffold',
          'Product',
          '--plan',
          '--format=json',
          '--output',
          outputDir,
        ]);

        final makePlan =
            (jsonDecode(makeOutput) as Map<String, dynamic>)['plan']
                as Map<String, dynamic>;
        final featurePlan =
            (jsonDecode(featureOutput) as Map<String, dynamic>)['plan']
                as Map<String, dynamic>;

        expect(featurePlan, equals(makePlan));
      },
    );

    test('feature forwards feature scope and project root to make', () async {
      final caller = await Directory.systemTemp.createTemp(
        'zfa_feature_command_caller_',
      );
      await File(path.join(caller.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_feature_caller
environment:
  sdk: ^3.11.0
''');

      try {
        final output = await CliRunner(exitOnCompletion: false).runCapturing([
          '-C',
          caller.path,
          'feature',
          'scaffold',
          'Product',
          '--feature=004-login-ui',
          '--project-root=${workspace.path}',
          '--plan',
          '--format=json',
        ]);

        expect((jsonDecode(output) as Map<String, dynamic>)['success'], isTrue);
      } finally {
        await caller.delete(recursive: true);
      }
    });
  });
}
