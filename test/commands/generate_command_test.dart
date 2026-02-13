import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/commands/generate_command.dart';

void main() {
  group('GenerateCommand', () {
    late Directory workspace;
    late String outputDir;
    late String previousCwd;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp(
        'zfa_generate_command_',
      );
      outputDir = '${workspace.path}/lib/src';
      await Directory(outputDir).create(recursive: true);
      await File(
        '${workspace.path}/pubspec.yaml',
      ).writeAsString('name: zuraffa_test');
      previousCwd = Directory.current.path;
      Directory.current = workspace.path;
    });

    tearDown(() async {
      Directory.current = previousCwd;
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('uses routeByDefault when vpc is enabled', () async {
      await File(
        '${workspace.path}/.zfa.json',
      ).writeAsString('{"routeByDefault": true, "diByDefault": false}');

      final result = await GenerateCommand().execute([
        'Product',
        '--methods=get',
        '--vpc',
        '--output',
        outputDir,
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      final hasRoutes = result.files.any(
        (file) => file.path.endsWith('routing/app_routes.dart'),
      );
      expect(hasRoutes, isTrue);
    });

    test('uses gqlByDefault for entity-based generation', () async {
      await File(
        '${workspace.path}/.zfa.json',
      ).writeAsString('{"gqlByDefault": true}');

      final result = await GenerateCommand().execute([
        'Product',
        '--methods=get',
        '--output',
        outputDir,
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      final hasGraphql = result.files.any(
        (file) => file.path.endsWith(
          'data/data_sources/product/graphql/get_product_query.dart',
        ),
      );
      expect(hasGraphql, isTrue);
    });

    test('allows sync usecase without repo or service', () async {
      final result = await GenerateCommand().execute([
        'IsWalkthroughRequire',
        '--type=sync',
        '--domain=customer',
        '--params=Customer',
        '--returns=bool',
        '--output',
        outputDir,
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      final hasUseCase = result.files.any(
        (file) => file.path.endsWith(
          'domain/usecases/customer/is_walkthrough_require_usecase.dart',
        ),
      );
      expect(hasUseCase, isTrue);
      
      // Verify content of the generated usecase
      final useCaseFile = result.files.firstWhere(
        (file) => file.path.endsWith(
          'domain/usecases/customer/is_walkthrough_require_usecase.dart',
        ),
      );
      
      expect(useCaseFile.content, contains('class IsWalkthroughRequireUseCase extends SyncUseCase<bool, Customer>'));
      expect(useCaseFile.content, isNot(contains('Repository')));
      expect(useCaseFile.content, isNot(contains('Service')));
    });
  });
}
