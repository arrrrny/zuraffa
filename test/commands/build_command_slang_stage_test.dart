/// Tests for the slang build stage (issue #1141, U6+U7+U8 — criterion 3:
/// `zfa build` succeeds after generation without manual i18n edits).
///
/// #834's design: "the loop must run `dart run slang` as a build step
/// (like zfa build) when translation sources change". The TDD loop
/// scaffolds `lib/i18n/*.i18n.json` sources (#965); this spec adds the
/// missing stage: `zfa build` runs the slang codegen BEFORE build_runner
/// when sources exist, defers to `slang_build_runner` when build.yaml
/// wires it, refuses with an actionable fix line when the toolchain is
/// unresolvable, and stays silent (zero drift) when no sources exist.
///
/// RED phase: the stage does not exist — compile red.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/build_slang_stage.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('slang_stage_1141_');
  });

  tearDown(() async {
    if (sandbox.existsSync()) {
      await sandbox.delete(recursive: true);
    }
  });

  Future<void> seedI18nSources() async {
    final file = File(p.join(sandbox.path, 'lib', 'i18n', 'strings.i18n.json'));
    await file.create(recursive: true);
    await file.writeAsString('{"auth": {"signIn": "Sign in"}}\n');
  }

  group('bug 1141 U6: the stage runs slang codegen when sources exist', () {
    test('lib/i18n/*.i18n.json sources are detected', () async {
      expect(
        SlangBuildStage.hasTranslationSources(projectRoot: sandbox.path),
        isFalse,
      );
      await seedI18nSources();
      expect(
        SlangBuildStage.hasTranslationSources(projectRoot: sandbox.path),
        isTrue,
      );
    });

    test('the stage resolves its decision from the project state', () async {
      // No sources → skipped, no output (zero drift).
      final bare = SlangBuildStage(projectRoot: sandbox.path);
      expect(bare.decision(), SlangStageDecision.skipped);
      expect(
        bare.previewLine(),
        isNull,
        reason: 'a skipped stage prints NOTHING (zero drift)',
      );

      // Sources + build.yaml wiring slang_build_runner → deferred.
      await seedI18nSources();
      await File(p.join(sandbox.path, 'build.yaml')).writeAsString('''
targets:
  \$default:
    builders:
      slang_build_runner:
        enabled: true
''');
      final deferred = SlangBuildStage(projectRoot: sandbox.path);
      expect(deferred.decision(), SlangStageDecision.deferred);

      // Sources without build.yaml slang wiring → run (the stage owns
      // the codegen).
      await File(p.join(sandbox.path, 'build.yaml')).writeAsString('''
targets:
  \$default:
    builders:
      zorphy:zorphy:
        enabled: true
''');
      final runner = SlangBuildStage(projectRoot: sandbox.path);
      expect(runner.decision(), SlangStageDecision.run);
      expect(runner.previewLine(), contains('slang'));
    });
  });

  group('bug 1141 U8: an unresolvable toolchain fails with a fix line', () {
    test('sources without a resolvable slang toolchain exit non-zero '
        'naming the dependency', () async {
      await seedI18nSources();
      // The sandbox has no pubspec — `dart run slang` cannot resolve.
      final stage = SlangBuildStage(projectRoot: sandbox.path);

      final result = await stage.run();

      expect(result.success, isFalse);
      expect(result.decision, SlangStageDecision.run);
      expect(result.fixLine, isNotNull);
      expect(result.fixLine, contains('slang'));
      expect(result.fixLine, contains('--> fix:'));
    });
  });

  group('bug 1141 U7: dry-run previews the stage without running it', () {
    test('the dry-run stage reports the sources but invokes nothing', () async {
      await seedI18nSources();
      final stage = SlangBuildStage(projectRoot: sandbox.path, dryRun: true);

      final result = await stage.run();

      // Dry-run never executes the codegen: no process, no verdict about
      // the toolchain — only the preview.
      expect(result.success, isTrue);
      expect(result.invoked, isFalse);
      expect(result.decision, SlangStageDecision.run);
      expect(
        result.preview,
        contains('strings.i18n.json'),
        reason: 'the preview names the translation sources found',
      );
    });
  });
}
