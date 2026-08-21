import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/build_command.dart';

/// In-process unit tests for `BuildCommand`'s `@visibleForTesting` helpers.
///
/// The integration tests in `build_command_test.dart` spawn `zfa build` as a
/// subprocess, which `dart test --coverage` cannot attribute line coverage to.
/// These tests exercise the same logic in-process (no subprocess, no
/// build_runner) so the self-healing + safety-net code paths get real line
/// coverage on the road to 100% (zuraffa#276).

/// Captures all `print()` output produced by [action] (sync) into a string.
String capturePrintSync(void Function() action) {
  final buf = <String>[];
  runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, msg) => buf.add(msg),
    ),
  );
  return buf.join('\n');
}

/// Captures all `print()` output produced by [action] (async) into a string.
Future<String> capturePrint(Future<void> Function() action) async {
  final buf = <String>[];
  await runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, msg) => buf.add(msg),
    ),
  );
  return buf.join('\n');
}

void main() {
  group('BuildCommand helpers (in-process, #276)', () {
    late Directory sandbox;
    late BuildCommand command;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('build_cmd_unit_');
      command = BuildCommand();
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    group('hasGeneratedOutputs', () {
      test('false when no lib/ or test/ dir exists', () {
        expect(command.hasGeneratedOutputs(projectRoot: sandbox.path), isFalse);
      });

      test('false when lib/ has only hand-written .dart files', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('class Foo {}');
        expect(command.hasGeneratedOutputs(projectRoot: sandbox.path), isFalse);
      });

      test('true when lib/ has a .zorphy.dart file', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.zorphy.dart'),
        ).writeAsString('// generated');
        expect(command.hasGeneratedOutputs(projectRoot: sandbox.path), isTrue);
      });

      test(
        'true when test/ has a .g.dart file (test/** generate_for)',
        () async {
          await Directory(p.join(sandbox.path, 'test')).create(recursive: true);
          await File(
            p.join(sandbox.path, 'test/foo.g.dart'),
          ).writeAsString('// generated');
          expect(
            command.hasGeneratedOutputs(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );
    });

    group('hasZorphyAnnotatedSources', () {
      test('false when no lib/ dir exists', () {
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('false when lib/ has no @Zorphy annotation', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('class Foo {}');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('true when a source carries @Zorphy(...)', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('@Zorphy(generateJson: true)\nclass Foo {}');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test('true when a source carries @ZorphyMixin', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('@ZorphyMixin()\nmixin Foo {}');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test('false when @Zorphy appears only in a // comment', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('// uses @Zorphy annotation here\nclass Foo {}');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isFalse,
          reason: 'a comment mentioning @Zorphy must not count as a source',
        );
      });

      test(
        'false when @Zorphy appears only after code on a // comment line',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/foo.dart'),
          ).writeAsString('class Foo {} // see @Zorphy for details');
          expect(
            command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
            isFalse,
          );
        },
      );

      test('skips generated .zorphy.dart files', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.zorphy.dart'),
        ).writeAsString('// @Zorphy mentioned in a generated file');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('does not match a different identifier like @ZorphyX', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('@ZorphyX\nclass Foo {}');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isFalse,
        );
      });
    });

    group('ensureBuildYaml', () {
      test('scaffolds build.yaml when missing and returns true', () async {
        final out = await capturePrint(
          () => command.ensureBuildYaml(projectRoot: sandbox.path),
        );
        expect(File(p.join(sandbox.path, 'build.yaml')).existsSync(), isTrue);
        expect(out, contains('No build.yaml found'));
        expect(out, contains('scaffolding'));
        expect(out, contains('Created: build.yaml'));
        // Idempotent: a second call sees an OK build.yaml and returns true.
        final result = await command.ensureBuildYaml(projectRoot: sandbox.path);
        expect(result, isTrue);
      });

      test('returns true without rewriting a valid build.yaml', () async {
        final f = File(p.join(sandbox.path, 'build.yaml'));
        await f.writeAsString(
          'targets:\n  \$default:\n    builders:\n      zorphy:zorphy:\n        enabled: true\n',
        );
        final mtimeBefore = f.statSync().modified;
        final result = await command.ensureBuildYaml(projectRoot: sandbox.path);
        expect(result, isTrue);
        expect(
          f.statSync().modified,
          mtimeBefore,
          reason: 'must not rewrite a valid build.yaml',
        );
      });

      test(
        'returns false + actionable error when zorphy builder is missing',
        () async {
          final f = File(p.join(sandbox.path, 'build.yaml'));
          await f.writeAsString(
            'targets:\n  \$default:\n    builders:\n      json_serializable:\n        enabled: true\n',
          );
          bool? result;
          final out = await capturePrint(() async {
            result = await command.ensureBuildYaml(projectRoot: sandbox.path);
          });
          expect(result, isFalse);
          expect(out, contains('does not register the zorphy builder'));
          expect(out, contains('zorphy:zorphy'));
          expect(out, contains('zfa setup'));
          // The user's build.yaml must be left untouched.
          expect(f.readAsStringSync(), isNot(contains('zorphy:zorphy')));
        },
      );
    });

    group('reportBuildYamlDryRun', () {
      test('announces would-scaffold when build.yaml is missing', () async {
        final out = capturePrintSync(
          () => command.reportBuildYamlDryRun(projectRoot: sandbox.path),
        );
        expect(out, contains('Would scaffold'));
        expect(
          File(p.join(sandbox.path, 'build.yaml')).existsSync(),
          isFalse,
          reason: 'dry-run must not write',
        );
      });

      test('warns when build.yaml omits the zorphy builder', () async {
        await File(p.join(sandbox.path, 'build.yaml')).writeAsString(
          'targets:\n  \$default:\n    builders:\n      json_serializable:\n        enabled: true\n',
        );
        final out = capturePrintSync(
          () => command.reportBuildYamlDryRun(projectRoot: sandbox.path),
        );
        expect(out, contains('omits the zorphy builder'));
        expect(out, contains('0 outputs'));
      });

      test('prints nothing when build.yaml is ok', () async {
        await File(p.join(sandbox.path, 'build.yaml')).writeAsString(
          'targets:\n  \$default:\n    builders:\n      zorphy:zorphy:\n        enabled: true\n',
        );
        final out = capturePrintSync(
          () => command.reportBuildYamlDryRun(projectRoot: sandbox.path),
        );
        expect(out, '');
      });
    });

    group('verifyOutputsOrFail (safety net — #276)', () {
      test(
        'returns true when there are no @Zorphy sources (nothing to gen)',
        () {
          // Empty sandbox — no lib/, no sources.
          expect(
            command.verifyOutputsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test(
        'returns true when @Zorphy sources exist AND outputs exist',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/foo.dart'),
          ).writeAsString('@Zorphy()\nclass Foo {}');
          await File(
            p.join(sandbox.path, 'lib/src/foo.zorphy.dart'),
          ).writeAsString('// generated');
          expect(
            command.verifyOutputsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test(
        'returns false + actionable error when @Zorphy sources exist but 0 outputs',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/foo.dart'),
          ).writeAsString('@Zorphy(generateJson: true)\nclass Foo {}');
          // No .zorphy.dart / .g.dart anywhere — the exact #276 regression.
          bool? result;
          final out = capturePrintSync(() {
            result = command.verifyOutputsOrFail(projectRoot: sandbox.path);
          });
          expect(result, isFalse);
          expect(out, contains('wrote 0 outputs'));
          expect(out, contains('@Zorphy'));
          expect(out, contains('generate_for'));
          expect(out, contains('lib/src/**'));
          expect(out, contains('zfa setup'));
        },
      );

      test(
        'does not false-positive when @Zorphy is only in a comment',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/foo.dart'),
          ).writeAsString('// @Zorphy\nclass Foo {}');
          expect(
            command.verifyOutputsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );
    });

    group('countEntities', () {
      test('returns 0 when no entities directory exists', () async {
        expect(await command.countEntities(projectRoot: sandbox.path), 0);
      });

      test(
        'counts entity dirs that have a matching <name>.dart file',
        () async {
          final entitiesDir = Directory(
            p.join(sandbox.path, 'lib/src/domain/entities/user'),
          );
          await entitiesDir.create(recursive: true);
          await File(
            p.join(entitiesDir.path, 'user.dart'),
          ).writeAsString('class User {}');
          // A dir WITHOUT a matching dart file must not count.
          await Directory(
            p.join(sandbox.path, 'lib/src/domain/entities/ghost'),
          ).create(recursive: true);
          expect(await command.countEntities(projectRoot: sandbox.path), 1);
        },
      );
    });

    group('countDartFiles', () {
      test('returns 0 when no lib/ directory exists', () async {
        expect(await command.countDartFiles(projectRoot: sandbox.path), 0);
      });

      test('counts all .dart files under lib/ recursively', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(p.join(sandbox.path, 'lib/a.dart')).writeAsString('');
        await File(p.join(sandbox.path, 'lib/src/b.dart')).writeAsString('');
        await File(p.join(sandbox.path, 'lib/src/c.dart')).writeAsString('');
        expect(await command.countDartFiles(projectRoot: sandbox.path), 3);
      });
    });

    group('verifyDeclaredPartsOrFail (#379)', () {
      test('true when no lib/ or test/ dir exists', () {
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test('true when sources declare no generated parts', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('class Foo {}');
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test(
        'false when a source declares a missing .g.dart part (#379)',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src/domain/entities/foo'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/domain/entities/foo/foo.dart'),
          ).writeAsString("part 'foo.zorphy.dart';\npart 'foo.g.dart';\n");
          // .zorphy.dart exists but .g.dart is missing — exactly the
          // json_serializable-failure-on-one-entity case from #379.
          await File(
            p.join(sandbox.path, 'lib/src/domain/entities/foo/foo.zorphy.dart'),
          ).writeAsString('// generated');
          final output = capturePrintSync(
            () => command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          );
          expect(output, contains('foo.g.dart'));
          expect(
            command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
            isFalse,
          );
        },
      );

      test('false when a declared .zorphy.dart part is missing', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString("part 'foo.zorphy.dart';\n");
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('true when all declared generated parts exist', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString("part 'foo.zorphy.dart';\npart 'foo.g.dart';\n");
        await File(
          p.join(sandbox.path, 'lib/src/foo.zorphy.dart'),
        ).writeAsString('// generated');
        await File(
          p.join(sandbox.path, 'lib/src/foo.g.dart'),
        ).writeAsString('// generated');
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test(
        'ignores hand-written multi-part libraries (non-generated parts)',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          // A hand-written library with a missing helper part must NOT trip the
          // check — only .zorphy.dart / .g.dart parts are verified.
          await File(
            p.join(sandbox.path, 'lib/src/lib.dart'),
          ).writeAsString("part 'helper.dart';\n");
          expect(
            command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test('matches double-quoted part declarations too', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('part "foo.zorphy.dart";\n');
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('does not re-check the generated part files themselves', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString("part 'foo.zorphy.dart';\n");
        await File(
          p.join(sandbox.path, 'lib/src/foo.zorphy.dart'),
        ).writeAsString("part of 'foo.dart';\n");
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isTrue,
        );
      });
    });
  });
}
