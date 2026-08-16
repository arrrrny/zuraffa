import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// CLI integration test for `zfa xray mock <Entity>` (issue #360).
///
/// Verifies the end-to-end flow: the command scaffolds `@XRayMock`
/// annotations onto generated usecase files and adds the
/// `zuraffa_flutter` import.
void main() {
  late Directory tempDir;
  late String originalWd;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_mock_cli_');
    originalWd = Directory.current.path;
  });

  tearDown(() async {
    try {
      if (Directory(originalWd).existsSync()) {
        Directory.current = originalWd;
      } else {
        Directory.current = Directory.systemTemp.path;
      }
    } catch (_) {
      Directory.current = Directory.systemTemp.path;
    }
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('zfa xray mock CLI integration', () {
    test('scaffolds @XRayMock onto a usecase file', () async {
      Directory.current = tempDir.path;

      // Create the usecases directory so the command proceeds past
      // the directory-exists check, but leave it empty.
      Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'usecases'),
      ).createSync(recursive: true);

      // Scaffold a usecase file.
      final usecaseDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'user',
      );
      final usecaseFile = File(p.join(usecaseDir, 'get_user_usecase.dart'));
      usecaseFile.parent.createSync(recursive: true);
      usecaseFile.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

class GetUserUseCase extends UseCase<User, String> {
  final UserRepository _repository;
  GetUserUseCase(this._repository);

  @override
  Future<User> execute(String params) => _repository.get(params);
}
''');

      // Run the CLI command.
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(['xray', 'mock', 'User']);

      // Verify the annotation was injected.
      final content = usecaseFile.readAsStringSync();
      expect(content, contains('@XRayMock('));
      expect(content, contains("name: 'Valid entry'"));
      expect(
        content,
        contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
      );
    });

    test('prints a helpful message when no usecase files are found', () async {
      Directory.current = tempDir.path;

      // Create the usecases directory so the command proceeds past
      // the directory-exists check, but leave it empty.
      Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'usecases'),
      ).createSync(recursive: true);

      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['xray', 'mock', 'Nonexistent']);

      expect(output, contains('No usecase files found'));
    });

    test('dry-run does not modify files', () async {
      Directory.current = tempDir.path;

      // Create the usecases directory so the command proceeds past
      // the directory-exists check, but leave it empty.
      Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'usecases'),
      ).createSync(recursive: true);

      final usecaseDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'product',
      );
      final usecaseFile = File(p.join(usecaseDir, 'get_product_usecase.dart'));
      usecaseFile.parent.createSync(recursive: true);
      final original = '''
class GetProductUseCase extends UseCase<Product, String> {}
''';
      usecaseFile.writeAsStringSync(original);

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(['xray', 'mock', 'Product', '--dry-run']);

      expect(usecaseFile.readAsStringSync(), equals(original));
    });

    test('zfa xray --help lists the mock subcommand', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final help = await runner.runCapturing(['xray', '--help']);
      expect(help, contains('mock'));
    });

    test('next-step deck hint includes the required --source', () async {
      Directory.current = tempDir.path;

      Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'usecases'),
      ).createSync(recursive: true);

      final usecaseDir = p.join(
        tempDir.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'order',
      );
      final usecaseFile = File(p.join(usecaseDir, 'get_order_usecase.dart'));
      usecaseFile.parent.createSync(recursive: true);
      usecaseFile.writeAsStringSync('''
class GetOrderUseCase extends UseCase<Order, String> {}
''');

      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['xray', 'mock', 'Order']);

      // The printed deck command must be runnable as-is: `zfa xray deck`
      // errors out with "provide --source and/or --yaml" when --source is
      // missing (issue #360 review finding).
      expect(output, contains('zfa xray deck --entity Order --source'));
      expect(
        output,
        contains('lib/src/domain/usecases/order/get_order_usecase.dart'),
      );

      // Execute the hinted deck command verbatim — it must generate the
      // deck + barrel without further flags.
      final deckOutput = await runner.runCapturing([
        'xray',
        'deck',
        '--entity',
        'Order',
        '--source',
        'lib/src/domain/usecases/order/get_order_usecase.dart',
      ]);
      expect(deckOutput, contains('Generated'));
      expect(deckOutput, isNot(contains('provide --source')));
      expect(
        File(
          p.join(tempDir.path, 'lib', 'src', 'xray', 'order_xray_deck.dart'),
        ).existsSync(),
        isTrue,
      );
    });
  });
}
