/// Spec 069-corpus-economics, T001 — incremental verification (RED first).
///
/// The refactor re-proof must be SCOPED to pass-registry-changed files:
/// the pass registry (`specs/<f>/tdd/pass-registry.json`) records the
/// checksum of every registered artifact file (test + subject) at the
/// last proof; a later refactor re-proves ONLY the tests covering files
/// whose checksums changed since. The full suite still runs as the
/// preflight, on the first proof, and when the nightly full-proof
/// window has expired — the full gate still exists, its frequency is
/// engineered (spec 069 FR-001..007, issue #916).
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'helpers/tdd_fixture.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/pass_registry_tracker.dart';

void main() {
  late TddFixture fx;
  const feature = '069-corpus-economics';
  String? fakeZfaBin;

  /// The fake zfa build-pass binary (cached per fixture).
  Future<String> fakeBin() async {
    if (fakeZfaBin != null) return fakeZfaBin!;
    fakeZfaBin = await fx.writeFakeZfaBin(
      logPath: p.join(fx.fakeBinDirPath, 'build.log'),
    );
    return fakeZfaBin!;
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    fakeZfaBin = null; // fresh fixture → fresh fake bin
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> seedProject() async {
    // Green suite + two registered behaviors (A/B) with pre-formatted
    // subjects so the refactor passes are clean no-ops.
    await fx.seedGreenSuite();
    await fx.registerBehavior(
      id: 'A-001',
      description: 'alpha returns 42',
      testContent: TddFixture.greenTest('alpha returns 42'),
    );
    await fx.registerBehavior(
      id: 'B-001',
      description: 'beta returns 42',
      testContent: TddFixture.greenTest('beta returns 42'),
    );
    for (final id in ['A-001', 'B-001']) {
      final subject = File(fx.subjectPathOf(id));
      await subject.parent.create(recursive: true);
      await subject.writeAsString(TddFixture.subjectReturning(id, 42));
    }
    // A spy suite script that logs every argv line (the scope lands in
    // the argv as explicit test file paths).
    final spy = await fx.writeSpyScript(
      'suite',
      output: TddFixture.greenSuiteTranscript,
    );
    await fx.rewriteProfile(
      singleTemplate: 'dart test {file} --plain-name "{name}"',
      suiteTemplate: spy,
    );
    // A fake zfa build pass that changes nothing (exit 0).
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: p.join(fx.fakeBinDirPath, 'build.log'),
    );
    return zfaBin;
  }

  Future<String> refactor({String? reproof, String? zfaBin}) async {
    final runner = CliRunner(exitOnCompletion: false);
    final args = [
      'tdd',
      'refactor',
      '--feature',
      feature,
      '--project',
      fx.root.path,
    ];
    if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
    if (reproof != null) args.addAll(['--reproof', reproof]);
    return runner.runCapturing(args);
  }

  test(
    'T001.1 first refactor re-proof is FULL and writes the pass registry',
    () async {
      final zfaBin = await seedProject();
      final out = await refactor(zfaBin: zfaBin);
      expect(out, contains('refactor: feature=$feature'), reason: out);
      expect(exitCode, 0, reason: out);

      // The pass registry exists with both behaviors' 4 files.
      final registryFile = File(
        p.join(fx.featureDir, 'tdd', 'pass-registry.json'),
      );
      expect(registryFile.existsSync(), isTrue, reason: out);
      final json =
          jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
      expect(json['feature'], feature);
      final files = (json['files'] as Map<String, dynamic>)
          .cast<String, String>();
      expect(files.length, 4, reason: 'two tests + two subjects');
      expect(json['last_full_proof_at'], isA<String>());
      // Full proof recorded.
      expect(json['last_full_proof_at'], isNotNull);

      // The suite spy was invoked exactly twice (preflight + full
      // re-proof) with NO appended test paths on either invocation.
      final log = fx.spyLog('suite');
      expect(log.length, 2, reason: log.toString());
      for (final line in log) {
        expect(line, isNot(contains('A-001')), reason: line);
        expect(line, isNot(contains('B-001')), reason: line);
      }
      expect(out, contains('re-proof scope: full'), reason: out);
      expect(zfaBin, isNotNull);
    },
  );

  test(
    'T001.2 second refactor with a changed subject re-proves SCOPED to the covering test only',
    () async {
      await seedProject();
      await refactor(
        zfaBin: await fakeBin(),
      ); // proof 1: full, registry committed

      // Mutate A's subject only (the pass-registry-changed file).
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(TddFixture.subjectReturning('A-001', 42 + 1));

      final out = await refactor(zfaBin: await fakeBin());
      expect(exitCode, 0, reason: out);
      expect(out, contains('re-proof scope: scoped'), reason: out);

      // Run 1 spawned preflight + full re-proof (2); run 2 spawned its
      // preflight + the SCOPED re-proof (2) — 4 invocations total. The
      // last one is the scoped re-proof: it carries A's test path and
      // NOT B's.
      final log = fx.spyLog('suite');
      expect(log.length, 4, reason: log.toString());
      final scopedArgv = log.last;
      expect(scopedArgv, contains('a_001_test.dart'), reason: scopedArgv);
      expect(
        scopedArgv,
        isNot(contains('b_001_test.dart')),
        reason: scopedArgv,
      );

      // Registry re-committed at the new state.
      final registryFile = File(
        p.join(fx.featureDir, 'tdd', 'pass-registry.json'),
      );
      final json =
          jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
      final changed = (json['files'] as Map<String, dynamic>)
          .cast<String, String>();
      // 4 files still registered; A's subject checksum changed vs run 1
      // is provable via the scoped argv above.

      // Cycle-log evidence names the scope.
      final cycle = await File(fx.cycleLogPath).readAsString();
      expect(cycle, contains('re-proof: scoped'), reason: cycle);
      expect(changed.length, 4);
    },
  );

  test(
    'T001.3 expired nightly full-proof window escalates the re-proof to FULL',
    () async {
      await seedProject();
      await refactor(
        zfaBin: await fakeBin(),
      ); // proof 1 (full) — stamps last_full_proof_at

      // Age the stamp beyond the default 24h nightly window.
      final registryFile = File(
        p.join(fx.featureDir, 'tdd', 'pass-registry.json'),
      );
      final json =
          jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
      final aged = DateTime.now().toUtc().subtract(const Duration(hours: 25));
      json['last_full_proof_at'] = aged.toIso8601String();
      await registryFile.writeAsString(jsonEncode(json));

      // Mutate A's subject so a delta exists.
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(TddFixture.subjectReturning('A-001', 7));

      final out = await refactor(zfaBin: await fakeBin());
      expect(exitCode, 0, reason: out);
      expect(out, contains('re-proof scope: full'), reason: out);
      expect(out, contains('nightly'), reason: out);

      // The re-proof invocation carries no appended test paths.
      final log = fx.spyLog('suite');
      expect(log.length, 4, reason: log.toString());
      expect(log.last, isNot(contains('a_001_test.dart')), reason: log.last);

      // The stamp is refreshed: the window restarts.
      final refreshed =
          jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
      expect(
        refreshed['last_full_proof_at'],
        isNot(equals(aged.toIso8601String())),
      );
    },
  );

  test(
    'T001.4 zero delta since the last proof skips the re-proof run (frequency engineered)',
    () async {
      await seedProject();
      await refactor(
        zfaBin: await fakeBin(),
      ); // proof 1: preflight + full re-proof = 2 spawns

      final out = await refactor(
        zfaBin: await fakeBin(),
      ); // nothing changed since
      expect(exitCode, 0, reason: out);
      expect(out, contains('re-proof scope: skipped'), reason: out);

      // Run 1 spawned preflight + full re-proof (2); run 2 spawned ONLY
      // its preflight (1) — 3 invocations total: no re-proof spawn
      // happened for the zero-delta run.
      final log = fx.spyLog('suite');
      expect(log.length, 3, reason: log.toString());

      // Evidence records the skip honestly.
      final cycle = await File(fx.cycleLogPath).readAsString();
      expect(cycle, contains('re-proof: skipped'), reason: cycle);
    },
  );

  test(
    'T001.5 a changed file the registry does not own escalates to FULL',
    () async {
      await seedProject();
      await refactor(zfaBin: await fakeBin()); // proof 1

      // An unregistered lib file changes (not any behavior's subject).
      await File(
        p.join(fx.root.path, 'lib', 'unregistered.dart'),
      ).writeAsString('int sideEffect() => 1;\n');

      final out = await refactor(zfaBin: await fakeBin());
      expect(exitCode, 0, reason: out);
      expect(out, contains('re-proof scope: full'), reason: out);
      expect(out, contains('unowned'), reason: out);

      final log = fx.spyLog('suite');
      expect(log.length, 4, reason: log.toString());
      expect(log.last, isNot(contains('a_001_test.dart')), reason: log.last);
    },
  );

  test(
    'T001.6 --reproof full forces the full re-proof even with a scoped delta',
    () async {
      await seedProject();
      await refactor(zfaBin: await fakeBin()); // proof 1

      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(TddFixture.subjectReturning('A-001', 9));

      final out = await refactor(reproof: 'full', zfaBin: await fakeBin());
      expect(exitCode, 0, reason: out);
      expect(out, contains('re-proof scope: full'), reason: out);
      expect(out, contains('forced'), reason: out);
      final log = fx.spyLog('suite');
      expect(log.length, 4, reason: log.toString());
      expect(log.last, isNot(contains('a_001_test.dart')), reason: log.last);
    },
  );

  test(
    'T001.7 PassRegistryTracker unit contract: capture, delta, commit',
    () async {
      await seedProject();
      final tracker = const PassRegistryTracker();
      final state = await tracker.capture(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
      );
      expect(state.feature, feature);
      expect(state.files.length, 4, reason: 'two tests + two subjects');
      // The tree covers every test/+lib/ file (registered or not).
      expect(state.tree.length, 6, reason: state.tree.keys.toString());
      expect(
        state.files.keys.every((k) => !p.isAbsolute(k)),
        isTrue,
        reason: 'registry paths are project-relative',
      );

      // Tree delta against an empty previous state = everything added.
      final previous = PassRegistryState(
        feature: feature,
        files: const {},
        lastFullProofAt: DateTime.now().toUtc().toIso8601String(),
      );
      final delta = PassRegistryTracker.delta(previous, state);
      expect(delta.added.length, 6);
      expect(delta.allChanged.length, 6);
      expect(delta.isEmpty, isFalse);

      // Identical states produce an empty delta.
      final same = PassRegistryTracker.delta(state, state);
      expect(same.isEmpty, isTrue);

      // A changed checksum is reported as changed, not added; an
      // unregistered file change is visible in the tree delta too.
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(TddFixture.subjectReturning('A-001', 5));
      await File(
        p.join(fx.root.path, 'lib', 'unregistered.dart'),
      ).writeAsString('int sideEffect() => 1;\n');
      final now = await tracker.capture(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
      );
      final changedDelta = PassRegistryTracker.delta(state, now);
      expect(changedDelta.changed, containsAll(['lib/a_001_subject.dart']));
      expect(changedDelta.added, contains('lib/unregistered.dart'));

      // Commit persists the state + stamp (tree included).
      await tracker.commit(
        featureDir: fx.featureDir,
        state: now,
        fullProof: true,
        proofAt: DateTime.now().toUtc().toIso8601String(),
      );
      final loaded = await tracker.load(fx.featureDir);
      expect(loaded, isNotNull);
      expect(loaded!.files.length, 4);
      expect(loaded.tree.length, 7, reason: loaded.tree.keys.toString());
      expect(loaded.lastFullProofAt, isNotNull);
    },
  );
}
