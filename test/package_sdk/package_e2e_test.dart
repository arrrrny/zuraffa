@Tags(['integration', 'slow'])

library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// SC-001 end-to-end proof (spec 025): a package scaffolded by
/// `zfa package create` passes static analysis AND the full build/codegen
/// pipeline with zero manual edits — create → pub get → analyze →
/// entity create → make → build — in under 5 minutes.
///
/// Runs the real CLI (AOT binary when available) against a scaffolded
/// package pinned to THIS checkout via `--zuraffa-path`, exactly the
/// local-development flow documented in the guide. Network access is
/// required for `dart pub get` (zorphy & friends from pub.dev) — the
/// same tier every other integration test in this repo uses.
void main() {
  setUpAll(initZfaSourceBin);

  test('U30/SC-001: scaffold → pub get → analyze → entity → make → build, '
      'zero manual edits, under 5 minutes', () async {
    final stopwatch = Stopwatch()..start();
    final tempDir = await Directory.systemTemp.createTemp('zfa_sc001_');
    final pkgPath = p.join(tempDir.path, 'sc001_pkg');

    try {
      // 1. Scaffold via the real CLI.
      final scaffoldResult = await runZfaSource([
        'package',
        'create',
        'sc001_pkg',
        '--output',
        tempDir.path,
        '--zuraffa-path',
        zfaProjectRoot,
      ], workingDirectory: tempDir.path);
      expect(
        scaffoldResult.exitCode,
        0,
        reason: 'scaffold failed: ${_out(scaffoldResult)}',
      );
      expect(File(p.join(pkgPath, 'pubspec.yaml')).existsSync(), isTrue);

      // 2. Resolve dependencies (zero manual edits — untouched scaffold).
      final pubGet = await _runSupervised(
        ['dart', 'pub', 'get'],
        workingDirectory: pkgPath,
        timeout: const Duration(seconds: 180),
      );
      expect(pubGet.exitCode, 0, reason: 'pub get failed: ${_out(pubGet)}');

      // 3. Static analysis — zero errors on the untouched scaffold.
      final analyze = await _runSupervised(
        ['dart', 'analyze', '--no-fatal-warnings'],
        workingDirectory: pkgPath,
        timeout: const Duration(seconds: 120),
      );
      expect(
        analyze.exitCode,
        0,
        reason: 'scaffold must analyze clean: ${_out(analyze)}',
      );

      final analyzeElapsed = stopwatch.elapsed;
      // ignore: avoid_print
      print('SC-001 phase 1 (scaffold+pubget+analyze): $analyzeElapsed');

      // 4. Generate an entity inside the package (zfa-only flow).
      final entity = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Product',
        '--field',
        'id:String',
        '--field',
        'name:String',
      ], workingDirectory: pkgPath);
      expect(
        entity.exitCode,
        0,
        reason: 'entity create failed: ${_out(entity)}',
      );
      expect(
        File(
          p.join(
            pkgPath,
            'lib',
            'src',
            'domain',
            'entities',
            'product',
            'product.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: 'canonical entity layout must exist',
      );

      // 5. Generate architecture in package mode (FR-003/FR-004).
      final make = await runZfaSource([
        'make',
        'Product',
        'datasource',
        'repository',
        'usecase',
        'di',
      ], workingDirectory: pkgPath);
      expect(make.exitCode, 0, reason: 'make failed: ${_out(make)}');

      // Package registrar emitted; app artifacts suppressed.
      expect(
        File(
          p.join(
            pkgPath,
            'lib',
            'src',
            'di',
            'sc001_pkg_package_registrar.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: 'package registrar must be emitted (FR-004)',
      );
      expect(
        File(
          p.join(pkgPath, 'lib', 'src', 'di', 'service_locator.dart'),
        ).existsSync(),
        isFalse,
        reason: 'no app service locator in package mode (FR-003)',
      );
      expect(
        Directory(p.join(pkgPath, 'lib', 'src', 'routing')).existsSync(),
        isFalse,
        reason: 'no routes in package mode (FR-003)',
      );
      expect(
        Directory(p.join(pkgPath, 'lib', 'src', 'presentation')).existsSync(),
        isFalse,
        reason: 'no presentation in package mode (FR-003)',
      );

      // 6. The full build/codegen pipeline — identical command as an app.
      final build = await runZfaSource(['build'], workingDirectory: pkgPath);
      // ignore: avoid_print
      print('BUILD exitCode=${build.exitCode}\n${_out(build)}');
      expect(build.exitCode, 0, reason: 'build failed: ${_out(build)}');

      // Codegen outputs landed.
      expect(
        File(
          p.join(
            pkgPath,
            'lib',
            'src',
            'domain',
            'entities',
            'product',
            'product.zorphy.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: 'zorphy codegen part must exist after build',
      );

      final total = stopwatch.elapsed;
      // ignore: avoid_print
      print('SC-001 TOTAL elapsed: $total (SC-001 requires < 5 min)');
      expect(
        total.inMinutes,
        lessThan(5),
        reason: 'SC-001: scaffold+analyze+build must finish < 5 min',
      );

      // 7. The scaffolded test harness passes against generated code.
      final testRun = await _runSupervised(
        ['dart', 'test'],
        workingDirectory: pkgPath,
        timeout: const Duration(seconds: 180),
      );
      expect(
        testRun.exitCode,
        0,
        reason: 'scaffolded smoke test failed: ${_out(testRun)}',
      );
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

String _out(ProcessResult result) {
  final stdoutText = result.stdout.toString().trim();
  final stderrText = result.stderr.toString().trim();
  return [
    if (stdoutText.isNotEmpty)
      'stdout: ${stdoutText.split('\n').take(25).join('\n | ')}',
    if (stderrText.isNotEmpty)
      'stderr: ${stderrText.split('\n').take(25).join('\n | ')}',
  ].join('\n');
}

Future<ProcessResult> _runSupervised(
  List<String> command, {
  required String workingDirectory,
  required Duration timeout,
}) async {
  final stdoutFile = File(
    '${Directory.systemTemp.path}/sc001_${DateTime.now().microsecondsSinceEpoch}.out',
  );
  final stderrFile = File(
    '${Directory.systemTemp.path}/sc001_${DateTime.now().microsecondsSinceEpoch}.err',
  );
  final result = await Process.start('sh', [
    '-c',
    '${command.join(' ')} > ${stdoutFile.path} 2> ${stderrFile.path}',
  ], workingDirectory: workingDirectory);
  final exitCode = await result.exitCode.timeout(
    timeout,
    onTimeout: () {
      result.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
  return ProcessResult(
    result.pid,
    exitCode,
    stdoutFile.existsSync() ? stdoutFile.readAsStringSync() : '',
    stderrFile.existsSync() ? stderrFile.readAsStringSync() : '',
  );
}
