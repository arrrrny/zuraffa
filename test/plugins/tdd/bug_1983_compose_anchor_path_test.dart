// Fast-tier regression test for bug #1983 — the composed subject's header
// must name its anchors by a PORTABLE path, never by the machine-absolute
// path the discovery resolved.
//
// Before the fix the header read
//
//   // composed against: U-001 (/Users/<dev>/zuraffa_purchase/packages/
//   zuraffa_purchase/lib/tdd/002-subscription-error-vocabulary/u1_subject.dart)
//
// — the header is a committed source file, so one developer's home
// directory ends up in the repository and the trace means nothing on
// another machine. The expected form is the anchor's package-qualified
// path (e.g. `lib/tdd/002-subscription-error-vocabulary/u1_subject.dart`
// for the flat layout, `packages/app:lib/tdd/.../u1_subject.dart` for a
// package below the project root).
//
// The fixture models the reported layout (arrrrny/zuraffa_purchase PR #4):
// a project root holding `specs/` with the package under `packages/<name>/`
// and its own `pubspec.yaml`, plus the flat single-package shape.
//
// The slow-tier end-to-end lives in `compose_command_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '900-compose-anchor-paths';

void main() {
  late Directory root;
  late Directory packageRoot;
  late Directory subjectDir;
  final runner = CliRunner(exitOnCompletion: false);

  /// Build the project tree: `specs/<feature>/tdd/` at the project root,
  /// the package (pubspec.yaml + lib/) under [packageRoot], and the
  /// registry/test-list/cycle-log artifacts compose reads.
  void seed({required bool nestedPackage}) {
    root = Directory.systemTemp.createTempSync('compose_paths_');
    packageRoot = nestedPackage
        ? Directory(p.join(root.path, 'packages', 'app'))
        : root;
    subjectDir = Directory(p.join(packageRoot.path, 'lib', 'tdd', feature))
      ..createSync(recursive: true);
    File(
      p.join(packageRoot.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: compose_pkg\n');

    final tddDir = Directory(p.join(root.path, 'specs', feature, 'tdd'))
      ..createSync(recursive: true);

    File(p.join(tddDir.path, 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the acceptance scenario completes | FR-007 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-001 | the unit behavior backing A-001 | FR-007 | PENDING |
''');

    // The registry records the project-relative subject path (issue #1397's
    // portable recorded form) — the ABSOLUTE path in the composed header is
    // the discovery's doing, not the registry's.
    final subjectRel = p
        .relative(p.join(subjectDir.path, 'u1_subject.dart'), from: root.path)
        .replaceAll(r'\', '/');
    final acceptanceRel = p
        .relative(p.join(subjectDir.path, 'a1_subject.dart'), from: root.path)
        .replaceAll(r'\', '/');
    File(p.join(tddDir.path, 'artifacts.json')).writeAsStringSync(
      jsonEncode({
        'feature': feature,
        'records': [
          {
            'behavior_id': 'A-001',
            'feature': feature,
            'source_criterion': 'FR-007',
            'test_path': 'test/a_001_test.dart',
            'subject_path': acceptanceRel,
            'runnable_test_name': 'test/a_001_test.dart::A-001',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-08-30T00:00:00.000Z',
          },
          {
            'behavior_id': 'U-001',
            'feature': feature,
            'source_criterion': 'FR-007',
            'test_path': 'test/u_001_test.dart',
            'subject_path': subjectRel,
            'runnable_test_name': 'test/u_001_test.dart::U-001',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-08-30T00:00:00.000Z',
          },
        ],
      }),
    );

    File(p.join(tddDir.path, 'cycle-log.md')).writeAsStringSync('''
## Cycle: A-001 (red)

- behavior: A-001
- kind: red
- criterion: FR-007
- exit: 1
- at: 2026-08-30T00:00:00.000Z

## Cycle: U-001 (green)

- behavior: U-001
- kind: green
- criterion: FR-007
- exit: 0
- at: 2026-08-30T00:00:00.000Z
''');

    File(p.join(subjectDir.path, 'a1_subject.dart')).writeAsStringSync('''
// GENERATED STUB — `zfa tdd gen A-001`.
library;

/// Scenario runner for behavior A-001.
int subject_a_001() => throw UnimplementedError('subject not implemented');
''');
    File(p.join(subjectDir.path, 'u1_subject.dart')).writeAsStringSync('''
library;

int subject_u_001() => 0;
''');
  }

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<String> compose() async {
    final out = await runner.runCapturing([
      'tdd',
      'compose',
      '--project',
      root.path,
      '--feature',
      feature,
      'A-001',
    ]);
    expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
    return File(p.join(subjectDir.path, 'a1_subject.dart')).readAsStringSync();
  }

  test('bug 1983: the composed header names its anchors by package-relative '
      'path (flat single-package layout)', () async {
    seed(nestedPackage: false);

    final composed = await compose();

    expect(
      composed,
      contains('// composed against: U-001 (lib/tdd/$feature/u1_subject.dart)'),
      reason: 'the header must carry the portable anchor path',
    );
    expect(composed, isNot(contains(root.path)));
    expect(_anchorPathsAreNotAbsolute(composed), isTrue);
  });

  test('bug 1983: the composed header names its anchors by package-relative '
      'path (package under packages/<name>/)', () async {
    seed(nestedPackage: true);

    final composed = await compose();

    expect(
      composed,
      contains(
        '// composed against: U-001 '
        '(packages/app:lib/tdd/$feature/u1_subject.dart)',
      ),
      reason:
          'the anchor path is qualified with the package it lives in, so it '
          'resolves from the project root and names no other package',
    );
    expect(composed, isNot(contains(root.path)));
    expect(_anchorPathsAreNotAbsolute(composed), isTrue);
  });
}

/// The invariant the leak guard asserts: every path the
/// `// composed against:` header names is RELATIVE — a machine-absolute
/// path is the leak issue #1983 is about, whichever machine it names.
bool _anchorPathsAreNotAbsolute(String composed) {
  final line = composed
      .split('\n')
      .firstWhere((l) => l.startsWith('// composed against:'));
  final paths = RegExp(r'\(([^)]*)\)').allMatches(line).map((m) => m.group(1)!);
  return paths.every((path) => !p.isAbsolute(path));
}
