@Tags(['slow'])
// Bug #1303 — `zfa build` must NOT retry with a clean cache when the
// failure is a pub RESOLUTION error: cache state cannot fix resolution,
// so the retry only burns a full rebuild before dying the same way.
//
// The subprocess shape mirrors build_command_test.dart: spawn the real
// `zfa build` (from source) in a temp workspace whose pubspec carries a
// stale path override. `dart run build_runner build` implicitly pub-gets,
// version solving fails fast, and the honest classification refuses the
// retry up front.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/build_command.dart';

import '../helpers/project_root.dart';

void main() {
  group('BuildCommand.reportsPubResolutionError (issue #1303 classifier)', () {
    test('matches the pub resolution signatures', () {
      const resolutionDump = '''
Because login_demo depends on zuraffa_flutter from path which doesn't exist
(No pubspec.yaml found for package zuraffa_flutter in
/…/zuraffa/zuraffa_flutter.), version solving failed.
''';
      expect(
        BuildCommand.reportsPubResolutionError(resolutionDump),
        isTrue,
        reason:
            'the exact issue #1303 dump shape must classify as '
            'resolution',
      );
      expect(
        BuildCommand.reportsPubResolutionError(
          "Because a depends on b ^2.0.0 which doesn't match any versions, "
          'version solving failed.',
        ),
        isTrue,
      );
      expect(
        BuildCommand.reportsPubResolutionError(
          'Error: Method not found: "Foo".\nFailed to compile.',
        ),
        isFalse,
        reason:
            'a compile error is NOT a resolution error — the retry '
            'fallback must keep firing for it (issue #1303 constraint)',
      );
      expect(BuildCommand.reportsPubResolutionError(''), isFalse);
    });
  });

  group('zfa build (issue #1303 — skip cache retry on resolution errors)', () {
    late Directory workspace;
    late String zfaBin;
    late bool useCompiledBinary;

    Future<Process> startZfa(
      List<String> args, {
      required String workingDirectory,
    }) {
      if (useCompiledBinary) {
        return Process.start(zfaBin, args, workingDirectory: workingDirectory);
      }
      return Process.start('dart', [
        zfaBin,
        ...args,
      ], workingDirectory: workingDirectory);
    }

    setUpAll(() async {
      final homeDir = Platform.environment['HOME'] ?? '';
      final compiledBin = p.join(homeDir, '.local', 'bin', 'zfa');
      final compiledExists = File(compiledBin).existsSync();
      if (compiledExists) {
        zfaBin = compiledBin;
        useCompiledBinary = true;
      } else {
        final projectRoot = await findProjectRoot();
        zfaBin = p.join(projectRoot, 'bin', 'zfa.dart');
        useCompiledBinary = false;
      }
    });

    setUp(() async {
      await findProjectRoot();
      workspace = await Directory.systemTemp.createTemp('zfa_1303_retry_');
      // The stale-override repro: the path target does not exist, so
      // implicit pub get inside build_runner fails version solving.
      File(p.join(workspace.path, 'pubspec.yaml')).writeAsStringSync('''
name: bug1303_build_fixture
environment:
  sdk: ^3.11.0
dependency_overrides:
  zuraffa_flutter:
    path: ../../zuraffa_flutter_does_not_exist
''');
    });

    tearDown(() {
      if (workspace.existsSync()) {
        try {
          workspace.deleteSync(recursive: true);
        } on FileSystemException {
          // build_runner can hold locks briefly; a leaked temp dir is
          // preferable to a flaky teardown.
        }
      }
    });

    test('a resolution failure refuses the clean-cache retry with the '
        'fix line', () async {
      final proc = await startZfa(['build'], workingDirectory: workspace.path);
      final out = await proc.stdout.transform(systemEncoding.decoder).join();
      final err = await proc.stderr.transform(systemEncoding.decoder).join();
      final combined = '$out$err';

      expect(
        proc.exitCode,
        completes,
        reason: 'the child process runs to completion',
      );
      final code = await proc.exitCode;
      expect(code, isNot(0), reason: 'a broken pubspec cannot build');

      expect(
        combined,
        isNot(contains('Retrying with clean cache')),
        reason:
            'issue #1303: a pub resolution error must not trigger the '
            'clean-cache retry — cache state cannot fix resolution. '
            'Output:\n$out$err',
      );
      expect(
        combined,
        contains('resolution error'),
        reason:
            'the honest classification must NAME the resolution class. '
            'Output:\n$combined',
      );
      expect(
        combined,
        contains('--> fix:'),
        reason:
            'errors-are-an-API: the skip verdict carries the remedy. '
            'Output:\n$combined',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
