import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// CLI integration test for `zfa xray mock <Entity>` (issue #360).
///
/// Verifies the end-to-end flow: the command scaffolds `@XRayMock`
/// annotations onto generated usecase files and adds the
/// `zuraffa_flutter` import.
///
/// The command is run as a subprocess with an explicit `workingDirectory`
/// (mirroring the MakeCommand #307 identity-contract group) so no
/// process-global `Directory.current` mutation leaks back into the parent
/// test process. This keeps the test hermetic under parallel `dart test`
/// (issue #506).
import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(() async {
    await initZfaSourceBin();
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_mock_cli_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group(
    'zfa xray mock CLI integration',
    timeout: const Timeout(Duration(minutes: 2)),
    () {
    test('scaffolds @XRayMock onto a usecase file', () async {
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
      await runZfaSource(
        ['xray', 'mock', 'User', '--root', tempDir.path],
        workingDirectory: zfaProjectRoot,
      );

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
      // Create the usecases directory so the command proceeds past
      // the directory-exists check, but leave it empty.
      Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'usecases'),
      ).createSync(recursive: true);

      final result = await runZfaSource([
        'xray',
        'mock',
        'Nonexistent',
        '--root',
        tempDir.path,
      ], workingDirectory: zfaProjectRoot);

      expect(combinedOutput(result), contains('No usecase files found'));
    });

    test('dry-run does not modify files', () async {
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

      final result = await runZfaSource([
        'xray',
        'mock',
        'Product',
        '--root',
        tempDir.path,
        '--dry-run',
      ], workingDirectory: zfaProjectRoot);

      expect(result.exitCode, 0, reason: 'dry-run must exit successfully');
      expect(usecaseFile.readAsStringSync(), equals(original));
    });

    test('zfa xray --help lists the mock subcommand', () async {
      final result = await runZfaSource(
        ['xray', '--help'],
        workingDirectory: zfaProjectRoot,
      );
      expect(combinedOutput(result), contains('mock'));
    });

    test('next-step deck hint includes the required --source', () async {
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

      final output = await runZfaSource([
        'xray',
        'mock',
        'Order',
        '--root',
        tempDir.path,
      ], workingDirectory: zfaProjectRoot);

      final outputStr = combinedOutput(output);

      // The printed deck command must be runnable as-is: `zfa xray deck`
      // errors out with "provide --source and/or --yaml" when --source is
      // missing (issue #360 review finding).
      expect(outputStr, contains('zfa xray deck --entity Order --source'));
      expect(
        outputStr,
        contains('lib/src/domain/usecases/order/get_order_usecase.dart'),
      );

      // Execute the hinted deck command verbatim — it must generate the
      // deck + barrel without further flags.
      final deckResult = await runZfaSource([
        'xray',
        'deck',
        '--entity',
        'Order',
        '--source',
        'lib/src/domain/usecases/order/get_order_usecase.dart',
        '--root',
        tempDir.path,
      ], workingDirectory: zfaProjectRoot);

      final deckOutput = combinedOutput(deckResult);
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
