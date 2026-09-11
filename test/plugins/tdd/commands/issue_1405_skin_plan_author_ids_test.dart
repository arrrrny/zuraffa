// Issue #1405 — the skin plan author emits strict `^W\d+$` ids; the plan
// validator rejects malformed ids at plan time (no artifacts).
//
// RED phase (against the unfixed tree): the malformed declaration plans
// green with prose in the id column (the bug), the sanitizable token
// leaks `W1 (renders the login screen pixel-perfect` into the id column,
// and the no-pattern prose fragments are ingested as behavior ids —
// every row below fails before the fix lands (recorded red evidence).
//
// Rows trace to specs/1405-skin-plan-author-ids/tdd/test-list.md.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/lane_plans.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

const String feature = '004-login-ui';

/// The base spec body: two acceptance scenarios (deriving A1, A2) and one
/// functional requirement (deriving U1) — everything the lane fixtures
/// below declare.
String specWithLanes(String skinBehaviors, {String coreBehaviors = 'A1, A2'}) =>
    '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller

## Functional Requirements

- **FR-001**: The system shall hash the password with the credential hasher.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [$coreBehaviors, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [$skinBehaviors]
    flutter_allowed: true
```
''';

/// The issue's malformed declaration (issue #1405 verbatim shape): the
/// author LLM split behavior sentences mid-fragment across tokens and
/// leaked prose into the id column.
const String malformedSkinBehaviors =
    'Sign In header and subtitle, W1 (renders the login screen pixel-perfect, '
    'W2, a full-width guest outline button, an or divider';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('issue_1405_skin_plan_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec(String spec) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  }

  /// Seed [spec] and run `zfa tdd plan`; returns the captured CLI output
  /// (stdout+stderr) so refusal-text rows can pin the validator's
  /// diagnosis contract.
  Future<String> plan(String spec) async {
    await seedSpec(spec);
    return CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'plan', '--project', tmpDir.path, feature]);
  }

  File laneFile(String name) => File(p.join(tddDir, name));

  group('A-1405-1 — strict W-id emission (FR-001, FR-002)', () {
    test('a leading-id token with leaked prose plans W1 with the prose in '
        'the behavior column', () async {
      await plan(
        specWithLanes('W1 (renders the login screen pixel-perfect, W2'),
      );
      expect(exitCode, 0, reason: 'the sanitizable declaration plans green');
      final skin = await laneFile('04-SKIN.md').readAsString();
      expect(
        skin,
        contains('| W1 | renders the login screen pixel-perfect |'),
        reason: 'the prose lands in the behavior column, never the id column',
      );
      expect(
        skin.contains('W1 (renders the login screen pixel-perfect'),
        isFalse,
        reason: 'no truncated mid-sentence id in the emitted table',
      );
      expect(skin, contains('| W2 | skin behavior declared in `## Lanes` |'));
    });

    test('a bare-prose token after a leading W-id also sanitizes', () async {
      await plan(specWithLanes('W1 renders the login screen, W2'));
      expect(exitCode, 0);
      final skin = await laneFile('04-SKIN.md').readAsString();
      expect(skin, contains('| W1 | renders the login screen |'));
      expect(skin.contains('| W1 renders the login screen |'), isFalse);
    });
  });

  group('A-1405-2 — the plan validator rejects malformed ids at plan time '
      '(FR-003, FR-004)', () {
    test('the issue\'s malformed declaration refuses exit 2 naming the '
        'no-pattern token, and writes NO 04-SKIN.md', () async {
      final out = await plan(specWithLanes(malformedSkinBehaviors));
      expect(exitCode, 2, reason: 'the malformed table is never ingested');
      expect(
        laneFile('04-SKIN.md').existsSync(),
        isFalse,
        reason: 'no artifacts on refusal — the malformed plan never lands',
      );
      expect(
        laneFile('04-ENGINE.md').existsSync(),
        isFalse,
        reason: 'an incomplete split never leaves a half-written lane plan',
      );
      expect(out, contains('lane contract FAILED'));
      expect(out, contains('Sign In header and subtitle'));
      expect(out, contains('--> fix:'));
    });

    test('the refusal names each prose fragment with the fix line', () async {
      final out = await plan(
        specWithLanes('Sign In header and subtitle, an or divider, W2'),
      );
      expect(exitCode, 2);
      expect(laneFile('04-SKIN.md').existsSync(), isFalse);
      expect(out, contains('Sign In header and subtitle'));
      expect(out, contains('an or divider'));
    });

    test('a prose fragment wedged between clean ids still refuses the '
        'whole plan', () async {
      await plan(specWithLanes('W1, a full-width guest outline button, W2'));
      expect(exitCode, 2);
      expect(laneFile('04-SKIN.md').existsSync(), isFalse);
    });
  });

  group('A-1405-3 — status reflects the actual W-id count (FR-005)', () {
    test('clean W1-W9 plans nine strict W rows the reader resolves as nine '
        'skin behaviors', () async {
      await plan(specWithLanes('W1-W9', coreBehaviors: 'A1, A2'));
      expect(exitCode, 0);
      final skin = await laneFile('04-SKIN.md').readAsString();
      final wRows = RegExp(
        r'^\| (W\d+) \|',
        multiLine: true,
      ).allMatches(skin).map((m) => m.group(1)!).toSet();
      expect(wRows, hasLength(9), reason: 'one row per W-behavior');
      for (var i = 1; i <= 9; i++) {
        expect(wRows, contains('W$i'));
      }
      // The machine-reachable count: what gen/run (and hence the journal
      // status totals) resolve from the lane plans.
      final rows = await TestListReader(featureDir).read();
      final lanes = await LanePlanReader(featureDir).resolve(rows);
      final skinWIds = lanes.skinIds.where(
        (id) => RegExp(r'^W\d+$').hasMatch(id),
      );
      expect(skinWIds, hasLength(9), reason: 'the W-id count, not 1');
    });
  });

  group('A-1405-4 / U-1405-6 — backward compatibility (FR-005, FR-006)', () {
    test(
      'the canonical #1000 lane fixture still plans exit 0 unchanged',
      () async {
        await plan('''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
3. **Given** a completed login **When** the session is active **Then** the app navigates to deal_list

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
- **FR-002**: The system shall hash the password with the credential hasher.
- **FR-003**: The system shall start a session and persist the auth token through the session repository.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1-U3]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1-W4]
    flutter_allowed: true
  - lane: BOTH
    behaviors: [A3 (acceptance: navigates to deal_list)]
    flutter_allowed: conditionally
```
''');
        expect(exitCode, 0, reason: 'clean ids keep planning green');
        final skin = await laneFile('04-SKIN.md').readAsString();
        expect(skin, contains('| W1 |'));
        expect(skin, contains('| W2 |'));
        expect(skin, contains('| W3 |'));
        expect(skin, contains('| W4 |'));
        // The BOTH seam's spec-derived acceptance row still renders in the
        // skin plan — the validator never tightens non-W grammar.
        expect(skin, contains('| A3 |'));
      },
    );

    test(
      'CORE annotations keep their documented behavior column form',
      () async {
        await plan('''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user

## Functional Requirements

- **FR-001**: The system shall hash the password with the credential hasher.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1, U9 (a hand-declared engine unit slot)]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
```
''');
        expect(exitCode, 0);
        final engine = await laneFile('04-ENGINE.md').readAsString();
        expect(
          engine,
          contains('| U9 | a hand-declared engine unit slot |'),
          reason:
              'CORE annotation prose stays in the behavior column, '
              'byte-identical to the pre-fix path',
        );
      },
    );
  });
}
