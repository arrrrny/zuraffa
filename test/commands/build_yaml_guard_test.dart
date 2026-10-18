import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:zuraffa/src/commands/build_yaml_guard.dart';

import '../helpers/cwd_mutex.dart';

void main() {
  group('BuildYamlGuard', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('build_yaml_guard_');
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    test(
      'check() returns BuildYamlStatus.missing when no build.yaml exists',
      () {
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.missing,
        );
      },
    );

    test('check() returns BuildYamlStatus.ok for the canonical build.yaml', () {
      final f = File(p.join(sandbox.path, 'build.yaml'));
      f.writeAsStringSync('''
targets:
  \$default:
    builders:
      zorphy:zorphy:
        enabled: true
        generate_for:
          - lib/src/**
          - test/**
      source_gen:combining_builder:
        enabled: true
''');
      expect(
        BuildYamlGuard.check(projectRoot: sandbox.path),
        BuildYamlStatus.ok,
      );
    });

    test(
      'check() returns missingZorphyBuilder when build.yaml omits zorphy:zorphy',
      () {
        final f = File(p.join(sandbox.path, 'build.yaml'));
        f.writeAsStringSync('''
targets:
  \$default:
    builders:
      json_serializable:
        enabled: true
        generate_for:
          - lib/**
''');
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.missingZorphyBuilder,
        );
      },
    );

    test('check() returns missingZorphyBuilder for an empty build.yaml', () {
      File(p.join(sandbox.path, 'build.yaml')).writeAsStringSync('');
      expect(
        BuildYamlGuard.check(projectRoot: sandbox.path),
        BuildYamlStatus.missingZorphyBuilder,
      );
    });

    test('check() tolerates indented zorphy:zorphy keys', () {
      final f = File(p.join(sandbox.path, 'build.yaml'));
      f.writeAsStringSync('''
targets:
  \$default:
    builders:
        zorphy:zorphy:
            enabled: true
''');
      expect(
        BuildYamlGuard.check(projectRoot: sandbox.path),
        BuildYamlStatus.ok,
      );
    });

    test('check() does not false-positive on a zorphy comment', () {
      final f = File(p.join(sandbox.path, 'build.yaml'));
      f.writeAsStringSync('''
# TODO: add zorphy:zorphy here
targets:
  \$default:
    builders:
      json_serializable:
        enabled: true
''');
      expect(
        BuildYamlGuard.check(projectRoot: sandbox.path),
        BuildYamlStatus.missingZorphyBuilder,
      );
    });

    test(
      'scaffold() writes build.yaml with the zorphy builder registered',
      () async {
        await BuildYamlGuard.scaffold(projectRoot: sandbox.path);
        final written = File(p.join(sandbox.path, 'build.yaml'));
        expect(written.existsSync(), isTrue);
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.ok,
          reason: 'scaffolded build.yaml must register zorphy:zorphy',
        );
      },
    );

    test(
      'scaffold() content matches DependencyWirer.buildYamlContent',
      () async {
        await BuildYamlGuard.scaffold(projectRoot: sandbox.path);
        final written = File(
          p.join(sandbox.path, 'build.yaml'),
        ).readAsStringSync();
        expect(written, contains('zorphy:zorphy'));
        expect(written, contains('json_serializable'));
        expect(written, contains('generate_for'));
      },
    );

    test('check() defaults to Directory.current when projectRoot is null', () {
      // Smoke test: should not throw and should return a valid status.
      final status = BuildYamlGuard.check();
      expect(
        status,
        anyOf(
          BuildYamlStatus.missing,
          BuildYamlStatus.missingZorphyBuilder,
          BuildYamlStatus.notApplicable,
          BuildYamlStatus.ok,
        ),
      );
    });

    // ── Issue #1709: a project that provably does not use the zuraffa/zorphy
    // code-generation pipeline must not be dead-ended by a build.yaml that
    // omits the zorphy builder registration. ────────────────────────────────

    group('check() — zorphy pipeline not in use (#1709)', () {
      /// A minimal non-zuraffa Dart/Flutter package: a real pubspec.yaml, a
      /// `build.yaml` for its OWN builders, plain Dart sources, and no
      /// zorphy dependency or `@Zorphy` annotation anywhere.
      void writeNonZuraffaProject({required String dartSource}) {
        File(p.join(sandbox.path, 'pubspec.yaml')).writeAsStringSync('''
name: shadapp
dependencies:
  flutter:
    sdk: flutter
''');
        File(p.join(sandbox.path, 'build.yaml')).writeAsStringSync('''
targets:
  \$default:
    builders:
      slang_build_runner:
        enabled: true
''');
        Directory(p.join(sandbox.path, 'lib/src')).createSync(recursive: true);
        File(
          p.join(sandbox.path, 'lib/src/app.dart'),
        ).writeAsStringSync(dartSource);
      }

      test(
        'returns notApplicable when there is no zorphy dep and no annotation',
        () {
          writeNonZuraffaProject(dartSource: 'class App {}');
          expect(
            BuildYamlGuard.check(projectRoot: sandbox.path),
            BuildYamlStatus.notApplicable,
          );
        },
      );

      test('returns missingZorphyBuilder when pubspec declares zorphy', () {
        writeNonZuraffaProject(dartSource: 'class App {}');
        File(p.join(sandbox.path, 'pubspec.yaml')).writeAsStringSync('''
name: shadapp
dependencies:
  zorphy_annotation: ^1.0.0
''');
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.missingZorphyBuilder,
        );
      });

      test('returns missingZorphyBuilder when dev_dependencies declares the '
          'zorphy builder', () {
        // The builder-name key (`zorphy`, not `zorphy_annotation`) in a
        // non-`dependencies` section — pins both halves of the per-section
        // probe (review note on #1748).
        writeNonZuraffaProject(dartSource: 'class App {}');
        File(p.join(sandbox.path, 'pubspec.yaml')).writeAsStringSync('''
name: shadapp
dev_dependencies:
  zorphy: ^2.0.0
''');
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.missingZorphyBuilder,
        );
      });

      test('returns missingZorphyBuilder when dependency_overrides declares '
          'zorphy_annotation', () {
        writeNonZuraffaProject(dartSource: 'class App {}');
        File(p.join(sandbox.path, 'pubspec.yaml')).writeAsStringSync('''
name: shadapp
dependency_overrides:
  zorphy_annotation: ^1.0.0
''');
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.missingZorphyBuilder,
        );
      });

      test('returns notApplicable when pubspec is unparseable and there are no '
          'annotations', () {
        // The documented fail-open decision: an unparseable pubspec yields
        // no dependency proof, and the annotation scan already established
        // this is not a zorphy-annotated project (review note on #1748).
        writeNonZuraffaProject(dartSource: 'class App {}');
        File(
          p.join(sandbox.path, 'pubspec.yaml'),
        ).writeAsStringSync('name: [unclosed\n  bad: : :\n');
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.notApplicable,
        );
      });

      test('returns missingZorphyBuilder when a @Zorphy source exists', () {
        writeNonZuraffaProject(dartSource: '@Zorphy()\nclass Product {}');
        expect(
          BuildYamlGuard.check(projectRoot: sandbox.path),
          BuildYamlStatus.missingZorphyBuilder,
        );
      });

      test(
        'stays missingZorphyBuilder without a pubspec (keeps the #276 guard)',
        () {
          // No pubspec.yaml → no dependency graph to prove zorphy is absent,
          // so the guard keeps failing closed on a bare build.yaml.
          File(p.join(sandbox.path, 'build.yaml')).writeAsStringSync('''
targets:
  \$default:
    builders:
      json_serializable:
        enabled: true
''');
          expect(
            BuildYamlGuard.check(projectRoot: sandbox.path),
            BuildYamlStatus.missingZorphyBuilder,
          );
        },
      );
    });

    test(
      'scaffold() with null projectRoot writes build.yaml into the CWD (#276)',
      () async {
        // Covers the `projectRoot ?? Directory.current.path` fallback in
        // scaffold() (previously uncovered — zuraffa#276 coverage gap).
        //
        // We temporarily switch CWD into the sandbox so the scaffolded
        // build.yaml lands in an isolated dir and is cleaned up by tearDown.
        // CWD is always restored, even on assertion failure, so other test
        // files never inherit a deleted/temp CWD (see build_command_test.dart
        // CWD-contamination note). Issue #1632 dart_core lane: the window is
        // serialized through the same cross-isolate lock CliRunner's `-C`
        // windows use, so a sibling's raw window cannot flip the CWD
        // mid-scaffold.
        await CwdMutex.acquire();
        final savedCwd = Directory.current.path;
        Directory.current = sandbox.path;
        try {
          await BuildYamlGuard.scaffold();
          final written = File(p.join(sandbox.path, 'build.yaml'));
          expect(
            written.existsSync(),
            isTrue,
            reason: 'build.yaml not created',
          );
          expect(
            BuildYamlGuard.check(),
            BuildYamlStatus.ok,
            reason: 'scaffolded build.yaml (CWD) must register zorphy:zorphy',
          );
        } finally {
          // Restore a still-existing CWD. If the saved CWD was deleted by
          // another test file, fall back to the system temp dir (always valid).
          if (Directory(savedCwd).existsSync()) {
            Directory.current = savedCwd;
          } else {
            Directory.current = Directory.systemTemp.path;
          }
          CwdMutex.release();
        }
      },
    );

    test('missingZorphyBuilderMessage is actionable', () {
      final msg = BuildYamlGuard.missingZorphyBuilderMessage;
      expect(msg, contains('zorphy:zorphy'));
      expect(msg, contains('0 outputs'));
      expect(msg, contains('zfa setup'));
    });
  });
}
