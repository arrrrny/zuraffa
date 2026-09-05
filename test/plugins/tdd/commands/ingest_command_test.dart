/// Unit behaviors U1–U4 for spec 1010-zfa-dream-one-command-app
/// (tdd/test-list.md): `zfa tdd ingest` — the draft validation gate the
/// dream loop re-prompts on.
///
/// Drives the real CLI entry point in-process (`CliRunner.runCapturing`,
/// the house pattern). The framework-export-collision fixture seeds a
/// probe symbol (`Z1010Probe`) through a fake package_config, the exact
/// pattern of framework_export_surface_test.dart, so assertions can never
/// be satisfied by the CLI checkout's own real surface.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late CliRunner runner;
  late Directory tmp;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tmp = await Directory.systemTemp.createTemp('ingest_cmd_');
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// The schema-valid draft body (the zuraffa-1.0 grammar every section
  /// shaped after the bug #919 fixtures).
  const kValidDraft = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1010-demo

## Acceptance Scenarios

1. **Given** a fresh state **When** the user invokes the feature
   **Then** the system responds

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| FavoriteDeal | `id: String`, `title: String` | One saved deal |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> FavoriteDeal?` | P1 |

## Layer Contracts

**Domain**:

- `FavoriteDealRepository`: `list() -> Future<Result<List<FavoriteDeal>, AppFailure>>`
''';

  String specsRoot() => p.join(tmp.path, 'specs');

  Future<File> writeDraft(String body, [String name = 'draft.md']) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsString(body);
    return f;
  }

  Future<String> drive(
    String feature,
    File draft, {
    List<String> extra = const [],
  }) => runner.runCapturing([
    'tdd',
    'ingest',
    feature,
    '--draft',
    draft.path,
    '--project',
    tmp.path,
    ...extra,
  ]);

  test(
    'U1: accepts a schema-valid draft — writes spec.md, exit 0, summary',
    () async {
      final draft = await writeDraft(kValidDraft);

      final out = await drive('1010-demo', draft);

      expect(exitCode, 0, reason: out);
      final spec = File(p.join(specsRoot(), '1010-demo', 'spec.md'));
      expect(spec.existsSync(), isTrue, reason: out);
      expect(spec.readAsStringSync(), kValidDraft);
      expect(
        out,
        contains(
          'ingest: feature=1010-demo result=accepted entities=1 '
          'dependencies=1 contracts=1',
        ),
        reason: out,
      );
    },
  );

  test('U2a: template-version drift — exit 3, no spec.md written', () async {
    final draft = await writeDraft('# Spec: no marker\n$kMinimalBody');

    final out = await drive('1010-demo', draft);

    expect(exitCode, 3, reason: out);
    expect(out, contains('contract drift'));
    expect(
      File(p.join(specsRoot(), '1010-demo', 'spec.md')).existsSync(),
      isFalse,
      reason: 'a refused draft must not land on disk',
    );
  });

  test(
    'U2b: declaration refusal (contract ambiguity class) — exit 2',
    () async {
      final draft = await writeDraft('''
**Template Version**: `zuraffa-1.0`

# Spec: 1010-demo

## Layer Contracts

**Function**:
- `Broken`: `format(Template)`

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the widget renders "Ready".
''');

      final out = await drive('1010-demo', draft);

      expect(exitCode, 2, reason: out);
      expect(out, contains('declaration refused'));
      expect(out, contains('--> fix:'));
      expect(
        File(p.join(specsRoot(), '1010-demo', 'spec.md')).existsSync(),
        isFalse,
      );
    },
  );

  test('U2c: undeclared external dependency — exit 2', () async {
    final draft = await writeDraft('''
**Template Version**: `zuraffa-1.0`

# Spec: 1010-demo

## Acceptance Scenarios

1. **Given** a fresh state **When** the user saves via Hive **Then** the
   system responds
''');

    final out = await drive('1010-demo', draft);

    expect(exitCode, 2, reason: out);
    expect(out, contains('undeclared dependencies'));
    expect(out, contains('Hive'));
    expect(
      File(p.join(specsRoot(), '1010-demo', 'spec.md')).existsSync(),
      isFalse,
    );
  });

  test(
    'U3a: intra-draft duplicate entity names — exit 2, rename fix',
    () async {
      final draft = await writeDraft(
        kValidDraft.replaceFirst(
          '| FavoriteDeal | `id: String`, `title: String` | One saved deal |',
          '| FavoriteDeal | `id: String`, `title: String` | One saved deal |\n'
              '| FavoriteDeal | `id: String` | duplicate row |',
        ),
      );

      final out = await drive('1010-demo', draft);

      expect(exitCode, 2, reason: out);
      expect(out, contains('entity name collision'));
      expect(out, contains('FavoriteDeal'));
      expect(out, contains('--> fix:'));
      expect(
        File(p.join(specsRoot(), '1010-demo', 'spec.md')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'U3b: framework-export entity collision — exit 2, #942 fix language',
    () async {
      // Seed a fake zuraffa package exporting the probe symbol, wired via
      // the fixture's own package_config (the surface test pattern).
      final dep = Directory(p.join(tmp.path, 'dep', 'lib'));
      await dep.create(recursive: true);
      await File(
        p.join(dep.path, 'zuraffa.dart'),
      ).writeAsString("class Z1010Probe {}\n");
      final dartTool = Directory(p.join(tmp.path, '.dart_tool'));
      await dartTool.create(recursive: true);
      await File(p.join(dartTool.path, 'package_config.json')).writeAsString(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'zuraffa', 'rootUri': 'file://${tmp.path}/dep'},
          ],
        }),
      );

      final draft = await writeDraft(
        kValidDraft.replaceAll('FavoriteDeal', 'Z1010Probe'),
      );

      final out = await drive('1010-demo', draft);

      expect(exitCode, 2, reason: out);
      expect(out, contains('entity name collision'));
      expect(out, contains('Z1010Probe'));
      expect(out, contains('framework export'));
      expect(out, contains('--> fix: rename the entity'));
      expect(
        File(p.join(specsRoot(), '1010-demo', 'spec.md')).existsSync(),
        isFalse,
      );
    },
  );

  test('U3c: interface declared under two layers — contract ambiguity, '
      'exit 2', () async {
    final draft = await writeDraft('''
$kValidDraft

**Presentation**:

- `FavoriteDealRepository`: `render() -> void`
''');

    final out = await drive('1010-demo', draft);

    expect(exitCode, 2, reason: out);
    expect(out, contains('contract ambiguity'));
    expect(out, contains('FavoriteDealRepository'));
    expect(
      File(p.join(specsRoot(), '1010-demo', 'spec.md')).existsSync(),
      isFalse,
    );
  });

  test('U3d: dependency row with an empty Contract cell — exit 2', () async {
    final draft = await writeDraft(
      kValidDraft.replaceFirst(
        '| Hive | storage | `read(key) -> FavoriteDeal?` | P1 |',
        '| Hive | storage |  | P1 |',
      ),
    );

    final out = await drive('1010-demo', draft);

    expect(exitCode, 2, reason: out);
    expect(out, contains('contract ambiguity'));
    expect(out, contains('Hive'));
    expect(
      File(p.join(specsRoot(), '1010-demo', 'spec.md')).existsSync(),
      isFalse,
    );
  });

  test(
    'U4a: refuses to overwrite an existing spec.md without --force',
    () async {
      final draft = await writeDraft(kValidDraft);
      final specDir = Directory(p.join(specsRoot(), '1010-demo'));
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString('# prior spec');

      final out = await drive('1010-demo', draft);

      expect(exitCode, 2, reason: out);
      expect(out, contains('already exists'));
      expect(out, contains('--force'));
      expect(
        File(p.join(specDir.path, 'spec.md')).readAsStringSync(),
        '# prior spec',
        reason: 'the existing spec must never be silently replaced',
      );
    },
  );

  test('U4b: --force replaces the existing spec.md', () async {
    final draft = await writeDraft(kValidDraft);
    final specDir = Directory(p.join(specsRoot(), '1010-demo'));
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('# prior spec');

    final out = await drive('1010-demo', draft, extra: ['--force']);

    expect(exitCode, 0, reason: out);
    expect(
      File(p.join(specDir.path, 'spec.md')).readAsStringSync(),
      kValidDraft,
    );
  });
}

const String kMinimalBody = '''
## Acceptance Scenarios

1. **Given** a fresh state **When** the user invokes the feature
   **Then** the system responds
''';
