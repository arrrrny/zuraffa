@Tags(['slow'])
// Issue #1541 — the contract-lane e2e against the REAL runner.
//
// The fast-tier suite (bug_1541_contract_harness_args_test.dart) pins the
// render surface. THIS suite proves the generated pair against a real
// `dart test` subprocess through the three #1541 outcomes:
//
//   1. an argument-validating seam (throws ArgumentError for the
//      scaffold's representative argument) executes the generated
//      contract test to a PASS (exit 0) and verify-red grades it OUT of
//      the blocked class (`classification=unexpected-green`) — the
//      SATISFIED-WITH-REJECTION outcome: the contract is satisfied
//      WITHOUT shimming the seam and WITHOUT hand-editing the scaffold;
//   2. the deliberately unimplemented seam STILL grades
//      `classification=blocked` with the contract-blocked receipt (the
//      BLOCKED path is byte-unchanged — FR-3);
//   3. the ISSUE'S EXACT scenario — a `dynamic`-typed declared param with
//      a seam that casts it (`subsystem as String`): the scaffold now
//      invokes the seam with the `_arg0()` placeholder, so the failure is
//      the placeholder's named `provide a representative` assertion (a
//      BLOCKED surface) instead of the pre-fix uncaught
//      `type 'Null' is not a subtype of type 'String' in type cast`
//      runner error; replacing the placeholder with a representative
//      value satisfies the contract.
//
// Mirrors the #1007 e2e harness conventions (a real temp fixture project
// whose profile's `single` template runs the real `dart test`; the fixture
// root is passed via --project so the process-global Directory.current is
// never mutated).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String kLoginUiSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 004-login-ui

## Functional Requirements

- **FR-001**: The login form validates the email before submitting.

## Acceptance Scenarios

1. **Given** a valid email **When** the user submits the login form **Then** the session starts

### Key Entities

| Entity | Fields | Purpose |
| User | email: String, password: String | The account holder |

## Layer Contracts

**Entities**:
- `User`: `validateEmail(String email) -> bool`
''';

const String kAgentSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 007-agent-log

## Functional Requirements

- **FR-001**: The agent log names its subsystem before writing.

## Acceptance Scenarios

1. **Given** a subsystem name **When** the logger is built **Then** the subsystem is named

## Layer Contracts

**Domain**:
- `AgentLog`: `logger(dynamic subsystem) -> Logger`
''';

Future<Directory> _fixture(String spec, String name) async {
  final tmp = Directory.systemTemp.createTempSync(name);
  final featureDir = p.join(tmp.path, 'specs', '004-login-ui');
  await Directory(featureDir).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString('''
name: contract_e2e_1541
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''');
  await Directory(
    p.join(tmp.path, '.specify', 'memory'),
  ).create(recursive: true);
  await File(
    p.join(tmp.path, '.specify', 'memory', 'tdd-profile.md'),
  ).writeAsString('''
# TDD Profile — contract e2e 1541

## Keys (machine-readable)

```yaml
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test'
file: 'dart test {file}'
```
''');
  final pubGet = await Process.run('dart', [
    'pub',
    'get',
  ], workingDirectory: tmp.path);
  expect(
    pubGet.exitCode,
    0,
    reason: 'pub get failed:\n${pubGet.stdout}${pubGet.stderr}',
  );
  return tmp;
}

/// plan + gen through the real CLI (in-process) for the feature's first
/// contract row; returns the generated pair's paths.
Future<(String, String)> _planAndGen(Directory tmp) async {
  final runner = CliRunner(exitOnCompletion: false);
  var out = await runner.runCapturing([
    'tdd',
    'plan',
    '004-login-ui',
    '--project',
    tmp.path,
  ]);
  expect(out, contains('contract:A1'), reason: out);
  out = await runner.runCapturing([
    'tdd',
    'gen',
    'contract:A1',
    '--project',
    tmp.path,
  ]);
  expect(out, contains('behavior_id: contract:A1'), reason: out);
  return (
    p.join(tmp.path, 'test', 'tdd', '004-login-ui', 'contract_a1_test.dart'),
    p.join(tmp.path, 'lib', 'tdd', '004-login-ui', 'contract_a1_subject.dart'),
  );
}

