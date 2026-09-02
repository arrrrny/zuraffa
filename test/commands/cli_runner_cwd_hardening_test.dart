import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  group('CliRunner CWD hardening', () {
    test('reusing one runner across different -C dirs rebuilds commands '
        'without a stale root or a duplicate-registration crash', () async {
      final dir1 = await Directory.systemTemp.createTemp('cwdr1_');
      final dir2 = await Directory.systemTemp.createTemp('cwdr2_');
      addTearDown(() async {
        await dir1.delete(recursive: true);
        await dir2.delete(recursive: true);
      });
      // Minimal project markers so ProjectRoot resolution succeeds.
      await File(p.join(dir1.path, 'pubspec.yaml')).writeAsString('name: r1\n');
      await File(p.join(dir2.path, 'pubspec.yaml')).writeAsString('name: r2\n');

      // A single CliRunner instance reused across two different project
      // directories (the scenario CodeRabbit flagged for #623).
      final runner = CliRunner(exitOnCompletion: false);

      final out1 = await runner.runCapturing(['-C', dir1.path, 'schema']);
      // Different -C on the same runner must rebuild root-bound commands
      // against the new directory. Without the rebuild the second
      // `_addCoreCommands` throws "command already exists".
      final out2 = await runner.runCapturing(['-C', dir2.path, 'schema']);

      expect(out1, contains('ZFA Generator Configuration'));
      expect(out2, contains('ZFA Generator Configuration'));
      expect(out1, isNot(contains('command already exists')));
      expect(out2, isNot(contains('command already exists')));
    });

    test('concurrent runCapturing invocations on one runner are rejected', () {
      final runner = CliRunner(exitOnCompletion: false);
      // The first call sets the re-entrancy guard synchronously and returns a
      // future; the second synchronous call must be rejected with a clear error
      // instead of racing on the process-wide Directory.current.
      final first = runner.runCapturing(['schema']);
      expect(() => runner.runCapturing(['schema']), throwsA(isA<StateError>()));
      // The first (permitted) invocation still completes normally.
      expectLater(first, completion(contains('ZFA Generator Configuration')));
    });

    test('restore survives a concurrently-deleted working directory', () async {
      // Regression guard for the flaky U19 PathNotFoundException observed
      // once the #767 suites changed suite scheduling: `Directory.current`
      // is process-wide, suites run as concurrent isolates, and the saved
      // CWD can be deleted by the other isolate's teardown between the
      // capture and the restore inside `_withDirectory`. The deterministic
      // part of that contract is the fallback resolver; the interleave
      // itself cannot be reproduced deterministically in-process.
      final outside = await Directory.systemTemp.createTemp('cwdr3_');
      final doomed = await Directory.systemTemp.createTemp('cwdr4_');
      final nested = Directory(p.join(doomed.path, 'child'))
        ..createSync(recursive: true);
      addTearDown(() async {
        if (outside.existsSync()) {
          await outside.delete(recursive: true);
        }
        if (doomed.existsSync()) {
          await doomed.delete(recursive: true);
        }
      });

      // Existing path resolves to itself.
      expect(
        CliRunner.nearestExistingDirectory(outside.path),
        equals(outside.path),
      );

      // Deleted leaf resolves to its nearest surviving ancestor.
      nested.deleteSync();
      doomed.deleteSync();
      expect(
        CliRunner.nearestExistingDirectory(nested.path),
        equals(p.dirname(p.dirname(nested.path))), // the systemTemp root
      );
    });
  });
}
