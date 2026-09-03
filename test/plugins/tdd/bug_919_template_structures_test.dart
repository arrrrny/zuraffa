// Bug #919 ([TDD-120], tdd-120-template-structures) — `zfa tdd plan` must
// consume the zuraffa-1.0 template's declared structures.
//
// This file drives the plan command through the real CLI entry point on a
// temp project (same harness as bug_846_coverage_gate_test.dart). Behaviors
// A1-A14 in .specify/bugs/tdd-120-template-structures/tdd/test-list.md.
//
// Scope: plan-side complete. Make-side consumption of the declared
// structures is #909 (mock-first make path) and is out of scope here.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

import 'helpers/spec_fixture.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '001-demo';

  List<String> planArgs() => [
    'tdd',
    'plan',
    featureName,
    '--project',
    tmpDir.path,
  ];

  Future<String> runPlan() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(planArgs());
  }

  Future<String> readTestList() => File(
    p.join(featureDir, 'tdd', 'test-list.md'),
  ).readAsString();

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('bug919_plan_');
    featureDir = makeFeatureDir(tmpDir.path, featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  test(
    'A1: table-declared Key Entities land in the plan artifact with fields '
    'and purpose',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| ShoeSizePreference | `id: String`, `sizeEu: double` | One saved shoe size for one brand |
''',
      );

      final out = await runPlan();

      expect(exitCode, 0, reason: out);
      final list = await readTestList();
      expect(
        list,
        contains(
          '| ShoeSizePreference | id: String, sizeEu: double'
          ' | One saved shoe size for one brand |',
        ),
        reason: list,
      );
    },
  );

  test(
    'A2: legacy bullet-format Key Entities section still extracts (the '
    'Template Version marker keeps legacy specs planning)',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## Key Entities

- **ShoeSizePreference**: `id: String`, `sizeEu: double` — one saved shoe size
''',
      );

      final out = await runPlan();

      expect(exitCode, 0, reason: out);
      final list = await readTestList();
      expect(
        list,
        contains('| ShoeSizePreference | id: String, sizeEu: double |'),
        reason: list,
      );
    },
  );

  test(
    'A3: entities planned from a table are read back by '
    'TestListReader.readEntities (phase-0 seam)',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| ShoeSizePreference | `id: String`, `sizeEu: double` | One saved shoe size for one brand |
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);

      final entities =
          await TestListReader('$tmpDir/specs/$featureName').readEntities();
      expect(entities, hasLength(1));
      expect(entities.first.name, 'ShoeSizePreference');
      expect(entities.first.fields, containsAll(<String>[
        'id:String',
        'sizeEu:double',
      ]));
    },
  );

  test(
    'A4: missing Template Version marker -> exit 3 + fix line + no artifacts',
    () async {
      await writeRawSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance
''',
      );

      final out = await runPlan();
      expect(exitCode, 3, reason: out);
      expect(out, contains('--> fix:'));
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isFalse,
        reason: 'no test list may be written when the version gate fires',
      );
    },
  );

  test(
    'A5: unknown Template Version (zuraffa-2.0) -> exit 3 naming the version '
    '+ fix line + no artifacts',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance
''',
        versionMarker: '**Template Version**: `zuraffa-2.0`',
      );

      final out = await runPlan();
      expect(exitCode, 3, reason: out);
      expect(out, contains('zuraffa-2.0'));
      expect(out, contains('--> fix:'));
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'A6: Template Version zuraffa-1.0 -> plan succeeds (exit 0, artifact '
    'written)',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'A7: External Dependencies & Contracts table lands row-for-row in the '
    'plan artifact (dependency, type, contract, mock priority)',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> ShoeSizePreference?` | P1 |
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);
      final list = await readTestList();
      expect(list, contains('## External dependencies'));
      expect(
        list,
        contains('| Hive | storage | `read(key) -> ShoeSizePreference?` | P1 |'),
      );
    },
  );

  test(
    'A8: Layer Contracts land per-layer, per-interface with method signatures',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## Layer Contracts

**Domain**:

- `ShoeSizePreferenceRepository`: `save(ShoeSizePreference) -> Future<Result<void, AppFailure>>`, `getByBrand(String brand) -> Future<Result<ShoeSizePreference?, AppFailure>>`
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);
      final list = await readTestList();
      expect(list, contains('## Layer contracts'));
      expect(list, contains('### Domain'));
      expect(list, contains('`ShoeSizePreferenceRepository`'));
      expect(
        list,
        contains(
          'save(ShoeSizePreference) -> Future<Result<void, AppFailure>>',
        ),
      );
    },
  );

  test(
    'A9: a requirement referencing an undeclared external (Hive) -> exit 2 '
    'naming the dependency + fix line + no artifacts',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## Functional Requirements

- **FR-001**: The system MUST persist preferences via Hive

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| SharedPreferences | storage | `getString(k) -> String?` | P1 |
''',
      );

      final out = await runPlan();
      expect(exitCode, 2, reason: out);
      expect(out, contains('Hive'));
      expect(out, contains('--> fix:'));
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'A10: a spec with no Key Entities section plans cleanly (no entity '
    'section rendered, exit 0)',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);
      final list = await readTestList();
      expect(list, isNot(contains('## Key entities')));
    },
  );

  test(
    'A11: a Key Entities section mixing a table and legacy bullets extracts '
    'both forms',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| ShoeSizePreference | `id: String`, `sizeEu: double` | One saved shoe size for one brand |

- **Brand**: `id: String`, `name: String` — the brand the size belongs to
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);
      final list = await readTestList();
      expect(
        list,
        contains('| ShoeSizePreference | id: String, sizeEu: double |'),
      );
      expect(list, contains('| Brand | id: String, name: String |'));
    },
  );

  test(
    'A12: requirements reference no externals (or only declared ones) -> plan '
    'exits 0 without the dependency lint firing',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## Functional Requirements

- **FR-001**: The system MUST return the saved size for a brand
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);
    },
  );

  test(
    'A13: a spec with BOTH a missing Template Version AND a coverage gap '
    'exits 3 (version gate runs before the coverage gate)',
    () async {
      await writeRawSpec(
        featureDir,
        '''
# Spec: 001-demo

## Functional Requirements

- **FR-001**: A requirement that produces no behavior row
''',
      );

      final out = await runPlan();
      expect(exitCode, 3, reason: out);
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'A14: dependencies and layer contracts land in the plan artifact in a '
    'shape TestListReader can parse (readDependencies + readLayerContracts '
    'read them back)',
    () async {
      await writeSpec(
        featureDir,
        '''
# Spec: 001-demo

$kMinimalAcceptance

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> ShoeSizePreference?` | P1 |

## Layer Contracts

**Domain**:

- `ShoeSizePreferenceRepository`: `save(ShoeSizePreference) -> Future<Result<void, AppFailure>>`
''',
      );

      final out = await runPlan();
      expect(exitCode, 0, reason: out);

      // The reader side of A14 is asserted in bug_919_reader_test.dart
      // (split out so the CLI-driven plan test loads independently of the
      // reader method surface). Here we just prove the artifact is the
      // single shape both share — the contract section is present.
      final list = await readTestList();
      expect(list, contains('## External dependencies'));
      expect(list, contains('| Hive | storage |'));
      expect(list, contains('## Layer contracts'));
      expect(list, contains('`ShoeSizePreferenceRepository`'));
    },
  );
}
