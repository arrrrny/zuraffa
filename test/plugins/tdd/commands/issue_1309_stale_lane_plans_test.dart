// Issue #1309: stale lane plans after a spec edit. A feature split via
// `zfa tdd split` carries `tdd/split-receipt.json`; when the spec no
// longer declares `## Lanes`, `zfa tdd plan` used to rewrite only
// `tdd/test-list.md` (demoting the meta-index) and leave the lane plans
// (04-ENGINE.md / 04-SKIN.md / 04-CONTRACT.md) stale — ghost behaviors
// (deleted FRs) kept running and new FRs were missed — while `zfa tdd
// split` refused with "already split". The two commands' guidance
// deadlocked.
//
// The contract under test:
// 1. the split receipt records `spec_hash` + `spec_mtime`;
// 2. `zfa tdd plan` regenerates the lane plans from the current
//    behavior set whenever a receipt exists (the split kind heuristic:
//    widget/theme rows are SKIN, the rest CORE), reports the stale
//    split when the spec changed since the receipt, and refreshes the
//    receipt so the detection fires only on the next real change;
// 3. `zfa tdd split --force` re-splits over an existing receipt and the
//    plain refusal names the actual remedy;
// 4. features never split, and features whose specs declare
//    `## Lanes`, keep their existing plan flows untouched.
//
// RED phase: the receipt carries no spec hash, plan has no staleness
// detection, and split has no --force flag.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

const String feature = '1309-fixture';

/// A zuraffa-1.0 spec with NO `## Lanes` — the shape `zfa tdd split`
/// migrates from. Scenario 2's prose carries UI intent ("renders"), so
/// plan re-derives it widget-kind (the SKIN heuristic lane).
const String fixtureSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** the login screen **When** it loads **Then** the login form renders the email and password fields
3. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
- **FR-002**: The system shall hash the password with the credential hasher.
''';

/// The spec with a third functional requirement (the post-split edit
/// whose behavior must appear in the regenerated lane plans).
const String editedSpecAddsFr = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** the login screen **When** it loads **Then** the login form renders the email and password fields
3. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
- **FR-002**: The system shall hash the password with the credential hasher.
- **FR-003**: The system shall rate-limit repeated failures through the login throttler.
''';

/// The spec with FR-002 deleted (the post-split edit whose ghost row
/// must disappear from the lane plans).
const String editedSpecDropsFr = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** the login screen **When** it loads **Then** the login form renders the email and password fields
3. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
''';

/// A legacy plan: acceptance + widget + unit rows in the single-file
/// shape `zfa tdd plan` wrote before the lane grammar.
const String legacyList =
    '''
# Test List: $feature

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the session starts with the authenticated user | AC-1 | PENDING |
| A3 | the error is reported to the caller | AC-3 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A2 | the login form renders the email and password fields | AC-2 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | validates the email format | FR-001 | PENDING |
| U2 | hashes the password | FR-002 | PENDING |
''';

/// A spec declaring `## Lanes` — the backward-compat shape plan's
/// existing lane path owns.
const String lanesSpec =
    '''
