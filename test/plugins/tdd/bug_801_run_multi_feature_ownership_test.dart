@Tags(['slow', 'integration'])
// Bug #801 — `zfa tdd run` must support multiple features in the same project.
//
// Reported failure (v6.1.0): run feature 001, then feature 004 — the second
// run dies at its FIRST gen step with
//
//   OwnershipConflict: test file ".../test/tdd/a1_test.dart" exists on disk
//   but the registry has no recorded ownership. Refusing to overwrite
//   non-owned content.
//
// Root cause: gen constructed feature-agnostic flat paths
// (test/tdd/<id>_test.dart) while the artifact registry is per-feature, so
// feature N+1's gen hit the FR-008 guardrail against feature N's artifacts.
// The fix (#827, PR #869) namespaces artifacts by feature-slug
// (test/tdd/<feature-slug>/, lib/tdd/<feature-slug>/); it merged ~7h AFTER
// this issue was filed, and v6.1.0 predates it — the reporter never saw it.
//
// What was still missing for #801: the issue's repro is the RUN driver
// (`zfa tdd run` twice), and the #827 regression pins cover bare `tdd gen`
// only (gen_namespacing_827_test.dart). This test pins the issue's exact
// scenario at the run level, through the real CLI, with both features'
// test lists seeded before either run:
//
//   1. `zfa tdd run 001-app-bootstrap`        → completes (exit 0);
//   2. `zfa tdd run 004-dependency-injection` → its A1 gen MUST succeed
//      (`[run] A1 gen -> ok`), no `ownership conflict` anywhere, artifacts
//      namespaced per feature, both features' pairs coexisting on disk.
//
// Known honest stop (NOT this bug): on a tree without PR #888, feature-2's
// first make still stops with `generation-error` — make's func spawn drops
// `--feature` (bug #877, fixed by PR #888) and the (correct) func ambiguity
// guard refuses the id that is now registered in both registries. That stop
// happens at `:make`, AFTER gen; this test pins only that the stop is never
// a gen/ownership failure, so it holds both before and after #888 merges.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late String repoRoot;
  late String forwarderPath;

  String findRepoRoot() {
    var dir = Directory.current;
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync() &&
          pubspec.readAsStringSync().contains('name: zuraffa')) {
        return dir.path;
      }
      if (dir.path == dir.parent.path) {
        throw StateError('cannot locate the zuraffa repo root');
      }
      dir = dir.parent;
    }
  }

  /// Seed one feature's spec + test list. Both features plan the SAME
  /// behavior ids (A1, A2) — the exact collision shape from the issue
  /// (001-app-bootstrap vs 004-dependency-injection, unit behaviors).
  Future<void> seedFeature(String featureName) async {
    final specDir = Directory(p.join(tmpDir.path, 'specs', featureName));
    await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for $featureName

## Functional Requirements

- **FR-1**: returns 42 when invoked with no args.
- **FR-2**: returns the doubled input.
''');
    await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
# Test List for $featureName

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| A1 | returns 42 when invoked with no args | FR-1 | unit | PENDING | sampleSubject |
| A2 | returns the doubled input | FR-2 | unit | PENDING | sampleSubject |
''');
  }

  Future<ProcessResult> zfa(List<String> args) => Process.run(
    Platform.resolvedExecutable,
    [p.join(repoRoot, 'bin', 'zfa.dart'), ...args],
    workingDirectory: tmpDir.path,
  );

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('bug801_run_multi_feature_');
    repoRoot = findRepoRoot();

    // Minimal Dart package the TDD baseline can attach to (the issue's
    // `zik_zak_tdd` project shape).
    await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: zik_zak_tdd
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''');

    for (final feature in const [
      '001-app-bootstrap',
      '004-dependency-injection',
    ]) {
      await seedFeature(feature);
    }

    // The TDD baseline (dart_test.yaml, smoke test, profile, dev deps) —
    // the same provisioning step the issue's repro runs.
    final init = await zfa(['tdd', 'init', '--project', tmpDir.path]);
    expect(
      init.exitCode,
      0,
      reason: 'tdd init failed:\n${init.stdout}${init.stderr}',
    );
    final pubGet = await Process.run('dart', [
      'pub',
      'get',
    ], workingDirectory: tmpDir.path);
    expect(
      pubGet.exitCode,
      0,
      reason: 'fixture pub get failed:\n${pubGet.stdout}${pubGet.stderr}',
    );

    // Pure exec forwarder to the REAL zfa CLI (sc_017 pattern): the run
    // driver's --zfa-bin entrypoint; it adds no semantics of its own.
    final binDir = Directory(p.join(tmpDir.path, 'fake_bin'));
    await binDir.create(recursive: true);
    forwarderPath = p.join(binDir.path, 'zfa');
    await File(forwarderPath).writeAsString(
      '#!/usr/bin/env bash\nexec '
      '"${Platform.resolvedExecutable}" '
      '"${p.join(repoRoot, 'bin', 'zfa.dart')}" '
      '"\$@"\n',
    );
    await Process.run('chmod', ['+x', forwarderPath]);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('bug #801: the second feature\'s run must not die at gen with an '
      'ownership conflict', () async {
    // -- Journey step 1 (the issue's "succeeds" run) -------------------
    final run1 = await zfa([
      'tdd',
      'run',
      '001-app-bootstrap',
      '--project',
      tmpDir.path,
      '--zfa-bin',
      forwarderPath,
    ]);
    expect(
      run1.exitCode,
      0,
      reason: 'feature-1 run failed:\n${run1.stdout}${run1.stderr}',
    );
    expect(
      run1.stdout,
      contains('run: feature=001-app-bootstrap result=complete'),
      reason:
          'feature-1 must complete before feature-2 starts '
          '(the issue\'s precondition):\n${run1.stdout}',
    );

    // -- Journey step 2 (the issue's failing run) ----------------------
    // Pre-#827 this died HERE, at A1 gen, with the ownership conflict —
    // the failure signature the issue reported.
    final run2 = await zfa([
      'tdd',
      'run',
      '004-dependency-injection',
      '--project',
      tmpDir.path,
      '--zfa-bin',
      forwarderPath,
    ]);
    final out2 = '${run2.stdout}${run2.stderr}';

    // THE pin: feature-2's A1 gen succeeds — no ownership conflict.
    expect(
      out2,
      contains('[run] A1 gen -> ok'),
      reason:
          'the issue\'s exact failing step must succeed '
          '(run 2 output):\n$out2',
    );
    expect(
      out2,
      isNot(contains('ownership conflict')),
      reason:
          'the FR-008 guardrail must never fire across features '
          '(run 2 output):\n$out2',
    );
    expect(
      out2,
      isNot(contains('OwnershipConflict')),
      reason:
          'no ownership-conflict exception may surface '
          '(run 2 output):\n$out2',
    );

    // Wherever run 2 stops (it may stop honestly at its first make while
    // PR #888 is unmerged — bug #877's func-spawn ambiguity — and it may
    // complete once #888 lands), the stop must NEVER be at gen.
    expect(
      out2,
      isNot(contains('step=gen')),
      reason:
          'a run-2 stop must never be a gen failure '
          '(run 2 output):\n$out2',
    );
    expect(
      out2,
      isNot(contains(':gen')),
      reason:
          'no stopped_at=<id>:gen may appear '
          '(run 2 output):\n$out2',
    );

    // Both features' artifacts coexist, each in its own namespace — the
    // core promise of multi-feature support.
    for (final feature in const [
      '001-app-bootstrap',
      '004-dependency-injection',
    ]) {
      expect(
        File(
          p.join(tmpDir.path, 'test', 'tdd', feature, 'a1_test.dart'),
        ).existsSync(),
        isTrue,
        reason: '$feature test artifact must exist after run 2',
      );
      expect(
        File(
          p.join(tmpDir.path, 'lib', 'tdd', feature, 'a1_subject.dart'),
        ).existsSync(),
        isTrue,
        reason: '$feature subject artifact must exist after run 2',
      );
      final registry = File(
        p.join(tmpDir.path, 'specs', feature, 'tdd', 'artifacts.json'),
      );
      expect(
        registry.existsSync(),
        isTrue,
        reason: '$feature registry must exist',
      );
      final raw = registry.readAsStringSync();
      expect(
        raw,
        contains('test/tdd/$feature/a1_test.dart'),
        reason: '$feature registry must record its namespaced test path',
      );
      expect(
        raw,
        contains('"$feature"'),
        reason: '$feature registry must stamp its own feature name',
      );
    }

    // On the fixed tree feature-1's pair is namespaced; asserting it
    // here (after run 2) also proves the two features' artifacts
    // coexisted across the whole journey.
    expect(
      File(
        p.join(tmpDir.path, 'test', 'tdd', '001-app-bootstrap', 'a1_test.dart'),
      ).existsSync(),
      isTrue,
      reason: 'feature-1 test artifact must exist after run 2',
    );

    // Feature-2's registry owns ITS namespace, not feature-1's.
    final registry2 = File(
      p.join(
        tmpDir.path,
        'specs',
        '004-dependency-injection',
        'tdd',
        'artifacts.json',
      ),
    ).readAsStringSync();
    expect(
      registry2,
      isNot(contains('test/tdd/001-app-bootstrap')),
      reason: 'feature-2 must never reference feature-1\'s namespace',
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
