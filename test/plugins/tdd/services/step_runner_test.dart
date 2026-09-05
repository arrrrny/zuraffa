// Tests for StepRunner (spec 049-tdd-run, U12-U18 / T007).
//
// Fast tier: the spawn hook is injected, so these drive the contract
// parsing without real sub-processes. The slow tier (run_command_test,
// scenarios) exercises the real spawn path through the fixture's fake
// zfa binary.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';

/// Records the spawn and replies with a canned [ProcessResult].
class _RecordingSpawner {
  _RecordingSpawner(this._reply);

  final ProcessResult Function() _reply;
  final List<List<String>> commands = [];
  final List<String> workingDirectories = [];

  Future<ProcessResult> call(List<String> command, String workingDirectory) {
    commands.add(command);
    workingDirectories.add(workingDirectory);
    return Future.value(_reply());
  }
}

ProcessResult _result({
  int exitCode = 0,
  String stdout = '',
  String stderr = '',
}) => ProcessResult(42, exitCode, stdout, stderr);

void main() {
  const feature = '090-fixture';
  const projectRoot = '/tmp/proj';

  StepRunner runnerWith(_RecordingSpawner spawner) =>
      StepRunner(zfaBin: '/fake/bin/zfa', spawner: spawner.call);

  test(
    'U12: steps spawn with argv tdd <step> <id> --feature --project',
    () async {
      final spawner = _RecordingSpawner(() => _result());
      final runner = runnerWith(spawner);

      await runner.run(
        step: 'verify-red',
        behaviorId: 'B-001',
        feature: feature,
        projectRoot: projectRoot,
      );

      expect(spawner.commands.single, [
        '/fake/bin/zfa',
        'tdd',
        'verify-red',
        'B-001',
        '--feature',
        feature,
        '--project',
        projectRoot,
      ]);
      expect(spawner.workingDirectories.single, projectRoot);
    },
  );

  test('U12: a .dart entrypoint is run through dart', () async {
    final spawner = _RecordingSpawner(() => _result());
    final runner = StepRunner(
      zfaBin: '/pkg/bin/zfa.dart',
      spawner: spawner.call,
    );

    await runner.run(
      step: 'gen',
      behaviorId: 'U1',
      feature: feature,
      projectRoot: projectRoot,
    );

    expect(spawner.commands.single.take(2), ['dart', '/pkg/bin/zfa.dart']);
    expect(spawner.commands.single.sublist(2), [
      'tdd',
      'gen',
      'U1',
      '--feature',
      feature,
      '--project',
      projectRoot,
    ]);
  });

  test('U13: verify-red succeeds only on exit 0 AND certified=true', () async {
    // exit 0 + certified=true -> success.
    var spawner = _RecordingSpawner(
      () => _result(
        stdout:
            'verify-red: behavior=B-001 classification=assertion '
            'certified=true feature=$feature\n',
      ),
    );
    var result = await runnerWith(spawner).run(
      step: 'verify-red',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isTrue);
    expect(result.outcome, 'certified');

    // exit 0 + certified=false -> failure with the named classification.
    spawner = _RecordingSpawner(
      () => _result(
        stdout:
            'verify-red: behavior=B-001 classification=compile-error '
            'certified=false feature=$feature\n',
      ),
    );
    result = await runnerWith(spawner).run(
      step: 'verify-red',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
    expect(result.outcome, 'compile-error');

    // exit 1 (whatever the line says) -> failure.
    spawner = _RecordingSpawner(
      () => _result(
        exitCode: 1,
        stdout:
            'verify-red: behavior=B-001 classification=assertion '
            'certified=true feature=$feature\n',
      ),
    );
    result = await runnerWith(spawner).run(
      step: 'verify-red',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
  });

  test('U14 (issue #694): make succeeds on outcome=skipped — the '
      'already-green skip transition is a success, not a stop', () async {
    var spawner = _RecordingSpawner(
      () => _result(stdout: 'make: behavior=B-001 outcome=skipped feature=f\n'),
    );
    var result = await runnerWith(spawner).run(
      step: 'make',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isTrue);
    expect(result.outcome, 'skipped');

    // exit 1 with outcome=skipped stays a failure (the exit code is
    // part of the contract).
    spawner = _RecordingSpawner(
      () => _result(
        exitCode: 1,
        stdout: 'make: behavior=B-001 outcome=skipped feature=f\n',
      ),
    );
    result = await runnerWith(spawner).run(
      step: 'make',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
  });

  test('U14: make succeeds only on exit 0 AND outcome=green', () async {
    var spawner = _RecordingSpawner(
      () => _result(stdout: 'make: behavior=B-001 outcome=green feature=f\n'),
    );
    var result = await runnerWith(spawner).run(
      step: 'make',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isTrue);
    expect(result.outcome, 'green');

    // exit 0 but outcome=unexpressible -> failure named by the outcome.
    spawner = _RecordingSpawner(
      () => _result(
        stdout: 'make: behavior=B-001 outcome=unexpressible feature=f\n',
      ),
    );
    result = await runnerWith(spawner).run(
      step: 'make',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
    expect(result.outcome, 'unexpressible');

    // exit 1 with outcome=green -> failure (exit code is part of the
    // contract).
    spawner = _RecordingSpawner(
      () => _result(
        exitCode: 1,
        stdout: 'make: behavior=B-001 outcome=green feature=f\n',
      ),
    );
    result = await runnerWith(spawner).run(
      step: 'make',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
  });

  test(
    'U15: refactor succeeds on outcome=clean or outcome=refactored',
    () async {
      for (final outcome in ['clean', 'refactored']) {
        final spawner = _RecordingSpawner(
          () => _result(
            stdout: 'refactor: behavior=B-001 outcome=$outcome feature=f\n',
          ),
        );
        final result = await runnerWith(spawner).run(
          step: 'refactor',
          behaviorId: 'B-001',
          feature: feature,
          projectRoot: projectRoot,
        );
        expect(result.success, isTrue, reason: outcome);
        expect(result.outcome, outcome);
      }

      final spawner = _RecordingSpawner(
        () => _result(
          stdout: 'refactor: behavior=B-001 outcome=regression feature=f\n',
        ),
      );
      final result = await runnerWith(spawner).run(
        step: 'refactor',
        behaviorId: 'B-001',
        feature: feature,
        projectRoot: projectRoot,
      );
      expect(result.success, isFalse);
      expect(result.outcome, 'regression');
    },
  );

  test('U16: gen succeeds on exit 0 and fails on exit != 0', () async {
    var spawner = _RecordingSpawner(() => _result());
    var result = await runnerWith(spawner).run(
      step: 'gen',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isTrue);
    expect(result.outcome, 'ok');

    spawner = _RecordingSpawner(
      () => _result(exitCode: 1, stderr: 'zfa tdd gen: ownership conflict'),
    );
    result = await runnerWith(spawner).run(
      step: 'gen',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
    expect(result.output, contains('ownership conflict'));
  });

  test('U16b (issue #992): a refused gen carries its verdict JSON — '
      'outcome=refused with the refusal kind, still a failure', () async {
    // The real `zfa tdd gen` refuses the widget lane (issue #938) with
    // the machine-parseable verdict JSON as the FINAL stdout line and
    // exit 1. The driver can only degrade per-kind (issue #992) when the
    // parsed StepResult names the refusal and its kind.
    final spawner = _RecordingSpawner(
      () => _result(
        exitCode: 1,
        stdout:
            '--> fix: add shadcn_ui (flutter pub add shadcn_ui --dev) or '
            're-run with --skip-widget\n'
            '{"command":"gen","behavior":"A8","verdict":"refused",'
            '"reason":"pubspec.yaml does not declare shadcn_ui",'
            '"kind":"widget"}\n',
      ),
    );
    final result = await runnerWith(spawner).run(
      step: 'gen',
      behaviorId: 'A8',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
    expect(result.outcome, 'refused');
    expect(result.verdictKind, 'widget');

    // A non-JSON failure keeps the generic outcome and no kind.
    final plain =
        await runnerWith(
          _RecordingSpawner(
            () => _result(exitCode: 1, stderr: 'zfa tdd gen: boom'),
          ),
        ).run(
          step: 'gen',
          behaviorId: 'A8',
          feature: feature,
          projectRoot: projectRoot,
        );
    expect(plain.success, isFalse);
    expect(plain.outcome, 'error');
    expect(plain.verdictKind, isNull);
  });

  test(
    'U17: a spawn failure yields a runner-error StepResult, not a crash',
    () async {
      final runner = StepRunner(
        zfaBin: '/nonexistent/fake-zfa',
        spawner: (command, workingDirectory) => throw ProcessException(
          command.first,
          command.sublist(1),
          'not found',
        ),
      );

      final result = await runner.run(
        step: 'gen',
        behaviorId: 'B-001',
        feature: feature,
        projectRoot: projectRoot,
      );

      expect(result.success, isFalse);
      expect(result.outcome, 'runner-error');
      expect(result.exitCode, -1);
      expect(result.output, contains('spawn failed'));
    },
  );

  test('U18: --zfa-bin overrides entrypoint resolution', () async {
    final spawner = _RecordingSpawner(() => _result());
    final runner = StepRunner(zfaBin: '/overrides/zfa', spawner: spawner.call);

    await runner.run(
      step: 'gen',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );

    expect(spawner.commands.single.first, '/overrides/zfa');
  });

  test('exit 0 without the summary line is a contract violation', () async {
    final spawner = _RecordingSpawner(() => _result(stdout: 'all done\n'));
    final result = await runnerWith(spawner).run(
      step: 'make',
      behaviorId: 'B-001',
      feature: feature,
      projectRoot: projectRoot,
    );
    expect(result.success, isFalse);
    expect(result.outcome, 'missing-summary');
  });

  test('defaultZfaBin resolves this package\'s bin/zfa.dart', () async {
    final bin = await StepRunner.defaultZfaBin();
    expect(p.basename(bin), 'zfa.dart');
    expect(await File(bin).exists(), isTrue);
  });

  group('bug #690: system-binary entrypoint fallback', () {
    /// A real executable file in a temp dir (the compiled system binary
    /// the tests stand in for).
    Future<File> executableFile(String dirName, String name) async {
      final dir = await Directory.systemTemp.createTemp(dirName);
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, name));
      await file.writeAsString('#!/bin/sh\nexit 0\n');
      await Process.run('chmod', ['+x', file.path]);
      return file;
    }

    Future<Uri?> noPackageUri(Uri packageUri) async => null;
    const staleScript = '/build/stale/zfa.dart.dill';

    test('resolves the system-installed zfa on PATH (tier 4)', () async {
      final systemZfa = await executableFile('zfa690_path', 'zfa');

      final bin = await StepRunner.resolveEntrypoint(
        // The pub-global snapshot shape: script is the snapshot itself,
        // NOT a .dart entrypoint, and the package is not resolvable.
        script: Uri.file('/build/stale/zfa.jit'),
        resolvedExecutable: '/usr/bin/dart',
        environment: {'PATH': p.dirname(systemZfa.path)},
        resolvePackageUri: noPackageUri,
      );

      expect(bin, systemZfa.path);
    });

    test('final fallback is Platform.resolvedExecutable for a compiled zfa '
        'binary not on PATH (tier 6)', () async {
      final compiled = await executableFile('zfa690_exe', 'zfa');

      final bin = await StepRunner.resolveEntrypoint(
        script: Uri.file('/build/stale/never-existed.dill'),
        resolvedExecutable: compiled.path,
        environment: {'PATH': '/usr/bin:/bin'},
        resolvePackageUri: noPackageUri,
      );

      expect(bin, compiled.path);
    });

    test('a usable Platform.script still wins over the resolvedExecutable '
        'fallback when nothing is on PATH (tier 5 preserved)', () async {
      final compiled = await executableFile('zfa690_exe2', 'zfa');
      final snapshot = await executableFile('zfa690_snap', 'zfa.jit');

      final bin = await StepRunner.resolveEntrypoint(
        script: Uri.file(snapshot.path),
        resolvedExecutable: compiled.path,
        environment: {'PATH': '/usr/bin:/bin'},
        resolvePackageUri: noPackageUri,
      );

      expect(bin, snapshot.path);
    });

    test('the Dart VM is never returned as the entrypoint — unresolved '
        'input still throws the pass --zfa-bin error', () async {
      await expectLater(
        StepRunner.resolveEntrypoint(
          script: Uri.file(staleScript),
          resolvedExecutable: '/usr/bin/dart',
          environment: {'PATH': ''},
          resolvePackageUri: noPackageUri,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cannot resolve the zfa entrypoint'),
          ),
        ),
      );
    });

    test('a non-executable PATH candidate is skipped (executable bit '
        'checked, mirroring #665)', () async {
      final dir = await Directory.systemTemp.createTemp('zfa690_nox');
      addTearDown(() => dir.delete(recursive: true));
      final notExecutable = File(p.join(dir.path, 'zfa'));
      await notExecutable.writeAsString('#!/bin/sh\nexit 0\n');
      final compiled = await executableFile('zfa690_exe3', 'zfa');

      final bin = await StepRunner.resolveEntrypoint(
        script: Uri.file(staleScript),
        resolvedExecutable: compiled.path,
        environment: {'PATH': dir.path},
        resolvePackageUri: noPackageUri,
      );

      expect(bin, compiled.path, reason: 'falls through to tier 6');
    });

    test('run() spawns steps through the resolved entrypoint', () async {
      final spawner = _RecordingSpawner(() => _result());
      // No --zfa-bin: the runner must fall through to defaultZfaBin(),
      // which resolves the system zfa on PATH for this test's inputs.
      final runner = StepRunner(spawner: spawner.call);

      await runner.run(
        step: 'gen',
        behaviorId: 'B-001',
        feature: feature,
        projectRoot: projectRoot,
      );

      // In the `dart test` context the package tier (3) resolves first,
      // so the spawn goes through this package's bin/zfa.dart via dart.
      expect(spawner.commands.single.take(2), [
        'dart',
        await StepRunner.defaultZfaBin(),
      ]);
    });
  });
}
