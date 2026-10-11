// Bug #1420 — the entity pipeline engages at gen for row-only entity traces.
//
// A unit behavior whose traces cell resolves a declared Key Entity row
// (row-only — entity rows declare no methods) used to land as the guard-only
// fallback pair with a prose-guessed subject, because gen's declared-routing
// seam consumed only the resolved signature (null for entity rows) and
// discarded the entityPipeline surface. The remediation synthesizes the
// declared entity-surface signature `<Entity>() -> <Entity>` and feeds the
// EXISTING SPEC 1489 contract-shape machinery:
//
//   - entity EXISTS on disk → `expect(result, isA<Entity>())` + verbatim
//     subject + entity import + `<Entity>() -> <Entity>` provenance header
//     (SC-1a — make's declared plan can then drive the entity pipeline);
//   - entity MISSING at gen → the traced `zfa:tdd: vacuous-guard` marker (the
//     #1308/#1320 designed hand-delta seam), `Object?` degradation, NO
//     guard-only warning token (SC-1b);
//   - UNDECLARED rows keep the legacy fallback byte-shape (SC-4).
//
// Test map (fast tier — the real GenCommand via CliRunner, no pub get, no
// build; the bug_1518 harness shape):
//   U-1420-G1 — entity exists: typed entity-surface assertion, no marker.
//   U-1420-G2 — entity missing: the traced marker, silent gen warning.
//   U-1420-G3 — undeclared: the legacy guard-only fallback, warning fires.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

void main() {
  late Directory tmp;
  const feature = '1420-entity-row';
  const entityName = 'SharedAttachmentType';
  const snakeEntity = 'shared_attachment_type';

  /// The TDD profile gen's entry preflight reads (the #1528 silent no-op
  /// seed — the bug_1518 harness idiom).
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

  /// A pubspec with a package name so the entity import renders in the
  /// lint-clean `package:` form (the real-project shape).
  void seedPubspec() {
    File(
      p.join(tmp.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: fixture_app\nenvironment:\n  sdk: ^3.11.0\n');
  }

  /// The issue's repro shape: a spec whose FR-001 traces a declared Key
  /// Entity row, and the matching test-list row (the plan-written traces
  /// cell `FR-001, SharedAttachmentType` — the row-only pass-through).
  void seedFeature({String traces = 'FR-001, $entityName'}) {
    seedProfile();
    seedPubspec();
    final featureDir = Directory(p.join(tmp.path, 'specs', feature));
    featureDir.createSync(recursive: true);
    File(p.join(featureDir.path, 'spec.md')).writeAsStringSync('''
# Spec: $feature

## Functional Requirements

- **FR-001**: `$entityName` MUST expose exactly the four share attachment
  kinds in declaration order

### Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| $entityName | `kind: String` | the four share attachment kinds |
''');
    final tddDir = Directory(p.join(featureDir.path, 'tdd'));
    tddDir.createSync();
    File(p.join(tddDir.path, 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | exposes exactly the four share attachment kinds in declaration order | $traces | PENDING |
''');
  }

  /// The canonical entity file `locateEntityFile` resolves (the phase-0
  /// `entity create` product).
  void seedEntity() {
    final entityFile = File(
      p.join(
        tmp.path,
        'lib',
        'src',
        'domain',
        'entities',
        snakeEntity,
        '$snakeEntity.dart',
      ),
    );
    entityFile.createSync(recursive: true);
    entityFile.writeAsStringSync('''
class $entityName {
  final String kind;
  const $entityName(this.kind);
}
''');
  }

  Future<String> runGen() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', 'gen', 'U1', '--project', tmp.path]);
  }

  String readTest() => File(
    p.join(tmp.path, 'test', 'tdd', feature, 'u1_test.dart'),
  ).readAsStringSync();

  String readSubject() => File(
    p.join(tmp.path, 'lib', 'tdd', feature, 'u1_subject.dart'),
  ).readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug_1420_gen_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('U-1420-G1: entity EXISTS — the paired test asserts the declared '
      'entity surface, the subject renders it verbatim, no marker', () async {
    seedFeature();
    seedEntity();

    final out = await runGen();

    final testContent = readTest();
    final subjectContent = readSubject();

    // SC-1a: the entity-surface assertion — NOT the guard-only fallback.
    expect(
      testContent,
      contains('expect(result, isA<$entityName>());'),
      reason: out,
    );
    expect(
      testContent,
      isNot(contains(vacuousGuardMarker)),
      reason: testContent,
    );
    // The entity import rides the paired test (SPEC 1489 return imports).
    expect(testContent, contains('$snakeEntity.dart'), reason: testContent);

    // The subject renders the declared type verbatim (the entity exists),
    // with the declared import and the provenance header wire's stub-header
    // fallback parses.
    expect(subjectContent, contains('$entityName subject_u1()'));
    expect(subjectContent, contains('$snakeEntity.dart'));
    expect(subjectContent, contains('$entityName() -> $entityName'));
    // The guard's nonsense prose-guessed subject is gone.
    expect(subjectContent, isNot(contains('int subject_u1()')));
  });

  test('U-1420-G2: entity MISSING — the traced vacuous-guard marker, the '
      'Object? degradation, the gen warning silent', () async {
    seedFeature();

    final out = await runGen();

    final testContent = readTest();
    final subjectContent = readSubject();

    // SC-1b: the traced hand-delta seam — the marker IS present.
    expect(testContent, contains(vacuousGuardMarker), reason: testContent);
    // The subject degrades (FR-011 compile safety) but the header preserves
    // the declared entity shape for wire's stub-header fallback.
    expect(subjectContent, contains('Object? subject_u1()'));
    expect(subjectContent, contains('$entityName() -> $entityName'));
    // The traced path stays silent — its warning is the marker itself
    // (issue #1308); the false "no traces" gen warning must not fire.
    expect(out, isNot(contains(vacuousGuardWarningToken)), reason: out);
    expect(out, isNot(contains('no `traces:` line')), reason: out);
  });

  test('U-1420-G3: UNDECLARED behavior — the legacy guard-only fallback is '
      'unchanged (no marker, warning fires)', () async {
    seedFeature(traces: 'FR-001');

    final out = await runGen();

    final testContent = readTest();
    expect(
      testContent,
      contains('expect(result, isNot(isA<UnimplementedError>()));'),
      reason: testContent,
    );
    expect(testContent, isNot(contains(vacuousGuardMarker)));
    // The undeclared class keeps its gen-time warning (the wording is TRUE
    // there: no traces line to a declared contract row exists).
    expect(out, contains(vacuousGuardWarningToken), reason: out);
  });
}
