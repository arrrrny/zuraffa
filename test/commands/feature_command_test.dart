@Tags(['slow'])
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import '../helpers/project_root.dart';

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
      Directory.current = workspace.path;
    });

    tearDown(() async {
      try {
        Directory.current = await findProjectRoot();
      } catch (_) {}
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'feature scaffold resolves through the same normalized plan as make',
      () async {
        final runner = CliRunner(exitOnCompletion: false);

        final makeOutput = await runner.runCapturing([
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
  });
}
