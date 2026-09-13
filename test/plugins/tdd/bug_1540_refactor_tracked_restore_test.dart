// Spec 1540 — `zfa tdd refactor` build pass restores-or-refuses (slow tier).
//
// Issue #1540: the refactor build pass invokes `zfa build`; build_runner's
// stale-output cleanup deletes git-tracked hand-authored `.g.dart`
// placeholders, the completeness gate then fails, and the loop dead-ends.
// These tests drive the REAL CLI surface against a TddFixture whose fake
// system zfa deletes a git-tracked placeholder during the build pass —
// mirroring the deletion the real build performs — and assert the
// restore-or-refuse contract:
//
//   A6 (US3.AC1/AC3): the deleted placeholder is restored byte-identical,
//      the restoration is recorded in the pass action output, exit 0.
//   A7 (US3.AC2): when the restore is impossible, the run stops on the
//      build pass, prints the `git checkout --` remedy, exits non-zero.

@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

const _placeholderRel = 'lib/src/engine/events/engine_event.g.dart';
const _placeholderContent =
    '// hand-authored placeholder (spec 1540 fixture) — part of engine_event\n';

Future<void> _git(Directory cwd, List<String> args) async {
  final r = await Process.run('git', args, workingDirectory: cwd.path);
  if (r.exitCode != 0) {
    fail('git ${args.join(' ')} failed (${r.exitCode}):\n${r.stderr}');
  }
}

/// git init + commit everything currently in [root] so the placeholder is
/// tracked in the index (the signal the guard protects).
Future<void> _initRepo(Directory root) async {
  // Keep the fixture repo lean: never track the pub resolution cache.
  await File(
    '${root.path}/.gitignore',
  ).writeAsString('.dart_tool/\npubspec.lock\n');
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

Future<void> main() async {
  final gitProbe = await Process.run('git', ['--version']);
  final gitOk = gitProbe.exitCode == 0;

  late TddFixture fx;
  late String fakeZfa;

  List<String> refactorArgs(TddFixture f, {String? zfaBin}) => [
    'tdd',
    'refactor',
    '--project',
    f.root.path,
    '--zfa-bin',
    zfaBin ?? fakeZfa,
  ];

  /// Seeds the green fixture + the git-tracked placeholder.
  Future<void> seedGreenWithTrackedPlaceholder() async {
    await fx.seedAlreadyCleanLib();
    final placeholder = File(p.join(fx.root.path, _placeholderRel));
    await placeholder.create(recursive: true);
    await placeholder.writeAsString(_placeholderContent);
  }

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A6: build pass deletes a tracked placeholder → restored '
      'byte-identical, restoration recorded, run exits 0', () async {
    await seedGreenWithTrackedPlaceholder();
    await _initRepo(fx.root);
    // The fake zfa deletes the tracked placeholder during `build` (what
    // build_runner's stale-output cleanup does to the real one) and exits 0.
    fakeZfa = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'build': ['rm -f "${p.join(fx.root.path, _placeholderRel)}"'],
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(refactorArgs(fx));

    final placeholder = File(p.join(fx.root.path, _placeholderRel));
    expect(
      placeholder.existsSync(),
      isTrue,
      reason:
          'the refactor build pass must restore the tracked '
          'placeholder the build deleted',
    );
    expect(
      placeholder.readAsStringSync(),
      _placeholderContent,
      reason: 'restore is byte-identical to the pre-pass content',
    );
    expect(
      out,
      contains('[1540] restored'),
      reason: 'the restoration is recorded in the pass evidence',
    );
    expect(
      out,
      contains(RegExp(r'refactor: feature=\S+ outcome=(clean|refactored)')),
    );
    expect(exitCode, 0);
  }, skip: gitOk ? false : 'git binary unavailable');

  test('A7: build pass deletes a tracked placeholder and the restore is '
      'impossible → refusal, remedy named, exit non-zero', () async {
    await seedGreenWithTrackedPlaceholder();
    await _initRepo(fx.root);
    // The build removes the whole directory: the placeholder's deletion can
    // never be restored (no parent to write into) → the registry refuses.
    fakeZfa = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'build': ['rm -rf "${p.join(fx.root.path, 'lib', 'src', 'engine')}"'],
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(refactorArgs(fx));

    expect(File(p.join(fx.root.path, _placeholderRel)).existsSync(), isFalse);
    expect(
      out,
      contains('git checkout -- $_placeholderRel'),
      reason: 'the refusal names the exact manual restore command',
    );
    expect(out, contains('refused'));
    expect(
      exitCode,
      isNot(0),
      reason: 'a refusal must never exit 0 — the tree is broken',
    );
  }, skip: gitOk ? false : 'git binary unavailable');
}
