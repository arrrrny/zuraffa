// Issue #1884: `zfa tdd split --force` re-splits an already-split
// feature by reading its own prior `04-ENGINE.md`. The declaration
// sections (Key entities / External dependencies / Layer contracts /
// Routing provenance) must survive that re-split even when `spec.md` no
// longer declares them — the prior engine plan is the source of record
// for a re-split.
//
// RED phase (review of PR #1914): layer contracts written by the engine
// renderer as `### <layer>` were unreadable by the spec grammar
// (`**<layer>**:`), so contracts that only lived in the prior engine
// plan were silently dropped on `--force`. The provenance scrape was
// also unscoped and not fence-aware, and a malformed Key Entities cell
// was written without the anomaly warning `zfa tdd plan` prints.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '1884-fixture';

const String fixtureSpec = '''
**Template Version**: `zuraffa-1.0`

## Key entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Session | `token: String`, `user: String` | the authenticated session |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| ---------- | ---- | -------- | ------------- |
| AuthApi | http | `login(String) -> Session` | high |

## Layer Contracts

**Function**:
- `LoginValidator`: `validate(String) -> bool`
- `CredentialHasher`: `hash(String) -> String`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** the login screen **When** it loads **Then** the login form renders the email and password fields

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
  traces: LoginValidator
- **FR-002**: The system shall hash the password with the credential hasher.
  traces: CredentialHasher
''';

const String legacyList =
    '''
# Test List: $feature

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the session starts with the authenticated user | AC-1 | PENDING |
| A2 | the login form renders the email and password fields | AC-2 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | validates the email format | FR-001 | PENDING |
| U2 | hashes the password | FR-002 | PENDING |

## Routing provenance

route: A1 -> core lane [declared]
route: U1 -> core lane [declared]
''';

/// The spec AFTER the first split, with every declaration section
/// removed — the shape a re-split must tolerate. Its
/// `## Routing provenance` section carries a fenced `route:` sample
/// documenting the CLI; that is documentation, not a routing decision.
const String specWithoutDeclarations = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** the login screen **When** it loads **Then** the login form renders the email and password fields

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
  traces: LoginValidator
- **FR-002**: The system shall hash the password with the credential hasher.
  traces: CredentialHasher

## Routing provenance

```text
route: A1 -> fake lane [documentation sample]
```
''';

/// A spec whose Key Entities cell shows a swallowed second pair —
/// `zfa tdd plan` warns about this row (issue #1486); split must too.
const String specWithMalformedEntityCell = '''
**Template Version**: `zuraffa-1.0`

## Key entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Broken | id: String; title: String | a row that drops a pair |

## Acceptance Scenarios

1. **Given** anything **When** it happens **Then** the session starts with the authenticated user

## Functional Requirements

- **FR-001**: The system shall validate the email format.
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('issue_1884_');
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

  File engineFile() => File(p.join(tddDir, '04-ENGINE.md'));

  Future<String> split({bool force = false}) async {
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(splitArgs(force: force));
    expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
    return out;
  }

  group('issue #1884 — split --force preserves the engine declaration '
      'sections', () {
    test('the first split carries every spec declaration section into '
        '04-ENGINE.md', () async {
      await seed();
      await split();

      final engine = await engineFile().readAsString();
      expect(engine, contains('## Key entities'));
      expect(engine, contains('| Session |'));
      expect(engine, contains('## External dependencies'));
      expect(engine, contains('| AuthApi |'));
      expect(engine, contains('## Layer contracts'));
      expect(engine, contains('### Function'));
      expect(
        engine,
        contains('- `LoginValidator`: `validate(String) -> bool`'),
      );
      expect(engine, contains('## Routing provenance'));
      expect(engine, contains('route: A1 -> core lane [declared]'));
    });

    test('--force re-split keeps declarations that only live in the prior '
        'engine plan', () async {
      await seed();
      await split();
      expect(engineFile().readAsStringSync(), contains('| Session |'));

      // The spec no longer declares Key entities / External dependencies /
      // Layer contracts: the prior engine plan is their only source.
      await File(
        p.join(featureDir, 'spec.md'),
      ).writeAsString(specWithoutDeclarations);

      await split(force: true);
      final engine = await engineFile().readAsString();

      expect(
        engine,
        contains('## Key entities'),
        reason: 'the entity section survives the re-split',
      );
      expect(engine, contains('| Session |'));
      expect(
        engine,
        contains('## External dependencies'),
        reason: 'the dependency section survives the re-split',
      );
      expect(engine, contains('| AuthApi |'));
      expect(
        engine,
        contains('## Layer contracts'),
        reason: 'the layer-contract section survives the re-split',
      );
      expect(
        engine,
        contains('### Function'),
        reason: 'the plan-shaped `### <layer>` label is re-read',
      );
      expect(
        engine,
        contains('- `LoginValidator`: `validate(String) -> bool`'),
      );
      expect(
        engine,
        contains('- `CredentialHasher`: `hash(String) -> String`'),
      );
      expect(
        engine,
        contains('## Routing provenance'),
        reason: 'the provenance section survives the re-split',
      );
      expect(engine, contains('route: A1 -> core lane [declared]'));
      expect(engine, contains('route: U1 -> core lane [declared]'));
      expect(
        engine,
        isNot(contains('fake lane')),
        reason: 'a fenced `route:` sample in spec.md is not a decision',
      );
      expect(engine, contains('| A1 |'), reason: 'behavior rows survive');
      expect(engine, contains('| U1 |'), reason: 'behavior rows survive');
    });

    test('a malformed Key Entities cell is reported, matching plan', () async {
      await seed(spec: specWithMalformedEntityCell);
      final out = await split();

      expect(
        out,
        contains('Key Entities row `Broken`'),
        reason:
            'the dropped field pair is named instead of silently lost: '
            '$out',
      );
      expect(out, contains('issue #1486'));
    });
  });
}
