@Tags(['integration', 'slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// B3 (spec 1602): the scaffolded `zuraffa_ocr` family posts the full
/// health board — per package `dart pub get`, `dart analyze
/// --no-fatal-warnings`, `dart test`, and `dart pub publish --dry-run`,
/// all exit 0 — with zero manual edits. Unlike the spec-1601 e2e, NO
/// `--zuraffa-path` is passed: the hosted zuraffa constraint must resolve
/// against pub.dev on its own (the #1615 miss).
void main() {
  setUpAll(initZfaSourceBin);

  test(
    'B3: scaffold → per-package pub get → analyze → test → publish dry-run',
    () async {
      final stopwatch = Stopwatch()..start();
      final tempDir = await Directory.systemTemp.createTemp('zfa_ocr_e2e_');

      try {
        final scaffold = await runZfaSource([
          'package',
          'create-plugin',
          'zuraffa_ocr',
          '--repo',
          'arrrrny/zuraffa_ocr',
          '--description',
          'Typed OCR support for the Zuraffa ecosystem: a pure-Dart port, '
              'recognition lifecycle, and typed failures behind an injected '
              'platform channel with federated adapters.',
          '--no-gate',
        ], workingDirectory: tempDir.path,
            timeout: const Duration(seconds: 240));
        expect(scaffold.exitCode, 0,
            reason: 'scaffold failed: ${_out(scaffold)}');
        final monorepo = p.join(tempDir.path, 'zuraffa_ocr');

        final packages = Directory(p.join(monorepo, 'packages'))
            .listSync()
            .whereType<Directory>()
            .map((d) => p.basename(d.path))
            .toList()
          ..sort();
        expect(packages, [
          'zuraffa_ocr',
          'zuraffa_ocr_android',
          'zuraffa_ocr_ios',
          'zuraffa_ocr_macos',
          'zuraffa_ocr_platform',
        ]);

        for (final pkg in packages) {
          final pkgPath = p.join(monorepo, 'packages', pkg);

          for (final gate in const [
            (['dart', 'pub', 'get'], Duration(seconds: 180)),
            (['dart', 'analyze', '--no-fatal-warnings'],
                Duration(seconds: 120)),
            (['dart', 'test'], Duration(seconds: 300)),
            (['dart', 'pub', 'publish', '--dry-run'],
                Duration(seconds: 120)),
          ]) {
            final result = await _runSupervised(
              gate.$1,
              workingDirectory: pkgPath,
              timeout: gate.$2,
            );
            expect(result.exitCode, 0,
                reason: '$pkg ${gate.$1.join(" ")} failed:\n'
                    '${_tail(result)}');
          }
        }

        // ignore: avoid_print
        print('B3 elapsed: ${stopwatch.elapsed}');
      } finally {
        if (tempDir.existsSync()) tempDir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

String _out(ProcessResult r) => '${r.stdout}${r.stderr}';

String _tail(ProcessResult r) {
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