$fixtureSpec

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A3, U1, U2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A2]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
```
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('issue_1309_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seed({
    String spec = fixtureSpec,
    String list = legacyList,
  }) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
    await File(p.join(tddDir, 'test-list.md')).writeAsString(list);
  }

  List<String> splitArgs({bool force = false}) => [
    'tdd',
    'split',
    '--project',
    tmpDir.path,
    if (force) '--force',
    feature,
  ];

  List<String> planArgs() => [
    'tdd',
    'plan',
    '--project',
    tmpDir.path,
    '--no-emit-markers',
    feature,
  ];

  File laneFile(String name) => File(p.join(tddDir, name));
  File receiptFile() => laneFile('split-receipt.json');
  File specFile() => File(p.join(featureDir, 'spec.md'));

  Future<Map<String, dynamic>> receiptJson() async =>
      jsonDecode(await receiptFile().readAsString()) as Map<String, dynamic>;

  group('issue #1309 — split receipt format', () {
    test(
      'the receipt records spec_hash and spec_mtime at split time',
      () async {
        await seed();
        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(splitArgs());
        expect(exitCode, 0, reason: out);

        final receipt = await receiptJson();
        final specContent = await specFile().readAsString();
        expect(
          receipt['spec_hash'],
          sha256.convert(utf8.encode(specContent)).toString(),
          reason: 'the receipt records the sha256 of the spec content',
        );
        expect(
          receipt['spec_mtime'],
          isNotNull,
          reason: 'the receipt records the spec mtime',
        );
        // The recorded mtime is a parseable ISO-8601 timestamp at (or
        // after) the spec's own mtime minus clock granularity.
        final recorded = DateTime.parse(receipt['spec_mtime'] as String);
        final actual = await specFile().lastModified();
        expect(
          recorded.isBefore(actual.add(const Duration(minutes: 1))),
          isTrue,
          reason: 'spec_mtime is a real timestamp, not a sentinel',
        );
      },
    );
  });

  group('issue #1309 — zfa tdd split refusal names the remedy', () {
    test(
      'an already-split feature is refused naming --force and plan',
      () async {
        await seed();
        await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
        expect(exitCode, 0);

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(splitArgs());
        expect(exitCode, 1, reason: 'the one-shot guard still refuses');
        expect(
          out.contains('--force'),
          isTrue,
          reason: 'the refusal names the --force re-split remedy',
        );
        expect(
          out.contains('zfa tdd plan'),
          isTrue,
          reason: 'the refusal names the plan refresh remedy',
        );
      },
    );

    test('--force re-splits over the existing receipt', () async {
      await seed();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);
      final firstSplitAt = (await receiptJson())['split_at'];

      // Hand-corrupt the contract plan (a non-row-source artifact):
      // --force must overwrite it alongside the lane plans.
      await laneFile('04-CONTRACT.md').writeAsString('# corrupted\n');
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(splitArgs(force: true));
      expect(exitCode, 0, reason: out);

      final engine = await laneFile('04-ENGINE.md').readAsString();
      expect(
        engine.contains('corrupted'),
        isFalse,
        reason: 'the old lane plans were overwritten',
      );
      expect(
        laneFile('04-CONTRACT.md').readAsStringSync().contains('corrupted'),
        isFalse,
        reason: 'the contract plan was overwritten',
      );
      expect(engine.contains('| U1 |'), isTrue, reason: 'rows re-derived');
      final receipt = await receiptJson();
      expect(
        receipt['split_at'],
        isNot(firstSplitAt),
        reason: 'a fresh receipt was written',
      );
      expect(
        receipt['spec_hash'],
        isNotNull,
        reason: 'the fresh receipt carries the spec hash',
      );
    });
  });

  group('issue #1309 — plan regenerates stale lane plans', () {
    test('a spec edit after the split is reported stale and the new FR '
        'appears in the regenerated engine plan', () async {
      await seed();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);
      expect(
        laneFile('04-ENGINE.md').readAsStringSync().contains('| U3 |'),
        isFalse,
        reason: 'pre-condition: U3 does not exist yet',
      );

      await specFile().writeAsString(editedSpecAddsFr);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);

      expect(
        out.toLowerCase().contains('stale'),
        isTrue,
        reason: 'plan reports the stale split: $out',
      );
      final engine = await laneFile('04-ENGINE.md').readAsString();
      expect(
        engine.contains('| U3 |'),
        isTrue,
        reason: 'the new FR behavior appears in the engine plan',
      );
      expect(
        engine.contains('| U1 |'),
        isTrue,
        reason: 'the existing behaviors are preserved',
      );
      final meta = await laneFile('test-list.md').readAsString();
      expect(
        meta.contains('## Lane split'),
        isTrue,
        reason: 'the meta-index is preserved (not demoted to a legacy list)',
      );

      final receipt = await receiptJson();
      expect(
        receipt['refreshed_at'],
        isNotNull,
        reason: 'plan refreshes the receipt audit trail',
      );
      expect(receipt['refreshed_by'], 'zfa tdd plan');
    });

    test('a deleted FR leaves no ghost row in any lane plan file', () async {
      await seed();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);
      expect(
        laneFile('04-ENGINE.md').readAsStringSync().contains('| U2 |'),
        isTrue,
        reason: 'pre-condition: U2 was split into the engine plan',
      );

      await specFile().writeAsString(editedSpecDropsFr);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);

      for (final name in ['04-ENGINE.md', '04-SKIN.md', '04-CONTRACT.md']) {
        expect(
          laneFile(name).readAsStringSync().contains('| U2 |'),
          isFalse,
          reason: 'the ghost row is gone from $name',
        );
      }
      final rows = await TestListReader(featureDir).read();
      expect(
        rows.map((r) => r.id),
        isNot(contains('U2')),
        reason: 'the shared reader resolves the current set only',
      );
      expect(
        rows.map((r) => r.id),
        containsAll(['A1', 'A2', 'A3', 'U1']),
        reason: 'the current behaviors still resolve',
      );
    });

    test('an unchanged spec is not reported stale but the lane plans '
        'still regenerate (meta-index preserved)', () async {
      await seed();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);

      // Hand-corrupt the engine plan: the refresh must rewrite it even
      // without a spec edit.
      await laneFile('04-ENGINE.md').writeAsString('# corrupted\n');
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);

      expect(
        out.toLowerCase().contains('stale'),
        isFalse,
        reason: 'no staleness is reported for an unchanged spec',
      );
      final engine = await laneFile('04-ENGINE.md').readAsString();
      expect(
        engine.contains('| U1 |'),
        isTrue,
        reason: 'the lane plans regenerated from the current behavior set',
      );
      expect(
        laneFile('test-list.md').readAsStringSync().contains('## Lane split'),
        isTrue,
        reason: 'the meta-index is preserved',
      );
    });

    test(
      'the lane plan mtimes are at least the spec mtime after plan',
      () async {
        await seed();
        await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
        expect(exitCode, 0);

        // Simulate a post-split edit AND back-date the spec so its mtime
        // is unambiguously older than anything plan writes next.
        await specFile().writeAsString(editedSpecAddsFr);
        await specFile().setLastModified(
          DateTime.now().subtract(const Duration(seconds: 30)),
        );

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(planArgs());
        expect(exitCode, 0, reason: out);

        final specMtime = await specFile().lastModified();
        for (final name in ['04-ENGINE.md', '04-SKIN.md', '04-CONTRACT.md']) {
          final laneMtime = await laneFile(name).lastModified();
          expect(
            laneMtime.isBefore(specMtime),
            isFalse,
            reason: '$name mtime ($laneMtime) >= spec mtime ($specMtime)',
          );
        }
      },
    );

    test('a legacy receipt without spec_hash falls back to the mtime '
        'comparison', () async {
      await seed();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);

      // Downgrade the receipt to the pre-#1309 shape (no spec_hash /
      // spec_mtime) and make the spec unambiguously newer than split_at.
      final receipt = await receiptJson()
        ..remove('spec_hash')
        ..remove('spec_mtime');
      final splitAt = DateTime.parse(receipt['split_at'] as String);
      await receiptFile().writeAsString(
        const JsonEncoder.withIndent('  ').convert(receipt),
      );
      await specFile().writeAsString(editedSpecAddsFr);
      // The mtime fallback compares the spec mtime against the receipt's
      // split_at — date the spec AFTER the split unambiguously (the
      // ordering against the lane writes is not asserted here).
      await specFile().setLastModified(splitAt.add(const Duration(hours: 1)));

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);

      expect(
        out.toLowerCase().contains('stale'),
        isTrue,
        reason: 'the mtime fallback still detects the stale split: $out',
      );
      expect(
        laneFile('04-ENGINE.md').readAsStringSync().contains('| U3 |'),
        isTrue,
        reason: 'the lane plans regenerated',
      );
    });

    test('the receipt refresh stops the stale report from re-firing', () async {
      await seed();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);
      await specFile().writeAsString(editedSpecAddsFr);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
      expect(exitCode, 0);

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);
      expect(
        out.toLowerCase().contains('stale'),
        isFalse,
        reason:
            'the refreshed receipt records the current spec state — the '
            'detection fires only on the NEXT change: $out',
      );
    });
  });

  group('issue #1309 — backward compatibility', () {
    test('a never-split feature plans the legacy single-file list with '
        'no lane files', () async {
      await seed();
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);

      final list = await laneFile('test-list.md').readAsString();
      expect(list.contains('| A1 |'), isTrue, reason: 'single-file rows');
      expect(list.contains('## Lane split'), isFalse);
      for (final name in [
        '04-ENGINE.md',
        '04-SKIN.md',
        '04-CONTRACT.md',
        'split-receipt.json',
      ]) {
        expect(
          laneFile(name).existsSync(),
          isFalse,
          reason: 'no lane artifacts for a never-split feature: $name',
        );
      }
    });

    test('a receipt-bearing feature whose spec declares ## Lanes plans '
        'through the declared lane path without a stale report', () async {
      await seed(spec: lanesSpec);
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);

      expect(
        out.toLowerCase().contains('stale'),
        isFalse,
        reason: 'the declared lane path owns this feature',
      );
      final engine = await laneFile('04-ENGINE.md').readAsString();
      final skin = await laneFile('04-SKIN.md').readAsString();
      expect(engine.contains('| A1 |'), isTrue, reason: 'CORE declared');
      expect(skin.contains('| A2 |'), isTrue, reason: 'SKIN declared');
      expect(
        skin.contains('mobile'),
        isTrue,
        reason: 'the declared adaptive slots ride the skin plan',
      );
    });
  });
}
