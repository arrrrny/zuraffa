// Issue #1186: `zfa tdd plan` routes every behavior via the labeled
// legacy classifier fallback because speckit-authored specs never carry
// the `**Type**` scenario markers (or `## Layer Contracts` rows) the
// strict grammar wants. The fix turns the per-run fallback into a
// ONE-TIME migration: plan emits the classified markers back into the
// spec post-derivation, the speckit spec template emits the markers
// from birth, and `--strict-routing` becomes usable on speckit-authored
// specs (mirror of #1183/#990, the template-drift family).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// A spec shaped like the speckit template's output: a widget-observable
/// acceptance scenario with NO `**Type**` marker, and an FR traced to a
/// declared Layer Contracts row (so the FR lane is declared and the
/// scenario's fallback is the only migration target).
const _speckitShapedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1186-prov

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

## Functional Requirements

- **FR-001**: the label renders the template
            traces: Formatter.format

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the page shows the settings form.
''';

Future<Directory> _featureDir(String spec) async {
  final tmp = Directory.systemTemp.createTempSync('emit1186_');
  final featureDir = p.join(tmp.path, 'specs', '1186-prov');
  await Directory(featureDir).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  return tmp;
}

Future<String> _plan(Directory tmp, [List<String> extra = const []]) async {
  final runner = CliRunner(exitOnCompletion: false);
  final out = await runner.runCapturing([
    'tdd',
    'plan',
    '1186-prov',
    '--project',
    tmp.path,
    ...extra,
  ]);
  return out;
}

String _scenarioBlock(String spec, int scenarioIndex) {
  final headers = RegExp(
    r'^\s*\d+\.\s*\*\*Given\*\*',
    multiLine: true,
  ).allMatches(spec).toList();
  final start = headers[scenarioIndex - 1].start;
  final end = scenarioIndex < headers.length
      ? headers[scenarioIndex].start
      : spec.length;
  return spec.substring(start, end);
}

void main() {
  group(
    '#1186: plan emits markers back into the spec (one-time migration)',
    () {
      test('a fallback-routed scenario gets its classified `**Type**` marker '
          'persisted into spec.md after a successful plan', () async {
        final tmp = await _featureDir(_speckitShapedSpec);
        try {
          final out = await _plan(tmp);
          expect(exitCode, 0, reason: out);
          // Bug #1481: the routing verdict reflects the spec state as of
          // the END of the invocation — the marker this run wrote is
          // what routes the scenario, so ONE run is truthful (the
          // pre-#1481 behavior reported the stale pre-emission fallback).
          expect(out, contains('[declared: type marker'));
          expect(out, isNot(contains('[fallback:')));
          // ...and the classified marker is MIGRATED into the spec.
          final spec = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          expect(spec, contains('**Type**: widget'));
          // The marker is INSIDE the scenario block (after its header).
          final markerLine = spec
              .split('\n')
              .firstWhere((l) => l.contains('**Type**: widget'));
          final headerIndex = spec
              .split('\n')
              .indexWhere((l) => l.startsWith('1. **Given**'));
          final markerIndex = spec.split('\n').indexOf(markerLine);
          expect(
            markerIndex,
            greaterThan(headerIndex),
            reason: 'the marker must sit inside its scenario block',
          );
          expect(out, contains('issue #1186'));
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('the migration is one-time: the re-run routes the migrated '
          'scenario [declared:] with zero fallback lines', () async {
        final tmp = await _featureDir(_speckitShapedSpec);
        try {
          await _plan(tmp);
          final out = await _plan(tmp);
          expect(exitCode, 0, reason: out);
          expect(out, isNot(contains('[fallback:')));
          expect(out, contains('[declared: type marker'));
          // Exactly one marker per scenario — a duplicate would refuse
          // the plan (declaration-refused, exit 2).
          final spec = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          expect(
            '**Type**: widget'.allMatches(spec).length,
            1,
            reason: 'idempotent emission — never a duplicate marker',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('strict-routing becomes usable: plan (migration) then plan '
          '--strict-routing exits 0 on the same spec', () async {
        final tmp = await _featureDir(_speckitShapedSpec);
        try {
          await _plan(tmp);
          final out = await _plan(tmp, ['--strict-routing']);
          expect(exitCode, 0, reason: out);
          expect(out, isNot(contains('[fallback:')));
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('an acceptance-lane scenario emits `**Type**: acceptance` (the '
          'classified lane, not a guess)', () async {
        final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 1186-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
''');
        try {
          final out = await _plan(tmp);
          expect(exitCode, 0, reason: out);
          final spec = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          expect(spec, contains('**Type**: acceptance'));
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('scenarios already carrying a marker are never re-declared '
          '(idempotent, no duplicate-marker refusal)', () async {
        final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 1186-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
   **Type**: acceptance
2. **Given** the app **When** it starts **Then** the page shows the settings form.
''');
        try {
          final out = await _plan(tmp);
          expect(exitCode, 0, reason: out);
          final spec = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          final a1 = _scenarioBlock(spec, 1);
          final a2 = _scenarioBlock(spec, 2);
          expect(
            '**Type**:'.allMatches(a1).length,
            1,
            reason: 'A1 must retain only its declared marker',
          );
          expect(a1, contains('**Type**: acceptance'));
          expect(a1, isNot(contains('**Type**: widget')));
          expect(a2, contains('**Type**: widget'));
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('marker emission uses current scenario ids after test-list id '
          'reconciliation', () async {
        final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 1186-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
   **Type**: acceptance
2. **Given** the app **When** another total is requested **Then** the other total equals the sum of items.
''');
        try {
          final tddDir = Directory(
            p.join(tmp.path, 'specs', '1186-prov', 'tdd'),
          );
          await tddDir.create();
          await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A9 | old first scenario | AC-1 | PENDING |
| A8 | old second scenario | AC-2 | PENDING |
''');

          final out = await _plan(tmp);
          expect(exitCode, 0, reason: out);
          final spec = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          final a1 = _scenarioBlock(spec, 1);
          final a2 = _scenarioBlock(spec, 2);
          expect('**Type**:'.allMatches(a1), hasLength(1));
          expect(a2, contains('**Type**: acceptance'));
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test(
        'a refused plan (skin-contract gate) never touches the spec either',
        () async {
          final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 1186-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the page shows the settings form.

## Skin Contract

```yaml
Skin Contract:
  adaptive_slots: [mobile]
  states: [data]
  routes: [home]
```
''');
          try {
            final before = await File(
              p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
            ).readAsString();
            final out = await _plan(tmp);
            expect(exitCode, 2, reason: out);
            expect(out, contains('skin contract refused'));
            final after = await File(
              p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
            ).readAsString();
            expect(
              after,
              before,
              reason:
                  'every refusal path (strict, skin, lanes) must run '
                  'BEFORE the marker emission touches the spec',
            );
          } finally {
            tmp.deleteSync(recursive: true);
          }
        },
      );

      test('a refused plan (strict gate) never touches the spec', () async {
        final tmp = await _featureDir(_speckitShapedSpec);
        try {
          final before = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          final out = await _plan(tmp, ['--strict-routing']);
          expect(exitCode, 1, reason: out);
          expect(out, contains('--> fix:'));
          final after = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          expect(
            after,
            before,
            reason:
                'round-2 fix 3a: a refusal mutates nothing — the '
                'migration only ever rides a SUCCESSFUL plan',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('a plan output failure does not migrate the spec', () async {
        final tmp = await _featureDir(_speckitShapedSpec);
        try {
          final specFile = File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          );
          final before = await specFile.readAsString();
          await File(
            p.join(tmp.path, 'specs', '1186-prov', 'tdd'),
          ).writeAsString('blocks output directory creation');

          final out = await _plan(tmp);
          expect(exitCode, 1, reason: out);
          expect(out, contains('FileSystemException'));
          expect(await specFile.readAsString(), before);
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test(
        'a fenced scenario example is documentation — never marked',
        () async {
          final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 1186-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the page shows the settings form.

How to write a scenario:

```markdown
1. **Given** a documented example **When** it runs **Then** it shows the result.
```
''');
          try {
            final out = await _plan(tmp);
            expect(exitCode, 0, reason: out);
            final spec = await File(
              p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
            ).readAsString();
            // The real scenario (A1) is migrated; the fenced example is not.
            final markerCount = '**Type**:'.allMatches(spec).length;
            expect(markerCount, 1, reason: spec);
            expect(
              spec.indexOf('**Type**:'),
              lessThan(spec.indexOf('```markdown')),
              reason: 'the only marker sits in the real scenario block',
            );
            // Idempotent: the fenced block stays marker-free on re-runs.
            await _plan(tmp);
            final spec2 = await File(
              p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
            ).readAsString();
            expect('**Type**:'.allMatches(spec2).length, 1, reason: spec2);
          } finally {
            tmp.deleteSync(recursive: true);
          }
        },
      );

      test('--no-emit-markers leaves the spec untouched', () async {
        final tmp = await _featureDir(_speckitShapedSpec);
        try {
          final before = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          final out = await _plan(tmp, ['--no-emit-markers']);
          expect(exitCode, 0, reason: out);
          expect(out, contains('[fallback:'));
          final after = await File(
            p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
          ).readAsString();
          expect(after, before, reason: 'opt-out preserves the spec verbatim');
          expect(after, isNot(contains('**Type**:')));
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test(
        'a manual scenario consumes its AC number and is never marked',
        () async {
          final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 1186-prov

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the page shows the settings form. (manual: QA)
2. **Given** the app **When** the total is requested **Then** the total equals the sum of items.
''');
          try {
            final out = await _plan(tmp);
            expect(exitCode, 0, reason: out);
            final spec = await File(
              p.join(tmp.path, 'specs', '1186-prov', 'spec.md'),
            ).readAsString();
            final a1 = _scenarioBlock(spec, 1);
            final a2 = _scenarioBlock(spec, 2);
            expect(
              a1,
              isNot(contains('**Type**:')),
              reason: 'A1 is manual and must remain marker-free',
            );
            expect(a2, contains('**Type**: acceptance'));
          } finally {
            tmp.deleteSync(recursive: true);
          }
        },
      );
    },
  );

  group('#1186: the speckit spec template emits the strict grammar', () {
    final repoTemplate = File(
      '.specify/templates/spec-template.md',
    ).readAsStringSync();

    test('scenario examples carry the `**Type**` marker', () {
      expect(repoTemplate, contains('**Type**:'));
    });

    test('the template declares a `## Layer Contracts` section', () {
      expect(
        repoTemplate,
        contains(RegExp(r'^## Layer Contracts', multiLine: true)),
      );
    });

    test('the Key Entities heading parses (bare heading, no suffix)', () {
      // The suffixed form `### Key Entities *(include if...)*` never
      // matched the parser's `key entities$` heading — the same
      // template-drift family as the version marker (#1183).
      expect(
        repoTemplate,
        contains(RegExp(r'^#{1,6} Key Entities\s*$', multiLine: true)),
      );
      expect(
        repoTemplate,
        isNot(contains('*(include if feature involves data)*')),
      );
    });

    test('FR examples show the `traces:` continuation grammar', () {
      expect(repoTemplate, contains('traces:'));
    });
  });
}
