// Bug #1480 (fix lever 2) — `zfa tdd plan` fails fast when any unit
// behavior would fallback-route. The unit lane can NEVER self-heal (a
// contract row name is authoring intent no classifier can invent —
// doc/BREAKING_CHANGES.md:62-73), so a fallback-routed unit behavior
// dead-ends at make (vacuous-green) only ~28 minutes into `zfa tdd run`.
// The asymmetry with the acceptance lane (whose fallback the #1186
// one-time marker migration heals) is exactly why the unit case refuses
// at plan time.
//
// Fix contract:
//   - default: plan refuses (exit 1, class `unit-fallback-refused`),
//     names every offending `U<n> (FR-xxx)`, writes NO artifacts, and
//     never mutates the spec (no marker emission)
//   - `--allow-unit-fallback` restores the legacy labeled-fallback plan
//     (the migration escape hatch)
//   - a spec whose FRs all carry declared traces is unaffected
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const _allFallbackSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1480-failfast

## Functional Requirements

- **FR-001**: the system validates the user's email address
- **FR-002**: the system logs every security event

## Acceptance Scenarios

1. **Given** a user with an invalid email **When** the form submits **Then** an
   error is shown.
   **Type**: acceptance
''';

const _tracedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1480-failfast

## Layer Contracts

**Function**:
- `Validator`: `validate(Input) -> Result`

## Functional Requirements

- **FR-001**: the system validates the user's email address
            traces: Validator.validate
- **FR-002**: the system logs every security event
            traces: Validator.validate

## Acceptance Scenarios

1. **Given** a user with an invalid email **When** the form submits **Then** an
   error is shown.
   **Type**: acceptance
''';

Future<(Directory, String)> _feature(String spec) async {
  final tmp = Directory.systemTemp.createTempSync('failfast1480_');
  final featureDir = p.join(tmp.path, 'specs', '1480-failfast');
  await Directory(featureDir).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  return (tmp, featureDir);
}

Future<String> _plan(Directory tmp, [List<String> extra = const []]) async {
  final runner = CliRunner(exitOnCompletion: false);
  final out = await runner.runCapturing([
    'tdd',
    'plan',
    '1480-failfast',
    '--project',
    tmp.path,
    ...extra,
  ]);
  return out;
}

void main() {
  late Directory tmpDir;
  late String featureDir;

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    CliRunner.lastDispatchedExitCode = 0;
  });

  group('bug #1480 — plan fails fast on unit-lane fallback', () {
    test('A2: an all-fallback spec REFUSES at plan time (exit 1) naming each '
        'U<n> (FR-xxx) — no 28-minute dead-end', () async {
      (tmpDir, featureDir) = await _feature(_allFallbackSpec);
      final specBefore = File(p.join(featureDir, 'spec.md')).readAsStringSync();

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        1,
        reason:
            'the plan must refuse instead of exiting 0 into a guaranteed '
            'make dead-end (issue #1480): out was\n$out',
      );
      expect(out, contains('unit-fallback-refused'));
      expect(out, contains('U1'));
      expect(out, contains('FR-001'));
      expect(out, contains('U2'));
      expect(out, contains('FR-002'));
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(
        testList.existsSync(),
        isFalse,
        reason: 'a refused plan writes no artifacts',
      );
      expect(
        File(p.join(featureDir, 'spec.md')).readAsStringSync(),
        specBefore,
        reason: 'a refused plan never mutates the spec (no marker emission)',
      );
    });

    test('A2b: the refusal names the three outs (declare traces inline, map '
        'them in contracts/*.md, or --allow-unit-fallback)', () async {
      (tmpDir, featureDir) = await _feature(_allFallbackSpec);

      final out = await _plan(tmpDir);

      expect(out, contains('traces:'));
      expect(out, contains('contracts/'));
      expect(out, contains('--allow-unit-fallback'));
    });

    test('U2b: --allow-unit-fallback restores the legacy labeled-fallback '
        'plan (migration escape hatch, exit 0)', () async {
      (tmpDir, featureDir) = await _feature(_allFallbackSpec);

      final out = await _plan(tmpDir, ['--allow-unit-fallback']);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason: 'the escape hatch keeps the legacy behavior: out was\n$out',
      );
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(testList.existsSync(), isTrue, reason: out);
      expect(
        testList.readAsStringSync(),
        contains('[fallback:'),
        reason: 'the legacy plan keeps its labeled fallback rows',
      );
    });

    test('U2c: a fully-traced spec plans green — the gate is silent', () async {
      (tmpDir, featureDir) = await _feature(_tracedSpec);

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason: 'declared routing is unaffected: out was\n$out',
      );
      final routing = File(
        p.join(featureDir, 'tdd', 'test-list.md'),
      ).readAsStringSync();
      expect(routing, contains('[declared: contract row: Validator'));
      expect(routing, isNot(contains('[fallback:')));
    });

    test('U2d: a PARTIALLY traced spec refuses naming only the untraced '
        'behavior', () async {
      final partial = _tracedSpec.replaceFirst(
        '- **FR-002**: the system logs every security event\n'
            '            traces: Validator.validate\n',
        '- **FR-002**: the system logs every security event\n',
      );
      (tmpDir, featureDir) = await _feature(partial);

      final out = await _plan(tmpDir);

      expect(CliRunner.lastDispatchedExitCode, 1, reason: out);
      expect(out, contains('FR-002'));
      expect(
        out,
        isNot(contains('FR-001)')),
        reason: 'the traced FR-001 is not implicated',
      );
    });
  });
}
