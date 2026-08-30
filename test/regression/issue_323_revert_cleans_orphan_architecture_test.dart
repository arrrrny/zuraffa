@Tags(['regression', 'slow'])
// Each test spawns `dart bin/zfa.dart` sub-processes (JIT start-up is
// several seconds each) and runs multiple `zfa make` invocations. The
// package:test default (30s) is too tight: when a test times out, its
// tearDown deletes the workspace while the sub-process is still running,
// and the next `Directory.current` throws PathNotFoundException. Give the
// suite a generous per-test budget instead. (Library-level annotation —
// `Timeout` targets the library, not `main`.)
@Timeout(Duration(minutes: 6))
library;

// Regression tests for issue #323.
//
// `zfa make: re-modeling entity as value_object orphans previously
// generated CRUD architecture — no zfa cleanup path (revert only tracks
// current run)`.
//
// Repro (from the issue):
//   1. Originally (pre-#322): created ChatMessage as a plain entity with
//      an id field, generated full CRUD via
//      `zfa make ChatMessage --preset=crud --with=vpc,state,di,test,mock`.
//   2. After #322 merged: re-modeled ChatMessage as a value object
//      (`@ZValueObject`, no id). `zfa make` correctly skips the root
//      plugins and generates nothing for the VO.
//   3. Tried to clean up the old CRUD via
//      `zfa make ChatMessage --preset=crud --with=vpc,state,di,test,mock --revert`
//      — `zfa make --revert` only removed files from the CURRENT
//      generation run. Since the VO make generated nothing, the saved
//      plan was empty and `--revert` reported "No files generated",
//      leaving ~50 orphaned CRUD files on disk (54 analyze errors).
//
// The fix (this issue): `zfa make <Entity> --revert` now performs a
// "deep revert" that walks the canonical entity-snake-keyed paths the
// generators would produce (datasources dir, usecases dir, presentation
// pages dir, repository file, DI registrations, mock data, tests, ...)
// and deletes those that exist — regardless of whether the current run
// generated them. This makes `--revert` mean "remove the entity's
// generated architecture" uniformly, for entities AND value objects.
//
// The entity source file itself
// (`lib/src/domain/entities/<snake>/<snake>.dart`) is NEVER touched by
// deep revert — the entity is the source of truth, not generated
// architecture. Re-modeling is the user's job.
//
// These tests exercise:
//   - Part A: basic `--revert` after a successful CRUD generation still
//     works (no regression on the existing plan-based path).
//   - Part B: the #323 regression — re-model as value object, then
//     `--revert` cleans the orphaned CRUD architecture.
//   - Part C: `--revert --dry-run` lists but does not delete.
//   - Part D: `--revert` preserves the entity source file.
//   - Part E: `--revert` on an entity with no generated architecture is
//     a graceful no-op (exit 0, "No files generated" or empty deleted
//     list).
//   - Part F: `--revert` only deletes the named entity's architecture —
//     other entities' files in shared directories are untouched.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// Resolve package root at discovery time, before any test changes CWD.
final _zfaRoot = Directory.current.path;

