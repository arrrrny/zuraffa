// Tests for ProvenanceScanner (spec 051-corpus-harness, U25-U30): lib/
// file -> zfa invocation attribution from the loop's artifact registries,
// cycle-log refactor evidence, setup/import provenance records, and the
// carve-out manifest.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/provenance_scanner.dart';

void main() {
  late Directory root;
  late ProvenanceScanner scanner;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('provenance_');
    scanner = ProvenanceScanner(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<File> write(String rel, String content) async {
    final file = File(p.join(root.path, rel));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  Future<String> libFile(String rel) async {
    await write(p.join('lib', rel), '// code\n');
    return p.posix.join('lib', rel);
  }

  group('U25 — artifact registries attribute subject files', () {
    test('subject_path attributes in absolute and relative form', () async {
      final rel = await libFile('generated.dart');
      await write(
        'specs/f1/tdd/artifacts.json',
        jsonEncode({
          'feature': 'f1',
          'records': [
            {
              'behavior_id': 'B-001',
              'feature': 'f1',
              'source_criterion': 'FR-001',
              'test_path': 'test/b_001_test.dart',
              'subject_path': rel,
              'runnable_test_name': 't',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-08-31T00:00:00Z',
            },
            {
              'behavior_id': 'B-002',
              'feature': 'f1',
              'source_criterion': 'FR-002',
              'test_path': 'test/b_002_test.dart',
              'subject_path': p.join(root.path, 'lib', 'abs_subject.dart'),
              'runnable_test_name': 't',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-08-31T00:00:00Z',
            },
          ],
        }),
      );
      await libFile('abs_subject.dart');

      final report = await scanner.scan();
      expect(report.attributed(rel), isNotNull);
      final by = report.attributed(rel)!;
      expect(by.source, AttributionSource.registry);
      expect(by.command, contains('tdd'));
      expect(
        report.attributed('lib/abs_subject.dart'),
        isNotNull,
        reason: 'absolute recorded paths normalize to project-relative',
      );
    });

    test('a malformed registry row is skipped, not fatal', () async {
      await libFile('orphan.dart');
      await write('specs/f2/tdd/artifacts.json', '{"records": [{"bad": 1}]}');
      final report = await scanner.scan();
      expect(report.attributed('lib/orphan.dart'), isNull);
    });
  });

  group('U26 — cycle-log refactor changed lists attribute', () {
    test('refactor actions attribute their changed files', () async {
      final rel = await libFile('refactored.dart');
      await write('specs/f1/tdd/cycle-log.md', '''
# Cycle Log

## Cycle: B-001 (refactor)

- behavior: B-001
- kind: refactor
- command: `dart fix --apply`
- exit: 0
actions:
- action: format
  command: `dart format lib`
  exit: 0
  changed: $rel, lib/other.dart
- action: no-change
  command: `dart fix`
  exit: 0
  changed: (none)
''');
      final report = await scanner.scan();
      expect(report.attributed(rel), isNotNull);
      expect(report.attributed(rel)!.source, AttributionSource.refactor);
      expect(report.files.containsKey('(none)'), isFalse);
    });
  });

  group('U27 — setup/import provenance records attribute', () {
    test('single-object and array forms both attribute', () async {
      final rel1 = await libFile('main.dart');
      final rel2 = await libFile('app_shell.dart');
      await write(
        '.zfa/provenance/setup.json',
        jsonEncode({
          'command': 'zfa setup demo --specs /corpus',
          'at': '2026-08-31T00:00:00Z',
          // rel1 twice: relative AND absolute form of the SAME file —
          // both must attribute to this record.
          'files': [rel1, p.join(root.path, rel1)],
        }),
      );
      await write(
        '.zfa/provenance/import.json',
        jsonEncode([
          {
            'command': 'zfa corpus import /corpus',
            'files': [rel2],
          },
        ]),
      );
      final report = await scanner.scan();
      expect(report.attributed(rel1)!.source, AttributionSource.provenance);
      expect(
        report.attributed(rel1)!.command,
        'zfa setup demo --specs /corpus',
      );
      expect(report.attributed(rel2)!.source, AttributionSource.provenance);
      expect(report.attributed(rel2)!.command, 'zfa corpus import /corpus');
    });

    test('a record with a missing command is skipped', () async {
      await libFile('dangling.dart');
      await write(
        '.zfa/provenance/bad.json',
        jsonEncode({
          'files': ['lib/dangling.dart'],
        }),
      );
      final report = await scanner.scan();
      expect(report.attributed('lib/dangling.dart'), isNull);
    });
  });

  group('U28 — carve-out entries attribute', () {
    test('carve-out paths attribute with their reason', () async {
      final rel = await libFile('manual_ui.dart');
      await write(
        '.zfa/manifests/corpus-carveout.json',
        jsonEncode({
          'carveouts': [
            {'path': rel, 'reason': 'manual UI (epic 045 carve-out)'},
          ],
        }),
      );
      final report = await scanner.scan();
      final by = report.attributed(rel);
      expect(by, isNotNull);
      expect(by!.source, AttributionSource.carveout);
      expect(by.command, contains('manual UI'));
    });
  });

  group('U29 — deterministic priority', () {
    test('registry wins over refactor, provenance, and carve-out', () async {
      final rel = await libFile('multi.dart');
      await write(
        'specs/f1/tdd/artifacts.json',
        jsonEncode({
          'feature': 'f1',
          'records': [
            {
              'behavior_id': 'B-001',
              'feature': 'f1',
              'subject_path': rel,
              'test_path': 'test/t.dart',
              'runnable_test_name': 't',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': 'x',
              'source_criterion': 'FR-001',
            },
          ],
        }),
      );
      await write('specs/f1/tdd/cycle-log.md', '''
## Cycle: B-001 (refactor)
actions:
- action: format
  command: `dart format lib`
  exit: 0
  changed: $rel
''');
      await write(
        '.zfa/provenance/setup.json',
        jsonEncode({
          'command': 'zfa setup demo',
          'files': [rel],
        }),
      );
      await write(
        '.zfa/manifests/corpus-carveout.json',
        jsonEncode({
          'carveouts': [
            {'path': rel, 'reason': 'manual'},
          ],
        }),
      );
      expect(
        (await scanner.scan()).attributed(rel)!.source,
        AttributionSource.registry,
      );

      // Without the registry: refactor wins.
      await File(
        p.join(root.path, 'specs', 'f1', 'tdd', 'artifacts.json'),
      ).delete();
      expect(
        (await scanner.scan()).attributed(rel)!.source,
        AttributionSource.refactor,
      );

      // Without refactor evidence: provenance wins.
      await File(
        p.join(root.path, 'specs', 'f1', 'tdd', 'cycle-log.md'),
      ).delete();
      expect(
        (await scanner.scan()).attributed(rel)!.source,
        AttributionSource.provenance,
      );
    });
  });

  group('U30 — path normalization', () {
    test('dot-prefixed and Windows-backslash variants match', () async {
      await libFile('norm.dart');
      for (final recordedPath in ['./lib/norm.dart', r'.\lib\norm.dart']) {
        await write(
          '.zfa/provenance/setup.json',
          jsonEncode({
            'command': 'zfa setup demo',
            'files': [recordedPath],
          }),
        );
        expect(
          (await scanner.scan()).attributed('lib/norm.dart'),
          isNotNull,
          reason: '$recordedPath normalizes to lib/norm.dart',
        );
      }
    });
  });

  group('unattributed files', () {
    test('an unknown lib/ file is unattributed and named', () async {
      await libFile('mystery.dart');
      final report = await scanner.scan();
      expect(report.unattributed, ['lib/mystery.dart']);
      expect(report.counts.files, 1);
      expect(report.counts.attributed, 0);
    });

    test(
      'no lib/ directory yields an empty (vacuously passing) scan',
      () async {
        final report = await scanner.scan();
        expect(report.counts.files, 0);
        expect(report.unattributed, isEmpty);
      },
    );

    test('nested lib/ files are walked', () async {
      await libFile('src/deep/nested.dart');
      await write(
        '.zfa/provenance/setup.json',
        jsonEncode({
          'command': 'zfa setup demo',
          'files': ['lib/src/deep/nested.dart'],
        }),
      );
      final report = await scanner.scan();
      expect(report.counts.files, 1);
      expect(report.attributed('lib/src/deep/nested.dart'), isNotNull);
    });
  });
}
