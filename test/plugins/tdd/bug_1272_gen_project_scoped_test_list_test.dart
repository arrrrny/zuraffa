// Bug #1272 — `zfa tdd gen`: `--project` scoping of the test-list
// resolution — the parser must read ONLY
// `<project>/specs/<feature>/tdd/test-list.md` under the resolved
// project root, never a test-list.md outside it.
//
// Root cause (verified on master d3679e0f): gen resolves the feature's
// test list as `<root>/specs/<featureRef>/tdd/test-list.md` with NO
// validation at resolution time. A path-shaped `--feature` reference
// (e.g. `../../../example/specs/004-login-ui`) normalizes OUTSIDE the
// project root and the parser reads whichever foreign test-list.md the
// escape hits first — monorepo sibling directories (`example/specs/`,
// `.worktrees/pr-XXX/specs/...`, `corpus/regression/.../specs/u2-flow/`)
// all carry differently-shaped lists. The reporter's 7-column
// `example/specs/004-login-ui` list then failed INSIDE the parser and
// surfaced as gen's own error, byte-for-byte:
//
//   ❌ Error: Bad state: zfa tdd gen: malformed test list —
//   test-list.md line 23: expected 4 columns (id/behavior/traces/state),
//   found 7: "| A1 | acceptance | User Story 1, Scenario 1 | DONE | ..."
//
// gen's existing `_validateFeatureSegment` (bug #827) does NOT cover
// this: it guards the artifact path only and runs AFTER the row was
// found — after the foreign list was already read and parsed. Every
// other TDD command (verify, make, refactor, compose, verify-red, the
// run driver) validates the feature segment BEFORE using it; gen's
// test-list resolution is the one unguarded path.
//
// The fix contract (assessment remediation, unchanged semantics):
//   1. the `--feature` reference is validated BEFORE any test-list read
//      (containment first: the resolution must stay inside
//      `<project>/specs`; then segment shape: ONE spec directory name);
//   2. the default (no `--project`) resolution is unchanged, and the
//      strict `--project` scoping over decoy-laden monorepos keeps
//      resolving the PROJECT's own test list.
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/commands/gen_command.dart';

