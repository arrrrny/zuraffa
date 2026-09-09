@Tags(['regression'])
library;

// Regression tests for verify misfires #1385 + #1386 (EPIC #1132 — the
// honesty sweep, spec 1334).
//
// Before spec 1334, two standalone generation verbs reported SUCCESS after
// producing nothing:
//
//   - `zfa test create <Entity>` with a missing UseCase source skipped every
//     requested test, printed the skips under `⏭ Skipped (use --force to
//     overwrite):` (misattributing the cause — `--force` cannot create a
//     missing source), and exited 0.
//   - `zfa api <Entity>` with no UseCases discovered under
//     `lib/src/domain/usecases/<entity>/` printed `No UseCases found` +
//     `No files generated.` and exited 0.
//
// That is the exit-0-on-error class EPIC 1 exists to end: fleet automation
// could not distinguish "generated" from "did nothing". Spec 1334 moves the
// verdict into the capability layer (where MCP + `zfa make` consume it):
//
//   - zero-artifact runs whose skips are missing-dependency skips FAIL
//     (`success: false`, honest message + `--> fix:` line, exit 1);
//   - zero-artifact runs whose skips are overwrite conflicts keep the
//     historical benign semantics (exit 0 + `--force` hint);
//   - dry runs are exempt (preview is explicit user intent).
//
// Receipt contract (#769) unchanged: zero-artifact runs persist no receipt.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group(
    '#1385 — zfa test create (missing UseCase source) must fail honestly',
    () {
      late Directory workspace;

      Future<ProcessResult> runZfa(List<String> args) {
        return runZfaSource([...args], workingDirectory: workspace.path);
      }

      setUp(() async {
        await initZfaSourceBin();
        workspace = await Directory.systemTemp.createTemp('issue_1385_');
        // Pure-Dart package with the entity + datasource sources the test
        // builder resolves first — but NO usecase source. The builder must
        // skip the test generation (missing dependency), and the run must
        // fail instead of reporting a lying success.
        await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_1385_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zuraffa:
dev_dependencies:
  test:
''');
        final datasourceDir = Directory(
          p.join(
            workspace.path,
            'lib',
            'src',
            'data',
            'datasources',
            'product',
          ),
        );
        await datasourceDir.create(recursive: true);
        await File(
          p.join(datasourceDir.path, 'product_datasource.dart'),
        ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

class ProductDataSource {
  const ProductDataSource();
}
''');
      });

      tearDown(() async {
        try {
          await workspace.delete(recursive: true);
        } on FileSystemException {
          // Best-effort cleanup; a leaked temp dir must not fail the run.
        }
      });

      test(
        'zero-artifact run with a missing-dependency skip exits non-zero',
        () async {
          final result = await runZfa(['test', 'create', 'Product']);

          expect(
            result.exitCode,
            isNot(0),
            reason:
                'a run that generated nothing because a dependency source '
                'is missing must not report success (EPIC #1132 honesty floor)',
          );
        },
        timeout: Timeout(scaleDuration(const Duration(minutes: 3))),
      );

      test(
        'failure output names the cause and a fix, never a lying success',
        () async {
          final result = await runZfa(['test', 'create', 'Product']);
          final stdout = '${result.stdout}';

          expect(stdout, contains('❌'));
          expect(stdout, contains('--> fix:'));
          expect(stdout, isNot(contains('✅ Success!')));
        },
        timeout: Timeout(scaleDuration(const Duration(minutes: 3))),
      );

      test(
        'dry run stays a benign success (preview is explicit intent)',
        () async {
          final result = await runZfa([
            'test',
            'create',
            'Product',
            '--dry-run',
          ]);

          expect(result.exitCode, 0);
        },
        timeout: Timeout(scaleDuration(const Duration(minutes: 3))),
      );
    },
  );

  group('#1386 — zfa api (no UseCases) must fail honestly', () {
    late Directory workspace;

    Future<ProcessResult> runZfa(List<String> args) {
      return runZfaSource([...args], workingDirectory: workspace.path);
    }

    setUp(() async {
      await initZfaSourceBin();
      workspace = await Directory.systemTemp.createTemp('issue_1386_');
      // Pure-Dart package with NO UseCases for the entity: the api bridge
      // builder discovers zero usecases and (pre-1334) the run exited 0.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_1386_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zuraffa:
dev_dependencies:
  test:
''');
    });

    tearDown(() async {
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup; a leaked temp dir must not fail the run.
      }
    });

    test(
      'zero-file bridge generation with no UseCases exits non-zero',
      () async {
        final result = await runZfa(['api', 'Product']);

        expect(
          result.exitCode,
          isNot(0),
          reason:
              'the api verb exists to bridge UseCases; discovering zero '
              'UseCases and exiting 0 is the lying-success pattern',
        );
        expect('${result.stdout}', contains('Failed to generate API bridge'));
      },
      timeout: Timeout(scaleDuration(const Duration(minutes: 3))),
    );

    test(
      'dry run stays a benign success (preview is explicit intent)',
      () async {
        final result = await runZfa(['api', 'Product', '--dry-run']);

        expect(result.exitCode, 0);
      },
      timeout: Timeout(scaleDuration(const Duration(minutes: 3))),
    );
  });
}
