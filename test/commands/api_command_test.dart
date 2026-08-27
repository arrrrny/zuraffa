import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  group('ApiCommand', () {
    late Directory workspace;
    late String previousCwd;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_api_command_');
      // UseCases are discovered under lib/src/domain/usecases/<entity>/
      // and the bridge is written under lib/src/api/bridges/ — both
      // relative to the current working directory.
      final usecaseDir = Directory(
        path.join(workspace.path, 'lib', 'src', 'domain', 'usecases', 'product'),
      );
      await usecaseDir.create(recursive: true);
      await File(path.join(usecaseDir.path, 'get_product_usecase.dart'))
          .writeAsString('''
class GetProductUseCase extends UseCase<Product, NoParams> {
  const GetProductUseCase();
}
''');

      // Entity directory so the generated bridge can resolve param imports.
      final entityDir = Directory(
        path.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');

      previousCwd = Directory.current.path;
      Directory.current = workspace.path;
    });

    tearDown(() async {
      // Restore CWD to a known-valid directory before deleting the workspace
      // so other test files that call findProjectRoot() at startup don't
      // inherit a deleted temp path as their CWD.
      try {
        if (Directory(previousCwd).existsSync()) {
          Directory.current = previousCwd;
        } else {
          Directory.current = Directory.systemTemp.path;
        }
      } catch (_) {
        try {
          Directory.current = Directory.systemTemp.path;
        } catch (_) {}
      }
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('zfa api <Entity> generates the bridge and does not throw',
        () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['api', 'Product']);

      // Must not be a UsageException / unknown-subcommand failure.
      expect(output, isNot(contains('Could not find a subcommand')));
      expect(output, isNot(contains('Usage:')));

      final bridge = File(
        path.join(
          workspace.path,
          'lib',
          'src',
          'api',
          'bridges',
          'product_api_bridge.dart',
        ),
      );
      expect(bridge.existsSync(), isTrue,
          reason: 'expected lib/src/api/bridges/product_api_bridge.dart');
    });

    test('zfa api <Entity> --domain <name> still generates the bridge',
        () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'api',
        'Product',
        '--domain',
        'billing',
      ]);

      expect(output, isNot(contains('Could not find a subcommand')));

      final bridge = File(
        path.join(
          workspace.path,
          'lib',
          'src',
          'api',
          'bridges',
          'product_api_bridge.dart',
        ),
      );
      expect(bridge.existsSync(), isTrue,
          reason: 'expected bridge with --domain flag');
    });
  });
}
