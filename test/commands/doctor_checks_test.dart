/// SDD-TDD suite for issue #793 — `zfa doctor` named checks + auto-heal.
///
/// Spec: .specify/bugs/doctor-named-checks-fix/spec.md (FR-1..FR-9, U1..U15).
///
/// Behaviors:
/// U1  deps-missing-dev-deps-fail
/// U2  deps-present-passes
/// U3  deps-fix-invokes-pub-add-and-reports-fixed
/// U4  artifacts-entity-missing-g-dart-fails
/// U5  artifacts-complete-or-absent-passes
/// U6  baseline-cache-corrupt-reports-reason-and-fix-deletes
/// U7  baseline-cache-stale-detects-test-tree-newer
/// U8  baseline-cache-fresh-or-absent-passes
/// U9  config-malformed-fails-valid-passes-unknown-plugin-warns
/// U10 profile-missing-fails-and-fix-via-tdd-init
/// U11 doctor-format-json-single-object
/// U12 doctor-exit-code-reflects-checks
/// U13 migration-only-skips-named-checks
/// U14 dry-run-previews-fixes-without-applying
/// U15 deps-zuraffa-pin-major-behind-warns
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/doctor_checks.dart';

const _tddDevDeps = {'mocktail', 'coverage', 'mutation_test'};

/// Records spawned fix commands instead of running them (hermetic tests).
class _RecordingRunner {
  final List<String> invocations = [];
  _RecordingRunner();

  Future<ProcessResult> call(String executable, List<String> args) async {
    invocations.add('$executable ${args.join(' ')}');
    return ProcessResult(0, 0, '', '');
  }
}

Future<Directory> _sandbox() async {
  final dir = await Directory.systemTemp.createTemp('zfa-doctor-793-');
  addTearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
  return dir;
}

String _pubspec({
  Set<String> devDeps = _tddDevDeps,
  String zuraffa = '^6.0.0',
}) {
  final sb = StringBuffer()
    ..writeln('name: sandbox')
    ..writeln('environment:')
    ..writeln("  sdk: '>=3.0.0 <4.0.0'")
    ..writeln('dependencies:')
    ..writeln('  zuraffa: $zuraffa');
  if (devDeps.isNotEmpty) {
    sb.writeln('dev_dependencies:');
    for (final dep in devDeps) {
      sb.writeln('  $dep: ^1.0.0');
    }
  }
  return sb.toString();
}

Future<File> _writePubspec(
  Directory dir, {
  Set<String> devDeps = _tddDevDeps,
  String zuraffa = '^6.0.0',
}) => File(
  '${dir.path}/pubspec.yaml',
).writeAsString(_pubspec(devDeps: devDeps, zuraffa: zuraffa));

Future<void> _markTddProject(Directory dir) async {
  await Directory('${dir.path}/specs/001-app').create(recursive: true);
}

Future<File> _writeBaseline(
  Directory dir,
  String feature, {
  required String body,
}) async {
  final f = File('${dir.path}/specs/$feature/tdd/run-baseline.json');
  await f.parent.create(recursive: true);
  return f.writeAsString(body);
}

Future<T> _withDir<T>(String path, Future<T> Function() body) async {
  final saved = Directory.current;
  Directory.current = path;
  try {
    return await body();
  } finally {
    Directory.current = saved;
  }
}

DoctorCheckResult _pick(List<DoctorCheckResult> results, String id) =>
    results.singleWhere((r) => r.id == id);

