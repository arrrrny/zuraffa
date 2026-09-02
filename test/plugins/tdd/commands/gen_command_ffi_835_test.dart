// Bug #835 (tdd-ffi-ocr-harness): `zfa tdd gen` for an ffi-kind behavior
// emits THREE surfaces in one transactional attempt — the contract pair
// (test + binding-contract harness), the marked golden fixture lane test,
// and the golden fixtures — registers the contract pair in the artifact
// registry, surfaces the lane in the structured output + JSON verdict,
// and never clobbers recorded golden data or a partially wired harness on
// re-gen.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  final featureName = '090-ffi-fixture';

  List<String> genArgs(String id) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    '--feature',
    featureName,
    id,
  ];

  Future<void> seedNativeLoopRow(String description) async {
    final specDir = Directory(p.join(tmpDir.path, 'specs', featureName));
    await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for $featureName

## Functional Requirements

- **FR-001**: $description
''');
    await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
# Test List for $featureName

## Native loop: ffi behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U1 | $description | FR-001 | PENDING |
''');
  }

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_ffi_835_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('Bug #835 — gen emits the golden fixture lane for ffi behaviors', () {
    test(
      'document variant: contract pair + lane test + pdf/md fixtures',
      () async {
        await seedNativeLoopRow(
          'the pdf-to-markdown ffi binding converts a sample pdf to markdown',
        );
        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(genArgs('U1'));

        final testDir = p.join(tmpDir.path, 'test', 'tdd', featureName);
        final fixtureDir = p.join(testDir, 'fixtures', 'u1');
        expect(
          File(p.join(testDir, 'u1_test.dart')).existsSync(),
          isTrue,
          reason: 'the contract lane test',
        );
        expect(
          File(
            p.join(tmpDir.path, 'lib', 'tdd', featureName, 'u1_subject.dart'),
          ).existsSync(),
          isTrue,
          reason: 'the binding-contract harness',
        );
        expect(
          File(p.join(testDir, 'u1_golden_test.dart')).existsSync(),
          isTrue,
          reason: 'the marked golden fixture lane test',
        );
        expect(
          File(p.join(fixtureDir, 'golden-input.pdf')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(fixtureDir, 'golden-expected.md')).existsSync(),
          isTrue,
        );

        // The structured output + verdict surface the lane.
        expect(out, contains('golden_test_path:'));
        expect(out, contains('golden_fixtures_dir:'));
        expect(out, contains('"golden_test":'));
        expect(out, contains('"golden_fixtures":'));
        expect(out, contains('"verdict":"created"'));
      },
    );

    test('OCR variant: image + expected extraction JSON fixtures', () async {
      await seedNativeLoopRow(
        'the ocr ffi binding extracts invoice fields within tolerance',
      );
      await CliRunner(exitOnCompletion: false).runCapturing(genArgs('U1'));
      final fixtureDir = p.join(
        tmpDir.path,
        'test',
        'tdd',
        featureName,
        'fixtures',
        'u1',
      );
      expect(File(p.join(fixtureDir, 'golden-input.png')).existsSync(), isTrue);
      final scenario = File(
        p.join(fixtureDir, 'golden-expected.json'),
      ).readAsStringSync();
      expect(scenario, contains('"seed"'));
      expect(scenario, contains('"thresholds"'));
      expect(scenario, contains('"expected":null'));
    });

    test(
      're-gen reuses the pair and NEVER touches recorded golden data',
      () async {
        await seedNativeLoopRow(
          'the pdf-to-markdown ffi binding converts a sample pdf to markdown',
        );
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(genArgs('U1'));

        final harnessPath = p.join(
          tmpDir.path,
          'lib',
          'tdd',
          featureName,
          'u1_subject.dart',
        );
        // Simulate PARTIAL wiring: a real library constant + a real symbol
        // list, seams still throwing (still an UnimplementedError stub).
        final harness = File(harnessPath).readAsStringSync();
        await File(harnessPath).writeAsString(
          harness
              .replaceFirst('NATIVE_LIBRARY_NOT_CONFIGURED', 'libpdf_to_md.so')
              .replaceFirst('REQUIRED_SYMBOL_NOT_CONFIGURED', 'pdf_convert'),
        );

        final goldenPath = p.join(
          tmpDir.path,
          'test',
          'tdd',
          featureName,
          'fixtures',
          'u1',
          'golden-expected.md',
        );
        await File(goldenPath).writeAsString('# RECORDED GOLDEN\n');

        final out2 = await runner.runCapturing(genArgs('U1'));
        expect(out2, contains('"verdict":"reused"'));
        expect(
          File(goldenPath).readAsStringSync(),
          '# RECORDED GOLDEN\n',
          reason: 'recorded golden data is inviolable',
        );
        expect(
          File(harnessPath).readAsStringSync(),
          contains('libpdf_to_md.so'),
          reason:
              'partial wiring is never clobbered — the staleness '
              'auto-regeneration is disabled for ffi harnesses',
        );
      },
    );

    test(
      'a unit-kind behavior emits NO golden lane (unchanged pair shape)',
      () async {
        final specDir = Directory(p.join(tmpDir.path, 'specs', featureName));
        await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
        await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for $featureName

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args
''');
        await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString(
          '''
# Test List for $featureName

## Inner loop: unit behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U1 | returns 42 when invoked with no args | FR-001 | PENDING |
''',
        );
        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(genArgs('U1'));
        expect(
          out,
          isNot(contains('golden_test_path')),
          reason: 'the golden lane is the ffi-kind surface only',
        );
        expect(
          File(
            p.join(
              tmpDir.path,
              'test',
              'tdd',
              featureName,
              'u1_golden_test.dart',
            ),
          ).existsSync(),
          isFalse,
        );
      },
    );
  });
}