void main() {
  group('#323 — zfa make --revert deep-cleans orphan architecture', () {
    late Directory workspace;
    late String outputDir;

    Future<ProcessResult> runZfa(List<String> args) {
      return runZfaSource([...args], workingDirectory: workspace.path);
    }

    setUp(() async {
  await initZfaSourceBin();
      workspace = await Directory.systemTemp.createTemp('issue_323_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      // Minimal pubspec — `zfa make` only needs the package to exist.
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_323_test_app
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: ${path.normalize(_zfaRoot)}
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    /// Writes a plain entity with a real `id: String` field — the
    /// pre-#322 shape that `zfa make` generates full CRUD for.
    Future<void> writeEntityWithId(String name) async {
      final snake = _toSnake(name);
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', snake),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, '$snake.dart')).writeAsString('''
class $name {
  final String id;
  final String label;

  const $name({required this.id, required this.label});
}

class ${name}Fields {
  static const Field<$name, String> id = Field<$name, String>(name: 'id');
  static const Field<$name, String> label =
      Field<$name, String>(name: 'label');
}
''');
    }

    /// Re-writes the entity source as a `@ZValueObject` (no id) — the
    /// #322 re-model that orphans the previously generated CRUD.
    Future<void> rewriteEntityAsValueObject(String name) async {
      final snake = _toSnake(name);
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', snake),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, '$snake.dart')).writeAsString('''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@ZValueObject
abstract class \$$name {
  String get label;
  DateTime get timestamp;
}
''');
    }

    /// Generates full CRUD for [name] (the same preset the issue repro
    /// uses). Returns the zfa exit code so tests can assert on it.
    Future<ProcessResult> generateCrud(String name) {
      return runZfa([
        'make',
        name,
        '--preset=crud',
        '--with=vpc,state,di,test,mock',
        '--methods=get,getList,create,update,delete,toggle',
        '--output',
        outputDir,
      ]);
    }

    /// Reverts the generated architecture for [name].
    Future<ProcessResult> revertEntity(
      String name, {
      bool dryRun = false,
      bool verbose = false,
    }) {
      final args = <String>[
        'make',
        name,
        '--preset=crud',
        '--with=vpc,state,di,test,mock',
        '--revert',
        '--output',
        outputDir,
      ];
      if (dryRun) args.add('--dry-run');
      if (verbose) args.add('--verbose');
      return runZfa(args);
    }

    /// The canonical architecture paths the generators produce for an
    /// entity — used to assert presence/absence after revert.
    List<String> expectedArchitecturePaths(String name) {
      final snake = _toSnake(name);
      return <String>[
        // data layer
        path.join(
          outputDir,
          'data',
          'datasources',
          snake,
          '${snake}_datasource.dart',
        ),
        path.join(
          outputDir,
          'data',
          'datasources',
          snake,
          '${snake}_mock_datasource.dart',
        ),
        path.join(
          outputDir,
          'data',
          'datasources',
          snake,
          '${snake}_remote_datasource.dart',
        ),
        path.join(
          outputDir,
          'data',
          'repositories',
          'data_${snake}_repository.dart',
        ),
        path.join(outputDir, 'data', 'mock', '${snake}_mock_data.dart'),
        // domain layer
        path.join(
          outputDir,
          'domain',
          'repositories',
          '${snake}_repository.dart',
        ),
        path.join(
          outputDir,
          'domain',
          'usecases',
          snake,
          'get_${snake}_usecase.dart',
        ),
        path.join(
          outputDir,
          'domain',
          'usecases',
          snake,
          'update_${snake}_usecase.dart',
        ),
        // di layer
        path.join(
          outputDir,
          'di',
          'repositories',
          '${snake}_repository_di.dart',
        ),
        path.join(outputDir, 'di', 'usecases', 'get_${snake}_usecase_di.dart'),
        path.join(
          outputDir,
          'di',
          'usecases',
          'update_${snake}_usecase_di.dart',
        ),
        // presentation layer
        path.join(
          outputDir,
          'presentation',
          'pages',
          snake,
          '${snake}_presenter.dart',
        ),
        path.join(
          outputDir,
          'presentation',
          'pages',
          snake,
          '${snake}_controller.dart',
        ),
        path.join(
          outputDir,
          'presentation',
          'pages',
          snake,
          '${snake}_state.dart',
        ),
        path.join(
          outputDir,
          'presentation',
          'pages',
          snake,
          '${snake}_view.dart',
        ),
      ];
    }

    /// The entity source path — must NEVER be deleted by `--revert`.
    String entitySourcePath(String name) {
      final snake = _toSnake(name);
      return path.join(outputDir, 'domain', 'entities', snake, '$snake.dart');
    }

    // ---------------------------------------------------------------------
    // Part A — basic `--revert` after a successful CRUD generation
    // ---------------------------------------------------------------------

    group('Part A — basic revert after CRUD generation', () {
      test('`zfa make <Entity> --revert` removes all generated '
          'architecture files for the entity', () async {
        await writeEntityWithId('Product');
        final gen = await generateCrud('Product');
        expect(
          gen.exitCode,
          equals(0),
          reason:
              'precondition: CRUD generation must succeed\n'
              'stdout: ${gen.stdout}\nstderr: ${gen.stderr}',
        );

        // Sanity check: at least the presenter + repository + a usecase
        // were generated (so we know revert has something to delete).
        final archPaths = expectedArchitecturePaths('Product');
        final presentBefore = archPaths.where((p) => File(p).existsSync());
        expect(
          presentBefore.isNotEmpty,
          isTrue,
          reason:
              'precondition: some architecture files must exist before '
              'revert. Looked for:\n${archPaths.join("\n")}',
        );

        // Revert.
        final rev = await revertEntity('Product');
        expect(
          rev.exitCode,
          equals(0),
          reason:
              'revert must exit 0\nstdout: ${rev.stdout}\nstderr: '
              '${rev.stderr}',
        );

        // Assert every canonical architecture path is gone.
        final stillPresent = archPaths
            .where((p) => File(p).existsSync())
            .toList();
        expect(
          stillPresent,
          isEmpty,
          reason:
              'after --revert, no canonical architecture files should '
              'remain. Still present:\n${stillPresent.join("\n")}',
        );

        // Entity-scoped directories should be gone (or empty) too.
        final snake = _toSnake('Product');
        final scopedDirs = [
          path.join(outputDir, 'data', 'datasources', snake),
          path.join(outputDir, 'domain', 'usecases', snake),
          path.join(outputDir, 'presentation', 'pages', snake),
        ];
        for (final dir in scopedDirs) {
          if (Directory(dir).existsSync()) {
            final dartFiles = Directory(dir)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))
                .toList();
            expect(
              dartFiles,
              isEmpty,
              reason:
                  'after --revert, entity-scoped directory $dir should '
                  'have no .dart files. Still contains:\n'
                  '${dartFiles.map((f) => f.path).join("\n")}',
            );
          }
        }
      });
    });

    // ---------------------------------------------------------------------
    // Part B — #323 regression: VO re-model orphans CRUD, revert cleans it
    // ---------------------------------------------------------------------

    group('Part B — #323 regression (VO re-model orphans CRUD)', () {
      test('re-modeling an entity as a value object leaves CRUD orphans '
          'on disk; `zfa make <Entity> --revert` cleans them up', () async {
        // 1. Originally: ChatMessage is a plain entity with an id.
        await writeEntityWithId('ChatMessage');
        final gen = await generateCrud('ChatMessage');
        expect(
          gen.exitCode,
          equals(0),
          reason:
              'precondition: original CRUD generation must succeed\n'
              'stdout: ${gen.stdout}\nstderr: ${gen.stderr}',
        );

        final archPaths = expectedArchitecturePaths('ChatMessage');
        final presentAfterGen = archPaths
            .where((p) => File(p).existsSync())
            .toList();
        expect(
          presentAfterGen.isNotEmpty,
          isTrue,
          reason:
              'precondition: CRUD generation must produce architecture '
              'files. None of these were found:\n${archPaths.join("\n")}',
        );

        // 2. Re-model as a value object (no id). `zfa make` should skip
        //    the root plugins and generate nothing — leaving the previous
        //    CRUD architecture on disk as orphans (#323).
        await rewriteEntityAsValueObject('ChatMessage');
        final voGen = await generateCrud('ChatMessage');
        expect(
          voGen.exitCode,
          equals(0),
          reason:
              'VO make must exit 0 (skips root plugins cleanly)\n'
              'stdout: ${voGen.stdout}\nstderr: ${voGen.stderr}',
        );
        expect(
          (voGen.stdout as String).contains('is a value object'),
          isTrue,
          reason: 'VO make must announce it is skipping root plugins',
        );

        // The orphans are STILL there — that is the bug. We don't assert
        // on this for the fix (the fix is in revert, not in VO make), but
        // we log it for diagnostic clarity.
        final orphansBeforeRevert = archPaths
            .where((p) => File(p).existsSync())
            .toList();
        expect(
          orphansBeforeRevert.isNotEmpty,
          isTrue,
          reason:
              'precondition for #323: the VO re-model must leave the '
              'previous CRUD architecture on disk as orphans. None found:\n'
              '${archPaths.join("\n")}',
        );

        // 3. `zfa make <Entity> --revert` must now clean up the orphans.
        final rev = await revertEntity('ChatMessage', verbose: true);
        expect(
          rev.exitCode,
          equals(0),
          reason:
              'revert must exit 0 even when the saved plan is empty '
              '(the deep-revert path handles orphans)\n'
              'stdout: ${rev.stdout}\nstderr: ${rev.stderr}',
        );

        final stillPresent = archPaths
            .where((p) => File(p).existsSync())
            .toList();
        expect(
          stillPresent,
          isEmpty,
          reason:
              'after --revert on a re-modeled entity, all orphan CRUD '
              'architecture must be gone. Still present:\n'
              '${stillPresent.join("\n")}\n'
              'revert stdout was:\n${rev.stdout}',
        );
      });
    });

    // ---------------------------------------------------------------------
    // Part C — --dry-run does not delete
    // ---------------------------------------------------------------------

    group('Part C — --dry-run does not delete', () {
      test('`zfa make <Entity> --revert --dry-run` leaves all architecture '
          'files on disk', () async {
        await writeEntityWithId('Order');
        final gen = await generateCrud('Order');
        expect(
          gen.exitCode,
          equals(0),
          reason:
              'precondition: CRUD generation must succeed\n'
              'stdout: ${gen.stdout}\nstderr: ${gen.stderr}',
        );

        final archPaths = expectedArchitecturePaths('Order');
        final presentBefore = archPaths
            .where((p) => File(p).existsSync())
            .toList();
        expect(
          presentBefore.isNotEmpty,
          isTrue,
          reason:
              'precondition: architecture files must exist before '
              'the dry-run revert',
        );

        final rev = await revertEntity('Order', dryRun: true);
        expect(
          rev.exitCode,
          equals(0),
          reason:
              'dry-run revert must exit 0\nstdout: ${rev.stdout}\n'
              'stderr: ${rev.stderr}',
        );

        final stillPresent = archPaths
            .where((p) => File(p).existsSync())
            .toList();
        expect(
          stillPresent,
          equals(presentBefore),
          reason:
              'dry-run must not delete any files. Files missing after '
              'dry-run (should still be there):\n'
              '${presentBefore.where((p) => !stillPresent.contains(p)).join("\n")}',
        );
      });
    });

    // ---------------------------------------------------------------------
    // Part D — entity source is preserved
    // ---------------------------------------------------------------------

    group('Part D — entity source is preserved', () {
      test('`zfa make <Entity> --revert` does NOT delete the entity source '
          'file', () async {
        await writeEntityWithId('Inventory');
        await generateCrud('Inventory');
        final entityFile = File(entitySourcePath('Inventory'));
        expect(
          entityFile.existsSync(),
          isTrue,
          reason: 'precondition: entity source must exist before revert',
        );

        final rev = await revertEntity('Inventory');
        expect(
          rev.exitCode,
          equals(0),
          reason:
              'revert must exit 0\nstdout: ${rev.stdout}\nstderr: '
              '${rev.stderr}',
        );

        expect(
          entityFile.existsSync(),
          isTrue,
          reason:
              'the entity source file is the source of truth, not '
              'generated architecture — `--revert` must never delete it. '
              'Missing after revert: ${entityFile.path}',
        );

        // The entity directory should still exist (with the source file).
        final snake = _toSnake('Inventory');
        final entityDir = Directory(
          path.join(outputDir, 'domain', 'entities', snake),
        );
        expect(
          entityDir.existsSync(),
          isTrue,
          reason: 'entity directory must survive revert',
        );
      });

      test('`zfa make <Entity> --revert` preserves the entity source even '
          'after VO re-model (#323 repro entity)', () async {
        await writeEntityWithId('TelemetryEvent');
        await generateCrud('TelemetryEvent');
        await rewriteEntityAsValueObject('TelemetryEvent');
        await generateCrud('TelemetryEvent'); // VO make — generates nothing

        final entityFile = File(entitySourcePath('TelemetryEvent'));
        expect(
          entityFile.existsSync(),
          isTrue,
          reason: 'precondition: VO entity source must exist',
        );

        final rev = await revertEntity('TelemetryEvent');
        expect(
          rev.exitCode,
          equals(0),
          reason:
              'revert must exit 0\nstdout: ${rev.stdout}\nstderr: '
              '${rev.stderr}',
        );

        expect(
          entityFile.existsSync(),
          isTrue,
          reason:
              'the (re-modeled) entity source file must survive revert. '
              'Missing: ${entityFile.path}',
        );
        // And the entity file should still contain the @ZValueObject
        // annotation we wrote — revert must not rewrite it.
        final content = await entityFile.readAsString();
        expect(
          content.contains('@ZValueObject'),
          isTrue,
          reason: 'entity source content must be untouched by revert',
        );
      });
    });

    // ---------------------------------------------------------------------
    // Part E — no architecture to revert is a graceful no-op
    // ---------------------------------------------------------------------

    group('Part E — graceful no-op', () {
      test(
        '`zfa make <Entity> --revert` on an entity with no generated '
        'architecture exits 0 and does not delete the entity source',
        () async {
          await writeEntityWithId('BrandNew');
          // No generateCrud call — no architecture exists.

          final rev = await revertEntity('BrandNew');
          expect(
            rev.exitCode,
            equals(0),
            reason:
                'revert on a fresh entity must exit 0\nstdout: '
                '${rev.stdout}\nstderr: ${rev.stderr}',
          );

          // Entity source untouched.
          expect(
            File(entitySourcePath('BrandNew')).existsSync(),
            isTrue,
            reason: 'fresh entity source must survive a no-op revert',
          );
          // No architecture magically created.
          final archPaths = expectedArchitecturePaths('BrandNew');
          final present = archPaths.where((p) => File(p).existsSync()).toList();
          expect(
            present,
            isEmpty,
            reason:
                'revert must not create files. Found:\n'
                '${present.join("\n")}',
          );
        },
      );
    });

    // ---------------------------------------------------------------------
    // Part F — revert only touches the named entity
    // ---------------------------------------------------------------------

    group('Part F — revert only touches the named entity', () {
      test('`zfa make <EntityA> --revert` does not delete EntityB '
          'architecture in shared directories', () async {
        await writeEntityWithId('Alpha');
        await writeEntityWithId('Beta');
        final genA = await generateCrud('Alpha');
        expect(
          genA.exitCode,
          equals(0),
          reason:
              'precondition: Alpha generation must succeed\n'
              'stdout: ${genA.stdout}\nstderr: ${genA.stderr}',
        );
        final genB = await generateCrud('Beta');
        expect(
          genB.exitCode,
          equals(0),
          reason:
              'precondition: Beta generation must succeed\n'
              'stdout: ${genB.stdout}\nstderr: ${genB.stderr}',
        );

        final betaArchBefore = expectedArchitecturePaths(
          'Beta',
        ).where((p) => File(p).existsSync()).toList();
        expect(
          betaArchBefore.isNotEmpty,
          isTrue,
          reason:
              'precondition: Beta architecture must exist before '
              'Alpha revert',
        );

        // Revert ONLY Alpha.
        final rev = await revertEntity('Alpha');
        expect(
          rev.exitCode,
          equals(0),
          reason:
              'Alpha revert must exit 0\nstdout: ${rev.stdout}\n'
              'stderr: ${rev.stderr}',
        );

        // Alpha architecture is gone.
        final alphaStillPresent = expectedArchitecturePaths(
          'Alpha',
        ).where((p) => File(p).existsSync()).toList();
        expect(
          alphaStillPresent,
          isEmpty,
          reason:
              'Alpha architecture must be gone after Alpha revert. '
              'Still present:\n${alphaStillPresent.join("\n")}',
        );

        // Beta architecture is intact.
        final betaStillPresent = expectedArchitecturePaths(
          'Beta',
        ).where((p) => File(p).existsSync()).toList();
        expect(
          betaStillPresent,
          equals(betaArchBefore),
          reason:
              'Beta architecture must be untouched by Alpha revert. '
              'Missing (should still be there):\n'
              '${betaArchBefore.where((p) => !betaStillPresent.contains(p)).join("\n")}',
        );
      });
    });
  });
}

/// Converts a PascalCase name to snake_case — mirrors the generator's
/// `StringUtils.camelToSnake` so the test asserts on the exact paths the
/// generator produces.
String _toSnake(String input) {
  if (input.isEmpty) return '';
  final result = <String>[];
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (i > 0 &&
        char.toLowerCase() != char &&
        char.toUpperCase() == char &&
        char != '_') {
      result.add('_');
    }
    result.add(char.toLowerCase());
  }
  return result.join();
}
