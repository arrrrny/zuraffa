// Issue #990 — `zfa tdd plan` refuses to generate a test list when the
// spec is missing the `**Template Version**` marker (the #919 contract
// drift gate) and no command injects the marker into a non-conformant
// spec: the documented fix is to re-author the spec from the zuraffa
// template by hand.
//
// This file pins the migration path: `zfa tdd plan --migrate-spec`
// injects the latest known template version into the spec frontmatter
// (missing marker) or refreshes a stale/unknown marker in place —
// without touching any other spec semantics — and then proceeds with
// the normal plan flow. The gate itself is UNCHANGED: without the flag
// a missing/unknown marker still exits 3 with no artifacts.
//
// Harness: the bug_919 spec_fixture harness (real CLI entry point on a
// temp project).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

import 'helpers/spec_fixture.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '001-demo';

  List<String> planArgs({bool migrate = false}) => [
    'tdd',
    'plan',
    featureName,
    if (migrate) '--migrate-spec',
    '--project',
    tmpDir.path,
  ];

  Future<String> runPlan({bool migrate = false}) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(planArgs(migrate: migrate));
  }

  Future<String> readSpec() =>
      File(p.join(featureDir, 'spec.md')).readAsString();

  Future<String?> readTestList() async {
    final f = File(p.join(featureDir, 'tdd', 'test-list.md'));
    return f.existsSync() ? f.readAsString() : null;
  }

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('issue990_migrate_');
    featureDir = makeFeatureDir(tmpDir.path, featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  group('contract preserved (the gate itself does not change)', () {
    test('M0: without --migrate-spec a missing marker still exits 3 and '
        'the spec is left untouched', () async {
      await writeRawSpec(featureDir, '''
# Spec: 001-demo

$kMinimalAcceptance
''');

      final out = await runPlan();
      expect(exitCode, 3, reason: out);
      expect(out, contains('missing `**Template Version**` marker'));
      expect(await readTestList(), isNull);
      expect(
        await readSpec(),
        isNot(contains('Template Version')),
        reason: 'the drift gate must never mutate the spec on its own',
      );
    });

    test(
      'M1: without --migrate-spec an unknown marker still exits 3',
      () async {
        await writeSpec(featureDir, '''
# Spec: 001-demo

$kMinimalAcceptance
''', versionMarker: '**Template Version**: `zuraffa-2.0`');

        final out = await runPlan();
        expect(exitCode, 3, reason: out);
        expect(out, contains('zuraffa-2.0'));
        expect(await readTestList(), isNull);
      },
    );

    test('M2: the drift fix line names the migration escape hatch', () async {
      await writeRawSpec(featureDir, '''
# Spec: 001-demo

$kMinimalAcceptance
''');

      final out = await runPlan();
      expect(exitCode, 3, reason: out);
      expect(out, contains('--migrate-spec'));
    });
  });

  group('--migrate-spec injects the marker', () {
    test('M3: a spec missing the marker is migrated to the latest known '
        'version and the test list is generated in the same run', () async {
      const rawSpec =
          '''
# Spec: 001-demo

$kMinimalAcceptance
''';
      await writeRawSpec(featureDir, rawSpec);

      final out = await runPlan(migrate: true);

      expect(exitCode, 0, reason: out);
      expect(out, contains('migrated'), reason: out);
      final spec = await readSpec();
      // The marker lands at the top of the file (frontmatter position),
      // pinning the latest known template version.
      const injected = '**Template Version**: `zuraffa-1.0`\n\n';
      expect(
        spec.split('\n').first,
        '**Template Version**: `${SpecParser.latestTemplateVersion}`',
        reason: spec,
      );
      // The rest of the spec is unchanged — byte-for-byte.
      expect(
        spec.substring(injected.length),
        rawSpec,
        reason: 'migration must not alter spec semantics',
      );
      // Planning proceeded in the same run.
      final list = await readTestList();
      expect(list, isNotNull, reason: out);
      expect(list!, contains('| A1 |'));
    });

    test('M4: a stale/unknown marker is refreshed to the latest known '
        'version in place', () async {
      await writeSpec(featureDir, '''
# Spec: 001-demo

$kMinimalAcceptance
''', versionMarker: '**Template Version**: `zuraffa-2.0`');

      final out = await runPlan(migrate: true);

      expect(exitCode, 0, reason: out);
      final spec = await readSpec();
      expect(
        spec,
        contains('**Template Version**: `${SpecParser.latestTemplateVersion}`'),
        reason: spec,
      );
      expect(spec, isNot(contains('zuraffa-2.0')), reason: spec);
      expect(await readTestList(), isNotNull, reason: out);
    });

    test('M5: migration is idempotent — an already-pinned spec is '
        'byte-identical after the run', () async {
      await writeSpec(featureDir, '''
# Spec: 001-demo

$kMinimalAcceptance
''');
      final before = await readSpec();

      final out = await runPlan(migrate: true);

      expect(exitCode, 0, reason: out);
      expect(await readSpec(), before, reason: 'no rewrite, no churn');
      expect(
        out,
        isNot(contains('migrated spec')),
        reason: 'an already-pinned spec must not report a migration',
      );
      expect(await readTestList(), isNotNull, reason: out);
    });

    test('M6: a marker mentioned only inside a fenced code block is '
        'documentation, not the pin — migration inserts the real marker '
        'and preserves the fence verbatim', () async {
      const rawSpec =
          '''
# Spec: 001-demo

## How to write a spec

```
**Template Version**: `zuraffa-2.0`
```

$kMinimalAcceptance
''';
      await writeRawSpec(featureDir, rawSpec);

      final out = await runPlan(migrate: true);

      expect(exitCode, 0, reason: out);
      final spec = await readSpec();
      expect(
        spec.split('\n').first,
        '**Template Version**: `${SpecParser.latestTemplateVersion}`',
        reason: spec,
      );
      // The fenced example survives untouched (both the example text
      // and the stale version it documents).
      expect(spec, contains('```'));
      expect(spec, contains('**Template Version**: `zuraffa-2.0`'));
      final list = await readTestList();
      expect(list, isNotNull, reason: out);
    });

    test('M7: migration keeps every other line byte-identical (body '
        'diff == the inserted marker lines only)', () async {
      const rawSpec =
          '''
# Spec: 001-demo

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| ShoeSizePreference | `id: String`, `sizeEu: double` | One saved shoe size |

$kMinimalAcceptance
''';
      await writeRawSpec(featureDir, rawSpec);

      final out = await runPlan(migrate: true);

      expect(exitCode, 0, reason: out);
      final after = await readSpec();
      expect(
        after.trim(),
        startsWith('**Template Version**: `zuraffa-1.0`\n\n# Spec: 001-demo'),
        reason: after,
      );
      // Body (everything after the injected marker + blank line) is the
      // original spec verbatim.
      expect(
        after.trim().substring(
          '**Template Version**: `zuraffa-1.0`\n\n'.length,
        ),
        rawSpec.trim(),
        reason: 'only the marker may be inserted',
      );
    });
  });
}
