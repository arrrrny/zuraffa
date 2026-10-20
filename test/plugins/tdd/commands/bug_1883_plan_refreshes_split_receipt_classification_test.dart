// Issue #1883 — a pre-existing split-receipt.json kept the PRIOR plan's
// classification map when `zfa tdd plan` refreshed it. After a
// declared-contract rename re-issued rows under fresh ids
// (`contract:A4` -> `contract:A19`), the receipt still named the old ids,
// and run-engine — which resolves the lane map from the receipt first —
// silently dropped the re-issued behaviors (37 -> 33) while `doctor`
// reported healthy.
//
// Behaviors (test-list):
//   B1 — plan with a stale receipt re-derives `classification` + `rows`
//        from the current plan: orphan ids are dropped, the re-issued
//        contract id is present, and the row count matches the map.
//   B2 — the split-time audit fields are re-derived with it: no stale
//        `classification_source` keys, current `golden_ids`/
//        `adaptive_slots`/`files`, zero engine flutter references.
//   B3 — unknown/custom receipt fields still survive the refresh.

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

## Layer Contracts

**Function**:
- `LoginValidator`: `validate(String) -> bool`

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
            traces: LoginValidator

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
    tmpDir = Directory.systemTemp.createTempSync('split_1883_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
    File(p.join(featureDir, 'spec.md')).writeAsStringSync(specWithLanes);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<String> plan() => CliRunner(
    exitOnCompletion: false,
  ).runCapturing(['tdd', 'plan', '--project', tmpDir.path, feature]);

  Map<String, dynamic> receipt() =>
      jsonDecode(File(p.join(tddDir, 'split-receipt.json')).readAsStringSync())
          as Map<String, dynamic>;

  void seedStaleReceipt() {
    final legacy = <String, dynamic>{
      'feature': feature,
      'source': 'tdd/test-list.md',
      'rows': 3,
      // The prior plan's map: an honored scenario id plus the old
      // contract id the rename removed and an id nothing declares.
      'classification': {'A1': 'CORE', 'contract:A4': 'CORE', 'A99': 'CORE'},
      'classification_source': {
        'A1': 'declared',
        'contract:A4': 'heuristic',
        'A99': 'heuristic',
      },
      'golden_ids': ['W9'],
      'adaptive_slots': ['tv'],
      'files': ['tdd/old-plan.md'],
      'engine_flutter_references': 7,
      'custom_marker': 'keep-me',
    };
    File(
      p.join(tddDir, 'split-receipt.json'),
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(legacy));
  }

  test(
    'B1: plan drops stale classification ids and keeps re-issued ones',
    () async {
      seedStaleReceipt();

      final out = await plan();
      expect(CliRunner.lastDispatchedExitCode, 0, reason: out);

      final loaded = receipt();
      final classification = loaded['classification'] as Map<String, dynamic>;
      expect(
        classification.containsKey('contract:A4'),
        isFalse,
        reason: 'the pre-rename contract id must not survive the refresh',
      );
      expect(
        classification.containsKey('A99'),
        isFalse,
        reason: 'an id no current plan row carries must not survive',
      );
      expect(
        classification.containsKey('contract:A1'),
        isTrue,
        reason:
            'the current `## Layer Contracts` method is re-issued as '
            'contract:A1',
      );
      expect(classification.containsKey('A1'), isTrue);
      expect(
        loaded['rows'],
        classification.length,
        reason: 'rows must count the re-derived map, not the stale plan',
      );
    },
  );

  test('B2: the split-time audit fields are re-derived too', () async {
    seedStaleReceipt();

    final out = await plan();
    expect(CliRunner.lastDispatchedExitCode, 0, reason: out);

    final loaded = receipt();
    final classification = loaded['classification'] as Map<String, dynamic>;
    final sources = loaded['classification_source'] as Map<String, dynamic>;
    expect(
      sources.keys.toSet(),
      classification.keys.toSet(),
      reason: 'the source map must describe exactly the fresh classification',
    );
    expect(
      sources.containsKey('contract:A4'),
      isFalse,
      reason: 'the source map must not name a removed id',
    );
    expect(
      loaded['golden_ids'],
      isEmpty,
      reason: 'the spec declares no golden ids',
    );
    expect(
      loaded['adaptive_slots'],
      isEmpty,
      reason: 'the spec declares no adaptive slots',
    );
    expect(
      loaded['engine_flutter_references'],
      0,
      reason: 'the engine plan is pure Dart by construction',
    );
    expect(loaded['files'], contains('tdd/04-ENGINE.md'));
    expect(loaded['files'], contains('tdd/04-SKIN.md'));
    expect(loaded['files'], contains('tdd/04-CONTRACT.md'));
    expect(
      loaded['files'],
      isNot(contains('tdd/old-plan.md')),
      reason: 'the file set must describe the artifacts this plan wrote',
    );
  });

  test('B3: unknown receipt fields still survive the refresh', () async {
    seedStaleReceipt();

    final out = await plan();
    expect(CliRunner.lastDispatchedExitCode, 0, reason: out);

    expect(receipt()['custom_marker'], 'keep-me');
  });
}
