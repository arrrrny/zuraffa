// Regression test for issue #411 — zfa entity create: silently rejects
// Duration type fields.
//
// Before the fix, `zfa entity create -n StopPolicy --field "wallClockTimeout:Duration"`
// failed with a misleading error:
//
//   ❌ Cannot create entity "StopPolicy": field type(s) could not be resolved.
//     • Unknown type "Duration" for field "wallClockTimeout" — no matching
//       entity directory or enum file found under lib/src/domain/entities.
//        Create the enum/entity first, for example:
//          zfa entity enum -n Duration --value <values>
//        or check the spelling.
//   No files were written. Resolve the above and re-run.
//
// The user filed the issue as a "silent reject" (no entity file written,
// no obvious error path forward). The expected behavior per the issue is
// either to ACCEPT Duration (generate `Duration? wallClockTimeout;`) OR
// to show a clear, actionable error specific to Duration. The fix goes
// with the first option: treat Duration (and Uri, BigInt) as a
// `dart:core` type by auto-marking the field as EXTERNAL via
// `EntityUtils.markDartCoreTypesAsExternal`. The external marker makes
//   - `EntityTypeValidator` skip on-disk resolution,
//   - zorphy's `FieldNormalizer` skip `$`-prefixing (so the source carries
//     `Duration`, not `$Duration` which would not resolve),
//   - zorphy's `ImportResolver` skip emitting a bogus entity-style import.
//
// This test drives the FULL user-facing flow:
//   1. `zfa entity create -n StopPolicy --field "wallClockTimeout:Duration"`
//      → exit 0, entity file written.
//   2. The generated `stop_policy.dart` declares
//      `Duration get wallClockTimeout;` (NOT `$Duration get wallClockTimeout;`).
//   3. No bogus `import '../duration/duration.dart';` is emitted —
//      Duration needs no import (`dart:core` is auto-imported).
//   4. Same flow works for `Duration?`, `List<Duration>`,
//      `Map<String, Duration>`, `Uri`, `BigInt`.
//   5. The `zfa entity add-field` flow also accepts Duration on an
//      existing entity (parity with `entity create`).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';

