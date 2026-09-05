// Issue #1007 — contract tests as a first-class `zfa tdd` test kind.
//
// A contract test is different from a unit test: it proves an
// implementation satisfies a DECLARED contract (one entity method,
// controller method or usecase of the spec's Layer Contracts section),
// not that a piece of code does what its author said. This suite pins
// the four deliverables end to end (fast tier — no `dart test` spawn):
//
//   1. plan emits `contract:<id>` rows for every entity method,
//      controller method and usecase (`zfa tdd plan 004-login-ui`
//      emits `contract:A1`, an entity method contract);
//   2. `zfa tdd gen` for contract behaviors generates a contract test
//      SCAFFOLD that enumerates the contract's cases (+ the contract
//      seam subject);
//   3. a failing contract test is a BLOCKED verdict (distinct from RED)
//      with its own receipt (`contract-blocked.<id>.json`) — it blocks
//      the cycle from proceeding to GREEN (the run driver parks the
//      behavior at BLOCKED and stops with `result=blocked`);
//   4. the corpus-economics gap ledger records contract-test failures
//      as highest-severity gaps.
//
// The real-`dart test` e2e (the generated pair compiles, fails through
// an assertion and is graded BLOCKED by the real runner transcript)
// lives in contract_blocked_e2e_1007_test.dart (slow tier).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

import '../helpers/corpus_fixture.dart';
import '../helpers/tdd_fixture.dart';

/// Reads the process-global `dart:io exitCode` and immediately resets it,
/// so this suite never LEAKS a nonzero code into a concurrently-running
/// suite's exitCode assertion (`exitCode` is process-global across test
/// isolates — the suite-wide flake hazard the eager reset shrinks).
int takeExitCode() {
  final code = exitCode;
  exitCode = 0;
  return code;
}

