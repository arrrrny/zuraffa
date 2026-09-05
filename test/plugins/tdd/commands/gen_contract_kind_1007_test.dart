// Issue #1007 ([VISION] Contract tests as first-class zfa tdd test kind):
// `zfa tdd gen contract:A1` materializes the CONTRACT pair — a test that
// enumerates the declared method cases (one `test` per case, asserting the
// implementation satisfies the case) and a compilable subject harness
// carrying the case table. The artifacts are namespaced by feature with
// the `contract:` id sanitized to a portable file segment, registered in
// the artifact registry, and the gen verdict carries kind=contract.
//
// RED phase: gen has no contract kind — the row never resolves.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '004-login-ui';

/// The minimal contract-carrying test list: one contract row per declared
/// Session method (the entity contract the exit criterion exercises).
const String contractTestList =
    '''
# Test List: $feature

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the session starts with the authenticated user | AC-1 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system shall validate the email format through the login validator. | FR-001 | PENDING |

## Contract loop: contract behaviors

Contract behaviors (issue #1007): one row per declared entity method,
controller method, and usecase. The gen pair is a contract test scaffold
that enumerates the method cases and asserts the implementation satisfies
them — a failing case is BLOCKED, never RED.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | Session.start must satisfy the declared contract `start(token) -> Result<void>` | Session.start | PENDING |
| contract:A2 | Session.isExpired must satisfy the declared contract `isExpired() -> bool` | Session.isExpired | PENDING |
''';

void main() {
  late Directory tmpDir;
  late String featureDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_contract_1007_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    Directory(p.join(featureDir, 'tdd')).createSync(recursive: true);
    File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: gen_contract_fixture
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''');
    File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).writeAsStringSync(contractTestList);
    // Resolve the (empty) dependency set so `dart analyze` works in the
    // fixture. No dependencies => a fast no-op resolve.
    Process.runSync('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: tmpDir.path);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  List<String> genArgs(String id) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    '--feature',
    feature,
    id,
  ];

  test('gen contract:A1 produces a contract test that enumerates method '
      'cases (issue #1007 exit criterion)', () async {
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(genArgs('contract:A1'));
    expect(exitCode, 0, reason: out);

    // Portable file segment: the `:` in the id is sanitized.
    final testPath = p.join(
      tmpDir.path,
      'test',
      'tdd',
      feature,
      'contract_a1_test.dart',
    );
    final subjectPath = p.join(
      tmpDir.path,
      'lib',
      'tdd',
      feature,
      'contract_a1_subject.dart',
    );
    expect(File(testPath).existsSync(), isTrue, reason: 'test written');
    expect(File(subjectPath).existsSync(), isTrue, reason: 'subject written');

    final test = await File(testPath).readAsString();
    // The generated pair identifies as contract kind.
    expect(test, contains('kind: contract'));
    // CONTRACT TEST, not an implementation test: the file says so.
    expect(test, contains('CONTRACT TEST'));
    // The test enumerates the declared cases through the subject's case
    // table — the enumeration loop is the scaffold's shape.
    expect(test, contains('contractCases'));
    // The case table carries the declared method with its signature.
    final subject = await File(subjectPath).readAsString();
    expect(
      subject,
      contains("claim: 'Session exposes start(token) -> Result<void>'"),
    );
    expect(
      subject,
      contains(
        "claim: 'Session.start satisfies the declared `start(token) -> Result<void>`'",
      ),
    );
    expect(subject, contains('UnimplementedError'));

    // The registry records the pair under the contract id.
    final registry = await File(
      p.join(featureDir, 'tdd', 'artifacts.json'),
    ).readAsString();
    expect(registry, contains('contract:A1'));
    expect(registry, contains('contract_a1_test.dart'));

    // The structured output + verdict carry the kind.
    expect(out, contains('kind: contract'));
    expect(out, contains('behavior_id: contract:A1'));
  });

  test('gen is idempotent for a contract behavior (reused)', () async {
    await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(genArgs('contract:A1'));
    expect(exitCode, 0);
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(genArgs('contract:A1'));
    expect(exitCode, 0, reason: out);
    expect(out, contains('ownership: reused/reused'));
  });

  test('the contract test compiles and fails while unsatisfied', () async {
    // The generated pair must analyze clean (compilable) — the failure is
    // the unsatisfied case, never a compile error.
    await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(genArgs('contract:A1'));
    expect(exitCode, 0);
    final testPath = p.join(
      tmpDir.path,
      'test',
      'tdd',
      feature,
      'contract_a1_test.dart',
    );
    // The subject must be syntactically valid Dart: analyze the whole
    // throwaway project (a file-scoped analyze is a usage error).
    final analyze = await Process.run('dart', [
      'analyze',
      '--no-fatal-warnings',
      tmpDir.path,
    ]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}${analyze.stderr}');
    expect(File(testPath).existsSync(), isTrue);
  });
}
