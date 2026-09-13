// Spec 069-corpus-economics — T004: baseline cache reuse, corpus-wide.
//
// Issue #741 made the run driver cache the full-suite baseline ONCE per
// `zfa tdd run` (per-feature). In the corpus lane every feature is a
// separate run driver spawn, so the suite baseline is re-captured once
// per FEATURE — the dominant per-feature suite spawn the corpus
// economics must remove. This file pins the corpus-wide extension:
//
//   1. CorpusBaselineCache writes/reads a project-level baseline
//      (`.zfa/corpus/run-baseline.json`) keyed by a dependency
//      fingerprint (pubspec.yaml + pubspec.lock + the profile's suite
//      template + the CONTENT of the `test/` and `lib/` trees + the
//      run-stable `.zfa/` memory/manifest state — issues #741, #916,
//      #1505).
//   2. A fingerprint MATCH reuses the snapshot across features: the
//      second feature's run driver materializes the feature-local
//      run-baseline.json from the corpus cache and NEVER runs the
//      suite (make steps still receive --suite-baseline).
//   3. Invalidation is correct, never stale: a pubspec change, a
//      test-file fix, a lib/ source edit, or a declared-state change
//      flips the fingerprint, the read misses, and the live suite
//      re-runs (issue #916: "correct invalidation on dependency
//      changes"; issue #1505: "invalidate when anything that can change
//      test outcomes changes").
//   4. Corrupt/missing cache files fall back to the live suite (the
//      #741 safe-failure stance, one level up).
//
// Fast tier: spy suite runners emit package:test-shaped transcripts.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const featureA = '090-baseline-cache';
  const featureB = '090-baseline-cache-b';
  late String suiteSpy;
  late String singleSpy;

  setUp(() async {
    fx = await TddFixture.create(featureName: featureA);
    suiteSpy = await fx.writeSpyScript(
      'suite',
      output: TddFixture.greenSuiteTranscript,
    );
    singleSpy = await fx.writeSpyScript(
      'single',
      output: '00:00 +1: unused: unused\n00:00 +1: All tests passed!',
    );
    await fx.rewriteProfile(
      singleTemplate: '$singleSpy {file} {name}',
      suiteTemplate: suiteSpy,
    );
    // The fake step driver (gen/verify-red/make/refactor per feature).
    await fx.writeFakeZfa();
    // The fingerprint inputs: the lock beside the fixture's pubspec.
    await File(
      p.join(fx.root.path, 'pubspec.lock'),
    ).writeAsString('# lock v1\n');
    // Feature B's spec dir + test list (same driven app, second feature).
    await Directory(
      p.join(fx.root.path, 'specs', featureB, 'tdd'),
    ).create(recursive: true);
    await File(
      p.join(fx.root.path, 'specs', featureB, 'tdd', 'test-list.md'),
    ).writeAsString('''
# Test List: $featureB

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| B-002 | second behavior | FR-001 | PENDING |
''');
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> drive(String featureName) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      featureName,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ]);
  }

  group('CorpusBaselineCache — persistence + fingerprint (T004 unit)', () {
    test('write() persists the corpus cache; read() round-trips on a '
        'matching fingerprint', () async {
      final cache = const CorpusBaselineCache();
      final fingerprint = await cache.dependencyFingerprint(fx.root.path);
      expect(fingerprint, isNotNull);

      final snapshot = SuiteSnapshot(
        command: suiteSpy,
        exitCode: 0,
        failedTests: const {},
        capturedAt: '2026-09-03T00:00:00.000Z',
        parseable: true,
      );
      final path = await cache.write(
        projectRoot: fx.root.path,
        snapshot: snapshot,
        fingerprint: fingerprint!,
      );
      expect(path, CorpusBaselineCache.pathFor(projectRoot: fx.root.path));
      expect(File(path).existsSync(), isTrue);

      final decoded =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      expect(decoded['dependency_fingerprint'], fingerprint);

      final read = await cache.read(
        projectRoot: fx.root.path,
        fingerprint: fingerprint,
      );
      expect(read, isNotNull);
      expect(read!.parseable, isTrue);
      expect(read.exitCode, 0);
    });

    test('a dependency change flips the fingerprint: read() misses (the '
        'stale-artifact guard — never a reused snapshot across a '
        'dependency change)', () async {
      final cache = const CorpusBaselineCache();
      final fingerprint = await cache.dependencyFingerprint(fx.root.path);
      await cache.write(
        projectRoot: fx.root.path,
        snapshot: SuiteSnapshot(
          command: suiteSpy,
          exitCode: 0,
          failedTests: const {},
          capturedAt: '2026-09-03T00:00:00.000Z',
          parseable: true,
        ),
        fingerprint: fingerprint!,
      );

      // The dependency graph changed.
      await File(
        p.join(fx.root.path, 'pubspec.yaml'),
      ).writeAsString('name: tdd_fixture\ndependencies:\n  http: ^1.0.0\n');
      final newFingerprint = await cache.dependencyFingerprint(fx.root.path);
      expect(newFingerprint, isNot(equals(fingerprint)));

      expect(
        await cache.read(
          projectRoot: fx.root.path,
          fingerprint: newFingerprint!,
        ),
        isNull,
        reason: 'a changed dependency set must NOT reuse the cache',
      );
    });

    test(
      'read() is fail-safe: missing and corrupt cache files yield null',
      () async {
        final cache = const CorpusBaselineCache();
        final fingerprint = await cache.dependencyFingerprint(fx.root.path);
        expect(
          await cache.read(
            projectRoot: fx.root.path,
            fingerprint: fingerprint!,
          ),
          isNull,
        );
        await File(
          CorpusBaselineCache.pathFor(projectRoot: fx.root.path),
        ).parent.create(recursive: true);
        await File(
          CorpusBaselineCache.pathFor(projectRoot: fx.root.path),
        ).writeAsString('{not json');
        expect(
          await cache.read(projectRoot: fx.root.path, fingerprint: fingerprint),
          isNull,
        );
      },
    );

    test('a project with no pubspec and no lock has no fingerprint — no '
        'corpus reuse (honest fallback, not a fabricated key)', () async {
      final empty = await Directory.systemTemp.createTemp('no_pubspec_');
      try {
        expect(
          await const CorpusBaselineCache().dependencyFingerprint(empty.path),
          isNull,
        );
      } finally {
        empty.deleteSync(recursive: true);
      }
    });
  });

  group('CorpusBaselineCache — #1505 fingerprint invalidation (outcome '
      'inputs: test/lib trees + .zfa memory/manifest state)', () {
    Future<String?> fingerprint() =>
        const CorpusBaselineCache().dependencyFingerprint(fx.root.path);

    test('T001: creating a file under test/ flips the fingerprint and '
        'read() misses — fixed tests must not reuse a stale baseline '
        '(#1505)', () async {
      final cache = const CorpusBaselineCache();
      final before = await fingerprint();
      expect(before, isNotNull);

      await cache.write(
        projectRoot: fx.root.path,
        snapshot: SuiteSnapshot(
          command: suiteSpy,
          exitCode: 1,
          failedTests: const {'test/broken_test.dart: broken loads [E]'},
          capturedAt: '2026-09-10T00:00:00.000Z',
          parseable: true,
        ),
        fingerprint: before!,
      );

      // The test file that produced the baseline failures gets FIXED.
      await Directory(p.join(fx.root.path, 'test')).create(recursive: true);
      await File(
        p.join(fx.root.path, 'test', 'broken_test.dart'),
      ).writeAsString('// fixed: the broken test now loads\n');

      final after = await fingerprint();
      expect(
        after,
        isNot(equals(before)),
        reason: 'a test/ tree change MUST invalidate the corpus baseline',
      );
      expect(
        await cache.read(projectRoot: fx.root.path, fingerprint: after!),
        isNull,
        reason:
            'the cached snapshot must not be served under the new '
            'fingerprint',
      );
    });

    test(
      'T002: a modified lib/ source flips the fingerprint (#1505)',
      () async {
        final libDir = Directory(p.join(fx.root.path, 'lib'));
        await libDir.create(recursive: true);
        final subject = File(p.join(libDir.path, 'subject.dart'));
        await subject.writeAsString('int answer() => 41;\n');
        final before = await fingerprint();

        await subject.writeAsString('int answer() => 42;\n');
        final after = await fingerprint();

        expect(
          after,
          isNot(equals(before)),
          reason: 'a lib/ source change can change test outcomes',
        );
      },
    );

    test('T003: .zfa/ memory/manifest state participates in the '
        'fingerprint (#1505, #1550 family)', () async {
      final before = await fingerprint();

      final manifests = Directory(p.join(fx.root.path, '.zfa', 'manifests'));
      await manifests.create(recursive: true);
      await File(
        p.join(manifests.path, 'corpus-manifest.json'),
      ).writeAsString('{"features": ["001-todo-app"]}\n');
      final withManifest = await fingerprint();
      expect(
        withManifest,
        isNot(equals(before)),
        reason: 'the corpus manifest is run-stable declared project state',
      );

      await File(
        p.join(fx.root.path, '.zfa', 'context.json'),
      ).writeAsString('{"entities": ["Todo"]}\n');
      final withContext = await fingerprint();
      expect(
        withContext,
        isNot(equals(withManifest)),
        reason: 'agent memory context is run-stable declared state',
      );
    });

    test('T003b: .zfa/AGENT_CONTRACT.md participates in the fingerprint '
        '(SC-2), while the tool-written absent→present transition of an '
        'EMPTY .zfa state does NOT flip it (review F1)', () async {
      final before = await fingerprint();

      // `ProjectContextStore.save()` creates an empty `.zfa/manifests/`
      // and writes `.zfa/context.json` at the tail of every `zfa make`
      // (plugin_manager.dart). A fresh lane therefore sees this exact
      // absent→present transition between two features.
      await Directory(
        p.join(fx.root.path, '.zfa', 'manifests'),
      ).create(recursive: true);
      await File(
        p.join(fx.root.path, '.zfa', 'context.json'),
      ).writeAsString('');
      final afterToolWrite = await fingerprint();
      expect(
        afterToolWrite,
        equals(before),
        reason:
            'an absent→present but EMPTY tool-written state carries zero '
            'declared-state change and must not force a spurious miss',
      );

      // A real content change still flips it — the pin above is not
      // vacuous (the file is keyed, it is only its emptiness that is
      // ignored).
      await File(
        p.join(fx.root.path, '.zfa', 'AGENT_CONTRACT.md'),
      ).writeAsString('# contract\n');
      final afterContract = await fingerprint();
      expect(
        afterContract,
        isNot(equals(afterToolWrite)),
        reason: 'SC-2 names .zfa/AGENT_CONTRACT.md as declared state',
      );
    });

    test('T007b: run-mutated .zfa/ dirs a normal run writes '
        '(.zfa/provenance, .zfa/decisions, .zfa/blueprints) do NOT flip '
        'the fingerprint (SC-3)', () async {
      final before = await fingerprint();
      for (final dirName in const ['provenance', 'decisions', 'blueprints']) {
        final dir = Directory(p.join(fx.root.path, '.zfa', dirName));
        await dir.create(recursive: true);
        await File(p.join(dir.path, 'entry.json')).writeAsString('{}\n');
      }
      final after = await fingerprint();
      expect(
        after,
        equals(before),
        reason: 'SC-3: these dirs are run-mutated, not declared state',
      );
    });

    test('T006: mtime-only changes do NOT flip the fingerprint '
        '(content hashing — no false invalidation)', () async {
      final testDir = Directory(p.join(fx.root.path, 'test'));
      await testDir.create(recursive: true);
      final pinned = File(p.join(testDir.path, 'pinned_test.dart'));
      await pinned.writeAsString('void main() {}\n');
      final before = await fingerprint();

      pinned.setLastModifiedSync(
        DateTime.now().toUtc().add(const Duration(days: 2)),
      );
      final after = await fingerprint();

      expect(
        after,
        equals(before),
        reason: 'metadata-only churn must not force a live suite re-run',
      );
    });

    test('T001b: DELETING a file under test/ flips the fingerprint '
        '(US-1 names created, modified, and renamed/deleted)', () async {
      final testDir = Directory(p.join(fx.root.path, 'test'));
      await testDir.create(recursive: true);
      final doomed = File(p.join(testDir.path, 'doomed_test.dart'));
      await doomed.writeAsString('void main() {}\n');
      final before = await fingerprint();

      await doomed.delete();
      final after = await fingerprint();

      expect(
        after,
        isNot(equals(before)),
        reason: 'a deletion changes the suite inputs exactly like an edit',
      );
    });

    test(
      'T011: an EMPTY test/ or lib/ directory hashes the same as an '
      'absent one — no scaffold-time false invalidation (review F3)',
      () async {
        final before = await fingerprint();
        await Directory(p.join(fx.root.path, 'test')).create(recursive: true);
        await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
        final after = await fingerprint();
        expect(
          after,
          equals(before),
          reason: 'an empty tree carries no content, like an absent one',
        );
      },
    );

    test('T009 fail-safe: a symlink under test/ is skipped — no crash, no '
        'fingerprint contribution', () async {
      final testDir = Directory(p.join(fx.root.path, 'test'));
      await testDir.create(recursive: true);
      final real = File(p.join(testDir.path, 'real_test.dart'));
      await real.writeAsString('void main() {}\n');
      final before = await fingerprint();

      await Link(p.join(testDir.path, 'link_test.dart')).create(real.path);
      final after = await fingerprint();

      expect(
        after,
        equals(before),
        reason: 'symlinks are skipped: no cycles, no platform drift',
      );
    });

    test('T010 fail-safe: an unreadable file under test/ degrades to an '
        '`unreadable` marker instead of failing the fingerprint', () async {
      final testDir = Directory(p.join(fx.root.path, 'test'));
      await testDir.create(recursive: true);
      final secret = File(p.join(testDir.path, 'secret_test.dart'));
      await secret.writeAsString('void main() {}\n');
      final before = await fingerprint();

      await Process.run('chmod', ['000', secret.path]);
      try {
        // root — and some CI images — can still read a 0o000 file; the
        // fail-safe only has meaning where the read genuinely fails.
        var unreadable = false;
        try {
          await secret.readAsBytes();
        } on FileSystemException {
          unreadable = true;
        }
        if (!unreadable) {
          markTestSkipped('0o000 is still readable in this environment');
          return;
        }

        final after = await fingerprint();
        expect(
          after,
          isNot(equals(before)),
          reason: 'the fail-safe marker replaces the unreadable content',
        );
        expect(after, isNotNull, reason: 'a read failure is never fatal');
      } finally {
        await Process.run('chmod', ['644', secret.path]);
      }
    });

    test('T007: run-mutated .zfa/ state (progress, lock, receipts, runs, '
        'plans, per-feature run-state) and the cache file itself do NOT '
        'flip the fingerprint — corpus economics preserved', () async {
      final cache = const CorpusBaselineCache();
      final before = await fingerprint();
      expect(before, isNotNull);

      // The cache file itself is written by every capture — it must be
      // self-excluded from its own key.
      await cache.write(
        projectRoot: fx.root.path,
        snapshot: SuiteSnapshot(
          command: suiteSpy,
          exitCode: 0,
          failedTests: const {},
          capturedAt: '2026-09-13T00:00:00.000Z',
          parseable: true,
        ),
        fingerprint: before!,
      );
      // Everything ONE normal run mutates after the baseline capture.
      final corpusDir = Directory(p.join(fx.root.path, '.zfa', 'corpus'));
      await corpusDir.create(recursive: true);
      await File(
        p.join(corpusDir.path, 'progress.json'),
      ).writeAsString('{"features": {}}\n');
      await File(p.join(corpusDir.path, 'run.lock')).writeAsString('1:2');
      for (final dirName in const ['receipts', 'runs', 'plans']) {
        final dir = Directory(p.join(fx.root.path, '.zfa', dirName));
        await dir.create(recursive: true);
        await File(p.join(dir.path, 'entry.json')).writeAsString('{}\n');
      }
      await File(
        p.join(fx.featureDir, 'tdd', 'run-state.json'),
      ).writeAsString('{"states": {}}\n');

      final after = await fingerprint();
      expect(
        after,
        equals(before),
        reason:
            'state a normal run mutates cannot key the cache or the '
            'next feature would always miss',
      );
      // The snapshot written under `before` still hits.
      expect(
        await cache.read(projectRoot: fx.root.path, fingerprint: before),
        isNotNull,
      );
    });

    test('T008u: the fingerprint is deterministic across repeated '
        'computations with no changes', () async {
      final a = await fingerprint();
      final b = await fingerprint();
      expect(a, equals(b));
    });
  });

  group('zfa tdd run — corpus-wide baseline reuse (T004 driver)', () {
    Future<void> seedBehavior(String featureName, String id) async {
      final testList = p.join(
        fx.root.path,
        'specs',
        featureName,
        'tdd',
        'test-list.md',
      );
      await File(testList).writeAsString('''
# Test List: $featureName

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| $id | behavior $id | FR-001 | PENDING |
''');
    }

    test('the SECOND feature\'s run reuses the corpus baseline: zero '
        'additional live suite runs, make steps still get '
        '--suite-baseline', () async {
      // Feature A's run: captures the baseline live (1 suite run) and
      // writes the corpus-wide cache.
      await seedBehavior(featureA, 'B-001');
      final out = await drive(featureA);
      expect(exitCode, 0, reason: out);
      expect(fx.spyLog('suite'), hasLength(1), reason: out);
      // The corpus cache exists.
      final cachePath = CorpusBaselineCache.pathFor(projectRoot: fx.root.path);
      expect(File(cachePath).existsSync(), isTrue, reason: out);

      // Feature B's run (the corpus lane's SECOND driver spawn): the
      // corpus cache fingerprint matches, so the suite is NOT re-run
      // and the feature-local run-baseline.json is materialized from
      // the corpus cache.
      await seedBehavior(featureB, 'B-002');
      final out2 = await drive(featureB);
      expect(exitCode, 0, reason: out2);
      expect(out2, contains('corpus-wide reuse'), reason: out2);

      // THE assertion: no additional suite invocation for feature B.
      expect(
        fx.spyLog('suite'),
        hasLength(1),
        reason: 'the second feature must not re-run the suite\n$out2',
      );

      // The feature-local baseline materialized from the corpus cache.
      final featureBBaseline = p.join(
        fx.root.path,
        'specs',
        featureB,
        'tdd',
        'run-baseline.json',
      );
      expect(File(featureBBaseline).existsSync(), isTrue, reason: out2);

      // Feature B's make steps received it via --suite-baseline.
      final makeArgv = fx
          .stepArgvLog()
          .where((line) => line.contains(' make ') && line.contains('B-002'))
          .toList();
      expect(makeArgv, isNotEmpty, reason: out2);
      for (final line in makeArgv) {
        expect(line, contains('--suite-baseline'), reason: line);
        expect(line, contains(featureBBaseline), reason: line);
      }
    });

    test('a pubspec change between runs invalidates the corpus cache: the '
        'live suite re-runs and the cache is rewritten', () async {
      await seedBehavior(featureA, 'B-001');
      final out = await drive(featureA);
      expect(exitCode, 0, reason: out);
      expect(fx.spyLog('suite'), hasLength(1), reason: out);

      // The dependency graph changed between the two feature runs.
      await File(
        p.join(fx.root.path, 'pubspec.yaml'),
      ).writeAsString('name: tdd_fixture\ndependencies:\n  args: ^2.0.0\n');

      await seedBehavior(featureB, 'B-002');
      final out2 = await drive(featureB);
      expect(exitCode, 0, reason: out2);
      // The live suite re-ran (fresh baseline) ...
      expect(fx.spyLog('suite'), hasLength(2), reason: out2);
      // ... and the cache was rewritten with the NEW fingerprint.
      final cachePath = CorpusBaselineCache.pathFor(projectRoot: fx.root.path);
      final decoded =
          jsonDecode(await File(cachePath).readAsString())
              as Map<String, dynamic>;
      final newFingerprint = await const CorpusBaselineCache()
          .dependencyFingerprint(fx.root.path);
      expect(decoded['dependency_fingerprint'], newFingerprint);
    });

    test(
      'a legacy profile suite-command change must NOT reuse the corpus '
      'baseline (the stored command must equal the loaded template)',
      () async {
        // Legacy frontmatter profile: NO machine-readable Keys block, so
        // the dependency fingerprint silently degrades to pubspec+lock —
        // a changed suite command cannot flip it. The command-equality
        // guard at the consumption site is the defense: the cached
        // snapshot must have been captured under the SAME suite command.
        Future<void> writeLegacyProfile(String suiteTemplate) async {
          final dir = Directory(p.join(fx.root.path, '.specify', 'memory'));
          await dir.create(recursive: true);
          await File(p.join(dir.path, 'tdd-profile.md')).writeAsString('''
# TDD Profile — fixture

## Commands

- Single test: `$singleSpy {file} {name}`
- Full suite (repo): `$suiteTemplate`
''');
        }

        await writeLegacyProfile(suiteSpy);
        await seedBehavior(featureA, 'B-001');
        final out = await drive(featureA);
        expect(exitCode, 0, reason: out);
        expect(fx.spyLog('suite'), hasLength(1), reason: out);
        final cachePath = CorpusBaselineCache.pathFor(
          projectRoot: fx.root.path,
        );
        expect(File(cachePath).existsSync(), isTrue, reason: out);

        // The suite command changes under the SAME pubspec/lock: the
        // fingerprint cannot see the change (no Keys block) — the command
        // guard must.
        final suiteSpyB = await fx.writeSpyScript(
          'suite-b',
          output: TddFixture.greenSuiteTranscript,
        );
        await writeLegacyProfile(suiteSpyB);

        await seedBehavior(featureB, 'B-002');
        final out2 = await drive(featureB);
        expect(exitCode, 0, reason: out2);
        // NOT reused: the live suite re-ran through the NEW command.
        expect(out2, isNot(contains('corpus-wide reuse')), reason: out2);
        expect(fx.spyLog('suite-b'), hasLength(1), reason: out2);
        // The original command's spy was NOT invoked again.
        expect(fx.spyLog('suite'), hasLength(1), reason: out2);
      },
    );

    test('a corrupt corpus cache is a safe failure: the live suite runs '
        '(never a silent pass from garbage)', () async {
      await seedBehavior(featureA, 'B-001');
      await drive(featureA);
      expect(fx.spyLog('suite'), hasLength(1));

      // Corrupt the corpus cache before feature B's run.
      final cachePath = CorpusBaselineCache.pathFor(projectRoot: fx.root.path);
      await File(cachePath).writeAsString('{garbage');

      await seedBehavior(featureB, 'B-002');
      final out2 = await drive(featureB);
      expect(exitCode, 0, reason: out2);
      expect(fx.spyLog('suite'), hasLength(2), reason: out2);
    });

    test('#1505 repro: a test-file fix between runs invalidates the corpus '
        'cache — the live suite re-runs and the stale snapshot is not '
        'reused', () async {
      await seedBehavior(featureA, 'B-001');
      final out = await drive(featureA);
      expect(exitCode, 0, reason: out);
      expect(fx.spyLog('suite'), hasLength(1), reason: out);

      // The test files that produced the baseline failures get FIXED.
      await Directory(p.join(fx.root.path, 'test')).create(recursive: true);
      await File(
        p.join(fx.root.path, 'test', 'broken_test.dart'),
      ).writeAsString('// fixed\n');

      await seedBehavior(featureB, 'B-002');
      final out2 = await drive(featureB);
      expect(exitCode, 0, reason: out2);
      // NOT reused: the live suite re-ran (a fresh baseline).
      expect(out2, isNot(contains('corpus-wide reuse')), reason: out2);
      expect(fx.spyLog('suite'), hasLength(2), reason: out2);
      // And the cache was rewritten under the NEW fingerprint.
      final cachePath = CorpusBaselineCache.pathFor(projectRoot: fx.root.path);
      final decoded =
          jsonDecode(await File(cachePath).readAsString())
              as Map<String, dynamic>;
      final current = await const CorpusBaselineCache().dependencyFingerprint(
        fx.root.path,
      );
      expect(decoded['dependency_fingerprint'], current);
    });

    test('#1505 economics guard: run-mutated state between runs keeps the '
        'corpus cache hit (zero additional suite spawns)', () async {
      // An existing test file BEFORE the first capture: its content is in
      // the fingerprint; only its mtime churns between the runs.
      await Directory(p.join(fx.root.path, 'test')).create(recursive: true);
      final pinned = File(p.join(fx.root.path, 'test', 'pinned_test.dart'));
      await pinned.writeAsString('void main() {}\n');

      await seedBehavior(featureA, 'B-001');
      final out = await drive(featureA);
      expect(exitCode, 0, reason: out);
      expect(fx.spyLog('suite'), hasLength(1), reason: out);

      // Everything a normal run mutates, plus mtime churn on the file.
      final corpusDir = Directory(p.join(fx.root.path, '.zfa', 'corpus'));
      await corpusDir.create(recursive: true);
      await File(
        p.join(corpusDir.path, 'progress.json'),
      ).writeAsString('{"features": {}}\n');
      await File(p.join(corpusDir.path, 'run.lock')).writeAsString('1:2');
      // A `zfa make` tail also creates an EMPTY `.zfa/manifests/` and
      // writes `.zfa/context.json` (ProjectContextStore.save()) — the
      // absent→present transition review F1 flagged. Reuse must survive.
      await Directory(
        p.join(fx.root.path, '.zfa', 'manifests'),
      ).create(recursive: true);
      await File(
        p.join(fx.root.path, '.zfa', 'context.json'),
      ).writeAsString('');
      pinned.setLastModifiedSync(
        DateTime.now().toUtc().add(const Duration(days: 2)),
      );

      await seedBehavior(featureB, 'B-002');
      final out2 = await drive(featureB);
      expect(exitCode, 0, reason: out2);
      expect(out2, contains('corpus-wide reuse'), reason: out2);
      expect(
        fx.spyLog('suite'),
        hasLength(1),
        reason: 'run bookkeeping must not force a live suite re-run\n$out2',
      );
    });
  });
}
