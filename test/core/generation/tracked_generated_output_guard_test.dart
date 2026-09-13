// Spec 1540 — TrackedGeneratedOutputGuard unit tests (fast tier).
//
// Drives the snapshot/detect/restore contract against REAL `git init`
// sandboxes in system temp. Skips when the `git` binary is unavailable so
// the suite stays portable (CI and dev containers always have git).
//
// Behaviors: A1 (byte-identical restore), A3 (disabled outside git),
// A4 (regenerated tracked file never flagged), U1-U7 (test-list.md).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/core/generation/tracked_generated_output_guard.dart';

/// True when `git` is executable; cached for the run.
Future<bool> _gitAvailable() async {
  try {
    final r = await Process.run('git', ['--version']);
    return r.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Runs one git command in [cwd]; fails the test on non-zero.
Future<void> _git(
  Directory cwd,
  List<String> args, {
  bool allowFailure = false,
}) async {
  final r = await Process.run('git', args, workingDirectory: cwd.path);
  if (r.exitCode != 0 && !allowFailure) {
    fail('git ${args.join(' ')} failed (${r.exitCode}):\n${r.stderr}');
  }
}

/// git init + track every current file (index + commit).
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
  ], allowFailure: true);
}

Future<void> main() async {
  final gitOk = await _gitAvailable();

  group('TrackedGeneratedOutputGuard (spec 1540)', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('spec1540_guard_');
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    Future<File> seedPlaceholder(String relPath, String content) async {
      final file = File(p.join(sandbox.path, relPath));
      await file.create(recursive: true);
      await file.writeAsString(content, flush: true);
      return file;
    }

    Future<TrackedGeneratedSnapshot> captureInRepo() async {
      await _initRepo(sandbox);
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      return guard.capture();
    }

    test('U1: gitTrackedFiles lists tracked paths, suffix-filtered, '
        'forward slashes', () async {
      await seedPlaceholder(
        'lib/src/engine/events/engine_event.g.dart',
        '// placeholder\n',
      );
      await seedPlaceholder('lib/notes.md', 'notes\n');
      await _initRepo(sandbox);
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      final tracked = await guard.gitTrackedFiles();
      expect(tracked, contains('lib/src/engine/events/engine_event.g.dart'));
      expect(tracked, isNot(contains('lib/notes.md')));
    }, skip: gitOk ? false : 'git binary unavailable');

    test('U2: capture() includes tracked generated-name files with exact '
        'bytes and skips untracked ones', () async {
      const content = '// hand-authored placeholder — DO NOT regenerate\n';
      await seedPlaceholder(
        'lib/src/engine/events/engine_event.g.dart',
        content,
      );
      final snapshot = await captureInRepo();
      // Scratch output created AFTER the snapshot (and never tracked): the
      // guard's membership is the git index, so this is never captured.
      await seedPlaceholder('lib/untracked.g.dart', '// scratch\n');
      expect(snapshot.enabled, isTrue);
      expect(
        snapshot.files,
        contains('lib/src/engine/events/engine_event.g.dart'),
      );
      expect(snapshot.files, isNot(contains('lib/untracked.g.dart')));
      expect(
        utf8.decode(
          snapshot.files['lib/src/engine/events/engine_event.g.dart']!,
        ),
        content,
      );
    }, skip: gitOk ? false : 'git binary unavailable');

    test('U3: capture() is disabled (empty) outside a git work tree', () async {
      await seedPlaceholder('lib/engine_event.g.dart', '// x\n');
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      final tracked = await guard.gitTrackedFiles();
      expect(tracked, isEmpty);
      final snapshot = await guard.capture();
      expect(snapshot.enabled, isFalse);
      expect(snapshot.files, isEmpty);
      expect(guard.detectDeleted(snapshot), isEmpty);
    }, skip: gitOk ? false : 'git binary unavailable');

    test(
      'A3: non-git project → capture/detect/restore are silent no-ops',
      () async {
        await seedPlaceholder('lib/engine_event.g.dart', '// x\n');
        final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
        final snapshot = await guard.capture();
        final deleted = guard.detectDeleted(snapshot);
        final result = await guard.restore(snapshot, deleted);
        expect(deleted, isEmpty);
        expect(result.restored, isEmpty);
        expect(result.failed, isEmpty);
      },
      skip: gitOk ? false : 'git binary unavailable',
    );

    test('A4: regenerated tracked .g.dart (exists pre and post) is never '
        'flagged or rewritten', () async {
      const pre = '// placeholder\n';
      final file = await seedPlaceholder(
        'lib/src/engine/events/engine_event.g.dart',
        pre,
      );
      final snapshot = await captureInRepo();
      // The build "regenerates" the file: different content, still exists.
      await file.writeAsString('// GENERATED — regenerated this build\n');
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      final deleted = guard.detectDeleted(snapshot);
      expect(
        deleted,
        isEmpty,
        reason: 'a file that exists post-build is not a deletion',
      );
      expect(
        file.readAsStringSync(),
        '// GENERATED — regenerated this build\n',
        reason: 'the guard must not touch existing files',
      );
    }, skip: gitOk ? false : 'git binary unavailable');

    test(
      'U4: detectDeleted() returns only snapshot members absent on disk',
      () async {
        await seedPlaceholder('lib/a.g.dart', '// a\n');
        await seedPlaceholder('lib/b.g.dart', '// b\n');
        final snapshot = await captureInRepo();
        await File(p.join(sandbox.path, 'lib', 'a.g.dart')).delete();
        final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
        expect(guard.detectDeleted(snapshot), ['lib/a.g.dart']);
      },
      skip: gitOk ? false : 'git binary unavailable',
    );

    test('U5/A1: restore() writes the exact pre-build bytes back '
        '(unstaged edits preserved)', () async {
      const committed = '// committed placeholder\n';
      final file = await seedPlaceholder(
        'lib/src/engine/events/engine_event.g.dart',
        committed,
      );
      // Unstaged hand edit BEFORE the snapshot: the real timeline — the
      // operator's edits exist pre-build, so the pre-build capture must
      // carry them (then the build deletes the file).
      const unstaged = '// committed placeholder\n// hand edit (uncommitted)\n';
      await file.writeAsString(unstaged);
      final snapshot = await captureInRepo();
      await file.delete();
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      final result = await guard.restore(
        snapshot,
        guard.detectDeleted(snapshot),
      );
      expect(result.restored, ['lib/src/engine/events/engine_event.g.dart']);
      expect(result.fullyRestored, isTrue);
      expect(
        file.readAsStringSync(),
        unstaged,
        reason:
            'restore writes captured pre-build bytes, not git index '
            'content — unstaged edits survive',
      );
    }, skip: gitOk ? false : 'git binary unavailable');

    test('U6: restore() reports failure when the parent directory is gone '
        '(never creates directories)', () async {
      final file = await seedPlaceholder(
        'lib/events/engine_event.g.dart',
        '//\n',
      );
      final snapshot = await captureInRepo();
      // The build anomaly removes the whole directory.
      await Directory(
        p.join(sandbox.path, 'lib', 'events'),
      ).delete(recursive: true);
      final guard = TrackedGeneratedOutputGuard(projectRoot: sandbox.path);
      final result = await guard.restore(
        snapshot,
        guard.detectDeleted(snapshot),
      );
      expect(result.restored, isEmpty);
      expect(result.failed, ['lib/events/engine_event.g.dart']);
      expect(file.existsSync(), isFalse);
    }, skip: gitOk ? false : 'git binary unavailable');

    test('U7: restoreRemedyLines names git checkout, both builder '
        'exclusions, and the doc page', () {
      final lines = TrackedGeneratedOutputGuard.restoreRemedyLines(const [
        'lib/src/engine/events/engine_event.g.dart',
      ]);
      final text = lines.join('\n');
      expect(
        text,
        contains(
          'git checkout -- '
          'lib/src/engine/events/engine_event.g.dart',
        ),
      );
      expect(text, contains('json_serializable'));
      expect(text, contains('source_gen:combining_builder'));
      expect(
        text,
        contains('lib/src/engine/events/engine_event.dart'),
        reason: 'convention-derived owning library appears in the exclude',
      );
      expect(text, contains(kHandAuthoredPlaceholderDoc));
    });

    test('owningLibraryFor: convention-derived, null without generated '
        'suffix', () {
      expect(
        TrackedGeneratedOutputGuard.owningLibraryFor(
          'lib/src/engine/events/engine_event.g.dart',
        ),
        'lib/src/engine/events/engine_event.dart',
      );
      expect(
        TrackedGeneratedOutputGuard.owningLibraryFor(
          'lib/src/models/user.zorphy.dart',
        ),
        'lib/src/models/user.dart',
      );
      expect(
        TrackedGeneratedOutputGuard.owningLibraryFor('lib/plain.dart'),
        isNull,
      );
    });

    test('trackedFilesSync: empty outside git, populated inside', () async {
      expect(
        TrackedGeneratedOutputGuard.trackedFilesSync(sandbox.path),
        isEmpty,
        reason: 'sandbox is not a git repo yet',
      );
      await seedPlaceholder('lib/a.g.dart', '// a\n');
      await _initRepo(sandbox);
      expect(
        TrackedGeneratedOutputGuard.trackedFilesSync(sandbox.path),
        contains('lib/a.g.dart'),
      );
    }, skip: gitOk ? false : 'git binary unavailable');
  });
}
