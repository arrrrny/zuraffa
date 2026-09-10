// Issue #1320 — the declared-assertion path is unreachable END-TO-END:
// plan never surfaces the bound contract row's METHOD in the unit traces
// cell (`traces: RouteContentType` keeps the cell row-only, so the
// multi-method mis-route class survives), the hand-delta that unlocks
// the declared path is destroyed by re-plan, gen refuses to re-generate
// the stale guard-only pair (verdict=reused), and the vacuous-green stop
// message never names the hand-delta seam.
//
// Behavior map:
//   U1 — plan (legacy writer) method-qualifies a single-method row-only
//        trace: `FR-001, RouteContentType.contentType`.
//   U2 — the lane writer (04-ENGINE.md) carries the same cell.
//   U3 — a multi-method row resolves by FR-prose verb match.
//   U4 — a multi-method row whose prose matches nothing REFUSES the plan
//        (exit 2, exact `--> fix:`, no artifacts).
//   U5 — the method-qualified cell round-trips a re-plan (the #1320
//        hand-delta is no longer destroyed).
//   U6 — gen REGENERATES the stale guard-only pair once the traces cell
//        gained a contract token (verdict=regenerated, not reused).
//   U7 — the regenerated pair runs trace→gen→verify-red→make green (the
//        capstone demo: no vacuous-green dead-end).
//   U8 — the shared vacuous-green remedy names the hand-delta seam.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

import '../helpers/tdd_fixture.dart';

