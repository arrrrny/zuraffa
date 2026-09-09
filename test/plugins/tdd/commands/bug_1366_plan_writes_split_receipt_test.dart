// Issue #1366 — a committed tree can ship lane plans (the meta-index
// test-list) WITHOUT split-receipt.json: plan only refreshed a receipt
// that already existed, so the migration record was lost and the one-shot
// split guard refused forever. Plan now writes the receipt whenever it
// emits lane plans (`source: zfa tdd plan`) — the record can never be
// lost again (spec 1366-plan-writes-split-receipt).
//
// Behaviors (test-list):
//   B1 — plan without a pre-existing receipt writes split-receipt.json
//        carrying `source: zfa tdd plan` + the classification.
//   B2 — the written receipt satisfies the one-shot guard: a follow-up
//        plain `zfa tdd split` resolves (no lost-record refusal).
//   B3 — a PRE-EXISTING receipt is still refreshed (fields preserved,
//        spec hash updated) — the #1309 contract unchanged.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '004-login-ui';

const String specWithLanes = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A2]
    flutter_allowed: true
```
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('split_1366_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
    File(p.join(featureDir, 'spec.md')).writeAsStringSync(specWithLanes);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<String> plan() => CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'plan',
        '--project',
        tmpDir.path,
        feature,
      ]);

  Map<String, dynamic> receipt() => jsonDecode(
        File(p.join(tddDir, 'split-receipt.json')).readAsStringSync(),
      ) as Map<String, dynamic>;

  test('B1: plan without a receipt writes one (source: zfa tdd plan)',
      () async {
    expect(
      File(p.join(tddDir, 'split-receipt.json')).existsSync(),
      isFalse,
      reason: 'precondition: no migration record',
    );

    final out = await plan();
    expect(exitCode, 0, reason: out);

    final loaded = receipt();
    expect(loaded['source'], 'zfa tdd plan');
    expect(loaded['spec_hash'], isA<String>());
    expect(loaded['classification'], isA<Map>());
  });

  test('B2: the plan-written receipt satisfies the one-shot guard',
      () async {
    final planOut = await plan();
    expect(exitCode, 0, reason: planOut);

    // The guard that refused the committed fixture in the issue: a
    // meta-index without a receipt. With the plan-written receipt, a
    // plain split resolves honestly instead of dead-ending.
    final out = await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'split',
      '--project',
      tmpDir.path,
      feature,
    ]);
    expect(out, isNot(contains('the migration record was lost')));
    expect(out, isNot(contains('Null check operator')));
  });

  test('B3: a pre-existing receipt is refreshed, not clobbered', () async {
    final legacyReceipt = {
      'feature': feature,
      'source': 'tdd/test-list.md',
      'rows': 3,
      'classification': {'A1': 'CORE'},
      'custom_marker': 'keep-me',
    };
    File(p.join(tddDir, 'split-receipt.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(legacyReceipt),
    );

    final out = await plan();
    expect(exitCode, 0, reason: out);

    final loaded = receipt();
    expect(loaded['custom_marker'], 'keep-me',
        reason: 'pre-existing receipt fields are preserved by the merge');
    expect(loaded['refreshed_by'], 'zfa tdd plan');
    expect(loaded['spec_hash'], isA<String>());
  });
}
