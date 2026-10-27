// Issue #2030 — `zfa tdd plan` injected the one-time `**Type**` marker
// mid-sentence in speckit-format acceptance scenarios. The #1186 emitter
// anchored on the scenario HEADER line and wrote the marker at
// headerIndex+1, assuming the zuraffa template's one-line scenario rows;
// speckit-format items wrap over several lines, so the marker landed
// between the header's first clause and its continuation, splitting the
// prose mid-sentence. The fix anchors on the END of the scenario item:
// the marker goes on its own line AFTER the complete item, still inside
// the scenario block the parser reads (`parseScenarioTypeMarkers` keeps
// the block open until the next numbered header or heading).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// A speckit-shaped spec whose first acceptance scenario wraps across
/// three lines — the shape issue #2030 reported — and whose second
/// scenario is a zuraffa-template one-liner (the shape #1186 pinned).
const _multiLineSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 2030-ml

## Layer Contracts

**Function**:
- `Total`: `compute() -> int`

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
            traces: Total

## Acceptance Scenarios

1. **Given** the app whose display declares the
   total-form cleaner, **When** the total is requested
   mid-run, **Then** the total equals the sum of items.
2. **Given** the app **When** it starts **Then** the page shows the form.
''';

Future<Directory> _featureDir(String spec) async {
  final tmp = Directory.systemTemp.createTempSync('emit2030_');
  final featureDir = p.join(tmp.path, 'specs', '2030-ml');
  await Directory(featureDir).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  return tmp;
}

Future<String> _plan(Directory tmp, [List<String> extra = const []]) async {
  final runner = CliRunner(exitOnCompletion: false);
  return runner.runCapturing([
    'tdd',
    'plan',
    '2030-ml',
    '--project',
    tmp.path,
    ...extra,
  ]);
}

Future<String> _readSpec(Directory tmp) =>
    File(p.join(tmp.path, 'specs', '2030-ml', 'spec.md')).readAsString();

/// The scenario block between numbered header [scenarioIndex] (1-based)
/// and the next one (or EOF) — the same slice convention the #1186 pins
/// use.
List<String> _scenarioBlockLines(String spec, int scenarioIndex) {
  final headers = RegExp(
    r'^\s*\d+\.\s*\*\*Given\*\*',
    multiLine: true,
  ).allMatches(spec).toList();
  final start = spec.lastIndexOf('\n', headers[scenarioIndex - 1].start) + 1;
  final end = scenarioIndex < headers.length
      ? headers[scenarioIndex].start
      : spec.length;
  return spec.substring(start, end).split('\n');
}

void main() {
  group(
    '#2030: the emitted `**Type**` marker follows the COMPLETE scenario item',
    () {
      test('a multi-line speckit scenario keeps its prose intact: the '
          'marker lands after the item, never mid-sentence', () async {
        final tmp = await _featureDir(_multiLineSpec);
        try {
          final out = await _plan(tmp);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          // The migrated content must re-parse as declared — a marker
          // outside its scenario block would have refused the plan.
          expect(out, contains('[declared: type marker'));
          final spec = await _readSpec(tmp);
          final block = _scenarioBlockLines(spec, 1);
          const header = '1. **Given** the app whose display declares the';
          const cont1 =
              '   total-form cleaner, **When** the total is requested';
          const cont2 =
              '   mid-run, **Then** the total equals the sum of items.';
          // The exact reported symptom: the marker sat at block index 1,
          // splitting the item between "declares the" and its object.
          expect(
            block[0],
            header,
            reason: 'the header line is preserved verbatim',
          );
          expect(
            block[1],
            cont1,
            reason:
                'the continuation follows the header directly — the '
                '#2030 symptom was a `**Type**` marker wedged between them',
          );
          expect(
            block[2],
            cont2,
            reason: 'the item prose stays contiguous, unsplit',
          );
          // The marker is the NEXT line after the complete item.
          expect(
            block[3],
            matches(RegExp(r'^\s*\*\*Type\*\*: (acceptance|widget)$')),
            reason: 'the marker follows the item on its own line',
          );
          expect(
            block.where((l) => l.contains('**Type**:')),
            hasLength(1),
            reason: 'exactly one marker for the scenario',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('a zuraffa-template one-liner keeps the #1186 placement: the '
          'marker directly follows the single-line row', () async {
        final tmp = await _featureDir(_multiLineSpec);
        try {
          final out = await _plan(tmp);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          final spec = await _readSpec(tmp);
          final block = _scenarioBlockLines(spec, 2);
          expect(block[0], contains('**Given**'));
          expect(
            block[1],
            matches(RegExp(r'^\s*\*\*Type\*\*: (acceptance|widget)$')),
            reason:
                'a one-line scenario item ends at its own header — '
                'marker placement is unchanged for the template shape',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('the last multi-line scenario before a heading gets its marker '
          'after the item, before the heading', () async {
        final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 2030-ml

## Layer Contracts

**Function**:
- `Total`: `compute() -> int`

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
            traces: Total

## Acceptance Scenarios

1. **Given** the app whose display declares the
   total-form cleaner, **When** the total is requested
   mid-run, **Then** the total equals the sum of items.

## Edge Cases
''');
        try {
          final out = await _plan(tmp);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          final spec = await _readSpec(tmp);
          final lines = spec.split('\n');
          final itemEnd = lines.indexWhere(
            (l) => l.contains('the total equals the sum of items.'),
          );
          final markerIndex = lines.indexWhere(
            (l) => RegExp(r'^\s*\*\*Type\*\*:').hasMatch(l),
          );
          final headingIndex = lines.indexWhere(
            (l) => l.startsWith('## Edge Cases'),
          );
          expect(itemEnd, greaterThan(-1));
          expect(
            markerIndex,
            itemEnd + 1,
            reason: 'the marker follows the complete item',
          );
          expect(
            headingIndex,
            greaterThan(markerIndex),
            reason: 'the heading stays after the emitted marker',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('a fenced example inside the item is documentation: the fence '
          'is skipped, preserved verbatim, and the marker lands after the '
          'post-fence continuation', () async {
        final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 2030-ml

## Layer Contracts

**Function**:
- `Total`: `compute() -> int`

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
            traces: Total

## Acceptance Scenarios

1. **Given** the app whose display declares the
   total-form cleaner, **When** the total is requested
   mid-run, **Then** the total is computed:

   ```
   total = cart.total()
   ```

   and the total is logged.
2. **Given** the app **When** it starts **Then** the page shows the form.
''');
        try {
          final out = await _plan(tmp);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          final spec = await _readSpec(tmp);
          final block = _scenarioBlockLines(spec, 1);
          // The fence is documentation: skipped by the item walk, so it
          // neither anchors nor breaks the item — the marker follows the
          // item's post-fence continuation, never the fence itself.
          expect(
            block.where((l) => l.trim() == '```'),
            hasLength(2),
            reason: 'the fenced example is preserved verbatim',
          );
          final postFence = block.indexWhere(
            (l) => l.contains('and the total is logged.'),
          );
          final markerIndex = block.indexWhere(
            (l) => RegExp(r'^\s*\*\*Type\*\*:').hasMatch(l),
          );
          expect(postFence, greaterThan(-1));
          expect(
            markerIndex,
            postFence + 1,
            reason:
                'the marker follows the COMPLETE item — the fenced span '
                'and the blank lines around it are skipped, not anchors',
          );
          expect(block.where((l) => l.contains('**Type**:')), hasLength(1));
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test(
        'trailing NON-indented prose between the item and the next '
        'heading belongs to the document: the marker lands before it',
        () async {
          final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 2030-ml

## Layer Contracts

**Function**:
- `Total`: `compute() -> int`

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
            traces: Total

## Acceptance Scenarios

1. **Given** the app whose display declares the
   total-form cleaner, **When** the total is requested
   mid-run, **Then** the total equals the sum of items.

How to write a scenario: keep one behavior per row.

## Edge Cases
''');
          try {
            final out = await _plan(tmp);
            expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
            final spec = await _readSpec(tmp);
            final lines = spec.split('\n');
            final itemEnd = lines.indexWhere(
              (l) => l.contains('the total equals the sum of items.'),
            );
            final markerIndex = lines.indexWhere(
              (l) => RegExp(r'^\s*\*\*Type\*\*:').hasMatch(l),
            );
            final proseIndex = lines.indexWhere(
              (l) => l.startsWith('How to write a scenario:'),
            );
            expect(itemEnd, greaterThan(-1));
            expect(
              markerIndex,
              itemEnd + 1,
              reason: 'the marker follows the item on its own line',
            );
            expect(
              proseIndex,
              greaterThan(markerIndex),
              reason:
                  'the non-indented section prose breaks the item — the '
                  'marker must not absorb it into the scenario',
            );
          } finally {
            tmp.deleteSync(recursive: true);
          }
        },
      );

      test('an issue-reference continuation (`#2030`) is prose, not a '
          'heading: it stays inside the item and the marker after it '
          'still parses', () async {
        final tmp = await _featureDir('''
**Template Version**: `zuraffa-1.0`

# Spec: 2030-ml

## Layer Contracts

**Function**:
- `Total`: `compute() -> int`

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
            traces: Total

## Acceptance Scenarios

1. **Given** the issue tracker cross-links this spec,
   #2030 and #1481 name the tracked regressions,
   **When** the total is requested, **Then** it is the sum of items.
2. **Given** the app **When** it starts **Then** the page shows the form.
''');
        try {
          final out = await _plan(tmp);
          // Both sides of the heading definition must agree: the emitter
          // keeps the marker inside the item (no `#2030` break) and the
          // parser keeps the block open through it — a disagreement
          // would refuse the plan with a misplaced-marker error.
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          expect(out, contains('[declared: type marker'));
          final spec = await _readSpec(tmp);
          final block = _scenarioBlockLines(spec, 1);
          final issueRef = block.indexWhere(
            (l) => l.contains('#2030 and #1481'),
          );
          final itemEnd = block.indexWhere(
            (l) => l.contains('it is the sum of items.'),
          );
          final markerIndex = block.indexWhere(
            (l) => RegExp(r'^\s*\*\*Type\*\*:').hasMatch(l),
          );
          expect(issueRef, greaterThan(0));
          expect(
            itemEnd,
            greaterThan(issueRef),
            reason: 'the issue-reference continuation stays inside the item',
          );
          expect(
            markerIndex,
            itemEnd + 1,
            reason:
                'the marker follows the COMPLETE item — it was never '
                'split before the `#2030` line',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('the migration stays idempotent on a multi-line item: one '
          're-run, one marker, no fallback', () async {
        final tmp = await _featureDir(_multiLineSpec);
        try {
          await _plan(tmp);
          final out = await _plan(tmp);
          expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
          expect(out, isNot(contains('[fallback:')));
          expect(out, contains('[declared: type marker'));
          final spec = await _readSpec(tmp);
          final block = _scenarioBlockLines(spec, 1);
          expect(
            block.where((l) => l.contains('**Type**:')),
            hasLength(1),
            reason: 'never a duplicate marker for the migrated item',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });
    },
  );
}