void main() {
  tearDown(() {
    exitCode = 0;
  });

  test('U-1541-4: an argument-validating seam SATISFIES the contract '
      '(satisfied-with-rejection, no seam shim)', () async {
    final tmp = await _fixture(kLoginUiSpec, 'contract_e2e_1541_reject_');
    try {
      final (testPath, subjectPath) = await _planAndGen(tmp);
      expect(File(testPath).existsSync(), isTrue);
      expect(File(subjectPath).existsSync(), isTrue);

      // The VALIDATING implementation: it rejects the scaffold's
      // representative argument ('contract-sample' is not an email) with
      // an ArgumentError — exactly the implementation class that used to
      // escape _captured as an uncaught runner error (issue #1541).
      await File(subjectPath).writeAsString('''
library;

/// Implemented, argument-validating contract seam.
bool validateEmail(String email) {
  if (!email.contains('@')) {
    throw ArgumentError('malformed email: \$email');
  }
  return true;
}
''');

      // (a) The real runner executes the generated contract test to a
      //     PASS — the captured ArgumentError passes Case 2 (the seam is
      //     implemented and validating) and the guarded Case 3 does not
      //     run against a rejection. The scaffold is unmodified: no seam
      //     shim, no hand-edited argument.
      final direct = await Process.run('dart', [
        'test',
        testPath,
        '--plain-name',
        'User.validateEmail(String email) -> bool (entity method contract)',
      ], workingDirectory: tmp.path);
      final transcript = '${direct.stdout}${direct.stderr}';
      expect(
        direct.exitCode,
        0,
        reason:
            'a captured rejection must satisfy the contract (issue #1541 '
            'satisfied-with-rejection) — transcript:\n$transcript',
      );

      // (b) verify-red grades the passing contract test out of the
      //     blocked class — the honest already-green class, NOT blocked,
      //     NOT a certified red, and NEVER runner-error.
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        'contract:A1',
        '--project',
        tmp.path,
      ]);
      expect(out, contains('classification=unexpected-green'), reason: out);
      expect(out, isNot(contains('classification=blocked')), reason: out);
      expect(out, isNot(contains('classification=runner-error')), reason: out);
      final code = exitCode;
      exitCode = 0;
      expect(code, 1, reason: out);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  test('U-1541-5: the unimplemented seam STILL grades BLOCKED with the '
      'contract-blocked receipt (the blocked path is unchanged)', () async {
    final tmp = await _fixture(kLoginUiSpec, 'contract_e2e_1541_blocked_');
    try {
      final (testPath, subjectPath) = await _planAndGen(tmp);
      expect(
        File(subjectPath).readAsStringSync(),
        contains('UnimplementedError'),
      );

      // The stub seam throws UnimplementedError: the captured error must
      // keep driving BLOCKED through the Case 2 assertion (FR-3), now
      // via the catch-all capture (FR-2) — the failure is an assertion
      // with the Expected:/Actual: signature, never an uncaught error.
      final direct = await Process.run('dart', [
        'test',
        testPath,
        '--plain-name',
        'User.validateEmail(String email) -> bool (entity method contract)',
      ], workingDirectory: tmp.path);
      final transcript = '${direct.stdout}${direct.stderr}';
      expect(direct.exitCode, isNot(0), reason: transcript);
      expect(transcript, contains('Expected:'), reason: transcript);
      expect(
        transcript,
        isNot(contains('Compilation failed')),
        reason: transcript,
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        'contract:A1',
        '--project',
        tmp.path,
      ]);
      expect(
        out,
        contains('classification=blocked certified=false'),
        reason: out,
      );
      expect(
        out,
        isNot(contains('classification=assertion certified=true')),
        reason: out,
      );
      final code = exitCode;
      exitCode = 0;
      expect(code, 1, reason: out);
      final receiptPath = p.join(
        tmp.path,
        '.zfa',
        'receipts',
        'contract-blocked.A1.json',
      );
      expect(File(receiptPath).existsSync(), isTrue, reason: out);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  test('U-1541-1 e2e: the issue scenario — a dynamic param seam that '
      'casts (subsystem as String) surfaces a NAMED verdict, and a '
      'representative value satisfies the contract', () async {
    final tmp = await _fixture(kAgentSpec, 'contract_e2e_1541_dynamic_');
    try {
      final runner = CliRunner(exitOnCompletion: false);
      var out = await runner.runCapturing([
        'tdd',
        'plan',
        '004-login-ui',
        '--project',
        tmp.path,
      ]);
      expect(out, contains('contract:A1'), reason: out);
      out = await runner.runCapturing([
        'tdd',
        'gen',
        'contract:A1',
        '--project',
        tmp.path,
      ]);
      expect(out, contains('behavior_id: contract:A1'), reason: out);
      final testPath = p.join(
        tmp.path,
        'test',
        'tdd',
        '004-login-ui',
        'contract_a1_test.dart',
      );
      final subjectPath = p.join(
        tmp.path,
        'lib',
        'tdd',
        '004-login-ui',
        'contract_a1_subject.dart',
      );

      // The generated scaffold passes the placeholder, never a bare null.
      final generated = File(testPath).readAsStringSync();
      expect(generated, contains('impl(_arg0())'), reason: generated);
      expect(generated, isNot(contains('impl(null)')), reason: generated);

      // The ISSUE'S seam: implemented, casting the dynamic param.
      // (`AgentLog.logger(subsystem as String)` throws ArgumentError for
      // invalid names; the cast throws TypeError for null.) Pre-fix the
      // scaffold passed null and the cast threw UNCAUGHT.
      await File(subjectPath).writeAsString('''
library;

/// The logging subsystem registry (validates names).
Object? _agentLogLogger(String subsystem) {
  if (subsystem.isEmpty || subsystem.contains(' ')) {
    throw ArgumentError('invalid subsystem name: \$subsystem');
  }
  return 'logger(\$subsystem)';
}

/// Implemented contract seam — the issue's cast shape.
Object? logger(dynamic subsystem) => _agentLogLogger(subsystem as String);
''');

      // Stage 1: the un-replaced placeholder throws UnimplementedError
      // BEFORE the seam runs — a named BLOCKED surface ('provide a
      // representative'), never the uncaught cast error.
      final direct = await Process.run('dart', [
        'test',
        testPath,
      ], workingDirectory: tmp.path);
      final transcript = '${direct.stdout}${direct.stderr}';
      expect(direct.exitCode, isNot(0), reason: transcript);
      expect(
        transcript,
        contains('provide a representative `dynamic`'),
        reason:
            'the placeholder instruction must be the failure surface '
            '(issue #1541) — transcript:\n$transcript',
      );
      expect(
        transcript,
        isNot(contains("type 'Null' is not a subtype")),
        reason:
            'the bare-null cast error must be unreachable from the '
            'scaffold — transcript:\n$transcript',
      );

      // Stage 2: the author replaces the placeholder with a
      // representative value — the contract satisfies WITHOUT shimming
      // the seam (the cast and the validation run for real).
      final edited = generated.replaceAll('impl(_arg0())', "impl('agent')");
      expect(edited, contains("impl('agent')"), reason: edited);
      await File(testPath).writeAsString(edited);
      final satisfied = await Process.run('dart', [
        'test',
        testPath,
      ], workingDirectory: tmp.path);
      final satisfiedTranscript = '${satisfied.stdout}${satisfied.stderr}';
      expect(
        satisfied.exitCode,
        0,
        reason:
            'a representative argument must satisfy the argument-validating '
            'contract (issue #1541 criterion 3) — '
            'transcript:\n$satisfiedTranscript',
      );
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });
}