/// The 004-login-ui spec fixture: one acceptance scenario, one FR, a
/// Key Entities table and a Layer Contracts section declaring one
/// entity method, one controller method and one usecase (the engine
/// surfaces issue #1007's exit criteria drive against).
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
  // -------------------------------------------------------------------
  // Reader: the `## Contract loop:` section + the contract id fold.
  // -------------------------------------------------------------------
  group('reader: the Contract loop section (issue #1007)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('contract_reader_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test(
      'a `## Contract loop` section header sets the contract kind',
      () async {
        final featureDir = p.join(tmp.path, 'specs', '004-login-ui');
        await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
        await File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List: 004-login-ui

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | a unit behavior | FR-001 | PENDING |

## Contract loop: contract behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | User.validateEmail(String email) -> bool (entity method contract) | User.validateEmail | PENDING |
''');
        final rows = await TestListReader(featureDir).read();
        expect(rows, hasLength(2));
        expect(rows[0].kind, BehaviorKind.unit);
        expect(rows[1].kind, BehaviorKind.contract);
        expect(rows[1].id, 'contract:A1');
        expect(rows[1].traces, 'User.validateEmail');
      },
    );

    test(
      'the default target folds the `contract:` prefix into an identifier',
      () {
        // `subject_contract:a1` is not a valid Dart identifier — the fold
        // must produce `subject_contract_a1` (the pair died at compile
        // before issue #1007).
        expect(
          TestListReader.resolveDefaultTarget('contract:A1'),
          'subject_contract_a1',
        );
        // Canonical id shapes keep their pre-1007 fold exactly.
        expect(TestListReader.resolveDefaultTarget('A1'), 'subject_a1');
        expect(TestListReader.resolveDefaultTarget('B-001'), 'subject_b_001');
      },
    );

    test('the BLOCKED state cell parses (hand-maintained rows)', () async {
      final featureDir = p.join(tmp.path, 'specs', '004-login-ui');
      await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
      await File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List: 004-login-ui

## Contract loop: contract behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | User.validateEmail(String email) -> bool (entity method contract) | User.validateEmail | BLOCKED |
''');
      final rows = await TestListReader(featureDir).read();
      expect(rows.single.state, BehaviorState.blocked);
    });
  });

  // -------------------------------------------------------------------
  // Deliverable 1: plan emits contract:<id> rows.
  // -------------------------------------------------------------------
  group(
    'plan: contract:<id> rows for every declared contract (issue #1007)',
    () {
      late Directory tmp;
      late String featureDir;

      setUp(() {
        tmp = Directory.systemTemp.createTempSync('contract_plan_');
        featureDir = p.join(tmp.path, 'specs', '004-login-ui');
      });

      tearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        exitCode = 0;
      });

      Future<void> writeSpec() async {
        await Directory(featureDir).create(recursive: true);
        await File(p.join(featureDir, 'spec.md')).writeAsString(kLoginUiSpec);
      }

      test('zfa tdd plan 004-login-ui emits contract:A1 (entity method '
          'contract) in the engine plan', () async {
        await writeSpec();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'plan',
          '004-login-ui',
          '--project',
          tmp.path,
        ]);

        final list = await File(
          p.join(featureDir, 'tdd', 'test-list.md'),
        ).readAsString();
        // The Contract loop section, in the canonical 4-column shape.
        expect(list, contains('## Contract loop: contract behaviors'));
        expect(list, contains('| id | behavior | traces | state |'));
        // Exit criterion 1: contract:A1 is the entity method contract.
        expect(
          list,
          contains(
            '| contract:A1 | User.validateEmail(String email) -> bool '
            '(entity method contract) | User.validateEmail | PENDING |',
          ),
        );
        // The controller method and the usecase are planned too.
        expect(
          list,
          contains(
            '| contract:A2 | LoginController.login(String email, '
            'String password) -> Result<bool, String> '
            '(controller method contract) | LoginController.login | PENDING |',
          ),
        );
        expect(
          list,
          contains(
            '| contract:A3 | LoginUseCase.execute(LoginParams) -> '
            'Future<Result<bool, String>> (usecase contract) | '
            'LoginUseCase.execute | PENDING |',
          ),
        );
        // The routing provenance names the declared lane.
        expect(
          out,
          contains(
            'route: contract:A1 -> contract lane '
            '[declared: layer contracts section]',
          ),
        );
      });

      test('a spec without Layer Contracts writes no contract section '
          '(pre-1007 plans keep their shape)', () async {
        await writeSpec();
        await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 004-login-ui

## Functional Requirements

- **FR-001**: The login form validates the email before submitting.

## Acceptance Scenarios

1. **Given** a valid email **When** the user submits the login form **Then** the session starts
''');
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'plan',
          '004-login-ui',
          '--project',
          tmp.path,
        ]);
        final list = await File(
          p.join(featureDir, 'tdd', 'test-list.md'),
        ).readAsString();
        expect(list, isNot(contains('## Contract loop')));
        expect(list, isNot(contains('contract:')));
      });

      test('re-planning keeps contract ids stable by traces', () async {
        await writeSpec();
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'plan',
          '004-login-ui',
          '--project',
          tmp.path,
        ]);
        // Hand-advance the first contract row's state (as a blocked or
        // done contract lane would leave it).
        final listFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
        final advanced = listFile.readAsStringSync().replaceAll(
          '| User.validateEmail | PENDING |',
          '| User.validateEmail | BLOCKED |',
        );
        await listFile.writeAsString(advanced);

        await runner.runCapturing([
          'tdd',
          'plan',
          '004-login-ui',
          '--project',
          tmp.path,
        ]);
        final reList = await listFile.readAsString();
        expect(
          reList,
          contains(
            '| contract:A1 | User.validateEmail(String email) -> bool '
            '(entity method contract) | User.validateEmail | BLOCKED |',
          ),
        );
      });
    },
  );

  // -------------------------------------------------------------------
  // Deliverable 2: gen emits the contract test scaffold + seam.
  // -------------------------------------------------------------------
  group('gen: the contract pair (issue #1007)', () {
    late Directory tmp;
    late String featureDir;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('contract_gen_');
      featureDir = p.join(tmp.path, 'specs', '004-login-ui');
      await Directory(featureDir).create(recursive: true);
      await File(p.join(featureDir, 'spec.md')).writeAsString(kLoginUiSpec);
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        '004-login-ui',
        '--project',
        tmp.path,
      ]);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test('zfa tdd gen contract:A1 produces a contract test that enumerates '
        'the method cases', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        'contract:A1',
        '--project',
        tmp.path,
      ]);
      expect(out, contains('behavior_id: contract:A1'));
      expect(out, contains('kind: contract'));

      final testPath = p.join(
        tmp.path,
        'test',
        'tdd',
        '004-login-ui',
        'contract_a1_test.dart',
      );
      final test = await File(testPath).readAsString();
      // The contract lane's provenance header.
      expect(test, contains('// kind: contract'));
      expect(test, contains('behavior_id: contract:A1'));
      // The test ENUMERATES the contract's cases (issue #1007): the
      // signature case, the implementation case and the return case.
      expect(test, contains('Case 1 of 3'));
      expect(test, contains('Case 2 of 3'));
      expect(test, contains('Case 3 of 3'));
      expect(test, contains('the declared method'));
      expect(test, contains('isNot(isA<UnimplementedError>())'));
      expect(test, contains('isA<bool>()'));
      // The declared contract is the assertion target.
      expect(test, contains('User.validateEmail'));
      // One test per behavior (the single-test runner contract).
      expect(RegExp(r'\btest\(').allMatches(test), hasLength(1));

      final subjectPath = p.join(
        tmp.path,
        'lib',
        'tdd',
        '004-login-ui',
        'contract_a1_subject.dart',
      );
      final subject = await File(subjectPath).readAsString();
      // The contract seam carries the DECLARED signature.
      expect(subject, contains('bool validateEmail(String email)'));
      expect(subject, contains('is not implemented'));
      expect(subject, contains('// kind: contract'));

      // The registry record links the pair.
      final registry =
          jsonDecode(
                await File(
                  p.join(featureDir, 'tdd', 'artifacts.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final records = registry['records'] as List;
      expect(records, hasLength(1));
      expect(records.first['behavior_id'], 'contract:A1');
    });

    test('the contract test imports the paired seam relatively', () async {
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'gen',
        'contract:A1',
        '--project',
        tmp.path,
      ]);
      final test = await File(
        p.join(
          tmp.path,
          'test',
          'tdd',
          '004-login-ui',
          'contract_a1_test.dart',
        ),
      ).readAsString();
      expect(
        test,
        contains(
          "import '../../../lib/tdd/004-login-ui/contract_a1_subject.dart' "
          'as subject;',
        ),
      );
    });
  });

  // -------------------------------------------------------------------
  // Deliverable 3 (command level): the BLOCKED verdict + receipt.
  // -------------------------------------------------------------------
  group('verify-red: a failing contract test is BLOCKED, not RED '
      '(issue #1007)', () {
    late Directory tmp;
    late String featureDir;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('contract_blocked_');
      featureDir = p.join(tmp.path, 'specs', '004-login-ui');
      await Directory(featureDir).create(recursive: true);
      await File(p.join(featureDir, 'spec.md')).writeAsString(kLoginUiSpec);
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        '004-login-ui',
        '--project',
        tmp.path,
      ]);
      final out2 = await runner.runCapturing([
        'tdd',
        'gen',
        'contract:A1',
        '--project',
        tmp.path,
      ]);
      expect(out2, contains('behavior_id: contract:A1'));
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      exitCode = 0;
    });

    test('a deliberately unimplemented method causes a BLOCKED verdict '
        'with the contract-blocked receipt and no red evidence', () async {
      // The profile's `single` template points at a scripted runner that
      // emits an HONEST assertion-failure transcript for the generated
      // contract test (the real `dart test` lane is proven in the slow
      // e2e suite; the classifier consuming the transcript is real here).
      final fakeRunner = p.join(tmp.path, '.fake-contract-runner');
      await File(fakeRunner).writeAsString('''
#!/bin/sh
echo "00:00 +0 -1: contract:A1 (User.validateEmail) contract:A1 - User.validateEmail(String email) -> bool (entity method contract) [E]"
echo "Expected: not <Instance of 'UnimplementedError'>"
echo "  Actual: UnimplementedError:<User.validateEmail is not implemented>"
exit 1
''');
      await Process.run('chmod', ['+x', fakeRunner]);
      await Directory(
        p.join(tmp.path, '.specify', 'memory'),
      ).create(recursive: true);
      await File(
        p.join(tmp.path, '.specify', 'memory', 'tdd-profile.md'),
      ).writeAsString('''
# TDD Profile — contract fixture

## Keys (machine-readable)

```yaml
single: '$fakeRunner {file} --plain-name "{name}"'
```
''');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        'contract:A1',
        '--project',
        tmp.path,
      ]);

      // BLOCKED, not RED: the summary token is the contract-lane verdict
      // and nothing is certified.
      expect(out, contains('classification=blocked certified=false'));
      expect(out, isNot(contains('classification=assertion certified=true')));
      expect(takeExitCode(), 1, reason: out);

      // The distinct receipt: contract-blocked.<id>.json.
      final receiptPath = p.join(
        tmp.path,
        '.zfa',
        'receipts',
        'contract-blocked.A1.json',
      );
      expect(File(receiptPath).existsSync(), isTrue, reason: out);
      final receipt =
          jsonDecode(await File(receiptPath).readAsString())
              as Map<String, dynamic>;
      expect(receipt['schema'], 'contract-blocked.v1');
      expect(receipt['behavior'], 'contract:A1');
      expect(receipt['feature'], '004-login-ui');
      expect(receipt['kind'], 'contract');
      expect(receipt['contract'], 'User.validateEmail');
      expect(receipt['classification'], 'blocked');
      expect(receipt['output_excerpt'], contains('Expected:'));

      // No red evidence: the cycle-log is never created for the blocked
      // contract lane (the receipt is the record — the cycle cannot ride
      // a contract failure into the green phase).
      expect(
        File(p.join(featureDir, 'tdd', 'cycle-log.md')).existsSync(),
        isFalse,
        reason: 'a blocked contract test must not append red evidence',
      );
    });
  });

  // -------------------------------------------------------------------
  // Deliverable 3 (driver level): BLOCKED blocks the cycle's way to
  // GREEN.
  // -------------------------------------------------------------------
  group('run: a blocked contract stops the cycle before GREEN '
      '(issue #1007)', () {
    late TddFixture fx;

    setUp(() async {
      // writeProfile: false — the fake zfa handles every step; no profile
      // also skips the driver's real `dart test` suite-baseline spawn
      // (the kernel-cache-safe fast-tier rule: no dart test in fixtures).
      fx = await TddFixture.create(
        featureName: '004-login-ui',
        writeProfile: false,
      );
      await fx.writeFakeZfa();
      // Only the contract row: the run must stop AT it (the fixture's
      // render order puts the unit section before the contract section,
      // so a unit row would complete first — the blocked-stop semantics
      // for LATER rows is the generic FR-007 contract, already pinned by
      // run_command_test.dart).
      await fx.seedTestList([
        (
          id: 'contract:A1',
          description:
              'User.validateEmail(String email) -> bool (entity method '
              'contract)',
          traces: 'User.validateEmail',
          state: 'PENDING',
          kind: 'contract',
        ),
      ]);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('verify-red reporting blocked parks the behavior at BLOCKED, '
        'stops the run with result=blocked, and never spawns make', () async {
      await fx.setStepOutcome('verify-red', 'contract:A1', 'blocked');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // The machine summary carries the BLOCKED verdict and count.
      expect(out, contains('result=blocked'));
      expect(out, contains('blocked=1'));
      expect(out, contains('stopped_at=contract:A1:verify-red'));
      expect(takeExitCode(), 1, reason: out);
      // BLOCKED is distinct from RED: the verdict line names the block.
      expect(out, contains('contract:A1 verify-red -> blocked'));
      expect(out, contains('the cycle is BLOCKED'));

      // make NEVER spawned for the blocked contract — the cycle cannot
      // proceed to GREEN. Exactly the two steps ran, then the honest
      // stop.
      expect(fx.stepInvocations(), [
        'gen contract:A1',
        'verify-red contract:A1',
      ]);

      // The persisted state is `blocked` — not `red`.
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(state['behavior_states']['contract:A1'], 'blocked');
    });
  });

  // -------------------------------------------------------------------
  // Deliverable 4: the corpus-economics gate treats contract failures
  // as highest-severity gaps.
  // -------------------------------------------------------------------
  group('corpus economics: contract-test failures are highest-severity '
      'gaps (issue #1007)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('contract_gap_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('appendGap grades blocked-run stops as severity=contract and the '
        'totals order them first', () async {
      final store = GapLedgerStore(tmp.path);
      // A standard roadblock first (append order), then the contract one.
      await store.appendGap(
        feature: 'f1-unit',
        behavior: 'U3',
        step: 'make',
        outcome: 'stopped',
        expectedResult: 'complete',
      );
      await store.appendGap(
        feature: 'f2-contract',
        behavior: 'contract:A1',
        step: 'verify-red',
        outcome: 'blocked',
        expectedResult: 'complete',
        severity: 'contract',
      );

      final ledger = await store.load();
      expect(ledger, hasLength(2));
      expect(ledger.last.severity, 'contract');
      expect(ledger.last.gapSeverity, GapSeverity.contract);
      expect(ledger.first.gapSeverity, GapSeverity.standard);

      final totals = GapLedgerTotals.fromEntries(
        ledger,
        doneFeatures: const {},
      );
      expect(totals.open, hasLength(2));
      expect(totals.contractGaps, 1);
      // Highest severity first: the contract gap leads the open list
      // even though it was appended second.
      expect(totals.open.first.feature, 'f2-contract');
      expect(totals.open.last.feature, 'f1-unit');
    });

    test(
      'pre-1007 ledger entries (no severity field) read as standard',
      () async {
        final ledgerDir = Directory(p.join(tmp.path, '.zfa', 'corpus'));
        await ledgerDir.create(recursive: true);
        await File(p.join(ledgerDir.path, 'gap-ledger.json')).writeAsString(
          jsonEncode([
            {
              'id': 'gap-001',
              'kind': 'gap',
              'at': '2026-09-01T00:00:00Z',
              'feature': 'f-legacy',
              'outcome': 'stopped',
              'expected_result': 'complete',
            },
          ]),
        );
        final store = GapLedgerStore(tmp.path);
        final ledger = await store.load();
        expect(ledger.single.gapSeverity, GapSeverity.standard);
        final totals = GapLedgerTotals.fromEntries(
          ledger,
          doneFeatures: const {},
        );
        expect(totals.contractGaps, 0);
      },
    );

    test(
      'a corpus run stopped at a blocked contract records the gap with '
      'the FULL contract behavior id, the step, and severity=contract '
      '(the colon in `contract:A1:verify-red` must not mangle the parse)',
      () async {
        final fx = await CorpusFixture.create();
        addTearDown(fx.dispose);
        await fx.writeManifest([
          (name: '004-login-ui', ready: true, reason: ''),
        ]);
        // Script the inner `zfa tdd run` to stop blocked at the contract
        // behavior: the summary line carries result=blocked + the
        // `contract:A1:verify-red` stopped_at (a behavior id that itself
        // contains a colon).
        await fx.writeFakeZfa(
          outcomes: {
            'run:004-login-ui': (
              exit: 1,
              stdout: const [
                'run: feature=004-login-ui result=blocked pending=0 red=0 '
                    'green=0 done=0 blocked=1 '
                    'stopped_at=contract:A1:verify-red',
              ],
            ),
          },
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'corpus',
          'run',
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeBin,
        ]);

        expect(out, contains('stopped at 004-login-ui (verify-red: blocked)'));
        expect(out, contains('contract-test failure (issue #1007)'));

        final ledger = await fx.readLedger();
        expect(ledger, hasLength(1));
        final gap = ledger.single as Map<String, dynamic>;
        // The behavior is the FULL contract id and the step is
        // verify-red — the LAST colon separates them; the first colon is
        // part of the id.
        expect(gap['behavior'], 'contract:A1');
        expect(gap['step'], 'verify-red');
        expect(gap['outcome'], 'blocked');
        expect(gap['severity'], 'contract');
        expect(gap['expected_result'], 'complete');
        // The summary line counts the contract gap on its own token.
        expect(out, contains('gaps=1 contract_gaps=1 result=stopped'));
      },
    );
  });
}
