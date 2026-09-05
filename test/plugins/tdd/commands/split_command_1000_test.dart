// Issue #1000: `zfa tdd split <feature>` — the one-shot migration that
// reads a feature's legacy single-file `tdd/test-list.md`, classifies
// every behavior row CORE or SKIN (the spec's `## Lanes` declaration
// winning over the kind heuristic: widget/theme rows are SKIN, the rest
// CORE), and emits the new plan pair — `04-ENGINE.md`, `04-SKIN.md`,
// `04-CONTRACT.md` — plus `tdd/split-receipt.json`, converting
// `test-list.md` into the meta-index. One-shot: an already-split feature
// is refused with a pointer to the receipt.
//
// RED phase: the command does not exist yet.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

const String feature = '004-login-ui';

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
| A2 | the error is reported to the caller | AC-2 | PENDING |
| A3 | the app navigates to deal_list | AC-3 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A4 | the login form renders the email and password fields | AC-4 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | validates the email format | FR-001 | PENDING |
| U2 | hashes the password | FR-002 | PENDING |
''';

/// The spec the legacy plan was planned from (no `## Lanes` — the
/// pre-lane grammar; split's kind heuristic classifies it).
const String legacySpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
3. **Given** a completed login **When** the session is active **Then** the app navigates to deal_list
4. **Given** the login screen **When** it loads **Then** the login form renders the email and password fields

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
- **FR-002**: The system shall hash the password with the credential hasher.
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('split_1000_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedLegacy({
    String spec = legacySpec,
    String list = legacyList,
  }) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
    await File(p.join(tddDir, 'test-list.md')).writeAsString(list);
  }

  List<String> splitArgs() => [
    'tdd',
    'split',
    '--project',
    tmpDir.path,
    feature,
  ];

  File laneFile(String name) => File(p.join(tddDir, name));

  group('issue #1000 — zfa tdd split (one-shot legacy migration)', () {
    test('split $feature produces 04-ENGINE.md, 04-SKIN.md, 04-CONTRACT.md '
        'and split-receipt.json from the old plan', () async {
      await seedLegacy();
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(splitArgs());
      expect(exitCode, 0, reason: out);

      expect(
        laneFile('04-ENGINE.md').existsSync(),
        isTrue,
        reason: 'engine plan emitted',
      );
      expect(
        laneFile('04-SKIN.md').existsSync(),
        isTrue,
        reason: 'skin plan emitted',
      );
      expect(
        laneFile('04-CONTRACT.md').existsSync(),
        isTrue,
        reason: 'contract emitted',
      );
      final receiptFile = laneFile('split-receipt.json');
      expect(receiptFile.existsSync(), isTrue, reason: 'receipt emitted');
    });

    test('widget rows classify SKIN, the rest CORE, and the receipt records '
        'every classification', () async {
      await seedLegacy();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);

      final engine = await laneFile('04-ENGINE.md').readAsString();
      final skin = await laneFile('04-SKIN.md').readAsString();

      // The widget row (A4) is skin; acceptance + unit rows are engine.
      expect(skin.contains('| A4 |'), isTrue, reason: 'widget row is skin');
      expect(engine.contains('| A4 |'), isFalse);
      for (final id in ['A1', 'A2', 'A3', 'U1', 'U2']) {
        expect(engine.contains('| $id |'), isTrue, reason: '$id is engine');
        expect(skin.contains('| $id |'), isFalse);
      }

      final receipt =
          jsonDecode(await laneFile('split-receipt.json').readAsString())
              as Map<String, dynamic>;
      expect(receipt['feature'], feature);
      final classification = receipt['classification'] as Map<String, dynamic>;
      expect(classification.length, 6, reason: 'every row classified');
      expect(classification['A4'], 'SKIN');
      expect(classification['A1'], 'CORE');
      expect(classification['A3'], 'CORE');
      expect(classification['U1'], 'CORE');
      expect(classification['U2'], 'CORE');
      expect(receipt['source'], contains('test-list.md'));
    });

    test('the old test-list.md becomes the meta-index and the rows still '
        'resolve through TestListReader', () async {
      await seedLegacy();
      await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
      expect(exitCode, 0);

      final meta = await laneFile('test-list.md').readAsString();
      expect(
        meta.toLowerCase().contains('meta-index'),
        isTrue,
        reason: 'the converted list identifies as the meta-index',
      );
      expect(
        meta.contains('| A1 |'),
        isFalse,
        reason: 'the behavior rows moved into the lane plans',
      );

      final rows = await TestListReader(featureDir).read();
      expect(
        rows.map((r) => r.id).toSet(),
        containsAll(['A1', 'A2', 'A3', 'A4', 'U1', 'U2']),
        reason: 'the reader resolves the split files transparently',
      );
    });

    test(
      'split is one-shot: a second run refuses naming the receipt',
      () async {
        await seedLegacy();
        await CliRunner(exitOnCompletion: false).runCapturing(splitArgs());
        expect(exitCode, 0);

        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(splitArgs());
        expect(exitCode, 1, reason: 'second run refuses');
        expect(
          out.contains('split-receipt.json'),
          isTrue,
          reason: 'the refusal points at the existing receipt',
        );
      },
    );

    test(
      "the spec's ## Lanes declarations win over the kind heuristic",
      () async {
        // A3 is an acceptance row (heuristic: CORE) but the spec's Lanes
        // section declares it BOTH — the declaration must win, placing
        // A3 in BOTH the engine and the skin plan.
        final spec =
            '''
$legacySpec

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1, U2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A4]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3]
    flutter_allowed: conditionally
```
''';
        await seedLegacy(spec: spec);
        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(splitArgs());
        expect(exitCode, 0, reason: out);

        final engine = await laneFile('04-ENGINE.md').readAsString();
        final skin = await laneFile('04-SKIN.md').readAsString();
        expect(
          engine.contains('| A3 |'),
          isTrue,
          reason: 'BOTH behavior appears in the engine plan',
        );
        expect(
          skin.contains('| A3 |'),
          isTrue,
          reason: 'BOTH behavior appears in the skin plan',
        );
        final receipt =
            jsonDecode(await laneFile('split-receipt.json').readAsString())
                as Map<String, dynamic>;
        expect(receipt['classification']['A3'], 'BOTH');

        // The declared adaptive slots land in the skin plan + contract.
        for (final slot in ['mobile', 'ios', 'android', 'macos']) {
          expect(skin.contains(slot), isTrue, reason: 'slot $slot in skin');
        }
      },
    );

    test(
      'a feature with no legacy plan refuses honestly (nothing to split)',
      () async {
        await File(p.join(featureDir, 'spec.md')).writeAsString(legacySpec);
        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(splitArgs());
        expect(exitCode, 1, reason: 'nothing to split');
        expect(
          out.contains('test-list.md'),
          isTrue,
          reason: 'the refusal names the missing plan',
        );
      },
    );
  });
}
