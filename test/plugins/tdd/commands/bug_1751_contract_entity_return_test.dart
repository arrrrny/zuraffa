// Issue #1751 — a contract test for a declared ENTITY/COLLECTION return
// goes GREEN without ever checking that return type.
//
// `ContractSubjectWriter` renders complex declared types as `Object?`
// (its `_isRenderableType` knows only scalars and scalar generics — the
// zero-parameter const class never consults the entity registry the unit
// lane threads through `UnitContractShape.ofResolved`, SPEC 1489), and
// `ContractTestWriter`'s `_returnCaseType` emits the return-type case
// (Case 3) only for non-nullable scalars. The paired test for
// `ShellTab.values() -> List<ShellTab>` therefore enumerates two
// unfalsifiable cases — "the tearoff is non-null" and "it did not throw
// UnimplementedError" — while Case 1's reason still claims the declared
// signature was checked.
//
// Fix under test (issue #1751):
//   FR-1 — the contract pair threads the entity registry (the SPEC 1489
//          lift, contract-lane surface): a declared return whose entity
//          file exists on disk renders VERBATIM in the seam (import
//          included) instead of degrading to `Object?`.
//   FR-2 — Case 3 is emitted for every non-void return: the declared
//          type verbatim when it is renderable (`isA<List<ShellTab>>()`),
//          and the documented `Object?` degradation (the FR-011 pattern
//          the seam applies) when it is not — never a silent vanish.
//   FR-3 — Case 1's reason no longer claims the declared signature was
//          checked (a tearoff of a non-nullable function type is never
//          null — the case proves exposure only).
//
// The issue's exact reproduction: the entity is on disk (phase-0 ran
// before gen — the SPEC 1489 precondition), the spec declares
// `ShellTab: values() -> List<ShellTab>`, `zfa tdd plan` + `zfa tdd gen`
// emit the pair. Fast tier only (CliRunner against a temp fixture
// project; no `dart test` spawn).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// The issue's declared contract: an entity method returning a
/// collection of the entity itself.
const String kShellSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 004-shell

## Functional Requirements

- **FR-001**: The shell exposes its declared tab values.
            traces: ShellTab.values

## Acceptance Scenarios

1. **Given** a shell **When** the tab values are read **Then** the declared list is returned

### Key Entities

| Entity | Fields | Purpose |
| ShellTab | index: int | A shell tab |

## Layer Contracts

**Entities**:
- `ShellTab`: `values() -> List<ShellTab>`
''';

/// The unresolvable shape: the declared return references an entity that
/// does NOT exist on disk — the FR-011 degradation must DOCUMENT itself
/// in the paired test instead of silently dropping the return case.
const String kMissingEntitySpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 004-nav

## Functional Requirements

- **FR-001**: The nav exposes its declared item values.
            traces: ShellNavItem.items

## Acceptance Scenarios

1. **Given** a nav **When** the item values are read **Then** the declared list is returned

### Key Entities

| Entity | Fields | Purpose |
| ShellNavItem | label: String | A nav item |

## Layer Contracts

**Entities**:
- `ShellNavItem`: `items() -> List<ShellNavItem>`
''';

/// The wrapper shape: the declared return is a `Future<Entity>` — the
/// contract lane renders the `Future`/`Stream` wrappers, so the registry
/// lift must reach THROUGH them (issue #1751).
const String kAsyncSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 004-async

## Functional Requirements

- **FR-001**: The shell exposes its declared tab values asynchronously.
            traces: ShellTab.values

## Acceptance Scenarios

1. **Given** a shell **When** the tab values are read **Then** the declared list is returned

### Key Entities

| Entity | Fields | Purpose |
| ShellTab | index: int | A shell tab |

## Layer Contracts

**Entities**:
- `ShellTab`: `values() -> Future<ShellTab>`
''';

const String _profile = '''
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
''';

void main() {
  late Directory tmp;
  late String featureDir;

  Future<void> seed({
    required String feature,
    required String spec,
    List<String> entitiesOnDisk = const [],
  }) async {
    tmp = Directory.systemTemp.createTempSync('contract_1751_');
    featureDir = p.join(tmp.path, 'specs', feature);
    final memoryDir = Directory(p.join(tmp.path, '.specify', 'memory'));
    memoryDir.createSync(recursive: true);
    File(p.join(memoryDir.path, 'tdd-profile.md')).writeAsStringSync(_profile);
    // The consumer package name — the emitted entity imports resolve to
    // lint-clean `package:` URIs (the real-pipeline shape).
    File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('''
name: repro_app
environment:
  sdk: ^3.11.0
