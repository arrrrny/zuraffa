// Issue #1365 — `zfa tdd split --force` regresses 04-SKIN.md: the split
// path renders the PRE-1004 shape (no platform contract matrix, no state
// machine, no route table, no machine skin-contract JSON) while
// `zfa tdd plan` renders the full typed contract from the same spec's
// `## Skin Contract` section. Re-splitting a feature can silently break
// skin-contract binding (`parseSkinContractJson`, spec 079; runtime
// auditor spec 1102).
//
// Contract under test (spec 1365-split-skin-contract-parity):
//   B1 — split renders the typed contract sections + machine JSON from
//        the spec's `## Skin Contract` (parity with plan).
//   B2 — a malformed `## Skin Contract` section REFUSES the split
//        (exit 2, no lane plans written) — errors are an API.
//   B3 — a spec with no Skin Contract section renders the pre-1004
//        shape (guard).
//   B4 — the FORCED re-split keeps the full contract (the issue's
//        exact --force path).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '004-login-ui';

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

const String lanesSection = '''
## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, A3, U1, U2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A4]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
```
''';

const String skinContractSection = '''
## Skin Contract

```yaml
Skin Contract:
  adaptive_slots: [mobile, ios, android, macos]
  platform_overrides:
    ios:
      home_indicator_safe_area: required
    macos:
      title_bar_alignment: trailing
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
```
''';

const String specBase = '''
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
    tmpDir = Directory.systemTemp.createTempSync('split_1365_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seed({required String spec, String list = legacyList}) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
    await File(p.join(tddDir, 'test-list.md')).writeAsString(list);
  }

  Future<String> split({bool force = false}) async {
    final out = await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'split',
      if (force) '--force',
      '--project',
      tmpDir.path,
      feature,
    ]);
    return out;
  }

  String skinPlan() => File(p.join(tddDir, '04-SKIN.md')).readAsStringSync();

  test(
    'B1: split renders the typed skin contract sections + machine JSON',
    () async {
      await seed(spec: '$specBase\n$lanesSection\n$skinContractSection');
      final out = await split();
      expect(exitCode, 0, reason: out);

      final skin = skinPlan();
      expect(
        skin,
        contains('home_indicator_safe_area'),
        reason: 'the platform contract matrix survives the split',
      );
      expect(skin, contains('title_bar_alignment'));
      expect(
        skin,
        contains('initial'),
        reason: 'the state machine contract survives',
      );
      expect(
        skin,
        contains('deal_list'),
        reason: 'the route contract survives',
      );
      expect(
        skin,
        contains('adaptiveSlots'),
        reason: 'the machine-parseable skin contract JSON survives',
      );
    },
  );

  test('B2: a malformed Skin Contract section refuses the split', () async {
    await seed(
      spec:
          '$specBase\n$lanesSection\n'
          '## Skin Contract\n\n'
          '```yaml\nSkin Contract:\n  adaptive_slots: [broken\n```\n',
    );
    final out = await split();
    expect(exitCode, 2, reason: out);
    expect(out, contains('skin contract refused'));
    expect(
      File(p.join(tddDir, '04-SKIN.md')).existsSync(),
      isFalse,
      reason: 'no lane plans are written from a refused contract',
    );
  });

  test('B3: a spec with no Skin Contract section renders the pre-1004 '
      'shape', () async {
    await seed(spec: '$specBase\n$lanesSection');
    final out = await split();
    expect(exitCode, 0, reason: out);
    final skin = skinPlan();
    expect(skin, contains('# Skin Plan:'));
    expect(skin, isNot(contains('home_indicator_safe_area')));
  });

  test(
    'B6: a contract without declared Lanes refuses (plan/split agree)',
    () async {
      await seed(spec: '$specBase\n$skinContractSection');
      final out = await split();
      expect(exitCode, 2, reason: out);
      expect(out, contains('skin contract refused'));
      expect(out, contains('## Lanes'));
      expect(
        File(p.join(tddDir, '04-SKIN.md')).existsSync(),
        isFalse,
        reason: 'no lane plans from a contract the lanes cannot carry',
      );
    },
  );

  test('B4: the FORCED re-split keeps the full contract', () async {
    await seed(spec: '$specBase\n$lanesSection\n$skinContractSection');
    final first = await split();
    expect(exitCode, 0, reason: first);
    final out = await split(force: true);
    expect(exitCode, 0, reason: out);

    final skin = skinPlan();
    expect(
      skin,
      contains('home_indicator_safe_area'),
      reason:
          'the platform matrix survives the forced re-split '
          '(the issue #1365 regression)',
    );
    expect(
      skin,
      contains('adaptiveSlots'),
      reason: 'the machine JSON survives the forced re-split',
    );
  });
}
