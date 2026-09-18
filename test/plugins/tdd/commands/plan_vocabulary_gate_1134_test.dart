// EPIC 3 / issue #1134, lane 4 — `zfa tdd plan` validates widget
// references against the `zfa ui schema` vocabulary: an
// out-of-vocabulary Presentation component token (grid, table,
// ShadGrid) on a feature with widget behaviors refuses the plan
// (exit 2, no artifacts) naming the token and the fix;
// in-vocabulary tokens (ShadInput, ZfaButton) pass.
//
//  U-1134-g2: the plan-time vocabulary gate.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const feature = '004-vocab-gate';

/// A spec whose Presentation contract declares [components] plus the
/// widget behaviors the gate scopes to.
String specWithComponents(List<String> components) =>
    '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: $feature — the vocabulary-gated login

## Acceptance Scenarios

1. **Given** the login view **When** it renders **Then** the app shows 'Sign in'
   **Type**: widget

## Functional Requirements

- **FR-001**: The system shall present the login view.
      traces: LoginForm

## Layer Contracts

**Presentation**:

- `LoginForm`: ${components.map((c) => '`$c`').join(', ')}

**Domain**:

- `LoginValidation`: `isSubmittable(String email, String password) -> bool`
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plan_vocab_gate_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<String> plan() => CliRunner(
    exitOnCompletion: false,
  ).runCapturing(['tdd', 'plan', '--project', tmpDir.path, feature]);

  test('U-1134-g2: an out-of-vocabulary widget reference refuses the '
      'plan (exit 2, no artifacts) naming the token + the vocabulary '
      'fix', () async {
    await File(
      p.join(featureDir, 'spec.md'),
    ).writeAsString(specWithComponents(['ShadInput', 'ShadGrid']));

    final out = await plan();

    expect(exitCode, 2, reason: out);
    expect(out, contains('ShadGrid'));
    expect(out, contains('grid'));
    expect(out, contains('--> fix:'));
    expect(out, contains('zfa ui schema'));
    expect(
      File(p.join(tddDir, 'test-list.md')).existsSync(),
      isFalse,
      reason: 'errors-are-an-API: a refused plan writes no artifacts',
    );
  });

  test('U-1134-g2b: `table` refuses too (not implemented, not in the '
      'vocabulary)', () async {
    await File(
      p.join(featureDir, 'spec.md'),
    ).writeAsString(specWithComponents(['table']));

    final out = await plan();

    expect(exitCode, 2, reason: out);
    expect(out, contains('table'));
    expect(out, contains(RegExp('not implemented', caseSensitive: false)));
  });

  test('U-1134-g2c: in-vocabulary tokens pass (ShadInput -> input, '
      'ZfaButton -> button)', () async {
    await File(
      p.join(featureDir, 'spec.md'),
    ).writeAsString(specWithComponents(['ShadInput', 'ZfaButton']));

    final out = await plan();

    expect(exitCode, 0, reason: out);
    expect(
      File(p.join(tddDir, 'test-list.md')).existsSync(),
      isTrue,
      reason: 'an in-vocabulary plan writes its artifacts',
    );
  });

  test('U-1134-g2d: method-signature tokens never refuse (the '
      'library-dev contracts stay untouched)', () async {
    await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Feature Specification: $feature — a library-dev contract

## Acceptance Scenarios

1. **Given** the parser **When** it runs **Then** the contract is honored
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The system shall honor the declared contract.
      traces: AppShellBuilder

## Layer Contracts

**Presentation**:

- `AppShellBuilder`: `buildMain(appName, coreImport, zuraffaApp) -> String`

**Domain**:

- `LoginValidation`: `isSubmittable(String email, String password) -> bool`
''');

    final out = await plan();

    expect(exitCode, 0, reason: out);
    expect(File(p.join(tddDir, 'test-list.md')).existsSync(), isTrue);
  });
}