void main() {
  group('#411 — zfa entity create: Duration field type', () {
    late Directory workspace;
    late String outputDir;
    late String zfaSourceBin;

    /// Runs zfa from SOURCE (never a stale global install) so the test
    /// picks up the patched `entity_command.dart` / `entity_utils.dart`.
    Future<ProcessResult> runZfaSource(List<String> args) {
      return Process.run('dart', [zfaSourceBin, ...args],
          workingDirectory: workspace.path);
    }

    setUpAll(() async {
      final projectRoot = await findProjectRoot();
      zfaSourceBin = p.join(projectRoot, 'bin', 'zfa.dart');
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('issue_411_');
      outputDir = p.join(workspace.path, 'lib', 'src', 'domain', 'entities');
      await Directory(outputDir).create(recursive: true);
      // The entity command's dependency check scans pubspec.yaml for the
      // strings `zorphy_annotation:` and `build_runner:`. The strings are
      // enough — entity creation itself does not run `dart pub get`.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_411_test_app
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      'zfa entity create -n StopPolicy --field wallClockTimeout:Duration '
      'writes the entity with `Duration get wallClockTimeout;`',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'StopPolicy',
          '--field',
          'wallClockTimeout:Duration',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(0),
            reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');

        final file = File(
          p.join(outputDir, 'stop_policy', 'stop_policy.dart'),
        );
        expect(file.existsSync(), isTrue,
            reason: 'entity file must be written for a Duration field');
        final src = file.readAsStringSync();

        // The field declaration must be `Duration get wallClockTimeout;`
        // (NOT `$Duration get wallClockTimeout;` which would not resolve
        // because `$Duration` is undefined in the zorphy entity tree).
        expect(
          src,
          contains('Duration get wallClockTimeout;'),
          reason: 'Duration must be emitted WITHOUT the \$ prefix',
        );
        expect(
          src,
          isNot(contains(r'$Duration')),
          reason:
              'The Zorphy entity prefix `\$` must NOT be applied to '
              'dart:core types like Duration',
        );

        // No bogus entity-style import — Duration lives in dart:core.
        expect(
          src,
          isNot(contains("import '../duration/duration.dart';")),
          reason: 'No import for dart:core types',
        );
      },
    );

    test(
      'Duration? is emitted as `Duration? get softTimeout;`',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Timeouts',
          '--field',
          'softTimeout:Duration?',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(0),
            reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');

        final file = File(
          p.join(outputDir, 'timeouts', 'timeouts.dart'),
        );
        expect(file.existsSync(), isTrue);
        final src = file.readAsStringSync();

        expect(src, contains('Duration? get softTimeout;'));
        expect(src, isNot(contains(r'$Duration')));
      },
    );

    test(
      'List<Duration> is emitted as `List<Duration> get tags;`',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'ScheduledTask',
          '--field',
          'tags:List<Duration>',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(0),
            reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');

        final file = File(
          p.join(outputDir, 'scheduled_task', 'scheduled_task.dart'),
        );
        expect(file.existsSync(), isTrue);
        final src = file.readAsStringSync();

        expect(src, contains('List<Duration> get tags;'));
        // The inner type must also stay Duration (not $Duration).
        expect(src, isNot(contains(r'$Duration')));
        expect(
          src,
          isNot(contains("import '../duration/duration.dart';")),
        );
      },
    );

    test(
      'Map<String, Duration> is emitted as `Map<String, Duration> get byKey;`',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'NamedTimeouts',
          '--field',
          'byKey:Map<String, Duration>',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(0),
            reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');

        final file = File(
          p.join(outputDir, 'named_timeouts', 'named_timeouts.dart'),
        );
        expect(file.existsSync(), isTrue);
        final src = file.readAsStringSync();

        expect(src, contains('Map<String, Duration> get byKey;'));
        expect(src, isNot(contains(r'$Duration')));
      },
    );

    test(
      'Uri and BigInt fields are accepted (same mechanism as Duration)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'WebLink',
          '--field',
          'endpoint:Uri',
          '--field',
          'viewCount:BigInt',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(0),
            reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');

        final file = File(
          p.join(outputDir, 'web_link', 'web_link.dart'),
        );
        expect(file.existsSync(), isTrue);
        final src = file.readAsStringSync();

        expect(src, contains('Uri get endpoint;'));
        expect(src, contains('BigInt get viewCount;'));
        expect(src, isNot(contains(r'$Uri')));
        expect(src, isNot(contains(r'$BigInt')));
      },
    );

    test(
      'mix: Duration + String + entity ref + Duration? all written correctly',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // First create the referenced Product entity.
        final productResult = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Product',
          '--field',
          'name:String',
          '--output',
          outputDir,
        ]);
        expect(productResult.exitCode, equals(0),
            reason: 'precondition: Product must be created');

        // Then create the entity mixing Duration + String + Product.
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Policy',
          '--field',
          'name:String',
          '--field',
          'wallClockTimeout:Duration',
          '--field',
          'softTimeout:Duration?',
          '--field',
          'product:Product',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(0),
            reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');

        final file = File(p.join(outputDir, 'policy', 'policy.dart'));
        expect(file.existsSync(), isTrue);
        final src = file.readAsStringSync();

        // All field declarations present, with correct types.
        expect(src, contains('String get name;'));
        expect(src, contains('Duration get wallClockTimeout;'));
        expect(src, contains('Duration? get softTimeout;'));
        // Product is a real entity — it SHOULD keep its `$` prefix.
        expect(src, contains(r'$Product get product;'));

        // The Product import was resolved (entity-style import).
        expect(src, contains("import '../product/product.dart';"));
        // But NO bogus Duration import.
        expect(
          src,
          isNot(contains("import '../duration/duration.dart';")),
        );
      },
    );

    test(
      'zfa entity add-field accepts Duration on an existing entity',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // 1. Create the entity with a single String field.
        final createResult = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Job',
          '--field',
          'name:String',
          '--output',
          outputDir,
        ]);
        expect(createResult.exitCode, equals(0),
            reason: 'precondition: Job must be created');

        // 2. Add a Duration field.
        final addResult = await runZfaSource([
          'entity',
          'add-field',
          '-n',
          'Job',
          '--field',
          'wallClockTimeout:Duration',
          '--output',
          outputDir,
        ]);

        expect(addResult.exitCode, equals(0),
            reason: 'stdout: ${addResult.stdout}\nstderr: ${addResult.stderr}');

        final file = File(p.join(outputDir, 'job', 'job.dart'));
        expect(file.existsSync(), isTrue);
        final src = file.readAsStringSync();

        // Both the original and the added field are present.
        expect(src, contains('String get name;'));
        expect(src, contains('Duration get wallClockTimeout;'));
        expect(src, isNot(contains(r'$Duration')));
      },
    );

    test(
      'zfa entity create exits 0 and prints "Created entity" for Duration '
      '(regression: used to exit 1 with misleading "Unknown type Duration")',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'StopPolicy',
          '--field',
          'wallClockTimeout:Duration',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, equals(0));
        final output = result.stdout.toString() + result.stderr.toString();
        expect(output, contains('Created entity'));
        // The misleading "Unknown type Duration" / "create an enum"
        // error path must NOT be triggered for a dart:core type.
        expect(output, isNot(contains('Unknown type "Duration"')));
        expect(output, isNot(contains('zfa entity enum -n Duration')));
      },
    );
  });
}
