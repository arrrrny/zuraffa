// Issue #1007 ([VISION] Contract tests as first-class zfa tdd test kind):
// `zfa tdd plan` derives one `contract:<id>` row per method declared in the
// spec's `## Layer Contracts` section — `contract:A1` is an entity method
// contract (the exit criterion's example) — renders them under
// `## Contract loop:`, and the shared `TestListReader` resolves the rows
// as the new `contract` kind.
//
// RED phase: plan knows nothing about contract rows — the assertions fail.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

const String feature = '004-login-ui';

/// The canonical 004-login-ui spec carrying a Layer Contracts section: a
/// `Session` entity contract (the entity-method surface), a
/// `LoginController` controller, and a `LoginUseCase` usecase.
const String contractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
3. **Given** a completed login **When** the session is active **Then** the app navigates to deal_list

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
- **FR-002**: The system shall hash the password with the credential hasher.
- **FR-003**: The system shall start a session and persist the auth token through the session repository.

## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Session | `token: String` | the authenticated session |

## Layer Contracts

**Domain**:

- `Session`: `start(token) -> Result<void>`, `isExpired() -> bool`

**Presentation**:

- `LoginController`: `submit(form) -> Result<Session, AuthFailure>`

**UseCases**:

- `LoginUseCase`: `execute(credentials) -> Result<Session, AuthFailure>`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1, U2, U3]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1-W2]
    flutter_allowed: true
  - lane: BOTH
    behaviors: [A3 (acceptance: navigates to deal_list)]
    flutter_allowed: conditionally
```
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plan_contract_1007_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<void> seedSpec(String spec) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  }

  List<String> planArgs() => ['tdd', 'plan', '--project', tmpDir.path, feature];

  test('plan emits contract:A1 (entity method contract) in the engine plan '
      '(issue #1007 exit criterion)', () async {
    await seedSpec(contractSpec);
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(planArgs());
    expect(exitCode, 0, reason: out);

    final engine = await File(p.join(tddDir, '04-ENGINE.md')).readAsString();
    // contract:A1 — the first ENTITY method contract (Session.start).
    expect(
      engine.contains('| contract:A1 |'),
      isTrue,
      reason: 'engine plan must carry the contract:A1 row',
    );
    // One contract row per declared method: Session.start (contract:A1),
    // Session.isExpired (contract:A2), LoginController.submit
    // (contract:C1), LoginUseCase.execute (contract:U1).
    expect(engine.contains('| contract:A2 |'), isTrue);
    expect(engine.contains('| contract:C1 |'), isTrue);
    expect(engine.contains('| contract:U1 |'), isTrue);
    // The contract loop section identifies itself.
    expect(
      engine.toLowerCase().contains('## contract loop'),
      isTrue,
      reason: 'the contract rows render under their own section',
    );
  });

  test('plan without Layer Contracts plans contract-free (additive hard '
      'constraint)', () async {
    // Remove ONLY the Layer Contracts block (keep the lanes split).
    final noContracts = contractSpec.replaceFirst(
      RegExp(r'## Layer Contracts[\s\S]*?(?=## Lanes)'),
      '',
    );
    await seedSpec(noContracts);
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(planArgs());
    expect(exitCode, 0, reason: out);
    final engine = await File(p.join(tddDir, '04-ENGINE.md')).readAsString();
    expect(engine.contains('contract:'), isFalse);
    expect(engine.contains('## Contract loop'), isFalse);
  });

  test(
    'legacy single-file plan (no lanes) also carries the contract rows',
    () async {
      final legacy = contractSpec.substring(
        0,
        contractSpec.indexOf('## Lanes'),
      );
      await seedSpec(legacy);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);
      final list = await File(p.join(tddDir, 'test-list.md')).readAsString();
      expect(list.contains('| contract:A1 |'), isTrue);
      expect(list.toLowerCase().contains('## contract loop'), isTrue);
    },
  );

  test(
    'TestListReader resolves contract rows with BehaviorKind.contract',
    () async {
      await seedSpec(contractSpec);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
      expect(exitCode, 0);

      final rows = await TestListReader(featureDir).read();
      final byId = {for (final row in rows) row.id: row};
      expect(
        byId.keys,
        containsAll([
          'contract:A1',
          'contract:A2',
          'contract:C1',
          'contract:U1',
        ]),
      );
      expect(
        byId['contract:A1']?.kind,
        BehaviorKind.contract,
        reason: 'the contract loop section sets the contract kind',
      );
      // The traces carry the declared interface + method.
      expect(
        byId['contract:A1']?.traces,
        contains('Session'),
        reason: 'the contract row traces to the declared interface',
      );
      // Re-planning preserves rows: the ids reconcile, state survives.
    },
  );

  test('contract rows survive re-planning with their state', () async {
    await seedSpec(contractSpec);
    await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
    expect(exitCode, 0);
    // Hand-advance one contract row (the implementer satisfied the case).
    final engineFile = File(p.join(tddDir, '04-ENGINE.md'));
    final engine = await engineFile.readAsString();
    await engineFile.writeAsString(
      engine.replaceFirstMapped(
        RegExp(r'^\| contract:A1 \|[^\n]*\| PENDING \|$', multiLine: true),
        (m) => m[0]!.replaceFirst('PENDING', 'GREEN'),
      ),
    );
    await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
    expect(exitCode, 0);
    final reEngine = await engineFile.readAsString();
    expect(
      RegExp(
        r'^\| contract:A1 \|[^\n]*\| GREEN \|$',
        multiLine: true,
      ).hasMatch(reEngine),
      isTrue,
      reason: 'a progressed contract row is never reset to PENDING',
    );
  });
}
