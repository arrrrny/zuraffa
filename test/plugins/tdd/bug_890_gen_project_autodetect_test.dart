// Bug #890 — `zfa tdd gen` (and the `tdd run` driver) cannot find the
// test-list when invoked from the project root without `--project`.
//
// Root cause: `ProjectRoot.find()` anchors ONLY on `pubspec.yaml`. The TDD
// commands' true project root is the directory holding `specs/` — the
// test-list lives at `specs/<feature>/tdd/test-list.md`. When the project
// root carries `specs/` but no `pubspec.yaml` while an ANCESTOR directory
// does (any parent workspace/IDE folder), the walk-up returns the ancestor
// and gen scans `<ancestor>/specs` — which does not exist — then reports
// the misleading `unknown behavior id "U24"` with no hint about which
// directory was actually searched.
//
// Reproduction (issue #890, byte-for-byte):
//   cd <project-root-with-specs-but-no-pubspec>
//   zfa tdd gen U24 --feature 004-cloud-agent-task-dispatch
//   → zfa tdd gen: unknown behavior id "U24". No matching row found in any
//     specs/<feature>/tdd/test-list.md for feature 004-...
//   zfa tdd gen U24 --feature ... --project <root>   → works
//
// The fix contract:
//   - the TDD project walk stops at the first ancestor containing
//     pubspec.yaml OR the specs/ anchor (nearest project marker wins);
//     a directory that IS the TDD project root resolves to itself
//   - explicit --project is never re-resolved (unchanged)
//   - a non-TDD caller that passes no anchor keeps the exact legacy
//     pubspec-only semantics
//   - when the resolved root has no specs/ directory at all, gen says so
//     and names the scanned root instead of a bare "unknown behavior id"
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/project_root.dart';

