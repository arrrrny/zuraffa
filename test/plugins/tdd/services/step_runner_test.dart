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
}
