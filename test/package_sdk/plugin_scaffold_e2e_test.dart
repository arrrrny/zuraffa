@Tags(['integration', 'slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// B9 / SC-001 end-to-end proof (spec 1601): a federated plugin family
/// scaffolded by the real CLI passes `dart pub get`, `dart analyze`, and
/// `dart test` per package with zero manual edits — in under 8 minutes.
///
/// Runs the real CLI (AOT binary when available) via the `plugin` alias of
/// `zfa package create-plugin`, pinned to THIS checkout through
/// `--zuraffa-path` (dependency_overrides — the dev flow FR-006/FR-013
/// mandate). Network access is required for `dart pub get` (lints & test
/// from pub.dev) — the same tier every other integration test uses.
void main() {
  setUpAll(initZfaSourceBin);

  test(
    'B9: scaffold → per-package pub get → analyze → test, zero manual edits',
    () async {
      final stopwatch = Stopwatch()..start();
      final tempDir = await Directory.systemTemp.createTemp('zfa_plugin_e2e_');

      try {
        // 1. Scaffold via the real CLI (the spec-1601 `plugin` alias).
        final scaffold = await runZfaSource([
          'package',
          'plugin',
          'e2e_plugin',
          '--output',
          tempDir.path,
          '--zuraffa-path',
          zfaProjectRoot,
          '--no-gate',
        ], workingDirectory: tempDir.path);
        expect(
          scaffold.exitCode,
          0,
          reason: 'scaffold failed: ${_out(scaffold)}',
        );
        final monorepo = p.join(tempDir.path, 'e2e_plugin');
        expect(Directory(monorepo).existsSync(), isTrue);

        final packages = Directory(p.join(monorepo, 'packages'))
            .listSync()
            .whereType<Directory>()
            .map((d) => p.basename(d.path))
            .toList()
          ..sort();
        expect(packages, [
          'e2e_plugin',
          'e2e_plugin_android',
          'e2e_plugin_ios',
          'e2e_plugin_macos',
          'e2e_plugin_platform',
        ]);

        // 2. Per package: resolve, analyze, test — zero manual edits.
        for (final pkg in packages) {
          final pkgPath = p.join(monorepo, 'packages', pkg);

          final pubGet = await _runSupervised(
            ['dart', 'pub', 'get'],
            workingDirectory: pkgPath,
            timeout: const Duration(seconds: 180),
          );
          expect(pubGet.exitCode, 0, reason: '$pkg pub get: ${_raw(pubGet)}');

          final analyze = await _runSupervised(
            ['dart', 'analyze', '--no-fatal-warnings'],
            workingDirectory: pkgPath,
            timeout: const Duration(seconds: 120),
          );
          expect(analyze.exitCode, 0,
              reason: '$pkg must analyze clean: ${_raw(analyze)}');

          final test = await _runSupervised(
            ['dart', 'test'],
            workingDirectory: pkgPath,
            timeout: const Duration(seconds: 300),
          );
          expect(test.exitCode, 0,
              reason: '$pkg tests must pass: ${_raw(test)}');
        }

        // ignore: avoid_print
        print('B9 elapsed: ${stopwatch.elapsed}');
      } finally {
        if (tempDir.existsSync()) tempDir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

String _out(ProcessResult r) => '${r.stdout}${r.stderr}';

String _raw(ProcessResult r) {
  final text = _out(r).trim();
  return text.length > 800 ? text.substring(text.length - 800) : text;
}

Future<ProcessResult> _runSupervised(
  List<String> command, {
  required String workingDirectory,
  required Duration timeout,
}) async {
  final result = await Process.run(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  ).timeout(timeout);
  return result;
}
