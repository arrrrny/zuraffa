@TestOn('linux || mac-os')
@Tags(['regression'])
// Spec 1520 — per-run scratch TMPDIR (issue #1520).
//
// Every `dart test` child of a tdd command writes a
// `$TMPDIR/dart_test.kernel.<random>/` kernel dir into the SHARED user
// TMPDIR, where any agent's #1507 janitor sweep can delete another agent's
// actively-compiling kernel. The fix is isolation by construction: each tdd
// command acquires ONE per-run scratch dir (`zfa-<feature>-<random>`),
// injects it as TMPDIR/TEMP/TMP into every child environment, and deletes
// it best-effort at run end.
//
// Contract pinned here (spec 1520):
//   B1 — `acquire` creates `zfa-<label>-<random>` under the effective temp
//        root of the INJECTED environment (TMPDIR/TEMP/TMP, else
//        Directory.systemTemp); labels sanitize `[^A-Za-z0-9._-]` to `_`.
//   B2 — root priority: `ZFA_TMPDIR` > `.zfa.json` `tdd.tmpDir` > the
//        effective temp root; empty values fall through to the next tier.
//   B3 — `childEnvironment` overrides TMPDIR/TEMP/TMP to the scratch path
//        and preserves every other base variable.
//   B4 — `dispose` deletes the scratch recursively and is idempotent.
//   B5 — an unusable configured root makes `acquire` return null —
//        best-effort, never a throw.
//   B6 — `runTimed(environment:)` passthrough: the child observes the
//        injected TMPDIR (the spawn chokepoint, tdd_timeout.dart).
//   B7 — `StepRunner(childEnvironment:)` injection: the spawned step child
//        observes the injected TMPDIR (step_runner.dart).
//
// Platform contract: B6/B7 probe real POSIX children (`printf "$TMPDIR"`),
// so the suite is tagged for the platforms the repo's spawn suites target.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/scratch_tmpdir.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_timeout.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('zfa1520-sandbox-');
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  group('B1: acquire — per-run scratch under the effective temp root', () {
    test('uses the injected TMPDIR as the default root and sanitizes the '
        'label into the zfa-<label>-<random> name', () async {
      final userTmp = Directory(p.join(sandbox.path, 'user-tmp'))
        ..createSync(recursive: true);

      final scratch = await ScratchTmpDir.acquire(
        label: 'my feature/x!',
        environment: {'TMPDIR': userTmp.path},
      );

      expect(scratch, isNotNull);
      final name = p.basename(scratch!.path);
      expect(
        name,
        startsWith('zfa-my_feature_x_-'),
        reason:
            'the label is sanitized ([^A-Za-z0-9._-] -> _) and the '
            'createTemp random suffix follows it',
      );
      expect(
        p.dirname(scratch.path),
        userTmp.path,
        reason:
            'the default scratch root is the effective temp root of '
            'the injected environment',
      );
    });

    test(
      'falls back TEMP then TMP then systemTemp when TMPDIR is absent',
      () async {
        final tmpA = Directory(p.join(sandbox.path, 'tmp-a'))..createSync();
        final tmpB = Directory(p.join(sandbox.path, 'tmp-b'))..createSync();

        final viaTemp = await ScratchTmpDir.acquire(
          label: 'f',
          environment: {'TEMP': tmpA.path},
        );
        expect(p.dirname(viaTemp!.path), tmpA.path);

        final viaTmp = await ScratchTmpDir.acquire(
          label: 'f',
          environment: {'TMP': tmpB.path},
        );
        expect(p.dirname(viaTmp!.path), tmpB.path);

        final viaSystem = await ScratchTmpDir.acquire(
          label: 'f',
          environment: <String, String>{'PATH': '/usr/bin'},
        );
        expect(p.dirname(viaSystem!.path), Directory.systemTemp.path);
      },
    );
  });

  group('B2: configurable scratch root (ZFA_TMPDIR > .zfa.json > default)', () {
    test(
      'ZFA_TMPDIR names the scratch root and wins over the ambient TMPDIR',
      () async {
        final cfgRoot = Directory(p.join(sandbox.path, 'cfg-root'))
          ..createSync(recursive: true);
        final userTmp = Directory(p.join(sandbox.path, 'user-tmp'))
          ..createSync(recursive: true);

        final scratch = await ScratchTmpDir.acquire(
          label: 'f',
          environment: {'ZFA_TMPDIR': cfgRoot.path, 'TMPDIR': userTmp.path},
        );

        expect(
          p.dirname(scratch!.path),
          cfgRoot.path,
          reason: 'the configured root wins over the effective temp root',
        );
      },
    );

    test(
      '.zfa.json tdd.tmpDir names the root when ZFA_TMPDIR is absent',
      () async {
        final project = Directory(p.join(sandbox.path, 'proj'))
          ..createSync(recursive: true);
        final cfgRoot = Directory(p.join(sandbox.path, 'cfg-root'))
          ..createSync(recursive: true);
        File(
          p.join(project.path, '.zfa.json'),
        ).writeAsStringSync('{"tdd": {"tmpDir": "${cfgRoot.path}"}}');

        final scratch = await ScratchTmpDir.acquire(
          label: 'f',
          projectRoot: project.path,
          environment: {'TMPDIR': sandbox.path},
        );

        expect(p.dirname(scratch!.path), cfgRoot.path);
      },
    );

    test(
      'ZFA_TMPDIR wins over .zfa.json, and empty values fall through',
      () async {
        final project = Directory(p.join(sandbox.path, 'proj'))
          ..createSync(recursive: true);
        final envRoot = Directory(p.join(sandbox.path, 'env-root'))
          ..createSync(recursive: true);
        final cfgRoot = Directory(p.join(sandbox.path, 'cfg-root'))
          ..createSync(recursive: true);
        File(
          p.join(project.path, '.zfa.json'),
        ).writeAsStringSync('{"tdd": {"tmpDir": "${cfgRoot.path}"}}');

        final byEnv = await ScratchTmpDir.acquire(
          label: 'f',
          projectRoot: project.path,
          environment: {'ZFA_TMPDIR': envRoot.path},
        );
        expect(
          p.dirname(byEnv!.path),
          envRoot.path,
          reason: 'the invocation-level env wins over the project config',
        );

        final byCfg = await ScratchTmpDir.acquire(
          label: 'f',
          projectRoot: project.path,
          environment: {'ZFA_TMPDIR': ''},
        );
        expect(
          p.dirname(byCfg!.path),
          cfgRoot.path,
          reason: 'an empty ZFA_TMPDIR falls through to .zfa.json',
        );
      },
    );
  });

  group('B3: childEnvironment — TMPDIR/TEMP/TMP override, base merge', () {
    test(
      'overrides the three temp vars and preserves everything else',
      () async {
        final userTmp = Directory(p.join(sandbox.path, 'user-tmp'))
          ..createSync(recursive: true);
        final scratch = await ScratchTmpDir.acquire(
          label: 'f',
          environment: {'TMPDIR': userTmp.path},
        );

        final env = scratch!.childEnvironment(
          base: {'PATH': '/opt/bin', 'HOME': '/home/zfa'},
        );

        expect(env['TMPDIR'], scratch.path);
        expect(env['TEMP'], scratch.path);
        expect(env['TMP'], scratch.path);
        expect(env['PATH'], '/opt/bin', reason: 'base variables are preserved');
        expect(env['HOME'], '/home/zfa');
      },
    );

    test('defaults to the platform environment as the base', () async {
      final userTmp = Directory(p.join(sandbox.path, 'user-tmp'))
        ..createSync(recursive: true);
      final scratch = await ScratchTmpDir.acquire(
        label: 'f',
        environment: {'TMPDIR': userTmp.path},
      );

      final env = scratch!.childEnvironment();

      expect(env['TMPDIR'], scratch.path);
      if (Platform.environment.containsKey('PATH')) {
        expect(env['PATH'], Platform.environment['PATH']);
      }
    });
  });

  group('B4: dispose — best-effort recursive delete, idempotent', () {
    test('deletes the scratch tree and survives a second dispose', () async {
      final userTmp = Directory(p.join(sandbox.path, 'user-tmp'))
        ..createSync(recursive: true);
      final scratch = await ScratchTmpDir.acquire(
        label: 'f',
        environment: {'TMPDIR': userTmp.path},
      );
      Directory(
        p.join(scratch!.path, 'dart_test.kernel.leak'),
      ).createSync(recursive: true);
      File(
        p.join(scratch.path, 'dart_test.kernel.leak', 'out.dill'),
      ).writeAsStringSync('dill');

      await scratch.dispose();

      expect(
        Directory(scratch.path).existsSync(),
        isFalse,
        reason:
            'run-end cleanup deletes the run\'s own scratch '
            'recursively (the #1507 leak fixed by construction)',
      );
      expect(
        userTmp.existsSync(),
        isTrue,
        reason: 'only the scratch goes — never its root',
      );

      await scratch.dispose(); // idempotent, no throw
      expect(Directory(scratch.path).existsSync(), isFalse);
    });
  });

  group('B5: acquire is best-effort', () {
    test('an unusable configured root yields null, never a throw', () async {
      final notADir = File(p.join(sandbox.path, 'root-is-a-file'))
        ..writeAsStringSync('not a directory');

      final scratch = await ScratchTmpDir.acquire(
        label: 'f',
        environment: {'ZFA_TMPDIR': notADir.path},
      );

      expect(
        scratch,
        isNull,
        reason:
            'a scratchless run (children inherit the ambient TMPDIR) '
            'always beats a crashed command',
      );
    });
  });

  group('B6: runTimed — the spawn chokepoint forwards the environment', () {
    test('the child observes the injected TMPDIR', () async {
      final result = await runTimed(
        'sh',
        ['-c', 'printf %s "\$TMPDIR"'],
        environment: const {'TMPDIR': '/zfa-scratch-probe'},
        timeout: const Duration(seconds: 30),
      );

      expect(result.exitCode, 0);
      expect(
        result.stdout,
        '/zfa-scratch-probe',
        reason:
            'runTimed must forward the caller\'s environment so the '
            'per-run scratch reaches every child',
      );
    });
  });

  group('B7: StepRunner — childEnvironment reaches the step child', () {
    test('the spawned step child observes the injected TMPDIR', () async {
      final probe = File(p.join(sandbox.path, 'zfa-tmp-probe'))
        ..writeAsStringSync('#!/bin/sh\necho "TMPDIR=\$TMPDIR"\nexit 0\n');
      Process.runSync('chmod', ['+x', probe.path]);

      final runner = StepRunner(
        zfaBin: probe.path,
        childEnvironment: const {'TMPDIR': '/zfa-step-scratch'},
      );
      final result = await runner.run(
        step: 'gen',
        behaviorId: 'B-001',
        feature: '090-tdd-fixture',
        projectRoot: sandbox.path,
      );

      expect(result.success, isTrue, reason: result.output);
      expect(
        result.output,
        contains('TMPDIR=/zfa-step-scratch'),
        reason:
            'the run driver\'s step children must observe the '
            'per-run scratch, not the shared user TMPDIR',
      );
    });
  });
}