void main() {
  group('deps check (U1-U3, U15)', () {
    test(
      'U1: missing TDD dev-deps fail with exact pub add suggestion',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir, devDeps: {'coverage', 'mutation_test'});
        await _markTddProject(dir);

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);

        final deps = _pick(results, 'deps');
        expect(deps.status, DoctorCheckStatus.fail);
        expect(deps.detail, contains('mocktail'));
        expect(deps.suggestedFix, contains('dart pub add dev:mocktail'));
      },
    );

    test('U2: all TDD dev-deps present passes', () async {
      final dir = await _sandbox();
      await _writePubspec(dir);
      await _markTddProject(dir);

      final results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);

      expect(_pick(results, 'deps').status, DoctorCheckStatus.pass);
    });

    test(
      'U3: fix invokes dart pub add for missing deps and reports fixed',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir, devDeps: {'mocktail'});
        await _markTddProject(dir);
        final runner = _RecordingRunner();

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
          processRunner: runner.call,
        ).runAll(fix: true);

        final deps = _pick(results, 'deps');
        expect(deps.status, DoctorCheckStatus.fixed);
        expect(deps.fixedItems, isNotEmpty);
        expect(
          runner.invocations,
          contains('dart pub add dev:coverage dev:mutation_test'),
        );
      },
    );

    test(
      'U15: zuraffa pin major behind CLI degrades to warn, never fail',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir, zuraffa: '^5.9.9');
        await _markTddProject(dir);

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);

        final deps = _pick(results, 'deps');
        expect(deps.status, DoctorCheckStatus.warn);
        expect(deps.detail, contains('5'));
      },
    );
  });

  group('artifacts check (U4-U5)', () {
    test(
      'U4: entity without sibling .g.dart fails with build_runner fix',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir);
        final entity = File(
          '${dir.path}/lib/src/domain/entities/user/user.dart',
        );
        await entity.parent.create(recursive: true);
        await entity.writeAsString('class User {}');

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);

        final artifacts = _pick(results, 'artifacts');
        expect(artifacts.status, DoctorCheckStatus.fail);
        expect(artifacts.detail, contains('user.dart'));
        expect(
          artifacts.suggestedFix,
          contains('dart run build_runner build --delete-conflicting-outputs'),
        );
      },
    );

    test('U5: complete entities pass and absent entities dir passes', () async {
      final dir = await _sandbox();
      await _writePubspec(dir);
      final entityDir = Directory('${dir.path}/lib/src/domain/entities/user');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/user.dart').writeAsString('class User {}');
      await File('${entityDir.path}/user.g.dart').writeAsString('// gen');
      await File('${entityDir.path}/user.zorphy.dart').writeAsString('// gen');

      var results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);
      expect(_pick(results, 'artifacts').status, DoctorCheckStatus.pass);

      final empty = await _sandbox();
      await _writePubspec(empty);
      results = await DoctorChecksRunner(
        projectDir: empty.path,
      ).runAll(fix: false);
      expect(_pick(results, 'artifacts').status, DoctorCheckStatus.pass);
    });
  });

  group('baseline-cache check (U6-U8)', () {
    test(
      'U6: corrupt + schema-invalid caches report WHY and fix deletes',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir);
        await _writeBaseline(dir, 'feat-a', body: 'not json {');
        await _writeBaseline(
          dir,
          'feat-b',
          body: jsonEncode({
            'command': 'dart test',
            'exitCode': 'zero',
            'failedTests': <String>[],
            'capturedAt': '2020-01-01T00:00:00.000Z',
            'parseable': true,
          }),
        );

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);

        final cache = _pick(results, 'baseline-cache');
        expect(cache.status, DoctorCheckStatus.fail);
        expect(cache.detail, contains('invalid JSON'));
        expect(cache.detail, contains('exitCode'));

        final fixed = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: true);
        final after = _pick(fixed, 'baseline-cache');
        expect(after.status, DoctorCheckStatus.fixed);
        expect(after.fixedItems.length, 2);
        expect(
          File('${dir.path}/specs/feat-a/tdd/run-baseline.json').existsSync(),
          isFalse,
        );
        expect(
          File('${dir.path}/specs/feat-b/tdd/run-baseline.json').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'U7: stale cache (test tree newer than capturedAt) fails and fix deletes',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir);
        final testFile = File('${dir.path}/test/misc_test.dart');
        await testFile.parent.create(recursive: true);
        await testFile.writeAsString('void main() {}');
        await _writeBaseline(
          dir,
          'feat',
          body: jsonEncode({
            'command': 'dart test',
            'exitCode': 0,
            'failedTests': <String>[],
            'capturedAt': '2020-01-01T00:00:00.000Z',
            'parseable': true,
          }),
        );

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);
        final cache = _pick(results, 'baseline-cache');
        expect(cache.status, DoctorCheckStatus.fail);
        expect(cache.detail, contains('stale'));

        final fixed = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: true);
        expect(_pick(fixed, 'baseline-cache').status, DoctorCheckStatus.fixed);
        expect(
          File('${dir.path}/specs/feat/tdd/run-baseline.json').existsSync(),
          isFalse,
        );
      },
    );

    test('U8: fresh cache and absent cache both pass', () async {
      final dir = await _sandbox();
      await _writePubspec(dir);
      final testFile = File('${dir.path}/test/misc_test.dart');
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('void main() {}');
      await _writeBaseline(
        dir,
        'feat',
        body: jsonEncode({
          'command': 'dart test',
          'exitCode': 0,
          'failedTests': <String>[],
          'capturedAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'parseable': true,
        }),
      );

      var results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);
      expect(_pick(results, 'baseline-cache').status, DoctorCheckStatus.pass);

      final empty = await _sandbox();
      await _writePubspec(empty);
      results = await DoctorChecksRunner(
        projectDir: empty.path,
      ).runAll(fix: false);
      final cache = _pick(results, 'baseline-cache');
      expect(cache.status, DoctorCheckStatus.pass);
      expect(cache.detail, contains('no cached baseline'));
    });
  });

  group('config check (U9)', () {
    test('U9: malformed fails, valid passes, unknown plugin warns', () async {
      final dir = await _sandbox();
      await _writePubspec(dir);

      final config = File('${dir.path}/.zfa.json');
      await config.writeAsString('{nope');
      var results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);
      var cfg = _pick(results, 'config');
      expect(cfg.status, DoctorCheckStatus.fail);
      expect(cfg.suggestedFix, contains('zfa config init'));

      await config.writeAsString('{}');
      results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);
      expect(_pick(results, 'config').status, DoctorCheckStatus.pass);

      await config.writeAsString(
        jsonEncode({
          'plugins': {
            'defaults': <String, dynamic>{},
            'bogus_plugin': <String, dynamic>{},
          },
        }),
      );
      results = await DoctorChecksRunner(
        projectDir: dir.path,
      ).runAll(fix: false);
      cfg = _pick(results, 'config');
      expect(cfg.status, DoctorCheckStatus.warn);
      expect(cfg.detail, contains('bogus_plugin'));
    });
  });

  group('profile check (U10)', () {
    test(
      'U10: missing profile fails suggesting tdd init; fix creates it',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir);
        await _markTddProject(dir);

        final results = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: false);
        final profile = _pick(results, 'profile');
        expect(profile.status, DoctorCheckStatus.fail);
        expect(profile.suggestedFix, 'zfa tdd init');

        final fixed = await DoctorChecksRunner(
          projectDir: dir.path,
        ).runAll(fix: true);
        final after = _pick(fixed, 'profile');
        expect(after.status, DoctorCheckStatus.fixed);
        expect(
          File('${dir.path}/.specify/memory/tdd-profile.md').existsSync(),
          isTrue,
        );
      },
    );
  });

  group('doctor command integration (U11-U14)', () {
    test(
      'U11: --format json emits exactly one parseable doctor.v1 object',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir);
        await _markTddProject(dir);
        await Directory('${dir.path}/.specify/memory').create(recursive: true);
        await File(
          '${dir.path}/.specify/memory/tdd-profile.md',
        ).writeAsString('profile');

        final out = await _withDir(dir.path, () async {
          final runner = CliRunner(exitOnCompletion: false);
          return runner.runCapturing(['doctor', '--format', 'json']);
        });

        final trimmed = out.trim();
        expect(trimmed, startsWith('{'));
        expect(trimmed, endsWith('}'));
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        expect(decoded['schema'], 'doctor.v1');
        final checks = decoded['checks'] as List;
        expect(checks.map((c) => c['id']).toSet(), {
          'deps',
          'artifacts',
          'baseline-cache',
          'config',
          'profile',
        });
        expect(decoded['ok'], isTrue);
        // json mode suppresses prose sections entirely.
        expect(trimmed.contains('v5 Migration'), isFalse);
        expect(trimmed.contains('Zuraffa Doctor'), isFalse);
      },
    );

    test('U12: exit code is 1 when a check fails, 0 when all pass', () async {
      final failing = await _sandbox();
      await _writePubspec(failing, devDeps: {'coverage'});
      await _markTddProject(failing);

      await _withDir(failing.path, () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(['doctor']);
        expect(out, contains('[FAIL] deps'));
        expect(exitCode, 1);
      });

      final healthy = await _sandbox();
      await _writePubspec(healthy);
      await _markTddProject(healthy);
      await Directory(
        '${healthy.path}/.specify/memory',
      ).create(recursive: true);
      await File(
        '${healthy.path}/.specify/memory/tdd-profile.md',
      ).writeAsString('profile');

      await _withDir(healthy.path, () async {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(['doctor']);
        expect(exitCode, 0);
      });
    });

    test(
      'U13: --migration-only skips named checks and their exit semantics',
      () async {
        final dir = await _sandbox();
        await _writePubspec(dir, devDeps: {'coverage'});
        await _markTddProject(dir);

        await _withDir(dir.path, () async {
          final runner = CliRunner(exitOnCompletion: false);
          final out = await runner.runCapturing(['doctor', '--migration-only']);
          expect(out.contains('Environment Checks'), isFalse);
          expect(exitCode, 0);
        });
      },
    );

    test('U14: --dry-run previews would-fix lines without applying', () async {
      final dir = await _sandbox();
      await _writePubspec(dir, devDeps: {'coverage', 'mutation_test'});
      await _markTddProject(dir);
      final cacheFile = await _writeBaseline(dir, 'feat', body: 'not json {');

      await _withDir(dir.path, () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(['doctor', '--dry-run']);
        expect(out, contains('would fix: dart pub add dev:mocktail'));
        expect(out, contains('would fix'));
        expect(exitCode, 1);
      });

      expect(
        cacheFile.existsSync(),
        isTrue,
        reason: 'dry-run must not delete the corrupt cache',
      );
    });
  });
}
