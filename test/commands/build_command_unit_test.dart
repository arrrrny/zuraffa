@Tags(['slow'])
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/build_command.dart';
import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';
import 'package:zuraffa/src/utils/zorphy_annotations.dart';

import '../helpers/project_root.dart';

/// In-process unit tests for `BuildCommand`'s `@visibleForTesting` helpers.
///
/// The integration tests in `build_command_test.dart` spawn `zfa build` as a
/// subprocess, which `dart test --coverage` cannot attribute line coverage to.
/// These tests exercise the same logic in-process (no subprocess, no
/// build_runner) so the self-healing + safety-net code paths get real line
/// coverage on the road to 100% (zuraffa#276).

/// Writes a zorphy v3 source at [libraryPath] (absolute, inside the test
/// sandbox, e.g. `<sandbox>/lib/src/foo.dart`): a `@ZorphyEntity`
/// declaring build_runner's shared part, with the URI derived by
/// [sharedPartUri] so the fixture can never drift from the real `_br_/`
/// convention. The library's project-relative path is everything after
/// the sandbox's `lib/` segment.
Future<void> writeV3Source(String libraryPath) async {
  final file = File(libraryPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    "import 'package:zorphy_annotation/zorphy_annotation.dart';\n\n"
    "part '${sharedPartUri(_projectRelative(libraryPath))}';\n\n"
    '@ZorphyEntity(principalKey: #id)\n'
    'abstract class \$Foo {\n  String get id;\n}\n',
  );
}

/// Writes the shared part a source at [libraryPath] declares, at the path
/// build_runner writes it (via [sharedPartPath]).
Future<void> writeSharedPart(String libraryPath) async {
  final root = _sandboxRoot(libraryPath);
  final part = File(
    p.join(root, sharedPartPath(_projectRelative(libraryPath))),
  );
  await part.parent.create(recursive: true);
  await part.writeAsString('// generated');
}

Future<void> writeColocatedSource(String libraryPath) async {
  final file = File(libraryPath);
  await file.parent.create(recursive: true);
  final partName = '${p.basenameWithoutExtension(libraryPath)}.zorphy.dart';
  await file.writeAsString(
    "import 'package:zorphy_annotation/zorphy_annotation.dart';\n\n"
    "part '$partName';\n\n"
    '@ZorphyEntity(principalKey: #id)\n'
    'abstract class \$Foo {\n  String get id;\n}\n',
  );
}

/// The sandbox root of an absolute [libraryPath]: everything before its
/// `lib` segment.
String _sandboxRoot(String libraryPath) {
  final segments = p.split(libraryPath);
  final libIndex = segments.lastIndexOf('lib');
  return p.joinAll(segments.sublist(0, libIndex));
}

