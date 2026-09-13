// Issue #1472 — the refactor pass's build gate must gate on ERRORS only.
//
// The refactor pass registry (`RefactorPasses`, spec 048) runs
// build → format → fix with misfire-stop on the first non-zero exit
// (FR-010). The build pass runs `zfa build`, whose analyze gate
// (issues #395/#1035) refuses the tree on errors OR warnings. A
// hand-implemented subject with one unused import therefore fails the
// build pass with a WARNINGS-ONLY refusal (0 errors + N warnings), the
// registry misfire-stops, and the `dart fix --apply` pass — the only
// pass that would remove exactly that lint — never runs. Deadlock.
//
// The fix mirrors issue #1407 (make's errors-only gate) at the registry:
// when the failed pass IS `build`, the process started, it was not killed
// by the per-pass timeout, and its output proves the refusal was the
// analyze gate's own verdict with 0 error(s) and >=1 warning(s)
// (cross-checked through the shared `BuildCommand.countAnalyzerIssues`
// parser — the single #1035 line-format contract), the verdict is logged
// with its accurate counts and the registry CONTINUES to format → fix.
// Anything else keeps the byte-identical misfire-stop. A project opts
// back into the legacy warnings-blocking strictness via the TDD
// profile's `analyze-gate: warnings-blocking` key (read by the command,
// passed in as `warningsBlocking`).
//
// Issue #1472 also pins the build pass's zfa binary to the version
// driving the run: the #717 chain prefers the system zfa on PATH, which
// can be a stale install executing a different gate. A candidate whose
// `--version` provably disagrees with the driving CLI's version is
// replaced by the driving CLI's own entrypoint (silence rules per
// #1184: an unprovable version never re-routes anything).
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/refactor_passes.dart';
import 'package:zuraffa/src/version.dart';

/// A fake process executor that records every invocation and returns
/// programmed outcomes in order (same shape as refactor_passes_test.dart).
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
    return ProcessRunOutcome(
      command: inv.command,
      exitCode: programmed.exitCode,
      output: programmed.output,
      startedProcess: programmed.startedProcess,
      timedOut: programmed.timedOut,
    );
  }
}

class _ProgrammedOutcome {
  _ProgrammedOutcome({
    required this.exitCode,
    required this.output,
    this.startedProcess = true,
    this.timedOut = false,
  });

  final int exitCode;
  final String output;
  final bool startedProcess;
  final bool timedOut;
}

/// The build pass's analyze-gate refusal on WARNINGS ONLY — the issue's
/// exact real-world shape: a hand-implemented subject with an unused
/// import (`dart fix` would remove it), 0 errors, and the gate's own
/// verdict line.
const _warningsOnlyBuildOutput =
    'Building...\n'
    '   warning - lib/tdd/login/u8_subject.dart:31:8 - Unused import: '
    'package:uuid/uuid.dart. - unused_import\n'
    '   warning - lib/tdd/login/u9_subject.dart:12:8 - Unused import: '
    'package:test/test.dart. - unused_import\n'
    '❌ dart analyze reported 0 error(s) and 2 warning(s) — generated code '
    'does not compile cleanly.';

/// The same refusal shape carrying analyzer ERRORS (the #942 class: the
/// generated tree does not compile).
const _errorsBuildOutput =
    '   error - lib/tdd/login/u8_subject.dart:31:8 - Undefined name '
    "'Widget'. - undefined_identifier\n"
    '❌ dart analyze reported 1 error(s) and 0 warning(s) — generated code '
    'does not compile cleanly.';

/// A build failure that is NOT the analyze gate's verdict (build_runner
/// crash class) — must keep the misfire-stop unchanged.
const _nonGateBuildOutput = 'build_runner crashed: exit 255, seed 4242';

/// Capture `print` output inside [body] (the registry logs the tolerated
/// verdict through `print`).
Future<(T, List<String>)> capturePrint<T>(Future<T> Function() body) async {
  final lines = <String>[];
  late final T result;
  await runZoned(
    () async {
      result = await body();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        lines.add(line);
      },
    ),
  );
  return (result, lines);
}

