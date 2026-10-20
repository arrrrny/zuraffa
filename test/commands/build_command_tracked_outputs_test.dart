@Tags(['e2e'])
library;

// Spec 1540 — build-command restore-or-refuse + completeness-gate remedy
// tests (fast tier, in-process — the build_command_unit_test.dart pattern).
//
// The recovery orchestration and the gate's git-tracked remedy are exercised
// against real `git init` sandboxes (skip when git is unavailable). The
// docs-content assertion (A8) keeps the remedy's documentation target honest.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/build_command.dart';
import 'package:zuraffa/src/core/generation/tracked_generated_output_guard.dart';

Future<bool> _gitAvailable() async {
  try {
    final r = await Process.run('git', ['--version']);
    return r.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<void> _git(Directory cwd, List<String> args) async {
  final r = await Process.run('git', args, workingDirectory: cwd.path);
  if (r.exitCode != 0) {
    fail('git ${args.join(' ')} failed (${r.exitCode}):\n${r.stderr}');
  }
}

Future<void> _initRepo(Directory root) async {
  await _git(root, ['init']);
  await _git(root, ['add', '-A']);
  await _git(root, [
    '-c',
    'user.name=spec1540',
    '-c',
    'user.email=spec1540@example.com',
    'commit',
    '-m',
    'init',
    '--allow-empty',
  ]);
}

/// Captures all `print()` output produced by [action] into a string.
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

Future<void> main() async {
  final gitOk = await _gitAvailable();

  group('BuildCommand spec-1540 tracked-output recovery', () {
    late Directory sandbox;
    late BuildCommand command;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('spec1540_build_');
      command = BuildCommand();
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    Future<TrackedGeneratedSnapshot> snapshotWithPlaceholder(
      String relPath,
      String content,
    ) async {
      final file = File(p.join(sandbox.path, relPath));
      await file.create(recursive: true);
      await file.writeAsString(content, flush: true);
      await _initRepo(sandbox);
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      return guard.capture();
    }

    test('U8: recovery restores the deletion and prints the FR-3 message '
        '(path, owning library, both excludes, doc ref)', () async {
      const placeholder = 'lib/src/engine/events/engine_event.g.dart';
      // Snapshot BEFORE the deletion (the pre-build timeline).
      final snapshot = await snapshotWithPlaceholder(
        placeholder,
        '// placeholder\n',
      );
      await File(p.join(sandbox.path, placeholder)).delete();
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);

      final out = await capturePrint(
        () => command.recoverTrackedGeneratedOutputs(guard, snapshot),
      );

      expect(File(p.join(sandbox.path, placeholder)).existsSync(), isTrue);
      expect(
        File(p.join(sandbox.path, placeholder)).readAsStringSync(),
        '// placeholder\n',
      );
      expect(out, contains(placeholder));
      expect(
        out,
        contains('lib/src/engine/events/engine_event.dart'),
        reason: 'convention-derived owning library is named',
      );
      expect(out, contains('json_serializable'));
      expect(out, contains('source_gen:combining_builder'));
      expect(out, contains(kHandAuthoredPlaceholderDoc));
    }, skip: gitOk ? false : 'git binary unavailable');

    test('U9/A2: recovery REFUSES (returns false, prints the git checkout '
        'remedy) when the deletion cannot be restored', () async {
      const placeholder = 'lib/events/engine_event.g.dart';
      // Snapshot BEFORE the removal (the pre-build timeline).
      final snapshot = await snapshotWithPlaceholder(
        placeholder,
        '// placeholder\n',
      );
      // Simulate the larger anomaly: the whole directory is gone, so the
      // restore cannot write the file back.
      await Directory(
        p.join(sandbox.path, 'lib', 'events'),
      ).delete(recursive: true);
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);

      var verdict = true;
      final out = await capturePrint(() async {
        verdict = await command.recoverTrackedGeneratedOutputs(guard, snapshot);
      });

      expect(
        verdict,
        isFalse,
        reason: 'a failed restore must refuse, not report success',
      );
      expect(out, contains('git checkout -- $placeholder'));
      expect(out, contains(kHandAuthoredPlaceholderDoc));
      expect(File(p.join(sandbox.path, placeholder)).existsSync(), isFalse);
    }, skip: gitOk ? false : 'git binary unavailable');

    test(
      'recovery is a silent no-op when nothing tracked was deleted',
      () async {
        await snapshotWithPlaceholder('lib/a.g.dart', '// a\n');
        final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
        final snapshot = await guard.capture();

        final out = await capturePrint(
          () => command.recoverTrackedGeneratedOutputs(guard, snapshot),
        );
        expect(
          out,
          isEmpty,
          reason: 'no deletions → no spec-1540 output on the happy path',
        );
      },
      skip: gitOk ? false : 'git binary unavailable',
    );
  });

  group('verifyDeclaredPartsOrFail spec-1540 remedy (US2/A5)', () {
    late Directory sandbox;
    late BuildCommand command;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('spec1540_gate_');
      command = BuildCommand();
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    /// Seeds `lib/src/engine/events/engine_event.dart` declaring the part
    /// and (optionally) tracks the placeholder in git.
    Future<void> seedSource({
      required String partName,
      required bool trackPart,
    }) async {
      final source = File(
        p.join(
          sandbox.path,
          'lib',
          'src',
          'engine',
          'events',
          'engine_event.dart',
        ),
      );
      await source.create(recursive: true);
      await source.writeAsString('''
part '$partName';

sealed class EngineEvent {
  const EngineEvent();
}
''');
      final partFile = File(
        p.join(sandbox.path, 'lib', 'src', 'engine', 'events', partName),
      );
      await partFile.writeAsString('// part of engine_event;\n');
      if (trackPart) {
        await _initRepo(sandbox);
        // Delete AFTER tracking: the gate sees a declared-but-missing part
        // whose path is git-tracked — the dead-end scenario.
        await partFile.delete();
      } else {
        // Untracked variant: the placeholder is removed BEFORE the repo
        // snapshot, so git never tracked it.
        await partFile.delete();
        await _initRepo(sandbox);
      }
    }

    test(
      'A5a: tracked missing part → remedy names git checkout + doc',
      () async {
        await seedSource(partName: 'engine_event.g.dart', trackPart: true);
        var verdict = true;
        final out = await capturePrint(() async {
          verdict = command.verifyDeclaredPartsOrFail(
            projectRoot: sandbox.path,
          );
        });
        expect(verdict, isFalse);
        expect(
          out,
          contains('git checkout -- lib/src/engine/events/engine_event.g.dart'),
        );
        expect(out, contains(kHandAuthoredPlaceholderDoc));
      },
      skip: gitOk ? false : 'git binary unavailable',
    );

    test('A5b: untracked missing part → message unchanged (no spec-1540 '
        'remedy)', () async {
      await seedSource(partName: 'engine_event.g.dart', trackPart: false);
      var verdict = true;
      final out = await capturePrint(() async {
        verdict = command.verifyDeclaredPartsOrFail(projectRoot: sandbox.path);
      });
      expect(verdict, isFalse);
      expect(out, isNot(contains('git checkout --')));
      expect(out, isNot(contains(kHandAuthoredPlaceholderDoc)));
      expect(out, contains('engine_event.dart -> engine_event.g.dart'));
    }, skip: gitOk ? false : 'git binary unavailable');

    test(
      'A5c: non-git project with missing part → unchanged message',
      () async {
        final source = File(p.join(sandbox.path, 'lib', 'engine_event.dart'));
        await source.create(recursive: true);
        await source.writeAsString("part 'engine_event.g.dart';\n");
        var verdict = true;
        final out = await capturePrint(() async {
          verdict = command.verifyDeclaredPartsOrFail(
            projectRoot: sandbox.path,
          );
        });
        expect(verdict, isFalse);
        expect(out, isNot(contains('git checkout --')));
      },
      skip: gitOk ? false : 'git binary unavailable',
    );
  });

  group('hand-authored placeholder docs (US4/A8)', () {
    test('docs page exists and documents both builder exclusions', () {
      final doc = File(
        p.join(
          Directory.current.path,
          'docs',
          'hand-authored-g-dart-placeholders.md',
        ),
      );
      expect(doc.existsSync(), isTrue, reason: '${doc.path} must exist (FR-9)');
      final text = doc.readAsStringSync();
      expect(text, contains('json_serializable'));
      expect(text, contains('source_gen:combining_builder'));
      expect(text, contains('generate_for'));
      expect(text, contains('exclude'));
      expect(text, contains('engine_event'));
    });
  });

  // Issue #1953: a FAILED build that REWROTE tracked generated-name files
  // must not keep the half-applied rewrites — restore-or-refuse extends
  // from deletions (spec 1540) to rewrites, and the terminal failure
  // verdict re-prints the captured diagnostic tail so wrapper-truncated
  // output cannot lose the actual error.
  group('BuildCommand rewrite recovery + failure diagnostic (issue #1953)', () {
    late Directory sandbox;
    late BuildCommand command;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('issue1953_build_');
      command = BuildCommand();
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    Future<TrackedGeneratedSnapshot> snapshotWithPlaceholder(
      String relPath,
      String content,
    ) async {
      final file = File(p.join(sandbox.path, relPath));
      await file.create(recursive: true);
      await file.writeAsString(content, flush: true);
      await _initRepo(sandbox);
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      return guard.capture();
    }

    test('B1: rewrite recovery restores pre-build bytes and prints the '
        'config-fix remedy', () async {
      const placeholder = 'lib/src/cache/hive_registrar.dart';
      const pre =
          '// placeholder\n'
          "import 'package:zuraffa/zuraffa.dart' hide DeviceInfo;\n";
      final snapshot = await snapshotWithPlaceholder(placeholder, pre);
      // The registrar generator clobbered the placeholder mid-build, then
      // the combining builder failed the build.
      await File(
        p.join(sandbox.path, placeholder),
      ).writeAsString('// clobbered\nimport gone wrong;\n');
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);

      var verdict = true;
      final out = await capturePrint(() async {
        verdict = await command.recoverRewrittenTrackedOutputs(guard, snapshot);
      });

      expect(verdict, isTrue);
      expect(
        File(p.join(sandbox.path, placeholder)).readAsStringSync(),
        pre,
        reason: 'the failed build must not keep the clobbered bytes',
      );
      expect(out, contains(placeholder));
      expect(out, contains('source_gen:combining_builder'));
      expect(
        out,
        contains('exclude: [$placeholder]'),
        reason: 'the remedy points at the exact build.yaml exclusion',
      );
      expect(out, contains(kHandAuthoredPlaceholderDoc));
    }, skip: gitOk ? false : 'git binary unavailable');

    test('B2: rewrite recovery is a silent no-op when nothing was '
        'rewritten', () async {
      await snapshotWithPlaceholder('lib/src/a.g.dart', '// a\n');
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      final snapshot = await guard.capture();

      final out = await capturePrint(
        () => command.recoverRewrittenTrackedOutputs(guard, snapshot),
      );
      expect(out, isEmpty);
    }, skip: gitOk ? false : 'git binary unavailable');

    test('B3: rewrite recovery REFUSES when the restore cannot write '
        '(unwritable file)', () async {
      const placeholder = 'lib/src/cache/hive_registrar.dart';
      final snapshot = await snapshotWithPlaceholder(placeholder, '// pre\n');
      // The generator clobbered the placeholder and left it unwritable, so
      // the restore cannot write the pre-build bytes back.
      final file = File(p.join(sandbox.path, placeholder));
      await file.writeAsString('// clobbered\n');
      await Process.run('chmod', ['444', file.path]);
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);

      var verdict = true;
      final out = await capturePrint(() async {
        verdict = await command.recoverRewrittenTrackedOutputs(guard, snapshot);
      });
      expect(verdict, isFalse, reason: 'a failed restore must refuse');
      expect(out, contains('git checkout -- $placeholder'));
    }, skip: gitOk ? false : 'git binary unavailable');

    test('B4: printBuildFailureDiagnostic re-prints the captured output '
        'tail, capped', () async {
      final lines = List<String>.generate(120, (i) => 'line $i');
      lines[119] = 'source_gen:combining_builder failed on hive_registrar';

      final out = await capturePrint(() async {
        command.printBuildFailureDiagnostic(lines.join('\n'));
      });

      expect(
        out,
        contains('source_gen:combining_builder failed on hive_registrar'),
        reason: 'the final summary line — the actual diagnostic — survives',
      );
      expect(out, contains('line 80'));
      expect(
        out,
        isNot(contains('line 0\n')),
        reason: 'only the tail is re-printed',
      );
      final printed = out
          .split('\n')
          .where((l) => l.startsWith('line '))
          .length;
      expect(printed, lessThan(80), reason: 'the tail is capped');
    });

    test('B5: printBuildFailureDiagnostic is silent on empty output', () async {
      final out = await capturePrint(() async {
        command.printBuildFailureDiagnostic('');
      });
      expect(out, isEmpty);
    });
  });
}