import '../../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  // The #890 layout: the TDD project root holds specs/ but NO
  // pubspec.yaml; the parent holds pubspec.yaml (any ancestor workspace
  // folder). buildFixture returns the project root.
  (Directory, String) buildFixture(
    Directory parent, {
    bool rootPubspec = false,
  }) {
    final root = Directory(p.join(parent.path, 'forklift'));
    root.createSync(recursive: true);
    if (rootPubspec) {
      File(
        p.join(root.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: forklift\nenvironment:\n  sdk: ^3.0.0\n');
    }
    File(
      p.join(parent.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: dev-workspace\nenvironment:\n  sdk: ^3.0.0\n');
    const feature = '004-cloud-agent-task-dispatch';
    final tddDir = Directory(p.join(root.path, 'specs', feature, 'tdd'));
    tddDir.createSync(recursive: true);
    File(
      p.join(tddDir.parent.path, 'spec.md'),
    ).writeAsStringSync('# Spec\n\n- **FR-007**: dispatches a task\n');
    File(p.join(tddDir.path, 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| U24 | Dispatches a cloud agent task | FR-007 | unit | PENDING | taskDispatcher |
''');
    return (root, feature);
  }

  group('ProjectRoot — specs anchor (unit)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('bug890_resolver_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('the walk stops at the start directory when it holds specs/ but no '
        'pubspec.yaml and an ancestor holds pubspec.yaml (issue #890)', () {
      final (root, _) = buildFixture(tmp);
      expect(
        File(p.join(root.path, 'pubspec.yaml')).existsSync(),
        isFalse,
        reason: 'precondition: the TDD root itself has no pubspec.yaml',
      );
      final resolved = ProjectRoot.find(
        startPath: root.path,
        anchorDir: 'specs',
      );
      expect(resolved, root.path);
    });

    test('legacy semantics preserved: without an anchor the ancestor pubspec '
        'still wins (non-TDD callers unchanged)', () {
      final (root, _) = buildFixture(tmp);
      final resolved = ProjectRoot.find(startPath: root.path);
      expect(
        resolved,
        tmp.path,
        reason: 'no anchor passed → pubspec-only walk, exactly as before',
      );
    });

    test('pubspec and specs at the same directory resolve identically with '
        'and without the anchor (normal Flutter project)', () {
      final (root, _) = buildFixture(tmp, rootPubspec: true);
      expect(
        ProjectRoot.find(startPath: root.path, anchorDir: 'specs'),
        root.path,
      );
      expect(ProjectRoot.find(startPath: root.path), root.path);
    });

    test('the anchor applies at every walk level: a specs-bearing ancestor '
        'between the start and the pubspec wins', () {
      // tmp/workspace (no markers) / pkg (specs/, no pubspec) /
      // sub (no markers); pubspec at tmp. Walking up from sub must stop
      // at pkg, not continue to tmp.
      final pkg = Directory(p.join(tmp.path, 'workspace', 'pkg'));
      Directory(p.join(pkg.path, 'sub', 'deeper')).createSync(recursive: true);
      Directory(p.join(pkg.path, 'specs')).createSync(recursive: true);
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('name: outer\n');
      final resolved = ProjectRoot.find(
        startPath: p.join(pkg.path, 'sub', 'deeper'),
        anchorDir: 'specs',
      );
      expect(resolved, pkg.path);
    });

    test('no specs anywhere and no pubspec anywhere → legacy fallback to the '
        'start path (unchanged)', () {
      final empty = Directory(p.join(tmp.path, 'empty'))..createSync();
      expect(
        ProjectRoot.find(startPath: empty.path, anchorDir: 'specs'),
        empty.path,
      );
    });
  });

  group('gen — project root auto-detect from the TDD root (#890, CLI)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('bug890_gen_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('gen without --project from a specs-root without pubspec resolves '
        'the project root and writes artifacts there', () async {
      final (root, feature) = buildFixture(tmp);
      final result = await runZfaSource([
        'tdd',
        'gen',
        'U24',
        '--feature',
        feature,
      ], workingDirectory: root.path);
      final out = combinedOutput(result);
      expect(
        result.exitCode,
        0,
        reason: 'gen must resolve the TDD root from CWD: $out',
      );
      expect(out, contains('behavior_id: U24'));
      expect(out, isNot(contains('unknown behavior id')));
      // The artifacts land under the TDD root, not the pubspec ancestor.
      expect(
        File(
          p.join(root.path, 'test', 'tdd', feature, 'u24_test.dart'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(root.path, 'lib', 'tdd', feature, 'u24_subject.dart'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(root.path, 'specs', feature, 'tdd', 'artifacts.json'),
        ).existsSync(),
        isTrue,
      );
    });

    test(
      'a pubspec at the TDD root still resolves to the nearest root '
      '(regression guard: the anchor never skips a nearer pubspec)',
      () async {
        final (root, feature) = buildFixture(tmp, rootPubspec: true);
        final result = await runZfaSource([
          'tdd',
          'gen',
          'U24',
          '--feature',
          feature,
        ], workingDirectory: root.path);
        final out = combinedOutput(result);
        expect(result.exitCode, 0, reason: out);
        expect(
          File(
            p.join(root.path, 'test', 'tdd', feature, 'u24_test.dart'),
          ).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'when the resolved root has no specs/ directory at all, the error '
      'names the scanned root instead of a bare unknown-behavior-id',
      () async {
        final bare = Directory(p.join(tmp.path, 'bare'))..createSync();
        final result = await runZfaSource([
          'tdd',
          'gen',
          'U24',
          '--feature',
          '004-any',
        ], workingDirectory: bare.path);
        final out = combinedOutput(result);
        expect(result.exitCode, isNot(0));
        expect(out, contains('no specs/ directory'));
        expect(
          out,
          contains(bare.path),
          reason: 'the error must name the resolved root it scanned',
        );
      },
    );
  });

  group('run driver — project root auto-detect from the TDD root (#890)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('bug890_run_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test(
      'tdd run without --project from a specs-root without pubspec drives '
      'the gen step past feature discovery',
      timeout: const Timeout(Duration(seconds: 90)),
      () async {
        final (root, feature) = buildFixture(tmp);
        final result = await runZfaSource([
          'tdd',
          'run',
          feature,
        ], workingDirectory: root.path);
        final out = combinedOutput(result);
        // The driver must resolve the TDD root itself: no feature-dir
        // runner-error, and the spawned gen step (which receives
        // --project from the driver) succeeds.
        expect(
          out,
          isNot(contains('no feature directory')),
          reason: 'the driver mis-resolved the project root: $out',
        );
        expect(out, contains('[run] U24 gen -> ok'), reason: out);
      },
    );
  });
}
