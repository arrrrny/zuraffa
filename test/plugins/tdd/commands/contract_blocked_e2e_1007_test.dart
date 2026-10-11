@Tags(['slow'])
// Issue #1007 — the contract-lane e2e against the REAL runner.
//
// The fast-tier suite (contract_kind_1007_test.dart) proves the plan /
// gen / verify-red / run-driver logic with a scripted runner transcript.
// THIS suite proves the generated pair against a real `dart test`
// subprocess: the contract test compiles standalone, fails through an
// ASSERTION (the captured UnimplementedError — never a compile error,
// never an uncaught error), and `zfa ttd verify-red` grades it BLOCKED
// with the contract-blocked receipt. It then proves the flip: once the
// seam is implemented, the contract test PASSES and the verdict leaves
// the blocked class (the cycle may proceed).
//
// Mirrors verify_red_command_test.dart's harness conventions (a real
// temp fixture project whose profile's `single` template runs the real
// `dart test`; the fixture root is passed via --project so the
// process-global Directory.current is never mutated).
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

**Presentation**:
- `LoginController`: `login(String email, String password) -> Result<bool, String>`

**Domain**:
- `LoginUseCase`: `execute(LoginParams) -> Future<Result<bool, String>>`
''';

void main() {
  late Directory tmp;
  late String featureDir;
  late String testPath;
  late String subjectPath;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('contract_e2e_1007_');
    featureDir = p.join(tmp.path, 'specs', '004-login-ui');
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(kLoginUiSpec);
    await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString('''
name: contract_e2e
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
# TDD Profile — contract e2e

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

    // plan -> gen through the real CLI (in-process).
    final runner = CliRunner(exitOnCompletion: false);
    var out = await runner.runCapturing([
      'tdd',
      'plan',
      '004-login-ui',
      '--project',
      tmp.path,
    ]);
    expect(out, contains('contract:A1'));
    out = await runner.runCapturing([
      'tdd',
      'gen',
      'contract:A1',
      '--project',
      tmp.path,
    ]);
    expect(out, contains('behavior_id: contract:A1'));

    testPath = p.join(
      tmp.path,
      'test',
      'tdd',
      '004-login-ui',
      'contract_a1_test.dart',
    );
    subjectPath = p.join(
      tmp.path,
      'lib',
      'tdd',
      '004-login-ui',
      'contract_a1_subject.dart',
    );
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('the generated contract test executes against the real runner and is '
      'graded BLOCKED (not RED) while the method is unimplemented', () async {
    // The pair exists with the contract lane's names.
    expect(File(testPath).existsSync(), isTrue);
    expect(File(subjectPath).existsSync(), isTrue);

    // (a) The real runner executes EXACTLY the target test and it
    //     fails through an assertion (honest, never a compile error).
    final direct = await Process.run('dart', [
      'test',
      testPath,
      '--plain-name',
      'User.validateEmail(String email) -> bool (entity method contract)',
    ], workingDirectory: tmp.path);
    final transcript = '${direct.stdout}${direct.stderr}';
    expect(direct.exitCode, isNot(0), reason: transcript);
    expect(transcript, contains('Expected:'));
    expect(transcript, isNot(contains('Compilation failed')));
    expect(transcript, isNot(contains('Failed to load')));

    // (b) verify-red grades the failing contract test BLOCKED — never
    //     a certified red — and writes the distinct receipt.
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
    expect(out, isNot(contains('classification=assertion certified=true')));
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
    // No red evidence for the contract lane.
    expect(
      File(p.join(featureDir, 'tdd', 'cycle-log.md')).existsSync(),
      isFalse,
      reason: 'a blocked contract test must not append red evidence',
    );
  });

  test('implementing the declared contract flips the verdict out of the '
      'blocked class (the cycle may proceed)', () async {
    await File(subjectPath).writeAsString('''
library;

/// Implemented contract seam (the e2e's stand-in for the production
/// `User.validateEmail`).
bool validateEmail(String email) => email.contains('@');
''');

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'verify-red',
      'contract:A1',
      '--project',
      tmp.path,
    ]);
    // The contract test now PASSES: the verdict is the honest
    // already-green class (issue #691) — NOT blocked, NOT a certified
    // red. The run driver's skip transition moves the behavior on.
    expect(out, contains('classification=unexpected-green'), reason: out);
    expect(out, isNot(contains('classification=blocked')));
    final code = exitCode;
    exitCode = 0;
    expect(code, 1, reason: out);
  });
}
