// Issue #1007 ([VISION] Contract tests as first-class zfa tdd test kind):
// a failing contract test is a BLOCKED verdict — distinct from RED.
//
// - `zfa tdd verify-red contract:A1` on a deliberately unimplemented
//   method reports `classification=blocked`, exits non-zero, writes NO
//   red evidence, and persists the receipt
//   `.zfa/receipts/contract-blocked.<id>.json`.
// - A NON-contract behavior with the same failing transcript still
//   certifies an honest red (the BLOCKED verdict exists only on the
//   contract lane — hard constraint).
// - The StepRunner surfaces the child's `classification=blocked` summary
//   token as the step outcome, and `zfa tdd run` turns a blocked
//   verify-red into `result=blocked` (the cycle cannot proceed to GREEN).
//
// RED phase: verify-red classifies a failing contract test as an ordinary
// assertion red — every blocked assertion fails.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';

const String feature = '004-login-ui';

/// A fake runner script: prints a dart-test transcript whose single test
/// fails through an assertion (the deliberately unimplemented case) and
/// exits 1. The classifier sees exactly one executed test + the
/// Expected/Actual assertion signature.
const String fakeRedRunner = '''
#!/usr/bin/env sh
printf '00:01 +0 -1: contract case [E]\\n'
printf 'Expected: a satisfied contract case\\n'
printf '  Actual: <Instance of UnimplementedError>\\n'
exit 1
''';

/// The contract test list: one contract row (the gen pair exists), the
/// fake runner drives its "execution".
const String contractTestList =
    '''
# Test List: $feature

## Contract loop: contract behaviors

Contract behaviors (issue #1007): the gen pair is a contract test scaffold
that enumerates the method cases and asserts the implementation satisfies
them.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | Session.start(token) | Session.start | PENDING |
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String fakeRunnerPath;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('blocked_1007_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    Directory(p.join(featureDir, 'tdd')).createSync(recursive: true);
    File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: blocked_fixture
environment:
  sdk: ^3.11.0
''');
    // The profile: the fake runner replaces `dart test` so the fast tier
    // never compiles a kernel (the transcript is scripted).
    fakeRunnerPath = p.join(tmpDir.path, 'fake_contract_red.sh');
    await File(fakeRunnerPath).writeAsString(fakeRedRunner);
    await Process.run('chmod', ['+x', fakeRunnerPath]);
    await Directory(
      p.join(tmpDir.path, '.specify', 'memory'),
    ).create(recursive: true);
    await File(
      p.join(tmpDir.path, '.specify', 'memory', 'tdd-profile.md'),
    ).writeAsString('''
# TDD Profile — fixture

## Commands

- Single test: `$fakeRunnerPath {file} --plain-name "{name}"`
- Full suite: `$fakeRunnerPath {file}`

## Keys (machine-readable)

```yaml
runner: dart
single: '$fakeRunnerPath {file} --plain-name "{name}"'
suite: '$fakeRunnerPath {file}'
file: '$fakeRunnerPath {file}'
coverage: '$fakeRunnerPath {file}'
```
''');
    File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).writeAsStringSync(contractTestList);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  /// Gen the contract pair in the fixture (the REAL gen command).
  Future<void> genContract() async {
    final out = await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'gen',
      '--project',
      tmpDir.path,
      '--feature',
      feature,
      'contract:A1',
    ]);
    expect(exitCode, 0, reason: out);
  }

  test('a deliberately unimplemented method is BLOCKED, not RED (issue '
      '#1007 exit criterion)', () async {
    await genContract();
    final out = await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'verify-red',
      '--project',
      tmpDir.path,
      '--feature',
      feature,
      'contract:A1',
    ]);

    // BLOCKED — the distinct verdict, never a certified red.
    expect(
      out,
      contains(
        'verify-red: behavior=contract:A1 classification=blocked '
        'certified=false feature=$feature',
      ),
      reason: 'the summary line must name the blocked class:\n$out',
    );
    expect(exitCode, isNot(0), reason: 'blocked must exit non-zero');
    // No red evidence: BLOCKED is not a certified red.
    expect(
      File(p.join(featureDir, 'tdd', 'cycle-log.md')).existsSync(),
      isFalse,
      reason: 'a blocked contract writes no red evidence',
    );

    // The distinct receipt: contract-blocked.<id>.json (the `:` in the
    // id sanitized per the portable receipt naming rules).
    final receiptPath = p.join(
      tmpDir.path,
      '.zfa',
      'receipts',
      'contract-blocked.contract_A1.json',
    );
    expect(
      File(receiptPath).existsSync(),
      isTrue,
      reason: 'the blocked receipt persists at $receiptPath',
    );
    final receipt = await File(receiptPath).readAsString();
    expect(receipt, contains('"classification": "blocked"'));
    expect(receipt, contains('contract:A1'));
    expect(receipt, contains('"feature": "$feature"'));
  });

  test('the same failing transcript on a NON-contract behavior still '
      'certifies an honest red (additive hard constraint)', () async {
    // A unit row + the same fake transcript: the ordinary lane is
    // untouched by the BLOCKED verdict.
    File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the subject is not unimplemented | FR-001 | PENDING |
''');
    final genOut = await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'gen',
      '--project',
      tmpDir.path,
      '--feature',
      feature,
      'U1',
    ]);
    expect(exitCode, 0, reason: genOut);

    final out = await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'verify-red',
      '--project',
      tmpDir.path,
      '--feature',
      feature,
      'U1',
    ]);
    expect(
      out,
      contains(
        'verify-red: behavior=U1 classification=assertion '
        'certified=true feature=$feature',
      ),
      reason: 'the unit lane is unchanged:\n$out',
    );
    expect(exitCode, 0);
  });

  test('StepRunner surfaces classification=blocked as the verify-red '
      'outcome (the run driver consumes it)', () async {
    final runner = StepRunner(
      spawner: (command, workingDirectory) async => ProcessResult(
        1,
        1,
        'verify-red: behavior=contract:A1 classification=blocked '
            'certified=false feature=$feature\n',
        '',
      ),
    );
    final result = await runner.run(
      step: 'verify-red',
      behaviorId: 'contract:A1',
      feature: feature,
      projectRoot: tmpDir.path,
    );
    expect(result.outcome, 'blocked');
    expect(result.success, isFalse);
    expect(result.exitCode, 1);
  });

  test(
    'a blocked verify-red stops the run BEFORE GREEN (result=blocked)',
    () async {
      // A fake zfa entrypoint: gen succeeds, verify-red reports blocked.
      // The run must stop at contract:A1:verify-red and never reach make.
      final zfaBin = p.join(tmpDir.path, 'fake_zfa.sh');
      await File(zfaBin).writeAsString('''
#!/usr/bin/env sh
step="\$2"
id="\$3"
if [ "\$step" = "verify-red" ]; then
  echo "verify-red: behavior=\$id classification=blocked certified=false feature=$feature"
  exit 1
fi
exit 0
''');
      await Process.run('chmod', ['+x', zfaBin]);

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        tmpDir.path,
        '--zfa-bin',
        zfaBin,
      ]);
      expect(
        out,
        contains('run: feature=$feature result=blocked'),
        reason: 'the summary line names the blocked result:\n$out',
      );
      expect(
        out,
        contains('stopped_at=contract:A1:verify-red'),
        reason: 'the stop names the blocked step',
      );
      // The blocked verdict never reaches make (GREEN is blocked).
      expect(out, isNot(contains('contract:A1 make ->')));
      expect(exitCode, 1);
    },
  );
}
