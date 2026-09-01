// Tests for the RefactorPasses service (spec 048-tdd-refactor, T006 + T010;
// behaviors U1, U2, U3, U4, U5).
//
// Drives the fixed pass registry (build → format → fix) through an
// injectable process executor so the registry can be tested without real
// subprocesses. The executor records each invocation and returns the
// programmed outcome so tests can assert order, capture, and stop-on-failure.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/refactor_passes.dart';

/// A fake process executor that records every invocation and returns
/// programmed outcomes in order.
class _FakeExecutor implements ProcessExecutor {
  _FakeExecutor(this._outcomes);

  final List<_ProgrammedOutcome> _outcomes;
  int _next = 0;
  final List<RefactorPassInvocation> invocations = [];

  @override
  Future<ProcessRunOutcome> run(RefactorPassInvocation inv) async {
    invocations.add(inv);
    if (_next >= _outcomes.length) {
      return ProcessRunOutcome(
        command: inv.command,
        exitCode: 0,
        output: '(default success)',
        startedProcess: true,
      );
    }
    final programmed = _outcomes[_next++];
    // Apply file mutations the test programmed for this pass.
    for (final mutation in programmed.fileMutations) {
      await mutation();
    }
    return ProcessRunOutcome(
      command: inv.command,
      exitCode: programmed.exitCode,
      output: programmed.output,
      startedProcess: programmed.startedProcess,
    );
  }
}

class _ProgrammedOutcome {
  _ProgrammedOutcome({
    required this.exitCode,
    required this.output,
    this.fileMutations = const [],
    this.startedProcess = true,
  });

  final int exitCode;
  final String output;
  final List<Future<void> Function()> fileMutations;
  final bool startedProcess;
}

