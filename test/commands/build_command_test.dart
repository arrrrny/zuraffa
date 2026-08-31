@Tags(['slow'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as path;

import '../helpers/project_root.dart';

/// Integration tests for `zfa build` self-healing when `build.yaml` is
/// missing or misconfigured (zuraffa#276).
///
/// These spawn the real `zfa build` subprocess against a temp workspace so we
/// exercise the full pre-flight → build_runner → report path. The
/// build_runner call itself is the slow part, so each test uses a minimal
/// project where build_runner finishes quickly (or fails fast).
void main() {
  group('zfa build (build.yaml self-healing — #276)', () {
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
      final compiledBin = path.join(homeDir, '.local', 'bin', 'zfa');
      final compiledExists = File(compiledBin).existsSync();
      if (compiledExists) {
        zfaBin = compiledBin;
        useCompiledBinary = true;
      } else {
        final projectRoot = await findProjectRoot();
        zfaBin = path.join(projectRoot, 'bin', 'zfa.dart');
        useCompiledBinary = false;
      }
    });

    setUp(() async {
      // The full test suite has pre-existing CWD-contamination: some test
      // files delete their temp CWD without restoring it, so a later
      // subprocess `zfa` invocation blows up in MakeCommand._findProjectRoot
      // -> Directory.current. findProjectRoot() runs _ensureValidCwd first,
      // recovering CWD to the project root if it was deleted. We call it here
      // so every test in this file starts from a valid CWD.
      await findProjectRoot();
      workspace = await Directory.systemTemp.createTemp('zfa_build_guard_');
    });

    tearDown(() async {
      // NOTE: we deliberately never call `Directory.current =` here. This test
      // passes `workingDirectory` to Process.start, so it never needs to change
      // CWD. Capturing/restoring CWD would inherit a stale path from other test
      // files (e.g. make_command_test) that DO change CWD, causing a
      // PathNotFoundException on tearDown. See zuraffa#276 test hygiene.
      if (workspace.existsSync()) {
        try {
          await workspace.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup; temp dirs are OS-reaped anyway.
        }
      }
    });

    test('--help still works and documents the build command', () async {
      final proc = await startZfa([
        'build',
        '--help',
      ], workingDirectory: workspace.path);
      final stdout = await proc.stdout.transform(systemEncoding.decoder).join();
      final stderr = await proc.stderr.transform(systemEncoding.decoder).join();
      final code = await proc.exitCode;
      expect(code, 0, reason: stderr);
      expect(stdout, contains('Run zuraffa_build'));
      // build.yaml scaffolding is automatic; no flag for it.
      expect(stdout, isNot(contains('--build-yaml')));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test(
      'dry-run reports it would scaffold build.yaml when missing (#276)',
      () async {
        // No build.yaml in workspace.
        final proc = await startZfa([
          'build',
          '--dry-run',
        ], workingDirectory: workspace.path);
        final stdout = await proc.stdout
            .transform(systemEncoding.decoder)
            .join();
        final stderr = await proc.stderr
            .transform(systemEncoding.decoder)
            .join();
        final code = await proc.exitCode;
        // dry-run should not invoke build_runner; it prints the pre-flight plan.
        expect(code, 0, reason: stderr);
        expect(
          stdout,
          contains('Would scaffold'),
          reason: 'dry-run should announce it would create build.yaml',
        );
        // And must NOT actually create one.
        expect(
          File(path.join(workspace.path, 'build.yaml')).existsSync(),
          isFalse,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'dry-run warns when build.yaml exists but omits zorphy builder (#276)',
      () async {
        final buildYaml = File(path.join(workspace.path, 'build.yaml'));
        await buildYaml.writeAsString('''
targets:
  \$default:
    builders:
      json_serializable:
        enabled: true
''');
        final proc = await startZfa([
          'build',
          '--dry-run',
        ], workingDirectory: workspace.path);
        final stdout = await proc.stdout
            .transform(systemEncoding.decoder)
            .join();
        final stderr = await proc.stderr
            .transform(systemEncoding.decoder)
            .join();
        final code = await proc.exitCode;
        expect(code, 0, reason: stderr);
        expect(
          stdout,
          contains('omits the zorphy builder'),
          reason: 'dry-run should warn about the missing zorphy registration',
        );
        // Should not modify the user's build.yaml.
        expect(buildYaml.readAsStringSync(), contains('json_serializable'));
        expect(buildYaml.readAsStringSync(), isNot(contains('zorphy:zorphy')));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'build scaffolds build.yaml when missing, then proceeds (#276)',
      () async {
        // This actually runs build_runner against the scaffolded build.yaml.
        // We don't need codegen to succeed — we just need to prove:
        //   (1) build.yaml was missing,
        //   (2) zfa build created it,
        //   (3) the message announces the scaffolding.
        // build_runner may fail (no pubspec etc.) but the pre-flight must run.
        final proc = await startZfa([
          'build',
        ], workingDirectory: workspace.path);
        final stdout = await proc.stdout
            .transform(systemEncoding.decoder)
            .join();
        final stderr = await proc.stderr
            .transform(systemEncoding.decoder)
            .join();
        await proc.exitCode;
        // Pre-flight scaffolding message must appear regardless of build_runner
        // outcome.
        expect(
          stdout,
          contains('No build.yaml found'),
          reason:
              'zfa build must announce the missing build.yaml. stderr:\n$stderr',
        );
        expect(
          stdout,
          contains('scaffolding'),
          reason: 'zfa build must announce it is scaffolding build.yaml',
        );
        // build.yaml must now exist and register zorphy.
        final created = File(path.join(workspace.path, 'build.yaml'));
        expect(created.existsSync(), isTrue);
        expect(created.readAsStringSync(), contains('zorphy:zorphy'));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'build fails loudly when build.yaml exists but omits zorphy builder (#276)',
      () async {
        final buildYaml = File(path.join(workspace.path, 'build.yaml'));
        await buildYaml.writeAsString('''
targets:
  \$default:
    builders:
      json_serializable:
        enabled: true
''');
        final proc = await startZfa([
          'build',
        ], workingDirectory: workspace.path);
        final stdout = await proc.stdout
            .transform(systemEncoding.decoder)
            .join();
        final code = await proc.exitCode;
        expect(
          code,
          isNot(0),
          reason: 'misconfigured build.yaml must abort with non-zero exit',
        );
        expect(stdout, contains('does not register the zorphy builder'));
        expect(stdout, contains('zorphy:zorphy'));
        expect(stdout, contains('zfa setup'));
        // build_runner must NOT have been invoked.
        expect(stdout, isNot(contains('Running build_runner build')));
        // The user's build.yaml must be untouched.
        expect(buildYaml.readAsStringSync(), isNot(contains('zorphy:zorphy')));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