/// The issue's repro spec: FR-001 traces to the declared DOMAIN row
/// `RouteContentType` (row-only, single method) whose declared signature
/// is `contentType() -> String`.
const singleMethodSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1320-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: RouteContentType

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// The same spec with `## Lanes` (all CORE) so plan splits into the lane
/// files — the issue's environment shape.
const lanedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1320-repro

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
```

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: RouteContentType

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// A multi-method row whose FR prose names exactly one method
/// (`contentType`) — the verb-match resolution path.
const multiMethodVerbMatchSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1320-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `parseHeader(String raw) -> bool`, `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose contentType for every response
            traces: RouteContentType

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// A multi-method row whose FR prose matches NO method — the refusal
/// path (the exact `--> fix:`).
const multiMethodAmbiguousSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1320-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `parseHeader(String raw) -> bool`, `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type
            traces: RouteContentType

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// A spec with NO traces continuation — the fallback shape whose gen
/// pair is the stale guard-only candidate for U6/U7.
const untracedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1320-repro

### Layer Contracts

**Domain**:
- `RouteContentType`: `contentType() -> String`

## Functional Requirements

- **FR-001**: System MUST expose the response content type

## Acceptance Scenarios

1. **Given** a response **When** the header is read **Then** the content type is exposed.
''';

/// Anchor a registry-recorded artifact path against the fixture root:
/// post-#1397 records carry the canonical project-relative POSIX form,
/// which must never be read relative to the process CWD.
String fixturePath(TddFixture fx, String recordedPath) =>
    p.isAbsolute(recordedPath)
    ? recordedPath
    : p.join(fx.root.path, recordedPath);

/// Plan [specMd] into a temp project and return stdout plus the raw
/// test-list content (and the 04-ENGINE content when the lane split
/// produced one).
Future<({String out, String testList, String engine, String? err})> planSpec(
  String specMd,
) async {
  final tmp = Directory.systemTemp.createTempSync('issue_1320_');
  try {
    final featureDir = p.join(tmp.path, 'specs', '1320-repro');
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(specMd);
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'plan',
      '1320-repro',
      '--project',
      tmp.path,
    ]);
    final testListFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
    final testList = testListFile.existsSync()
        ? await testListFile.readAsString()
        : '';
    final engineFile = File(p.join(featureDir, 'tdd', '04-ENGINE.md'));
    final engine = engineFile.existsSync()
        ? await engineFile.readAsString()
        : '';
    return (out: out, testList: testList, engine: engine, err: null);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// The unit row line for [id] out of a rendered test list / lane plan.
String? unitRowOf(String rendered, String id) => rendered
    .split('\n')
    .where((line) => line.startsWith('| $id |'))
    .firstOrNull;

void main() {
  group(
    'issue #1320 — plan writes the method-qualified cell (both writers)',
    () {
      tearDown(() {
        exitCode = 0;
      });

      test('U1: a single-method row-only trace method-qualifies the unit '
          'cell (legacy writer)', () async {
        final (:out, testList: list, engine: _, err: _) = await planSpec(
          singleMethodSpec,
        );
        expect(exitCode, 0, reason: 'plan must succeed: $out');
        final row = unitRowOf(list, 'U1');
        expect(row, isNotNull, reason: 'the plan must derive U1:\n$list');
        expect(
          row,
          contains('FR-001, RouteContentType.contentType'),
          reason:
              'the traces cell must carry the method-qualified contract row '
              '(issue #1320 remediation 1) — the single-method row resolves '
              'directly:\n$list',
        );
      });

      test('U2: the lane plan (04-ENGINE.md) carries the same '
          'method-qualified cell', () async {
        final (:out, testList: _, engine: engine, err: _) = await planSpec(
          lanedSpec,
        );
        expect(exitCode, 0, reason: 'the laned plan must succeed: $out');
        final row = unitRowOf(engine, 'U1');
        expect(
          row,
          isNotNull,
          reason: 'the engine lane must carry U1:\n$engine',
        );
        expect(
          row,
          contains('FR-001, RouteContentType.contentType'),
          reason:
              'both writers must surface the bound contract row\'s method '
              '(issue #1320 remediation 1):\n$engine',
        );
      });

      test('U3: a multi-method row resolves by FR-prose verb match', () async {
        final (:out, testList: list, engine: _, err: _) = await planSpec(
          multiMethodVerbMatchSpec,
        );
        expect(exitCode, 0, reason: 'plan must succeed: $out');
        final row = unitRowOf(list, 'U1');
        expect(row, isNotNull, reason: 'the plan must derive U1:\n$list');
        expect(
          row,
          contains('FR-001, RouteContentType.contentType'),
          reason:
              'the FR prose names contentType — the verb match resolves the '
              'method-qualified cell (issue #1320 remediation 1):\n$list',
        );
      });

      test('U4: a multi-method row whose prose matches nothing refuses the '
          'plan with the exact --> fix: and no artifacts', () async {
        final tmp = Directory.systemTemp.createTempSync('issue_1320_refuse_');
        try {
          final featureDir = p.join(tmp.path, 'specs', '1320-repro');
          await Directory(featureDir).create(recursive: true);
          await File(
            p.join(featureDir, 'spec.md'),
          ).writeAsString(multiMethodAmbiguousSpec);
          final runner = CliRunner(exitOnCompletion: false);
          final out = await runner.runCapturing([
            'tdd',
            'plan',
            '1320-repro',
            '--project',
            tmp.path,
          ]);
          expect(exitCode, 2, reason: 'the ambiguous trace must refuse: $out');
          expect(out, contains('--> fix:'));
          expect(
            out,
            contains('traces: RouteContentType.<method>'),
            reason:
                'the fix line names the exact method-qualified token the '
                'author must write (the <method> placeholder when the prose '
                'names none)',
          );
          final listFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
          expect(
            listFile.existsSync(),
            isFalse,
            reason: 'a refused plan writes no artifacts (errors-are-an-API)',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });

      test('U5: the method-qualified cell round-trips a re-plan — the '
          '#1320 hand-delta is no longer destroyed', () async {
        final tmp = Directory.systemTemp.createTempSync('issue_1320_replan_');
        try {
          final featureDir = p.join(tmp.path, 'specs', '1320-repro');
          await Directory(featureDir).create(recursive: true);
          final specFile = File(p.join(featureDir, 'spec.md'));
          await specFile.writeAsString(singleMethodSpec);
          final runner = CliRunner(exitOnCompletion: false);
          await runner.runCapturing([
            'tdd',
            'plan',
            '1320-repro',
            '--project',
            tmp.path,
          ]);
          final listFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
          final firstList = await listFile.readAsString();
          expect(
            unitRowOf(firstList, 'U1'),
            contains('FR-001, RouteContentType.contentType'),
            reason:
                'the first plan writes the method-qualified cell:\n'
                '$firstList',
          );

          // The hand-delta shape (identical here — the author's hand edit
          // or the derived cell): re-plan must keep it byte-for-byte.
          await runner.runCapturing([
            'tdd',
            'plan',
            '1320-repro',
            '--project',
            tmp.path,
          ]);
          final reList = await listFile.readAsString();
          expect(
            unitRowOf(reList, 'U1'),
            contains('FR-001, RouteContentType.contentType'),
            reason:
                'the method-qualified cell must round-trip the re-plan — '
                'the prior-row read must never silently revert it to the '
                'row-only or criterion-only shape (issue #1320 remediation '
                '2/3):\n$reList',
          );
        } finally {
          tmp.deleteSync(recursive: true);
        }
      });
    },
  );

  group('issue #1320 — gen re-generates when the traces cell gained a '
      'contract token', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: '1320-repro');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('U6: gen reports verdict=regenerated (not reused) and the pair '
        'gains the declared assertion', () async {
      // 1. The untraced spec plans a criterion-only cell.
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString(untracedSpec);
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        '1320-repro',
        '--project',
        fx.root.path,
      ]);
      // 2. gen creates the stale guard-only pair.
      final first = await runner.runCapturing([
        'tdd',
        'gen',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: 'the first gen must succeed: $first');
      final recordBefore = await fx.registryRecordOf('U1');
      final testBefore = await File(
        fixturePath(fx, recordBefore['test_path'] as String),
      ).readAsString();
      expect(
        contentIsVacuousGreen(testBefore),
        isTrue,
        reason: 'the untraced pair is the guard-only candidate',
      );

      // 3. The spec gains the declared trace; re-plan surfaces the
      //    contract token in the cell.
      await File(
        p.join(fx.featureDir, 'spec.md'),
      ).writeAsString(singleMethodSpec);
      await runner.runCapturing([
        'tdd',
        'plan',
        '1320-repro',
        '--project',
        fx.root.path,
      ]);
      // 4. The re-gen must REGENERATE (verdict=regenerated), not reuse
      //    the stale guard-only pair.
      final second = await runner.runCapturing([
        'tdd',
        'gen',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: 'the re-gen must succeed: $second');
      expect(
        second,
        contains('verdict=regenerated'),
        reason:
            'the traces cell gained a contract token since the owned '
            'artifact was generated — gen must re-generate with '
            'verdict=regenerated instead of reused (issue #1320 '
            'remediation 3):\n$second',
      );
      final testAfter = await File(
        fixturePath(fx, recordBefore['test_path'] as String),
      ).readAsString();
      expect(
        testAfter,
        contains('expect(result, isA<String>())'),
        reason: 'the regenerated pair carries the declared assertion',
      );
      expect(
        contentCarriesVacuousGuardMarker(testAfter),
        isFalse,
        reason: 'the guard-only vacuous marker is gone',
      );
    });

    test('U7: the regenerated pair runs gen→verify-red→make green — the '
        'vacuous-green dead-end is unreachable', () async {
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString(untracedSpec);
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        '1320-repro',
        '--project',
        fx.root.path,
      ]);
      await runner.runCapturing([
        'tdd',
        'gen',
        'U1',
        '--project',
        fx.root.path,
      ]);
      // The spec gains the trace; re-plan + re-gen regenerate the pair.
      await File(
        p.join(fx.featureDir, 'spec.md'),
      ).writeAsString(singleMethodSpec);
      await runner.runCapturing([
        'tdd',
        'plan',
        '1320-repro',
        '--project',
        fx.root.path,
      ]);
      final regen = await runner.runCapturing([
        'tdd',
        'gen',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(regen, contains('verdict=regenerated'), reason: regen);
      // Honest red on the regenerated pair.
      final red = await runner.runCapturing([
        'tdd',
        'verify-red',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(
        exitCode,
        0,
        reason:
            'the regenerated pair must certify red: '
            '$red',
      );
      // The implementation step: the subject returns a real String — the
      // regenerated test asserts the DECLARED outcome, so make must
      // certify green (the vacuous-green refusal never fires).
      final record = await fx.registryRecordOf('U1');
      final subjectFile = File(
        fixturePath(fx, record['subject_path'] as String),
      );
      final subject = await subjectFile.readAsString();
      await subjectFile.writeAsString(
        subject.replaceFirst(
          RegExp(r'=> throw UnimplementedError\([^;]*\);'),
          "=> 'text/event-stream';",
        ),
      );
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: 'make must certify green: $out');
      expect(
        out,
        isNot(contains('outcome=vacuous-green')),
        reason:
            'the declared-assertion path keeps the run off the '
            'vacuous-green dead-end end-to-end',
      );
    });
  });

  test('U8: the shared vacuous-green remedy names the hand-delta seam '
      '(issue #1320 remediation 4)', () {
    expect(
      vacuousGuardFallbackRemedy,
      contains('hand-delta seam'),
      reason:
          'the fallback-routed vacuous-green stop must name the designed '
          'hand-delta seam: hand-edit the traces cell to FR-00N, '
          'Row.method, then re-run',
    );
    expect(vacuousGuardFallbackRemedy, contains('Row.method'));
    expect(
      vacuousGuardFallbackRemedy,
      contains('add traces: <ContractRow> to the FR'),
      reason: 'the spec-level remedy stays the primary path',
    );
  });
}