/// A throwaway in-memory "project" the fake executor can mutate. The pass
/// registry snapshots `lib/` between passes via a real temp directory so
/// filesChanged attribution works against actual files.
void main() {
  group('RefactorPasses (T006 / T010)', () {
    test(
      'U1: passes execute in fixed registry order: build → format → fix',
      () async {
        final project = await _ScratchProject.create();
        try {
          final executor = _FakeExecutor([
            _ProgrammedOutcome(exitCode: 0, output: 'build ok'),
            _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
            _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
          ]);
          final passes = RefactorPasses(project.root.path, executor: executor);
          final result = await passes.run();

          expect(executor.invocations.map((i) => i.passName).toList(), [
            'build',
            'format',
            'fix',
          ]);
          expect(result.actions.map((a) => a.name).toList(), [
            'build',
            'format',
            'fix',
          ]);
          expect(result.stopped, isFalse);
          expect(result.failedPass, isNull);
        } finally {
          project.dispose();
        }
      },
    );

    test(
      'U2: each pass is captured as a RefactorAction with command, exit code, '
      'filesChanged, output',
      () async {
        final project = await _ScratchProject.create();
        try {
          // Pre-create lib/foo.dart so the format pass can "change" it.
          await project.writeLibFile('foo.dart', 'unformatted\n');
          final executor = _FakeExecutor([
            _ProgrammedOutcome(exitCode: 0, output: 'build ok'),
            _ProgrammedOutcome(
              exitCode: 0,
              output: 'format ok',
              fileMutations: [
                () => project.writeLibFile('foo.dart', 'formatted\n'),
              ],
            ),
            _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
          ]);
          final passes = RefactorPasses(project.root.path, executor: executor);
          final result = await passes.run();

          expect(result.actions, hasLength(3));
          final build = result.actions[0];
          expect(build.name, 'build');
          expect(build.exitCode, 0);
          expect(build.output, 'build ok');
          // Bug #689: the build pass resolves the zfa entrypoint (override
          // → running-from-source → PATH → fallback), never the hardcoded
          // `dart run bin/zfa.dart build` that misfired in projects without
          // that file. The executor records the exact resolved command.
          expect(build.command, endsWith(' build'));
          // Bug #717: the package-config tier of the shared chain used to
          // shadow the PATH tier and surface the running package tree's own
          // bin/zfa.dart here (the refactor pass suppresses that tier), and
          // the published 6.1.0 hardcoded `dart run bin/zfa.dart build`.
          // With the fix the recorded command never names bin/zfa.dart.
          expect(
            build.command,
            isNot(contains('bin/zfa.dart')),
            reason: 'the hardcoded bin/zfa.dart path was the bug',
          );
          expect(build.filesChanged, isEmpty);

          final format = result.actions[1];
          expect(format.name, 'format');
          expect(format.exitCode, 0);
          expect(format.output, 'format ok');
          expect(format.command, contains('dart format'));
          expect(format.filesChanged, contains('lib/foo.dart'));

          final fix = result.actions[2];
          expect(fix.name, 'fix');
          expect(fix.exitCode, 0);
          expect(fix.output, 'fix ok');
          expect(fix.command, contains('dart fix'));
        } finally {
          project.dispose();
        }
      },
    );

    test('U3: the first failing pass stops the remaining passes', () async {
      final project = await _ScratchProject.create();
      try {
        final executor = _FakeExecutor([
          _ProgrammedOutcome(exitCode: 0, output: 'build ok'),
          _ProgrammedOutcome(exitCode: 1, output: 'format failed'),
          // fix never runs.
          _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
        ]);
        final passes = RefactorPasses(project.root.path, executor: executor);
        final result = await passes.run();

        expect(result.actions, hasLength(2));
        expect(result.actions.last.name, 'format');
        expect(result.actions.last.exitCode, 1);
        expect(result.stopped, isTrue);
        expect(result.failedPass, 'format');
        // The fix pass was never invoked.
        expect(executor.invocations.map((i) => i.passName).toList(), [
          'build',
          'format',
        ]);
      } finally {
        project.dispose();
      }
    });

    test(
      'U4: a pass that changes nothing records filesChanged: [] (not error)',
      () async {
        final project = await _ScratchProject.create();
        try {
          final executor = _FakeExecutor([
            _ProgrammedOutcome(exitCode: 0, output: 'build ok'),
            _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
            _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
          ]);
          final passes = RefactorPasses(project.root.path, executor: executor);
          final result = await passes.run();

          for (final action in result.actions) {
            expect(action.filesChanged, isEmpty, reason: action.name);
          }
          expect(result.stopped, isFalse);
        } finally {
          project.dispose();
        }
      },
    );

    test('U5: filesChanged is computed from a per-pass before/after snapshot '
        'diff', () async {
      final project = await _ScratchProject.create();
      try {
        await project.writeLibFile('a.dart', 'v1\n');
        await project.writeLibFile('b.dart', 'v1\n');
        final executor = _FakeExecutor([
          _ProgrammedOutcome(exitCode: 0, output: 'build ok'),
          _ProgrammedOutcome(
            exitCode: 0,
            output: 'format ok',
            fileMutations: [
              () => project.writeLibFile('a.dart', 'v2\n'),
              () => project.writeLibFile('c.dart', 'new\n'),
            ],
          ),
          _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
        ]);
        final passes = RefactorPasses(project.root.path, executor: executor);
        final result = await passes.run();

        final format = result.actions[1];
        // format changed a.dart (content) and added c.dart.
        expect(format.filesChanged, contains('lib/a.dart'));
        expect(format.filesChanged, contains('lib/c.dart'));
        // b.dart was not touched.
        expect(format.filesChanged, isNot(contains('lib/b.dart')));
      } finally {
        project.dispose();
      }
    });

    test('a pass that does not start misfire-stops the registry', () async {
      final project = await _ScratchProject.create();
      try {
        final executor = _FakeExecutor([
          _ProgrammedOutcome(
            exitCode: 0,
            output: 'build did not start',
            startedProcess: false,
          ),
        ]);
        final passes = RefactorPasses(project.root.path, executor: executor);
        final result = await passes.run();

        expect(result.actions, hasLength(1));
        expect(result.stopped, isTrue);
        expect(result.failedPass, 'build');
      } finally {
        project.dispose();
      }
    });

    test('the default pass set is exactly build, format, fix', () async {
      final passes = RefactorPasses('/tmp/unused');
      expect((await passes.passSpecs).map((s) => s.name).toList(), [
        'build',
        'format',
        'fix',
      ]);
    });

    // Bug #689: the build pass hardcoded `dart run bin/zfa.dart build`,
    // but `zfa setup` never creates bin/zfa.dart in the project (it
    // installs the system zfa), so refactor always misfired. The build
    // pass must resolve the zfa entrypoint the same way make/gen/verify
    // do (PipelineRunner FR-004/U11 tiers).
    group('bug #689 — build pass resolves the zfa entrypoint', () {
      test(
        'an explicit --zfa-bin override wins and names the binary',
        () async {
          final passes = RefactorPasses(
            '/tmp/unused',
            zfaBinOverride: '/home/dev/.local/bin/zfa',
          );
          final build = (await passes.passSpecs).first;
          expect(build.name, 'build');
          expect(build.command, '/home/dev/.local/bin/zfa build');
          expect(
            build.command,
            isNot(contains('bin/zfa.dart')),
            reason: 'the hardcoded bin/zfa.dart path was the bug',
          );
        },
      );

      test(
        'a zfa on PATH (system install) is preferred over the fallback '
        '(bug #717: the PATH tier wins for the refactor build pass)',
        () async {
          final fakeBin = Directory.systemTemp.createTempSync('fake_path_689_');
          addTearDown(() => fakeBin.deleteSync(recursive: true));
          final zfa = File(p.join(fakeBin.path, 'zfa'));
          zfa.writeAsStringSync('#!/bin/sh\nexit 0\n');
          // The resolver only accepts executable candidates (same contract
          // as PipelineRunner's PATH lookup), so mark the fake executable.
          await Process.run('chmod', ['+x', zfa.path]);
          final environment = <String, String>{
            'PATH': '/usr/bin:${fakeBin.path}',
          };
          final build = (await RefactorPasses.defaultPassSpecs(
            environment: environment,
          )).first;
          // Bug #717: the build pass calls the system zfa directly (Option
          // B) — the system install on PATH wins over the running package
          // tree's own bin/zfa.dart (the package tier is suppressed for
          // this pass), and never the original hardcoded literal.
          expect(build.command, '${zfa.path} build');
        },
      );

      test(
        'the default command never names the nonexistent bin/zfa.dart',
        () async {
          final build = (await RefactorPasses.defaultPassSpecs()).first;
          expect(build.name, 'build');
          expect(
            build.command,
            isNot(equals('dart run bin/zfa.dart build')),
            reason:
                'hardcoding bin/zfa.dart regressed every project without '
                'that file (bug #689, exit 255)',
          );
          expect(build.command, endsWith(' build'));
        },
      );

      // Bug #717: `zfa tdd refactor` still misfired in the wild (published
      // 6.1.0) and the PATH tier was shadowed by the package-config tier
      // (which resolves the RUNNING package tree's own bin/zfa.dart in
      // source/test/kernel contexts). zfa setup installs the system CLI and
      // never creates bin/zfa.dart, so the build pass must EXECUTE the
      // system zfa from PATH. This test runs the real executor (no fake,
      // no --zfa-bin) against a fixture project without bin/zfa.dart and a
      // fake system zfa on PATH, and asserts the binary actually ran with
      // the `build` argument.
      test('the build pass executes the system zfa on PATH in a project '
          'without bin/zfa.dart (bug #717)', () async {
        final project = await _ScratchProject.create();
        final fakeBin = Directory.systemTemp.createTempSync('fake_zfa_717_');
        try {
          final record = File(p.join(fakeBin.path, 'invocations.txt'));
          final zfa = File(p.join(fakeBin.path, 'zfa'));
          zfa.writeAsStringSync(
            '#!/bin/sh\n'
            'echo zfa "\$@" >> "${record.path}"\n'
            'exit 0\n',
          );
          await Process.run('chmod', ['+x', zfa.path]);

          final environment = <String, String>{
            'PATH': '${fakeBin.path}:/usr/bin:/bin',
          };
          final passes = RefactorPasses(
            project.root.path,
            environment: environment,
          );
          final result = await passes.run();

          final build = result.actions.first;
          expect(build.name, 'build');
          expect(build.command, '${zfa.path} build');
          expect(
            build.exitCode,
            0,
            reason:
                'the system zfa on PATH must run successfully; '
                'output was: ${build.output}',
          );
          // The decisive assertion: the resolved system zfa binary was
          // actually EXECUTED with the build argument (not just shaped
          // into a command string).
          expect(
            record.existsSync(),
            isTrue,
            reason: 'the fake system zfa was never executed',
          );
          expect(record.readAsStringSync(), contains('build'));
          expect(result.failedPass, isNot('build'));
        } finally {
          project.dispose();
          fakeBin.deleteSync(recursive: true);
        }
      });
    });
  });
}

/// Minimal scratch project used by the fake executor for snapshot diffing.
class _ScratchProject {
  _ScratchProject._(this.root);

  final Directory root;

  static Future<_ScratchProject> create() async {
    final d = Directory.systemTemp.createTempSync('refactor_passes_');
    await Directory('${d.path}/lib').create(recursive: true);
    return _ScratchProject._(d);
  }

  Future<void> writeLibFile(String name, String content) async {
    await File(p.join(root.path, 'lib', name)).writeAsString(content);
  }

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
