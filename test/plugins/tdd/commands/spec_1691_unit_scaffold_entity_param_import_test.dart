// SPEC 1691 — the unit-lane test scaffold imports lifted entity PARAM
// types (issue #1691: verify-red dies at compile-error).
//
// SPEC 1489 lifted `UnitContractParam.type` from `Object?` to the declared
// type when the entity exists on disk. The unit-lane test scaffold then
// emits the `_argN()` placeholder helper with the LIFTED type
// (`LoginParams _arg0() => throw UnimplementedError(...)`), but the test
// writer only added `returnEntityImports` to the test's import set — not
// `entityImports`. Result: `verify-red -> compile-error`
// (`Error: 'LoginParams' isn't a type.`) instead of the designed
// honest-red / hand-seam transition.
//
// Remediation (issue #1691): the test writer emits the FULL
// `shape.entityImports` set (deduped by the shape derivation — a superset
// of `returnEntityImports`). Unused-import risk is nil by construction:
// `entityImports` only contains entities that exist on disk (the exact
// lift condition), a lifted entity param always takes the `_argN()` seam
// (no scalar literal, no scenario claim covers an entity type), and a
// lifted entity return always feeds the `isA<T>()` assertion. The SUBJECT
// writer already emitted the full set (SPEC 1489 SC-2) — the test writer
// was not extended the same way.
//
// Test map (fast tier — the real GenCommand via CliRunner, no pub get, no
// build; the bug_1420 harness shape):
//   U-1691-G1 — the issue's repro (`login(LoginParams) -> UserSession`):
//               the paired test imports the PARAM entity AND the return
//               entity, param-first (the shape's documented order).
//   U-1691-G2 — entity param + scalar return (`fetch(LoginParams) -> bool`):
//               the param entity is imported (the latent scalar-return
//               compile-error case the return-only import set missed).
//   U-1691-G3 — scalar-only contract (`add(int a, int b) -> int`): NO
//               entity imports — the legacy template stays byte-identical
//               (hard constraint: scalar-param behavior unchanged).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmp;
  const feature = '1691-repro';
  const paramEntity = 'LoginParams';
  const paramSnake = 'login_params';
  const returnEntity = 'UserSession';
  const returnSnake = 'user_session';

  /// The TDD profile gen's entry preflight reads (the bug_1420 idiom).
  void seedProfile() {
    final memoryDir = Directory(p.join(tmp.path, '.specify', 'memory'));
    memoryDir.createSync(recursive: true);
    File(p.join(memoryDir.path, 'tdd-profile.md')).writeAsStringSync('''
# TDD Profile — fixture

## Commands

- Single test: `dart test {file} --plain-name "{name}"`
- Full suite: `dart test`

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test'
file: 'dart test {file}'
coverage: 'dart test --coverage'
```
''');
  }

  /// A pubspec with a package name so the entity imports render in the
  /// lint-clean `package:` form (the real-project shape).
  void seedPubspec() {
    File(
      p.join(tmp.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: fixture_app\nenvironment:\n  sdk: ^3.11.0\n');
  }

  /// The spec + test-list rows for a declared Domain contract. [contract]
  /// is the declared signature row; [traces] is the method-qualified cell
  /// plan writes for a single-method row (issue #1320).
  void seedFeature({
    required String contract,
    required String traces,
    required String description,
  }) {
    seedProfile();
    seedPubspec();
    final featureDir = Directory(p.join(tmp.path, 'specs', feature));
    featureDir.createSync(recursive: true);
    File(p.join(featureDir.path, 'spec.md')).writeAsStringSync('''
**Template Version**: `zuraffa-1.0`

# Spec: $feature

### Layer Contracts

**Domain**:
- `AuthRepo`: `$contract`

## Functional Requirements

- **FR-001**: System MUST $description
            traces: AuthRepo.login

## Acceptance Scenarios

1. **Given** credentials **When** the user signs in **Then** the session is established.
''');
    final tddDir = Directory(p.join(featureDir.path, 'tdd'));
    tddDir.createSync();
    File(p.join(tddDir.path, 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | System MUST $description | $traces | PENDING |
''');
  }

  /// The canonical entity files `locateEntityFile` resolves (the phase-0
  /// `entity create` product).
  void seedEntity(String name, String snake) {
    final entityFile = File(
      p.join(
        tmp.path,
        'lib',
        'src',
        'domain',
        'entities',
        snake,
        '$snake.dart',
      ),
    );
    entityFile.createSync(recursive: true);
    entityFile.writeAsStringSync('''
class $name {
  const $name();
}
''');
  }

  Future<String> runGen() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', 'gen', 'U1', '--project', tmp.path]);
  }

  String readTest() => File(
    p.join(tmp.path, 'test', 'tdd', feature, 'u1_test.dart'),
  ).readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('spec_1691_gen_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  test(
    'U-1691-G1: entity param + entity return — the paired test imports '
    'the param entity AND the return entity (the #1691 repro compiles)',
    () async {
      seedFeature(
        contract: 'login($paramEntity) -> $returnEntity',
        traces: 'FR-001, AuthRepo.login',
        description: 'authenticate the submitted credentials',
      );
      seedEntity(paramEntity, paramSnake);
      seedEntity(returnEntity, returnSnake);

      final out = await runGen();
      final testContent = readTest();

      // The lifted param type renders in the _argN() helper (SPEC 1489 —
      // unchanged by this fix).
      expect(
        testContent,
        contains('$paramEntity _arg0() => throw UnimplementedError('),
        reason: testContent,
      );
      // THE FIX: the param entity's import rides the paired test. Without it
      // verify-red classifies compile-error (`'LoginParams' isn't a type`).
      expect(
        testContent,
        contains(
          "import 'package:fixture_app/src/domain/entities/"
          "$paramSnake/$paramSnake.dart';",
        ),
        reason: testContent,
      );
      // The return entity's import still rides the test (SPEC 1489 SC-2,
      // unchanged by this fix).
      expect(
        testContent,
        contains(
          "import 'package:fixture_app/src/domain/entities/"
          "$returnSnake/$returnSnake.dart';",
        ),
        reason: testContent,
      );
      // The shape's documented order: params first (declaration order), then
      // the return — the entityImports set is insertion-ordered.
      final paramIndex = testContent.indexOf('$paramSnake/$paramSnake.dart');
      final returnIndex = testContent.indexOf('$returnSnake/$returnSnake.dart');
      expect(
        paramIndex < returnIndex,
        isTrue,
        reason:
            'param entity import must precede the return entity import:\n'
            '$testContent',
      );
      expect(out, isNot(contains('Error')), reason: out);
    },
  );

  test('U-1691-G2: entity param + scalar return — the param entity is '
      'imported (the latent scalar-return compile-error case)', () async {
    seedFeature(
      contract: 'fetch($paramEntity) -> bool',
      traces: 'FR-001, AuthRepo.fetch',
      description: 'validate the submitted credentials',
    );
    seedEntity(paramEntity, paramSnake);

    final out = await runGen();
    final testContent = readTest();

    expect(
      testContent,
      contains('$paramEntity _arg0() => throw UnimplementedError('),
      reason: testContent,
    );
    // The param entity import is REQUIRED here too: the helper references
    // the lifted type even though the RETURN is a plain scalar.
    expect(
      testContent,
      contains(
        "import 'package:fixture_app/src/domain/entities/"
        "$paramSnake/$paramSnake.dart';",
      ),
      reason: testContent,
    );
    // The scalar return renders the typed assertion — no return entity.
    expect(testContent, contains('expect(result, isA<bool>());'));
    expect(out, isNot(contains('Error')), reason: out);
  });

  test(
    'U-1691-G3: scalar-only contract — NO entity imports, the legacy '
    'template stays byte-identical (scalar-param behavior unchanged)',
    () async {
      seedFeature(
        contract: 'add(int a, int b) -> int',
        traces: 'FR-001, AuthRepo.add',
        description: 'add the two submitted integers',
      );

      await runGen();
      final testContent = readTest();

      // Scalar params take the representative literals — no _argN helper.
      expect(testContent, contains('subject_u1(0, 0)'), reason: testContent);
      expect(testContent, isNot(contains('_arg0()')), reason: testContent);
      // No entity imports at all — the template is the legacy shape.
      expect(
        testContent,
        isNot(contains('domain/entities/')),
        reason: testContent,
      );
      expect(
        testContent,
        isNot(contains('$paramSnake/$paramSnake.dart')),
        reason: testContent,
      );
    },
  );
}