''');
    for (final entity in entitiesOnDisk) {
      final snake = entity
          .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'),
            (m) => '${m.group(1)}_${m.group(2)!.toLowerCase()}',
          )
          .toLowerCase();
      await File(
            p.join(
              tmp.path,
              'lib',
              'src',
              'domain',
              'entities',
              snake,
              '$snake.dart',
            ),
          )
          .create(recursive: true)
          .then(
            (file) =>
                file.writeAsString('class $entity {\n  const $entity();\n}\n'),
          );
    }
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing(['tdd', 'plan', feature, '--project', tmp.path]);
  }

  Future<({String test, String subject})> genPair(String feature) async {
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'tdd',
      'gen',
      'contract:A1',
      '--project',
      tmp.path,
    ]);
    return (
      test: await File(
        p.join(tmp.path, 'test', 'tdd', feature, 'contract_a1_test.dart'),
      ).readAsString(),
      subject: await File(
        p.join(tmp.path, 'lib', 'tdd', feature, 'contract_a1_subject.dart'),
      ).readAsString(),
    );
  }

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  test("an entity return on disk gets a real return-type case (the issue's "
      'reproduction)', () async {
    await seed(
      feature: '004-shell',
      spec: kShellSpec,
      entitiesOnDisk: const ['ShellTab'],
    );
    final pair = await genPair('004-shell');
    expect(
      pair.test,
      contains('isA<List<ShellTab>>()'),
      reason:
          'the declared return `List<ShellTab>` must be asserted — a '
          'green without it is the vacuous green of issue #1751:\n'
          '${pair.test}',
    );
    expect(
      pair.test,
      contains('Case 3 of 3'),
      reason: 'the return-type case must be enumerated:\n${pair.test}',
    );
    expect(
      pair.test,
      isNot(contains('isA<Object?>()')),
      reason:
          'the entity exists on disk — the assertion must not degrade '
          'to the documented `Object?` case:\n${pair.test}',
    );
  });

  test('the seam renders the declared entity return verbatim, import '
      'included (FR-1)', () async {
    await seed(
      feature: '004-shell',
      spec: kShellSpec,
      entitiesOnDisk: const ['ShellTab'],
    );
    final pair = await genPair('004-shell');
    expect(
      pair.subject,
      contains('List<ShellTab> values('),
      reason:
          'the seam must carry the declared return type (SPEC 1489 lift), '
          'not `Object?`:\n${pair.subject}',
    );
    expect(
      pair.subject,
      contains(
        "import 'package:repro_app/src/domain/entities/shell_tab/"
        "shell_tab.dart';",
      ),
      reason:
          'the seam must import the entity its declared return names — a '
          'verbatim type without the import does not compile:\n'
          '${pair.subject}',
    );
    expect(
      pair.test,
      contains(
        "import 'package:repro_app/src/domain/entities/shell_tab/"
        "shell_tab.dart';",
      ),
      reason:
          'the paired test asserts `isA<List<ShellTab>>()` — the entity '
          'import must ride the test too:\n${pair.test}',
    );
  });

  test('Case 1 no longer claims the declared signature was checked '
      '(FR-3)', () async {
    await seed(
      feature: '004-shell',
      spec: kShellSpec,
      entitiesOnDisk: const ['ShellTab'],
    );
    final pair = await genPair('004-shell');
    expect(
      pair.test,
      isNot(matches(RegExp(r'exposed with the declared\s+signature'))),
      reason:
          'a tearoff of a non-nullable function type is never null — the '
          'reason must not overclaim the check (issue #1751):\n'
          '${pair.test}',
    );
    expect(
      pair.test,
      contains('exposure'),
      reason:
          'Case 1 is an EXPOSURE case (the method resolves on the subject) '
          '— the emitted comment must say so (issue #1751):\n'
          '${pair.test}',
    );
  });

  test('an unresolvable entity return degrades to the DOCUMENTED '
      '`Object?` case, never a silent vanish (FR-2)', () async {
    await seed(feature: '004-nav', spec: kMissingEntitySpec);
    final pair = await genPair('004-nav');
    expect(
      pair.test,
      contains('Case 3 of 3'),
      reason:
          'the return-type case must be enumerated even when the declared '
          'type cannot be resolved (issue #1751):\n${pair.test}',
    );
    expect(
      pair.test,
      contains('isA<Object?>()'),
      reason:
          'the unresolvable type degrades to the documented `Object?` '
          'case (the FR-011 pattern):\n${pair.test}',
    );
    expect(
      pair.test,
      contains('issue #1751'),
      reason:
          'the degradation must be DOCUMENTED in the emitted test, not '
          'silent:\n${pair.test}',
    );
  });

  test('the registry lift reaches through a `Future<Entity>` wrapper '
      '(issue #1751)', () async {
    await seed(
      feature: '004-async',
      spec: kAsyncSpec,
      entitiesOnDisk: const ['ShellTab'],
    );
    final pair = await genPair('004-async');
    expect(
      pair.subject,
      contains('Future<ShellTab> values('),
      reason:
          'the contract lane renders the `Future`/`Stream` wrappers — the '
          'registry lift must reach through them:\n${pair.subject}',
    );
    expect(
      pair.test,
      contains('isA<Future<ShellTab>>()'),
      reason:
          'the return-type case asserts the declared wrapper type:\n'
          '${pair.test}',
    );
  });
}
