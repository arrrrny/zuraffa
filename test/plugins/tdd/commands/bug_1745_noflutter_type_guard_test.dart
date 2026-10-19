// Bug #1745 — the noFlutter guard was a bare `package:flutter` substring
// test. A CORE plan could therefore declare Flutter TYPES (`Widget`,
// `IconData`, ...) in its `### Key Entities` fields and in its
// `## Layer Contracts` signatures, and plan cleanly; and a contract
// derived from the `**Presentation**` layer silently defaulted to CORE,
// emitting a presentation artifact into 04-ENGINE.md — the file whose
// own header says the engine lane is "pure Dart by construction".
//
// Contract under test:
// 1. A Key Entity field typed with a Flutter type refuses when the lane
//    split writes it into 04-ENGINE.md — the refusal names the entity
//    and the offending type.
// 2. A Layer Contract signature carrying a Flutter type refuses — the
//    refusal names the declared interface/method and the type.
// 3. A contract derived from the `**Presentation**` layer does NOT
//    default to CORE: with no `## Lanes` declaration for its id, plan
//    refuses (no silent default — the lane model's own rule). Declaring
//    the contract id in the CORE lane row is the author's explicit
//    routing and plans cleanly, with the row in 04-ENGINE.md.
// 4. A refused plan writes no lane artifact (an incomplete split never
//    leaves a half-written plan).
//
// The exit code is read from `CliRunner.lastDispatchedExitCode` — the
// per-isolate snapshot — never the process-global `dart:io CliRunner.lastDispatchedExitCode`,
// which a sibling suite finishing concurrently clobbers (issue #1632).
//
// RED phase: recorded against the unfixed tree — every fixture below
// planned cleanly (exit 0) and 04-ENGINE.md carried the Flutter type.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String feature = '004-shell';

/// The issue's shape, entity half: a CORE lane whose `### Key Entities`
/// table declares a Flutter-typed field (`icon: IconData`).
const String flutterTypedEntitySpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the shell **When** a tab is tapped **Then** the branch index updates
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall track the selected tab slot.

### Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| ShellNavItem | index: int, icon: IconData, label: String | the tab slot |

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
```
''';

/// The issue's shape, contract half: a `**Presentation**` Layer Contract
/// whose signature returns a Flutter type (`build() -> Widget`).
const String widgetSignatureContractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the shell **When** a tab is tapped **Then** the branch index updates
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall track the selected tab slot.

## Layer Contracts

**Presentation**:
- `AppBottomNav`: `build() -> Widget`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
```
''';

/// The type guard is layer-independent: a pure Dart engine contract that
/// still names a Flutter type refuses too.
const String domainFlutterTypeContractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the shell **When** a tab is tapped **Then** the branch index updates
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall track the selected tab slot.

## Layer Contracts

**Domain**:
- `ShellBuilder`: `build(BuildContext context) -> ShellState`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
```
''';

/// The corpus shape: a `**Presentation**` contract whose signature names
/// no Flutter type (`present(WalletState) -> WalletView`). It must still
/// not DEFAULT to CORE — the contract id has to be declared.
const String presentationContractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the wallet **When** a value is committed **Then** the wallet list renders
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall present the wallet state.

## Layer Contracts

**Presentation**:
- `WalletPresenter`: `present(WalletState) -> WalletView`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
```
''';

/// The same spec with the author's EXPLICIT routing: the derived contract
/// id is declared in the CORE lane row — declarations win, and the row
/// renders engine-side.
const String declaredPresentationContractSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** the wallet **When** a value is committed **Then** the wallet list renders
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall present the wallet state.

## Layer Contracts

**Presentation**:
- `WalletPresenter`: `present(WalletState) -> WalletView`

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1, contract:A1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
```
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1745_noflutter_types_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec(String spec) =>
      File(p.join(featureDir, 'spec.md')).writeAsString(spec);

  List<String> planArgs() => [
    'tdd',
    'plan',
    '--project',
    tmpDir.path,
    feature,
    '--allow-unit-fallback',
  ];

  File laneFile(String name) => File(p.join(tddDir, name));

  Future<String> plan() async {
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(planArgs());
    return out;
  }

  void expectNothingWritten() {
    for (final name in [
      '04-ENGINE.md',
      '04-SKIN.md',
      '04-CONTRACT.md',
      'test-list.md',
    ]) {
      expect(
        laneFile(name).existsSync(),
        isFalse,
        reason: 'an incomplete split never leaves a half-written plan ($name)',
      );
    }
  }

  group('Bug #1745 — the noFlutter guard is type-aware', () {
    test('a Flutter-typed Key Entity refuses instead of landing in '
        '04-ENGINE.md (A-1745-1)', () async {
      await seedSpec(flutterTypedEntitySpec);
      final out = await plan();

      expect(
        CliRunner.lastDispatchedExitCode,
        2,
        reason:
            'a Key Entity field typed with a Flutter type renders into '
            '04-ENGINE.md, which is pure Dart by construction — the plan '
            'must refuse, not accept (out:\n$out)',
      );
      expect(
        out,
        contains('ShellNavItem'),
        reason: 'the refusal names the offending declaration',
      );
      expect(out, contains('IconData'));
      expectNothingWritten();
    });

    test('a Flutter-typed Layer Contract signature refuses — the '
        'signature lands on the contract row (A-1745-2)', () async {
      await seedSpec(widgetSignatureContractSpec);
      final out = await plan();

      expect(
        CliRunner.lastDispatchedExitCode,
        2,
        reason:
            '`build() -> Widget` is rendered into the engine plan\'s '
            'contract row; the bare `package:flutter` substring test '
            'never saw it (out:\n$out)',
      );
      expect(
        out,
        contains('AppBottomNav'),
        reason: 'the refusal names the declared interface/method',
      );
      expect(out, contains('Widget'));
      expectNothingWritten();
    });

    test('the type guard is layer-independent — a Domain contract naming '
        'a Flutter type refuses too (A-1745-3)', () async {
      await seedSpec(domainFlutterTypeContractSpec);
      final out = await plan();

      expect(CliRunner.lastDispatchedExitCode, 2, reason: 'out:\n$out');
      expect(out, contains('ShellBuilder'));
      expect(out, contains('BuildContext'));
      expectNothingWritten();
    });
  });

  group('Bug #1745 — a Presentation contract never defaults to CORE', () {
    test('an undeclared Presentation contract refuses instead of riding '
        'the engine lane (A-1745-4)', () async {
      await seedSpec(presentationContractSpec);
      final out = await plan();

      expect(
        CliRunner.lastDispatchedExitCode,
        2,
        reason:
            'a contract derived from the `**Presentation**` layer is a '
            'SKIN-side declaration; the SKIN plan renders no contract '
            'section, so silently defaulting it to CORE is the '
            '#1745 misroute (out:\n$out)',
      );
      expect(
        out,
        contains('WalletPresenter'),
        reason: 'the refusal names the declared contract',
      );
      expectNothingWritten();
    });

    test('an explicit CORE declaration is the author\'s word — the row '
        'renders in 04-ENGINE.md (A-1745-5)', () async {
      await seedSpec(declaredPresentationContractSpec);
      final out = await plan();

      expect(CliRunner.lastDispatchedExitCode, 0, reason: 'out:\n$out');
      final engine = laneFile('04-ENGINE.md').readAsStringSync();
      expect(
        engine,
        contains('WalletPresenter.present(WalletState) -> WalletView'),
        reason: 'the declared row rides the CORE lane as declared',
      );
    });
  });
}
