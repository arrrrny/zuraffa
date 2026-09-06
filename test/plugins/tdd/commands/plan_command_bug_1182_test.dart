// Bug #1182: `zfa tdd plan .specify/bugs/<slug>` fails — plan_command.dart
// hardcodes `$repoRoot/specs/$feature/spec.md`, so the bug extension's TDD
// mode (spec-whole for bugs, `feature_directory` pinned to
// `.specify/bugs/<slug>`) cannot plan a bug feature without the
// undocumented `specs/bug-<slug>` symlink bridge (and any tool resolving
// paths through that bridge reports odd relative paths).
//
// The fix teaches the TDD feature resolver the SUPPORTED shapes so the
// bridge is no longer needed:
//
//   1. `<name>`                  → `<root>/specs/<name>`   (legacy, unchanged)
//   2. `specs/<name>`            → `<root>/specs/<name>`   (same dir as run's stripSpecsPrefix)
//   3. `.specify/bugs/<slug>`    → `<root>/.specify/bugs/<slug>`  (bug extension pin, issue #1182)
//   4. an absolute path          → normalized as-is
//
// Artifacts (test-list.md, traceability.md) land BESIDE the resolved
// spec — never under a fabricated `specs/` path — and the "spec not
// found" error names the resolved path, not the legacy guess.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/feature_path_resolver.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmpDir;
  const slug = 'tdd-run-baseline-timeout';

  const specMd =
      '''
# Spec for $slug

**Template Version**: zuraffa-1.0

## Acceptance Scenarios

1. **Given** a seeded bug record **When** the operator plans it **Then** the test list is written beside the bug spec

## Functional Requirements

- **FR-001**: The system shall plan a bug feature rooted at .specify/bugs/<slug> without a symlink bridge.
''';

  setUp(() => tmpDir = Directory.systemTemp.createTempSync('bug_1182_'));

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedBugFeature() async {
    final bugDir = Directory(p.join(tmpDir.path, '.specify', 'bugs', slug));
    await Directory(p.join(bugDir.path, 'tdd')).create(recursive: true);
    await File(p.join(bugDir.path, 'spec.md')).writeAsString(specMd);
  }

  List<String> planArgs(String featureRef) => [
    'tdd',
    'plan',
    '--project',
    tmpDir.path,
    featureRef,
  ];

  group('Bug #1182 — tdd plan resolves .specify/bugs/<slug> directly', () {
    test('a bug feature plans without a symlink bridge', () async {
      await seedBugFeature();

      await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs('.specify/bugs/$slug'));

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason: 'the bug feature plans like any feature',
      );
      final rows = await TestListReader(
        p.join(tmpDir.path, '.specify', 'bugs', slug),
      ).read();
      expect(
        rows,
        isNotEmpty,
        reason: 'the test list was written BESIDE the bug spec',
      );
    });

    test(
      'artifacts land beside the bug spec, never under a fabricated specs/ path',
      () async {
        await seedBugFeature();

        await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(planArgs('.specify/bugs/$slug'));

        final list = File(
          p.join(tmpDir.path, '.specify', 'bugs', slug, 'tdd', 'test-list.md'),
        );
        expect(list.existsSync(), isTrue);
        expect(
          File(
            p.join(tmpDir.path, 'specs', '.specify', 'bugs', slug),
          ).existsSync(),
          isFalse,
          reason: 'no phantom specs/.specify/... directory may be created',
        );
      },
    );

    test(
      'a missing bug spec reports the RESOLVED path, not the legacy guess',
      () async {
        await Directory(
          p.join(tmpDir.path, '.specify', 'bugs', 'nope'),
        ).create(recursive: true);

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing([...planArgs('.specify/bugs/nope'), '--json']);

        expect(CliRunner.lastDispatchedExitCode, isNot(0));
        final verdictLine = out
            .split('\n')
            .lastWhere(
              (l) => l.trim().startsWith('{'),
              orElse: () => fail('no verdict.v1 envelope on stdout'),
            );
        final verdict = jsonDecode(verdictLine) as Map<String, dynamic>;
        expect(verdict['schema'], 'zuraffa.verdict.v1');
        final details = verdict['details'] as Map<String, dynamic>;
        final spec = details['spec'] as String?;
        expect(spec, isNotNull, reason: 'the envelope carries the spec path');
        expect(
          spec!,
          contains(p.join('.specify', 'bugs', 'nope', 'spec.md')),
          reason:
              'the envelope names the path the user actually referenced '
              '(truthful resolution, issue #1182 "odd relative paths")',
        );
        expect(
          spec.contains('specs/.specify'),
          isFalse,
          reason: 'no doubled specs/.specify/... guess is reported',
        );
      },
    );
  });

  group('Bug #1182 — documented shapes keep their contracts', () {
    test('a plain feature name keeps the legacy specs/ location', () async {
      const name = '1190-plain-feature';
      final dir = Directory(p.join(tmpDir.path, 'specs', name));
      await Directory(p.join(dir.path, 'tdd')).create(recursive: true);
      await File(p.join(dir.path, 'spec.md')).writeAsString(specMd);

      await CliRunner(exitOnCompletion: false).runCapturing(planArgs(name));

      expect(CliRunner.lastDispatchedExitCode, 0);
      final rows = await TestListReader(dir.path).read();
      expect(rows, isNotEmpty, reason: 'the legacy shape is unchanged');
    });

    test('a specs/-prefixed reference resolves the same feature', () async {
      const name = '1190-plain-feature';
      final dir = Directory(p.join(tmpDir.path, 'specs', name));
      await Directory(p.join(dir.path, 'tdd')).create(recursive: true);
      await File(p.join(dir.path, 'spec.md')).writeAsString(specMd);

      await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs('specs/$name'));

      expect(CliRunner.lastDispatchedExitCode, 0);
      final rows = await TestListReader(dir.path).read();
      expect(
        rows,
        isNotEmpty,
        reason: 'specs/<name> matches run stripSpecsPrefix semantics',
      );
    });
  });

  group('Bug #1182 — TddFeaturePaths unit contract', () {
    final root = '/repo';

    ResolvedFeatureDir resolve(String ref) =>
        TddFeaturePaths.resolve(projectRoot: root, featureRef: ref);

    test('plain name keeps the legacy specs/ location and name', () {
      final r = resolve('020-foo');
      expect(r.dir, p.join(root, 'specs', '020-foo'));
      expect(r.name, '020-foo');
    });

    test('specs/-prefixed reference matches stripSpecsPrefix semantics', () {
      final r = resolve('specs/020-foo');
      expect(r.dir, p.join(root, 'specs', '020-foo'));
      expect(r.name, '020-foo');
    });

    test('bug directory resolves directly (no bridge)', () {
      final r = resolve('.specify/bugs/some-bug');
      expect(r.dir, p.join(root, '.specify', 'bugs', 'some-bug'));
      expect(r.name, 'some-bug');
    });

    test('bug directory with a trailing slash resolves the same', () {
      final r = resolve('.specify/bugs/some-bug/');
      expect(r.dir, p.join(root, '.specify', 'bugs', 'some-bug'));
      expect(r.name, 'some-bug');
    });

    test('absolute path is used as-is with its basename as name', () {
      final abs = p.join(root, 'elsewhere', 'feature');
      final r = resolve(abs);
      expect(r.dir, abs);
      expect(r.name, 'feature');
    });

    test('undeclared relative shape keeps the legacy resolution', () {
      final r = resolve('somewhere/else');
      expect(r.dir, p.join(root, 'specs', 'somewhere/else'));
      expect(r.name, 'somewhere/else');
    });
  });
}