void main() {
  group('issue #1472 — the refactor build gate is errors-only', () {
    test('U-1472-1: a warnings-only build-gate refusal does NOT misfire-stop '
        '— format and fix still run', () async {
      final project = Directory.systemTemp.createTempSync('z1472_gate_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        // The build pass refused on warnings only (0 errors).
        _ProgrammedOutcome(exitCode: 1, output: _warningsOnlyBuildOutput),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);
      final result = await passes.run();

      // Pre-fix: misfire-stop after build; the fix pass never ran.
      expect(executor.invocations.map((i) => i.passName).toList(), [
        'build',
        'format',
        'fix',
      ]);
      expect(result.stopped, isFalse);
      expect(result.failedPass, isNull);
      expect(result.completed, isTrue);
      expect(result.actions, hasLength(3));
    });

    test('U-1472-2: the tolerated build action keeps the honest exit code '
        'and the raw refusal output (auditability)', () async {
      final project = Directory.systemTemp.createTempSync('z1472_honest_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(exitCode: 1, output: _warningsOnlyBuildOutput),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);
      final result = await passes.run();

      final build = result.actions.first;
      expect(build.name, 'build');
      expect(
        build.exitCode,
        1,
        reason: 'the true exit code is never rewritten',
      );
      expect(build.output, contains('dart analyze reported 0 error(s)'));
    });

    test('U-1472-3: the tolerated verdict is logged with the gate\'s own '
        'counts and names warnings non-blocking — never "did not compile '
        'cleanly"', () async {
      final project = Directory.systemTemp.createTempSync('z1472_log_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(exitCode: 1, output: _warningsOnlyBuildOutput),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);

      final (result, lines) = await capturePrint(passes.run);
      final transcript = lines.join('\n');

      expect(result.stopped, isFalse);
      // Accurate counts (SC-3): the gate's own numbers, named non-blocking.
      expect(transcript, contains('0 error(s), 2 warning(s)'));
      expect(transcript, contains('non-blocking'));
      // The warnings themselves are surfaced (the fix pass's input).
      expect(transcript, contains('u8_subject.dart:31:8'));
      // Never the compile-failure claim for a warnings-only refusal.
      expect(transcript, isNot(contains('misfire-stop')));
    });

    test('U-1472-4: a build refusal carrying analyzer ERRORS keeps the '
        'misfire-stop (the fix pass never runs)', () async {
      final project = Directory.systemTemp.createTempSync('z1472_err_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(exitCode: 1, output: _errorsBuildOutput),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);
      final result = await passes.run();

      expect(result.stopped, isTrue);
      expect(result.failedPass, 'build');
      expect(executor.invocations.map((i) => i.passName).toList(), ['build']);
    });

    test('U-1472-5: a non-gate build failure keeps the misfire-stop', () async {
      final project = Directory.systemTemp.createTempSync('z1472_other_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(exitCode: 255, output: _nonGateBuildOutput),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);
      final result = await passes.run();

      expect(result.stopped, isTrue);
      expect(result.failedPass, 'build');
      expect(executor.invocations.map((i) => i.passName).toList(), ['build']);
    });

    test(
      'U-1472-6: gate message claims 0 errors but the raw output carries '
      '`error -` lines — the honest misfire-stop stands (safe-failure)',
      () async {
        final project = Directory.systemTemp.createTempSync('z1472_drift_');
        addTearDown(() => project.deleteSync(recursive: true));
        await Directory(p.join(project.path, 'lib')).create(recursive: true);

        final lyingOutput =
            '   error - lib/tdd/login/u8_subject.dart:31:8 - Undefined name '
            "'Widget'. - undefined_identifier\n"
            '❌ dart analyze reported 0 error(s) and 1 warning(s) — generated '
            'code does not compile cleanly.';
        final executor = _FakeExecutor([
          _ProgrammedOutcome(exitCode: 1, output: lyingOutput),
          _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
          _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
        ]);
        final passes = RefactorPasses(project.path, executor: executor);
        final result = await passes.run();

        expect(result.stopped, isTrue, reason: 'never a silent pass on drift');
        expect(result.failedPass, 'build');
        expect(executor.invocations.map((i) => i.passName).toList(), ['build']);
      },
    );

    test('U-1472-7: warningsBlocking restores the legacy refusal for a '
        'warnings-only output (SC-5 profile opt-in)', () async {
      final project = Directory.systemTemp.createTempSync('z1472_optin_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(exitCode: 1, output: _warningsOnlyBuildOutput),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(
        project.path,
        executor: executor,
        warningsBlocking: true,
      );
      final result = await passes.run();

      expect(result.stopped, isTrue);
      expect(result.failedPass, 'build');
      expect(executor.invocations.map((i) => i.passName).toList(), ['build']);
    });

    test('U-1472-8: a timed-out build never qualifies for the arm even with '
        'a gate line in its captured output', () async {
      final project = Directory.systemTemp.createTempSync('z1472_timeout_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(
          exitCode: -1,
          output: _warningsOnlyBuildOutput,
          timedOut: true,
        ),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);
      final result = await passes.run();

      expect(result.stopped, isTrue);
      expect(result.failedPass, 'build');
      expect(executor.invocations.map((i) => i.passName).toList(), ['build']);
    });

    test('U-1472-9: a build pass that did not start never qualifies', () async {
      final project = Directory.systemTemp.createTempSync('z1472_spawn_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(
          exitCode: 0,
          output: _warningsOnlyBuildOutput,
          startedProcess: false,
        ),
        _ProgrammedOutcome(exitCode: 0, output: 'format ok'),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);
      final result = await passes.run();

      expect(result.stopped, isTrue);
      expect(result.failedPass, 'build');
      expect(executor.invocations.map((i) => i.passName).toList(), ['build']);
    });

    test('U-1472-10: the arm is build-only — a format pass failing with the '
        'same warnings-only verdict line still misfire-stops', () async {
      final project = Directory.systemTemp.createTempSync('z1472_buildonly_');
      addTearDown(() => project.deleteSync(recursive: true));
      await Directory(p.join(project.path, 'lib')).create(recursive: true);

      final executor = _FakeExecutor([
        _ProgrammedOutcome(exitCode: 0, output: 'build ok'),
        _ProgrammedOutcome(exitCode: 1, output: _warningsOnlyBuildOutput),
        _ProgrammedOutcome(exitCode: 0, output: 'fix ok'),
      ]);
      final passes = RefactorPasses(project.path, executor: executor);
      final result = await passes.run();

      expect(result.stopped, isTrue);
      expect(result.failedPass, 'format');
      expect(executor.invocations.map((i) => i.passName).toList(), [
        'build',
        'format',
      ]);
    });
  });

  group(
    'issue #1472 — the build pass is pinned to the driving zfa version',
    () {
      /// Install a fake `zfa` on an injected PATH whose `--version` stdout is
      /// [versionLine] and return (binDir, zfaPath).
      Future<(Directory, String)> installFakeZfa(String versionLine) async {
        final binDir = Directory.systemTemp.createTempSync('z1472_pin_');
        final zfa = File(p.join(binDir.path, 'zfa'));
        zfa.writeAsStringSync(
          '#!/usr/bin/env bash\n'
          "if [[ \"\$*\" == *'--version'* ]]; then\n"
          "  echo '$versionLine'\n"
          'fi\n'
          'exit 0\n',
        );
        await Process.run('chmod', ['+x', zfa.path]);
        return (binDir, zfa.path);
      }

      test(
        'U-1472-11: a PATH zfa whose version differs from the driving CLI '
        'is NOT used — the build pass pins to the driving entrypoint',
        () async {
          final (binDir, zfaPath) = await installFakeZfa('zfa v0.0.9');
          addTearDown(() => binDir.deleteSync(recursive: true));

          final specs = await RefactorPasses.defaultPassSpecs(
            environment: {'PATH': '${binDir.path}:/usr/bin:/bin'},
          );

          final build = specs.first;
          expect(build.name, 'build');
          // The stale system zfa is bypassed…
          expect(build.command, isNot(contains(zfaPath)));
          // …in favor of the driving CLI's own entrypoint (the running
          // package's bin/zfa.dart, resolved through the un-suppressed chain).
          expect(build.command, contains('bin/zfa.dart'));
          expect(build.command, endsWith(' build'));
        },
      );

      test('U-1472-12: a PATH zfa reporting the DRIVING version stays the '
          'build command (bug #717 contract intact)', () async {
        final (binDir, zfaPath) = await installFakeZfa('zfa v$version');
        addTearDown(() => binDir.deleteSync(recursive: true));

        final specs = await RefactorPasses.defaultPassSpecs(
          environment: {'PATH': '${binDir.path}:/usr/bin:/bin'},
        );

        final build = specs.first;
        expect(build.name, 'build');
        expect(build.command, '$zfaPath build');
      });

      test(
        'U-1472-13: a PATH zfa with an UNPROVABLE version keeps the #717 '
        'resolution (silence rule — never re-route on unprovable input)',
        () async {
          final (binDir, zfaPath) = await installFakeZfa('');
          addTearDown(() => binDir.deleteSync(recursive: true));

          final specs = await RefactorPasses.defaultPassSpecs(
            environment: {'PATH': '${binDir.path}:/usr/bin:/bin'},
          );

          final build = specs.first;
          expect(build.name, 'build');
          expect(build.command, '$zfaPath build');
        },
      );
    },
  );
}
