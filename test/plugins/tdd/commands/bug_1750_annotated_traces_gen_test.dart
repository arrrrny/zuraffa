// Bug #1750 — an ANNOTATED traces cell (`Class.method (path/to/component.dart)`)
// is provenance, not part of the member reference. The `(`-carrying token used
// to be dropped whole by `SpecParser.traceTokens` (the expected-signature drop
// rule), the row read as unbound, `declaredRoutingFor` returned null, and gen
// degraded to the legacy stub — `int subject_u2()` for a contract declared
// `branchIndex(int index) -> int?` — a signature that can never express the
// behaviour (the #1259/#1651 vacuous-artifact class: gen reports success and
// the dead end only shows up at make).
//
// The fix strips a trailing whitespace-separated parenthesised annotation
// before the drop rule (the resolver-side twin of the plan-time
// `_expandBehaviorTokens` strip), so the annotated cell resolves the declared
// signature and gen emits the CONTRACT-DERIVED stub:
//
//   U-1750-G1 — the annotated test-list row: gen emits
//               `int? subject_u2(int index)` with the contract header, and the
//               paired test imports the subject (the reported symptom shape).
//   U-1750-G2 — the bare cell on the same fixture: byte-identical declared
//               emission (the clean-trace control from the issue's A/B).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmp;
  const feature = '1750-annotated-trace';
  const annotatedTraces =
      'FR-002, ShellNavItem.branchIndex '
      '(lib/src/domain/entities/shell_nav_item/shell_nav_item.dart)';

  /// The TDD profile gen's entry preflight reads (the bug_1518 harness
  /// idiom, shared by the bug_1420 gen test).
  void seedProfile() {
    final memoryDir = Directory(p.join(tmp.path, '.specify', 'memory'));
    memoryDir.createSync(recursive: true);
    File(p.join(memoryDir.path, 'tdd-profile.md')).writeAsStringSync('''
# TDD Profile — fixture

## Commands

- Single test: `dart test {file} --plain-name "{name}"`
- Full suite: `dart test`

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test'
file: 'dart test {file}'
coverage: 'dart test --coverage'
```
''');
  }

  void seedPubspec() {
    File(
      p.join(tmp.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: fixture_app\nenvironment:\n  sdk: ^3.11.0\n');
  }

  /// The issue's exact repro shape: a Domain contract with a parameter and a
  /// nullable return, FR-002 tracing it, and a test-list row whose traces cell
  /// carries the reconciler's `component_of()` annotation.
  void seedFeature({required String traces}) {
    seedProfile();
    seedPubspec();
    final featureDir = Directory(p.join(tmp.path, 'specs', feature));
    featureDir.createSync(recursive: true);
    File(p.join(featureDir.path, 'spec.md')).writeAsStringSync('''
# Spec: $feature

## Functional Requirements

- **FR-002**: the shell nav item reports the branch index for an index

### Layer Contracts

**Domain**:
- `ShellNavItem`: `branchIndex(int index) -> int?`
''');
    final tddDir = Directory(p.join(featureDir.path, 'tdd'));
    tddDir.createSync();
    File(p.join(tddDir.path, 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U2 | reports the branch index for an index | $traces | PENDING |
''');
  }

  Future<String> runGen() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', 'gen', 'U2', '--project', tmp.path]);
  }

  String readSubject() => File(
    p.join(tmp.path, 'lib', 'tdd', feature, 'u2_subject.dart'),
  ).readAsStringSync();

  String readTest() => File(
    p.join(tmp.path, 'test', 'tdd', feature, 'u2_test.dart'),
  ).readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug_1750_gen_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('U-1750-G1: the ANNOTATED traces cell emits the CONTRACT-DERIVED '
      'stub — `int? subject_u2(int index)`, never the legacy `int '
      'subject_u2()`', () async {
    seedFeature(traces: annotatedTraces);

    final out = await runGen();

    final subject = readSubject();
    expect(
      subject,
      contains('int? subject_u2(int index) =>'),
      reason: 'the declared signature survives the annotation\n$out',
    );
    expect(
      subject,
      contains('CONTRACT-DERIVED SUBJECT (issue #1259)'),
      reason: subject,
    );
    expect(
      subject,
      contains('branchIndex(int index) -> int?'),
      reason: 'the contract header quotes the declaration verbatim',
    );
    // The reported degraded shape is gone: no parameterless non-nullable
    // legacy stub, and no `subject_u1` placeholder in a `u2` file.
    expect(subject, isNot(contains('int subject_u2() =>')), reason: subject);
    expect(subject, isNot(contains('subject_u1')), reason: subject);

    // The paired test imports the subject it exercises (the A/B shape —
    // the fixture's package name renders the lint-clean `package:` form)
    // and invokes it WITH the declared parameter.
    final test = readTest();
    expect(
      test,
      contains(
        "import 'package:fixture_app/tdd/$feature/u2_subject.dart' "
        'as subject;',
      ),
      reason: test,
    );
    expect(test, contains('subject.subject_u2(0)'), reason: test);
  });

  test('U-1750-G2: the bare cell on the same fixture emits the same '
      'declared shape (the clean-trace control)', () async {
    seedFeature(traces: 'FR-002, ShellNavItem.branchIndex');

    final out = await runGen();

    expect(
      readSubject(),
      contains('int? subject_u2(int index) =>'),
      reason: out,
    );
  });
}