/// [libraryPath] relative to its sandbox root (`lib/src/foo.dart`).
String _projectRelative(String libraryPath) => p
    .relative(libraryPath, from: _sandboxRoot(libraryPath))
    .replaceAll(r'\', '/');

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

      test(
        'true when lib/ has a build_runner shared part under _br_/',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/_br_/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/_br_/src/foo.part.dart'),
          ).writeAsString('// generated');
          expect(
            command.hasGeneratedOutputs(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test('a .part.dart outside _br_/ is source, not build output', () async {
        // Only build_runner's reserved directory is its output; a
        // hand-written part elsewhere must not count as generated.
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/helper.part.dart'),
        ).writeAsString('// hand-written');
        expect(command.hasGeneratedOutputs(projectRoot: sandbox.path), isFalse);
      });

      test(
        'true when lib/ has a colocated .zorphy.dart output (#2200)',
        () async {
          final output = File(
            p.join(
              sandbox.path,
              'lib/src/domain/entities/product/product.zorphy.dart',
            ),
          );
          await output.parent.create(recursive: true);
          await output.writeAsString('// generated');
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

      test('false when lib/ has no zorphy archetype', () async {
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

      test('true when a source carries @ZorphyEntity(...)', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('@ZorphyEntity(principalKey: #id)\nclass \$Foo {}');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test(
        'true when a source carries @ZorphyValue() (an embedded type)',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/foo.dart'),
          ).writeAsString('@ZorphyValue()\nabstract class \$Foo {}');
          expect(
            command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test('false when an archetype appears only in a // comment', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('// uses @ZorphyEntity annotation here\nclass Foo {}');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isFalse,
          reason: 'a comment mentioning an archetype must not count',
        );
      });

      test('false when an archetype appears only after code on a // comment '
          'line', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString('class Foo {} // see @ZorphyEntity for details');
        expect(
          command.hasZorphyAnnotatedSources(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('skips files under build_runner output (_br_/)', () async {
        // A generated part that merely textually contains an annotation
        // must not be taken as an annotated SOURCE.
        await Directory(
          p.join(sandbox.path, 'lib/_br_/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/_br_/src/foo.part.dart'),
        ).writeAsString('// @ZorphyEntity mentioned in a generated file');
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

      test(
        'returns true + a note when the project does not use zorphy (#1709)',
        () async {
          // A non-zuraffa package: its own build.yaml, a real pubspec with no
          // zorphy dependency, and no zorphy sources.
          final f = File(p.join(sandbox.path, 'build.yaml'));
          await f.writeAsString(
            'targets:\n  \$default:\n    builders:\n      slang_build_runner:\n        enabled: true\n',
          );
          await File(p.join(sandbox.path, 'pubspec.yaml')).writeAsString(
            'name: shadapp\ndependencies:\n  flutter:\n    sdk: flutter\n',
          );
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/app.dart'),
          ).writeAsString('class App {}');
          bool? result;
          final out = await capturePrint(() async {
            result = await command.ensureBuildYaml(projectRoot: sandbox.path);
          });
          expect(result, isTrue);
          expect(out, contains('no zorphy sources and no zorphy dependency'));
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

      test(
        'notes the not-applicable pass when the project does not use zorphy (#1709)',
        () async {
          await File(p.join(sandbox.path, 'build.yaml')).writeAsString(
            'targets:\n  \$default:\n    builders:\n      slang_build_runner:\n        enabled: true\n',
          );
          await File(p.join(sandbox.path, 'pubspec.yaml')).writeAsString(
            'name: shadapp\ndependencies:\n  flutter:\n    sdk: flutter\n',
          );
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/app.dart'),
          ).writeAsString('class App {}');
          final out = capturePrintSync(
            () => command.reportBuildYamlDryRun(projectRoot: sandbox.path),
          );
          expect(out, contains('no zorphy sources and no zorphy dependency'));
          expect(out, contains('issue #1709'));
          expect(out, isNot(contains('build would write 0 outputs')));
        },
      );
    });

    group('verifyOutputsOrFail (safety net — #276)', () {
      test(
        'returns true when there are no zorphy sources (nothing to gen)',
        () {
          // Empty sandbox — no lib/, no sources.
          expect(
            command.verifyOutputsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test('returns true when annotated sources exist AND their shared part '
          'exists', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await writeV3Source(p.join(sandbox.path, 'lib/src/foo.dart'));
        await writeSharedPart(p.join(sandbox.path, 'lib/src/foo.dart'));
        expect(command.verifyOutputsOrFail(projectRoot: sandbox.path), isTrue);
      });

      test('returns true when an annotated source has colocated .zorphy.dart '
          'output (#2200)', () async {
        final source = p.join(sandbox.path, 'lib/src/foo.dart');
        await writeColocatedSource(source);
        await File(
          p.join(sandbox.path, 'lib/src/foo.zorphy.dart'),
        ).writeAsString('// generated');
        expect(command.verifyOutputsOrFail(projectRoot: sandbox.path), isTrue);
      });

      test('returns false + actionable error when annotated sources exist but '
          '0 outputs', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await writeV3Source(p.join(sandbox.path, 'lib/src/foo.dart'));
        // No shared part anywhere — the exact #276 regression.
        bool? result;
        final out = capturePrintSync(() {
          result = command.verifyOutputsOrFail(projectRoot: sandbox.path);
        });
        expect(result, isFalse);
        expect(out, contains('wrote 0 outputs'));
        expect(out, contains('zorphy'));
        expect(out, contains('generate_for'));
        expect(out, contains('lib/src/**'));
        expect(out, contains('zfa setup'));
      });

      test(
        'does not false-positive when an archetype appears only in a comment',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          await File(
            p.join(sandbox.path, 'lib/src/foo.dart'),
          ).writeAsString('// @ZorphyEntity()\nclass Foo {}');
          expect(
            command.verifyOutputsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );
      test('#1322: 0 outputs + builder package missing from the dependency '
          'graph → names zorphy + prescribes `dart pub add --dev zorphy`, '
          'NOT the glob remedy', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await writeV3Source(p.join(sandbox.path, 'lib/src/foo.dart'));
        // The canonical build.yaml `zfa build` scaffolds, registering
        // zorphy:zorphy — with the correct globs. The real problem: the
        // zorphy builder package is not resolvable.
        await File(
          p.join(sandbox.path, 'build.yaml'),
        ).writeAsString(DependencyWirer.buildYamlContent);
        final dartTool = Directory(p.join(sandbox.path, '.dart_tool'));
        await dartTool.create(recursive: true);
        final entries = [
          'json_serializable',
          'source_gen',
          'test',
        ].map((n) => '{"name":"$n","rootUri":"../"}').join(',');
        await File(
          p.join(dartTool.path, 'package_config.json'),
        ).writeAsString('{"configVersion":2,"packages":[$entries]}');
        const buildOutput =
            '[WARNING] Ignoring options for unknown builder '
            '"zorphy:zorphy" found in build.yaml.';

        bool? result;
        final out = capturePrintSync(() {
          result = command.verifyOutputsOrFail(
            projectRoot: sandbox.path,
            buildOutput: buildOutput,
          );
        });
        expect(result, isFalse);
        // Names the missing package + the exact fix + the build_runner
        // signal (surfaced instead of the generic glob remedy).
        expect(out, contains('zorphy'));
        expect(out, contains('dart pub add --dev zorphy'));
        expect(out, contains('Ignoring options for unknown builder'));
        expect(out, contains('package_config.json'));
        // The misdiagnosis this spec kills: no glob remedy here.
        expect(out, isNot(contains('generate_for')));
        expect(out, isNot(contains('zfa setup')));
      });

      test('#1322 back-compat: 0 outputs with every builder package '
          'resolvable → the current glob remedy, no pub add', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await writeV3Source(p.join(sandbox.path, 'lib/src/foo.dart'));
        await File(
          p.join(sandbox.path, 'build.yaml'),
        ).writeAsString(DependencyWirer.buildYamlContent);
        final dartTool = Directory(p.join(sandbox.path, '.dart_tool'));
        await dartTool.create(recursive: true);
        final entries = [
          'zorphy',
          'json_serializable',
          'source_gen',
        ].map((n) => '{"name":"$n","rootUri":"../"}').join(',');
        await File(
          p.join(dartTool.path, 'package_config.json'),
        ).writeAsString('{"configVersion":2,"packages":[$entries]}');

        bool? result;
        final out = capturePrintSync(() {
          result = command.verifyOutputsOrFail(
            projectRoot: sandbox.path,
            buildOutput:
                '[WARNING] Ignoring options for unknown builder '
                '"zorphy:typo" found in build.yaml.',
          );
        });
        expect(result, isFalse);
        expect(out, contains('wrote 0 outputs'));
        expect(out, contains('generate_for'));
        expect(out, contains('lib/src/**'));
        expect(out, isNot(contains('pub add')));
      });
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
          ).writeAsString("part 'foo.g.dart';\n");
          // Only the .g.dart is missing — exactly the
          // json_serializable-failure-on-one-entity case from #379.
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

      test('false when an annotated source declares its shared part and the '
          'part is missing', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await writeV3Source(p.join(sandbox.path, 'lib/src/foo.dart'));
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('false when a source declares a missing colocated .zorphy.dart part '
          '(#2200)', () async {
        await writeColocatedSource(p.join(sandbox.path, 'lib/src/foo.dart'));
        final output = capturePrintSync(
          () => command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
        );
        expect(output, contains('foo.zorphy.dart'));
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test(
        'true when a source declares an existing colocated .zorphy.dart part '
        '(#2200)',
        () async {
          await writeColocatedSource(p.join(sandbox.path, 'lib/src/foo.dart'));
          await File(
            p.join(sandbox.path, 'lib/src/foo.zorphy.dart'),
          ).writeAsString('// generated');
          expect(
            command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test('true when an annotated source declares its shared part and the '
          'part exists', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await writeV3Source(p.join(sandbox.path, 'lib/src/foo.dart'));
        await writeSharedPart(p.join(sandbox.path, 'lib/src/foo.dart'));
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test(
        'true when a source with NO archetype declares a shared part that '
        'was never written (the builder contributes nothing to it)',
        () async {
          await Directory(
            p.join(sandbox.path, 'lib/src'),
          ).create(recursive: true);
          // The stale-directive shape: a library that declares the shared
          // part but carries no zorphy archetype. build_runner writes no
          // part for it, so a missing one is not a broken build.
          final lib = p.join(sandbox.path, 'lib/src/foo.dart');
          await File(lib).writeAsString(
            "import 'package:zorphy_annotation/zorphy_annotation.dart';\n\n"
            "part '${sharedPartUri('lib/src/foo.dart')}';\n\n"
            'class Foo {}\n',
          );
          expect(
            command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
            isTrue,
          );
        },
      );

      test('false when a declared .g.dart part is missing (regardless of '
          'archetype)', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString("part 'foo.g.dart';\n");
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isFalse,
        );
      });

      test('true when a part directive appears only inside a string literal '
          '(templates/fixtures — the 073 refactor-gate misfire)', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        // The entity-scaffolding template shape: a generated-part line
        // inside a template string is NOT a declaration.
        await File(p.join(sandbox.path, 'lib/src/template.dart')).writeAsString(
          "String generate(String entityName) {\n"
          "  return '''\n"
          "part '\$entityName.g.dart';\n"
          "''';\n"
          "}\n",
        );
        // The handwritten-fixture shape: an embedded fixture source
        // with its own part directive (issue-310 regression class).
        await File(
          p.join(sandbox.path, 'lib/src/fixture_source.dart'),
        ).writeAsString(
          "const String fixture = '''\n"
          "part 'search_result_price.g.dart';\n"
          "''';\n",
        );
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isTrue,
        );
      });

      test('true when every declared .g.dart part exists', () async {
        await Directory(
          p.join(sandbox.path, 'lib/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/src/foo.dart'),
        ).writeAsString("part 'foo.g.dart';\n");
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
          // check — only generated parts (a shared part, .g.dart) are
          // verified.
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
        ).writeAsString('part "foo.g.dart";\n');
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
        ).writeAsString("part '../_br_/src/foo.part.dart';\n");
        // A generated part is itself a `part of` file: it must not be
        // scanned as a source declaring parts.
        await Directory(
          p.join(sandbox.path, 'lib/_br_/src'),
        ).create(recursive: true);
        await File(
          p.join(sandbox.path, 'lib/_br_/src/foo.part.dart'),
        ).writeAsString("part of '../../src/foo.dart';\n");
        expect(
          command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path),
          isTrue,
        );
      });
    });

    group('analyzeReportsError (post-build guard — #395)', () {
      test('returns false for clean analyze output', () {
        const out = 'Analyzing lib/...\nNo issues found!';
        expect(BuildCommand.analyzeReportsError(out), isFalse);
      });

      test('returns false when only warnings/info are reported', () {
        const out = '''
Analyzing lib/...
   info - lib/src/foo.dart:10:3 - Some lint. - lint_code
   warning - lib/src/bar.dart:5:1 - Another lint. - warn_code
No issues found (2)''';
        expect(BuildCommand.analyzeReportsError(out), isFalse);
      });

      test('returns true when an error-severity line is present', () {
        const out = '''
Analyzing lib/...
   error - lib/src/services/artifact_service.dart:12:3 - Target of URI doesn't exist: 'package:zuraffa/...'. - uri_does_not_exist
   info - lib/src/foo.dart:1:1 - Some lint. - lint_code''';
        expect(BuildCommand.analyzeReportsError(out), isTrue);
      });

      test('returns true for the exact #395 import-depth symptom', () {
        // Reproduces the kind of analyze output the issue describes: an
        // undefined type caused by a missing/wrong-depth entity import.
        const out = '''
Analyzing lib/...
   error - lib/src/data/providers/artifact/artifact_provider.dart:14:5 - Undefined name 'StoreParams'. - undefined_identifier
   error - lib/src/data/providers/artifact/artifact_provider.dart:15:5 - Undefined name 'ArtifactStoreResult'. - undefined_identifier''';
        expect(BuildCommand.analyzeReportsError(out), isTrue);
      });

      test('does not match "error" inside a path or message', () {
        // The word "error" appears in a file path and a message, but not as
        // a severity marker at line start.
        const out = '''
Analyzing lib/...
   info - lib/src/error_handler.dart:1:1 - Handles error cases. - lint_code
   warning - lib/src/utils.dart:5:1 - Error path configured. - warn_code''';
        expect(BuildCommand.analyzeReportsError(out), isFalse);
      });
    });

    group('countAnalyzerIssues (issue #1035 — severity-filtered gate)', () {
      test('counts each severity bucket from one output block', () {
        const out = '''
Analyzing lib/...
   error - lib/src/a.dart:1:1 - Boom. - uri_does_not_exist
   error - lib/src/b.dart:2:2 - Boom again. - undefined_class
   warning - lib/src/c.dart:3:3 - Unused import. - unused_import
   info - lib/tdd/1035-lint-repro/a1_subject.dart:18:6 - Snake name. - non_constant_identifier_names
   info - lib/tdd/1035-lint-repro/u1_subject.dart:16:8 - Snake name. - non_constant_identifier_names
5 issues found.''';
        final counts = BuildCommand.countAnalyzerIssues(out);
        expect(counts.errors, 2);
        expect(counts.warnings, 1);
        expect(counts.infos, 2);
        expect(counts.blocksGate, isTrue);
      });

      test('info-only output never blocks the gate (info is style)', () {
        const out = '''
Analyzing lib/...
   info - lib/tdd/1035-lint-repro/a1_subject.dart:18:6 - Snake name. - non_constant_identifier_names
   info - test/tdd/1035-lint-repro/a1_test.dart:17:8 - Relative lib import. - avoid_relative_lib_imports
39 issues found.''';
        final counts = BuildCommand.countAnalyzerIssues(out);
        expect(counts.errors, 0);
        expect(counts.warnings, 0);
        expect(counts.infos, 2);
        expect(counts.blocksGate, isFalse);
      });

      test('a warning blocks the gate (error/warning are not style)', () {
        const out = '''
Analyzing lib/...
   warning - lib/tdd/1035-lint-repro/u5_subject.dart:12:8 - Duplicate import. - duplicate_import
1 issue found.''';
        final counts = BuildCommand.countAnalyzerIssues(out);
        expect(counts.blocksGate, isTrue);
      });

      test('severity words inside messages never count', () {
        const out = '''
Analyzing lib/...
   info - lib/src/error_path.dart:1:1 - warning error info words in prose. - lint_code
1 issue found.''';
        final counts = BuildCommand.countAnalyzerIssues(out);
        expect(counts.errors, 0);
        expect(counts.warnings, 0);
        expect(counts.infos, 1);
      });

      test('analyzeReportsError keeps the #942 error-only semantics on the '
          'shared counter', () {
        // The make tolerance gate reads the SAME line format through the
        // SAME counter — warnings/infos alone must never read as a
        // non-compiling tree.
        const warnOnly = '''
Analyzing lib/...
   warning - lib/src/c.dart:3:3 - Unused import. - unused_import
   info - lib/tdd/x_subject.dart:1:1 - Snake name. - non_constant_identifier_names''';
        expect(BuildCommand.analyzeReportsError(warnOnly), isFalse);
        expect(BuildCommand.countAnalyzerErrors(warnOnly), 0);
      });
    });

    group('analyzerOffendingPaths (issue #1412 — ownership evidence)', () {
      test('extracts deduped paths from error/warning lines in first-seen '
          'order', () {
        const out = '''
Analyzing lib/...
   error - lib/src/a.dart:1:1 - Boom. - uri_does_not_exist
   warning - lib/src/b.dart:2:2 - Warn. - some_lint
   warning - lib/src/b.dart:2:2 - Warn again. - other_lint
   info - lib/src/c.dart:3:3 - Style. - lint_code
5 issues found.''';
        expect(BuildCommand.analyzerOffendingPaths(out), [
          'lib/src/a.dart',
          'lib/src/b.dart',
        ]);
      });

      test('info lines and severity words in prose never fabricate '
          'offenders (the #1035 line-anchored discipline)', () {
        const out = '''
Analyzing lib/...
   info - lib/tdd/x_subject.dart:18:6 - Snake name. - non_constant_identifier_names
   info - lib/src/error_path.dart:1:1 - warning error words in prose. - lint_code
39 issues found.''';
        expect(BuildCommand.analyzerOffendingPaths(out), isEmpty);
      });
    });

    group('analyzeGateRemedyLines (issue #1412 — ownership-aware remedy)', () {
      test('hand-authored-only offenders name the files and drop the '
          '"Fix the generator" misdirection', () {
        const out = '''
Analyzing lib/...
   warning - lib/features/splash/view/splash_page.dart:12:9 - Unused import. - unused_import
   warning - lib/core/theme.dart:5:7 - Dead null aware expression. - dead_null_aware_expression
2 issues found.''';
        final lines = BuildCommand.analyzeGateRemedyLines(out);
        expect(lines, hasLength(2));
        expect(
          lines.first,
          'hand-authored offending (not generator output): '
          'lib/features/splash/view/splash_page.dart, lib/core/theme.dart',
        );
        expect(
          lines.last,
          'Fix the named files, or run with --no-analyze to skip this check.',
        );
      });

      test('generated-only offenders keep the existing "Fix the generator" '
          'remedy', () {
        const out = '''
Analyzing lib/...
   warning - lib/_br_/src/models/user.part.dart:10:1 - Warn. - some_lint
   warning - lib/src/mappers/user_mapper.g.dart:3:3 - Warn. - other_lint
2 issues found.''';
        expect(BuildCommand.analyzeGateRemedyLines(out), [
          'Fix the generator or run with --no-analyze to skip this check.',
        ]);
      });

      test('mixed offenders name both ownership groups', () {
        const out = '''
Analyzing lib/...
   warning - lib/_br_/src/models/user.part.dart:10:1 - Warn. - some_lint
   warning - lib/src/hand.dart:7:7 - Warn. - other_lint
2 issues found.''';
        final lines = BuildCommand.analyzeGateRemedyLines(out);
        expect(lines, [
          // Bug 1675: the generated-group label no longer enumerates the
          // suffix surfaces — suffix files AND make's directory-convention
          // output both classify as generator output now.
          'generator output offending (generated by zfa): '
              'lib/_br_/src/models/user.part.dart',
          'hand-authored offending (not generator output): lib/src/hand.dart',
          'Fix the named files, or run with --no-analyze to skip this check.',
        ]);
      });

      test('more than 3 offenders per group cap with a +N more remainder', () {
        const out = '''
Analyzing lib/...
   warning - lib/a.dart:1:1 - W1. - l
   warning - lib/b.dart:1:1 - W2. - l
   warning - lib/c.dart:1:1 - W3. - l
   warning - lib/d.dart:1:1 - W4. - l
   warning - lib/e.dart:1:1 - W5. - l
5 issues found.''';
        final lines = BuildCommand.analyzeGateRemedyLines(out);
        expect(
          lines.first,
          'hand-authored offending (not generator output): '
          'lib/a.dart, lib/b.dart, lib/c.dart (+2 more)',
        );
      });

      test('no parseable offenders fall back to the existing generator '
          'remedy (the gate verdict stands, the message stays honest)', () {
        const out = 'Analyzing lib/...\nNo issues found!';
        expect(BuildCommand.analyzeGateRemedyLines(out), [
          'Fix the generator or run with --no-analyze to skip this check.',
        ]);
      });
    });

    group('verifyAnalyzeOrFail (issue #415 flag; issue #1035 severity gate)', () {
      test(
        'runs `dart analyze lib` without the rejected --fatal-infos=value '
        'flag and passes on the current info-only lib',
        // `dart analyze lib` over the whole package takes ~30s on this repo,
        // so the default 30s per-test timeout is too tight. Give it headroom.
        timeout: const Timeout(Duration(minutes: 2)),
        () async {
          // Regression for #415: the guard previously invoked
          // `dart analyze --fatal-infos=false lib`, which the analyzer rejects
          // at flag-parse ("Flag option should not be given a value", exit 64)
          // — producing empty stdout and a falsely-clean result. The fixed
          // invocation drops the flag (info is non-fatal by default).
          // Issue #1035: the gate fails on error/warning only — the repo's
          // own lib is warning-free, so the info-level style lints pass.
          final command = BuildCommand();
          // Run analysis against the real package root explicitly so the check
          // is hermetic and does not inherit a process-CWD that another
          // parallel test file may have mutated (issue: non-hermetic CLI
          // tests). findProjectRoot() is CWD-independent (Platform.script).
          final repoRoot = await findProjectRoot();
          final ok = await command.verifyAnalyzeOrFail(projectRoot: repoRoot);
          expect(ok, isTrue);
        },
      );
    });
  });
}
