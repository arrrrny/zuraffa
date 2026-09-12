// Bug #1480 (fix lever 2) originally made `zfa tdd plan` fail fast when a
// unit behavior would fallback-route: the unit lane can never self-heal
// (a contract row name is authoring intent no classifier can invent —
// doc/BREAKING_CHANGES.md:62-73), so a fallback-routed unit behavior
// dead-ended at make (vacuous-green) only ~28 minutes into `zfa tdd run`.
//
// Feature 1484 (issue option 3) SUPERSEDES that gate: an FR with no
// surviving `traces:` binding is recorded as a manual declaration, so the
// fallback-routed unit row is never derived and there is nothing left to
// refuse. The gate and its `--allow-unit-fallback` escape hatch remain
// accepted (the migration window), but the default contract these tests
// pin is now the manual routing.
//
// Contract:
//   - default: an untraced FR routes to a manual declaration (exit 0, a
//     `FR-xxx derives no unit behaviour` warning naming the two remedies)
//   - `--allow-unit-fallback` is inert — there is no fallback lane to restore
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

  group('bug #1480 — unit-lane fallback is retired by feature 1484', () {
    // Feature 1484 (issue option 3) supersedes the #1480 fail-fast gate:
    // an FR with no surviving `traces:` binding is recorded as a manual
    // declaration, so a fallback-routed unit row is never derived and
    // the gate has nothing left to refuse. These tests pin the new
    // contract over the same fixtures the fail-fast gate used.
    test('A2: an all-untraced spec plans green — every FR routes to a '
        'manual declaration, no unit row, no refusal', () async {
      (tmpDir, featureDir) = await _feature(_allFallbackSpec);
      final specBefore = File(p.join(featureDir, 'spec.md')).readAsStringSync();

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'the manual routing replaces the refusal (issue #1484): '
            'out was\n$out',
      );
      expect(out, isNot(contains('unit-fallback-refused')));
      expect(out, contains('FR-001 derives no unit behaviour'));
      expect(out, contains('FR-002 derives no unit behaviour'));
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(testList.existsSync(), isTrue, reason: out);
      expect(
        testList.readAsStringSync(),
        isNot(contains('[fallback:')),
        reason: 'no fallback-routed unit row is derived under 1484',
      );
      expect(
        File(p.join(featureDir, 'spec.md')).readAsStringSync(),
        specBefore,
        reason: 'the manual routing never mutates the spec',
      );
    });

    test('A2b: the defaulted-FR warning names the two remedies', () async {
      (tmpDir, featureDir) = await _feature(_allFallbackSpec);

      final out = await _plan(tmpDir);

      expect(out, contains('traces:'));
      expect(out, contains('**Type**: manual'));
    });

    test('U2b: --allow-unit-fallback is inert — the manual routing stands '
        '(exit 0, no fallback rows)', () async {
      (tmpDir, featureDir) = await _feature(_allFallbackSpec);

      final out = await _plan(tmpDir, ['--allow-unit-fallback']);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason: 'the flag still parses: out was\n$out',
      );
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(testList.existsSync(), isTrue, reason: out);
      expect(
        testList.readAsStringSync(),
        isNot(contains('[fallback:')),
        reason: 'there is no fallback lane left to restore under 1484',
      );
    });

    test('U2c: a fully-traced spec plans green — no manual routing', () async {
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

    test('U2d: a partially untraced spec routes only the untraced FR to '
        'manual', () async {
      final partial = _tracedSpec.replaceFirst(
        '- **FR-002**: the system logs every security event\n'
            '            traces: Validator.validate\n',
        '- **FR-002**: the system logs every security event\n',
      );
      (tmpDir, featureDir) = await _feature(partial);

      final out = await _plan(tmpDir);

      expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
      expect(out, contains('FR-002 derives no unit behaviour'));
      expect(
        out,
        isNot(contains('FR-001 derives no unit behaviour')),
        reason: 'the traced FR-001 is not implicated',
      );
    });
  });
}
