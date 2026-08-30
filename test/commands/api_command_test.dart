@Tags(['slow'])
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import '../helpers/project_root.dart';

void main() {
  group('ApiCommand', () {
    late Directory workspace;
    late String zfaSourceBin;
    // Handle to the child `dart` process so tearDown can guarantee it is
    // terminated before the workspace is deleted.
    Process? zfaProcess;

    // Runs zfa from SOURCE (never a stale compiled binary) as a subprocess
    // with an explicit workingDirectory. The child process owns its own CWD,
    // so this test never mutates the parent isolate's `Directory.current` —
    // which is what previously let the generated bridge leak into the repo
    // root when this file ran alongside others in a combined suite.
    Future<ProcessResult> runZfa(List<String> args) async {
      final process = await Process.start('dart', [
        zfaSourceBin,
        ...args,
      ], workingDirectory: workspace.path);
      zfaProcess = process;

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      return ProcessResult(process.pid, exitCode, stdout, stderr);
    }

    setUpAll(() async {
      final projectRoot = await findProjectRoot();
      zfaSourceBin = path.join(projectRoot, 'bin', 'zfa.dart');
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_api_command_');

      // UseCases are discovered under lib/src/domain/usecases/<entity>/
      // and the bridge is written under lib/src/api/bridges/ — both
      // relative to the child process's working directory (the workspace).
      final usecaseDir = Directory(
        path.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'usecases',
          'product',
        ),
      );
      await usecaseDir.create(recursive: true);
      await File(
        path.join(usecaseDir.path, 'get_product_usecase.dart'),
      ).writeAsString('''
class GetProductUseCase extends UseCase<Product, NoParams> {
  const GetProductUseCase();
}
''');

      // Entity directory so the generated bridge can resolve param imports.
      final entityDir = Directory(
        path.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'product',
        ),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});

  Map<String, dynamic> toJson() => {'id': id};
}
''');
    });

    tearDown(() async {
      // Terminate any still-running subprocess BEFORE deleting its workspace
      // (a timed-out child may still be holding the directory).
      if (zfaProcess != null) {
        try {
          zfaProcess!.kill(ProcessSignal.sigkill);
        } catch (_) {
          // Already exited — ignore.
        }
        await zfaProcess!.exitCode
            .timeout(const Duration(seconds: 10))
            .catchError((_) => -1);
        zfaProcess = null;
      }
      if (workspace.existsSync()) {
        try {
          await workspace.delete(recursive: true);
        } on PathNotFoundException {
          // A late-exiting child may still be removing files concurrently;
          // tolerate ENOENT during recursive enumeration.
        }
      }
    });

    test(
      'zfa api <Entity> generates the bridge and does not throw',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa(['api', 'Product']);
        expect(
          result.exitCode,
          equals(0),
          reason: 'stderr: ${result.stderr}\nstdout: ${result.stdout}',
        );

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
        expect(
          bridge.existsSync(),
          isTrue,
          reason: 'expected lib/src/api/bridges/product_api_bridge.dart',
        );
      },
    );

    test(
      'zfa api <Entity> --domain <name> still generates the bridge',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa(['api', 'Product', '--domain', 'billing']);
        expect(
          result.exitCode,
          equals(0),
          reason: 'stderr: ${result.stderr}\nstdout: ${result.stdout}',
        );

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
        expect(
          bridge.existsSync(),
          isTrue,
          reason: 'expected bridge with --domain flag',
        );
      },
    );
  });
}