import '../../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory tmp;
  late Directory monorepo;
  late Directory projectRoot; // apps/login_demo

  const feature = '001-login-ui';
  const projectRow = 'PROJECT acceptance row';
  const rootLevelRow = 'ROOT-LEVEL acceptance row';

  // The issue's monorepo layout: the project under apps/, plus the
  // confusingly-named sibling spec trees the parser must never touch —
  // `example/specs/004-login-ui` (7-column shape, the reported decoy)
  // and `corpus/regression/.../specs/u2-flow` (same 7-column shape).
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug1272_');
    monorepo = Directory(p.join(tmp.path, 'monorepo'))
      ..createSync(recursive: true);
    File(
      p.join(monorepo.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: monorepo\nenvironment:\n  sdk: ^3.0.0\n');

    // Decoy 1: example/specs/004-login-ui — the 7-column schema from
    // the issue report (a row gen must NEVER read under --project).
    final exampleTdd = Directory(
      p.join(monorepo.path, 'example', 'specs', '004-login-ui', 'tdd'),
    )..createSync(recursive: true);
    File(p.join(exampleTdd.path, 'test-list.md')).writeAsStringSync('''
# Test List: 004-login-ui

## Outer loop: acceptance behaviors

| id | behavior | traces | state | notes | path | extra |
|----|----------|--------|-------|-------|------|-------|
| A1 | acceptance | US1, S1 | DONE | toggle method is generated across all layers | test/integration/toggle_method_test.dart | zzz |
''');

    // Decoy 2: corpus regression spec tree (7-column shape).
    final corpusTdd = Directory(
      p.join(
        monorepo.path,
        'corpus',
        'regression',
        'x',
        'specs',
        'u2-flow',
        'tdd',
      ),
    )..createSync(recursive: true);
    File(p.join(corpusTdd.path, 'test-list.md')).writeAsStringSync('''
# Test List: u2-flow

## Inner loop: unit behaviors

| id | behavior | traces | state | notes | path | extra |
|----|----------|--------|-------|-------|------|-------|
| A1 | CORPUS unit row | FR-1 | DONE | n | t/x.dart | z |
''');

    // The real project: apps/login_demo with its OWN specs tree.
    projectRoot = Directory(p.join(monorepo.path, 'apps', 'login_demo'))
      ..createSync(recursive: true);
    File(
      p.join(projectRoot.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: login_demo\nenvironment:\n  sdk: ^3.0.0\n');
    final projectTdd = Directory(
      p.join(projectRoot.path, 'specs', feature, 'tdd'),
    )..createSync(recursive: true);
    File(
      p.join(projectTdd.parent.path, 'spec.md'),
    ).writeAsStringSync('# Spec\n\n- **FR-007**: logs the user in\n');
    File(p.join(projectTdd.path, 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| A1 | $projectRow | US1.AC1 | PENDING |
''');

    // A root-level specs tree (canonical 4-column): what the DEFAULT
    // (no --project) resolution reads from the monorepo root.
    final rootTdd = Directory(p.join(monorepo.path, 'specs', feature, 'tdd'))
      ..createSync(recursive: true);
    File(p.join(rootTdd.path, 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| A1 | $rootLevelRow | US1.AC1 | PENDING |
''');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('gen — test-list scope rejection contract (unit, #1272)', () {
    test('a plain feature name is accepted', () {
      expect(
        GenCommand.testListScopeRejection(projectRoot.path, feature),
        isNull,
      );
    });

    test('a reference normalizing outside the project root is rejected '
        '(containment — the remediation)', () {
      final rejection = GenCommand.testListScopeRejection(
        projectRoot.path,
        '../../../example/specs/004-login-ui',
      );
      expect(rejection, isNotNull);
      expect(rejection!, contains('outside the project root'));
      expect(rejection, contains('<project>/specs/<feature>/tdd/test-list.md'));
    });

    test('the root-level specs tree is ALSO outside the --project root '
        '(the escape target being valid does not matter)', () {
      final rejection = GenCommand.testListScopeRejection(
        projectRoot.path,
        '../../../specs/$feature',
      );
      expect(rejection, isNotNull);
      expect(rejection!, contains('outside the project root'));
    });

    test('a path-shaped reference that stays inside the root is still '
        'rejected (segment shape — the house contract)', () {
      final rejection = GenCommand.testListScopeRejection(
        projectRoot.path,
        'specs/$feature',
      );
      expect(rejection, isNotNull);
      expect(rejection!, contains('invalid --feature'));
      expect(rejection, contains('not a path'));
    });

    test('bare dot segments are rejected', () {
      expect(
        GenCommand.testListScopeRejection(projectRoot.path, '.'),
        contains('invalid --feature'),
      );
      expect(
        GenCommand.testListScopeRejection(projectRoot.path, '..'),
        contains('outside the project root'),
      );
      expect(
        GenCommand.testListScopeRejection(projectRoot.path, r'..\x'),
        isNotNull,
      );
    });
  });

  group(
    'gen — test-list resolution scoped to the project root (#1272, CLI)',
    () {
      test(
        'a path-shaped --feature is rejected BEFORE any test-list read: '
        'the foreign 7-column example/specs list is never parsed '
        '(the reported "malformed test list — found 7" repro)',
        timeout: const Timeout(Duration(seconds: 120)),
        () async {
          final result = await runZfaSource([
            'tdd',
            'gen',
            'A1',
            '--project',
            'apps/login_demo',
            '--feature',
            '../../../example/specs/004-login-ui',
            '--dry-run',
          ], workingDirectory: monorepo.path);
          final out = combinedOutput(result);
          expect(
            result.exitCode,
            isNot(0),
            reason: 'the escaping reference must be rejected: $out',
          );
          expect(out, contains('outside the project root'), reason: out);
          // The foreign list must not even be READ: its parse failure
          // (the reported repro's error) must never surface.
          expect(out, isNot(contains('malformed test list')), reason: out);
          expect(out, isNot(contains('found 7')), reason: out);
        },
      );

      test(
        'an escaping --feature pointing at a VALID foreign list is also '
        'rejected — the parser never walks above the project root',
        timeout: const Timeout(Duration(seconds: 120)),
        () async {
          // ../../../specs/001-login-ui normalizes to the monorepo root's
          // own (valid, 4-column, A1-carrying) spec tree. Reading it would
          // "work" — and still be the bug: the resolved test list is
          // outside the project root.
          final result = await runZfaSource([
            'tdd',
            'gen',
            'A1',
            '--project',
            'apps/login_demo',
            '--feature',
            '../../../specs/$feature',
            '--dry-run',
          ], workingDirectory: monorepo.path);
          final out = combinedOutput(result);
          expect(result.exitCode, isNot(0), reason: out);
          expect(out, contains('outside the project root'), reason: out);
          expect(out, isNot(contains(rootLevelRow)), reason: out);
        },
      );

      test(
        'a path-shaped --feature that stays INSIDE the root is rejected as '
        'a usage error (a feature reference is one directory name)',
        timeout: const Timeout(Duration(seconds: 120)),
        () async {
          final result = await runZfaSource([
            'tdd',
            'gen',
            'A1',
            '--project',
            'apps/login_demo',
            '--feature',
            'specs/$feature',
            '--dry-run',
          ], workingDirectory: monorepo.path);
          final out = combinedOutput(result);
          expect(result.exitCode, isNot(0), reason: out);
          expect(out, contains('invalid --feature'), reason: out);
        },
      );

      test(
        'batch gen rejects the escaping --feature the same way (no '
        'verdict=stopped masking the real cause)',
        timeout: const Timeout(Duration(seconds: 120)),
        () async {
          final result = await runZfaSource([
            'tdd',
            'gen',
            '--all',
            '--project',
            'apps/login_demo',
            '--feature',
            '../../../example/specs/004-login-ui',
          ], workingDirectory: monorepo.path);
          final out = combinedOutput(result);
          expect(result.exitCode, isNot(0), reason: out);
          expect(out, contains('outside the project root'), reason: out);
          expect(out, isNot(contains('found 7')), reason: out);
          expect(out, isNot(contains('verdict=stopped')), reason: out);
        },
      );

      test(
        'REGRESSION GUARD — strict --project scoping over the decoy-laden '
        'monorepo still resolves the PROJECT test list (and never the '
        'root-level or example/ one)',
        timeout: const Timeout(Duration(seconds: 120)),
        () async {
          final result = await runZfaSource([
            'tdd',
            'gen',
            'A1',
            '--project',
            'apps/login_demo',
            '--feature',
            feature,
            '--dry-run',
          ], workingDirectory: monorepo.path);
          final out = combinedOutput(result);
          expect(result.exitCode, 0, reason: out);
          expect(out, contains(projectRow), reason: out);
          expect(out, isNot(contains(rootLevelRow)), reason: out);
        },
      );

      test(
        'REGRESSION GUARD — the unscoped (no --feature) scan with --project '
        'reads ONLY the project specs tree',
        timeout: const Timeout(Duration(seconds: 120)),
        () async {
          final result = await runZfaSource([
            'tdd',
            'gen',
            'A1',
            '--project',
            'apps/login_demo',
            '--dry-run',
          ], workingDirectory: monorepo.path);
          final out = combinedOutput(result);
          expect(result.exitCode, 0, reason: out);
          expect(out, contains(projectRow), reason: out);
          expect(out, isNot(contains(rootLevelRow)), reason: out);
        },
      );

      test(
        'REGRESSION GUARD — default (no --project) behavior unchanged: from '
        'the monorepo root the root-level specs tree is scanned',
        timeout: const Timeout(Duration(seconds: 120)),
        () async {
          final result = await runZfaSource([
            'tdd',
            'gen',
            'A1',
            '--feature',
            feature,
            '--dry-run',
          ], workingDirectory: monorepo.path);
          final out = combinedOutput(result);
          expect(result.exitCode, 0, reason: out);
          expect(out, contains(rootLevelRow), reason: out);
          expect(out, isNot(contains(projectRow)), reason: out);
        },
      );
    },
  );
}
