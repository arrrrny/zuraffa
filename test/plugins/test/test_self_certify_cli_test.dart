import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../../helpers/project_root.dart';
import '../../helpers/run_zfa_source.dart';

/// Spec 980 / FR-001 — the REAL CLI exit-code proof.
///
/// Drives the actual `zfa` executable (AOT-precompiled, the same hermetic
/// subprocess pattern as the proof-command tests) against a sandbox whose
/// generated test cannot compile (the sandbox resolves no zuraffa
/// dependency). The machine verdict line must be printed and the process
/// must exit non-zero — never a silent success.
void main() {
  late Directory workspace;

  setUpAll(() async {
    await initZfaSourceBin();
  });

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_cert_cli_');
    await Directory(
      path.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: cert_cli_app
environment:
  sdk: ^3.11.0
''');
    final usecase = File(
      path.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'account',
        'fetch_user_usecase.dart',
      ),
    );
    await usecase.parent.create(recursive: true);
    await usecase.writeAsString('''
import 'package:zuraffa/zuraffa.dart';

class FetchUserUseCase extends UseCase<User, NoParams> {
  final UserRepository _repository;

  FetchUserUseCase(this._repository);

  @override
  Future<User> execute(NoParams params, CancelToken? cancelToken) async {
    throw UnimplementedError();
  }
}
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) await workspace.delete(recursive: true);
  });

  test(
    'A1 (real CLI) — non-compiling generated test exits 1 with the verdict line',
    () async {
      final result = await runZfaSource(
        ['-C', workspace.path, 'test', 'create', '--name', 'FetchUser'],
        workingDirectory: zfaProjectRoot,
        timeout: const Duration(seconds: 110),
      );

      final output = combinedOutput(result);

      expect(
        result.exitCode,
        equals(1),
        reason:
            'non-compiling generated tests must exit non-zero '
            '(exitCode=${result.exitCode})\noutput:\n$output',
      );
      expect(
        output,
        contains('compile=fail'),
        reason: 'the machine verdict line must be printed\noutput:\n$output',
      );
      expect(
        output,
        contains('test: entity=FetchUser'),
        reason: 'the verdict names the entity\noutput:\n$output',
      );
      // The per-method receipt is still written: proof for the next run.
      expect(
        File(
          path.join(workspace.path, '.zfa', 'receipts', 'test-fetch_user.json'),
        ).existsSync(),
        isTrue,
        reason: 'receipt written even when certification fails',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
