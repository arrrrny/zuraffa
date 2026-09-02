// Tests for GoldenHarnessWriter (bug #835, tdd-ffi-ocr-harness): the
// marked integration-lane test + golden fixtures an ffi gen emits.
//
// Contract pinned here:
//   - document variant: a real, minimal, VALID pdf (header, EOF,
//     startxref target, every xref offset points at `N 0 obj`) + a
//     golden-expected.md scaffold;
//   - OCR variant: a real 1x1 PNG (canonical signature) + a
//     golden-expected.json scenario script with the deterministic seed
//     and the tolerance thresholds, `expected` null until recorded;
//   - the lane test is tagged `integration` + `slow` (marked lane),
//     imports the subject harness relatively, and never skips silently;
//   - the scenario seed is a stable FNV-1a derivative (identical across
//     invocations — NOT String.hashCode);
//   - existing files are never clobbered (recorded golden data is
//     inviolable — the entity-reuse contract, remediation 5's sibling).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/golden_harness_writer.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('golden_harness_835_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Behavior behavior(String description, {String id = 'U1'}) => Behavior(
    id: id,
    feature: '090-ffi-fixture',
    kind: BehaviorKind.ffi,
    description: description,
    sourceCriterion: 'FR-001',
    target: 'subject_$id',
  );

  group('variant selection', () {
    test('ocr/tesseract descriptions select the OCR variant', () {
      expect(
        GoldenHarnessWriter.isOcr('the ocr binding extracts fields'),
        isTrue,
      );
      expect(
        GoldenHarnessWriter.isOcr('tesseract extraction within tolerance'),
        isTrue,
      );
      expect(
        GoldenHarnessWriter.isOcr('converts a sample pdf to markdown'),
        isFalse,
      );
    });
  });

  group('scenario seed', () {
    test(
      'is deterministic across invocations (stable, not String.hashCode)',
      () {
        final a = GoldenHarnessWriter.scenarioSeed('U2');
        final b = GoldenHarnessWriter.scenarioSeed('U2');
        final other = GoldenHarnessWriter.scenarioSeed('U3');
        expect(a, b);
        expect(a, inInclusiveRange(0, 99999));
        expect(
          other,
          isNot(equals(a)),
          reason: 'distinct ids derive distinct seeds',
        );
        // Golden-pinned values (U2 also cross-checked against the
        // generated scenario JSON): any change to the seed derivation
        // breaks byte-stability of previously generated scenario scripts.
        expect(GoldenHarnessWriter.scenarioSeed('U1'), 21961);
        expect(GoldenHarnessWriter.scenarioSeed('U2'), 18578);
      },
    );
  });

  group('document variant', () {
    late GoldenHarnessPaths paths;

    setUp(() async {
      paths = await const GoldenHarnessWriter().write(
        behavior: behavior(
          'the pdf-to-markdown ffi binding converts a sample pdf to markdown',
        ),
        projectRoot: tmp.path,
        featureName: '090-ffi-fixture',
        snakeId: 'u1',
      );
    });

    test(
      'writes the lane test + the pdf/md fixtures in the #827 namespace',
      () {
        expect(
          paths.laneTestPath,
          p.join(
            tmp.path,
            'test',
            'tdd',
            '090-ffi-fixture',
            'u1_golden_test.dart',
          ),
        );
        expect(File(paths.laneTestPath).existsSync(), isTrue);
        final input = File(
          p.join(paths.fixturesDir, 'golden-input.pdf'),
        ).readAsBytesSync();
        expect(input.length, greaterThan(0));
        final expected = File(
          p.join(paths.fixturesDir, 'golden-expected.md'),
        ).existsSync();
        expect(expected, isTrue);
      },
    );

    test('the pdf fixture is a VALID minimal pdf', () {
      final pdf = File(
        p.join(paths.fixturesDir, 'golden-input.pdf'),
      ).readAsStringSync();
      expect(pdf, startsWith('%PDF-1.4'));
      expect(pdf.trim(), endsWith('%%EOF'));
      final startxref = RegExp(r'startxref\s+(\d+)').firstMatch(pdf)!.group(1)!;
      final xrefOffset = int.parse(startxref);
      expect(
        pdf.substring(xrefOffset, xrefOffset + 4),
        'xref',
        reason: 'the startxref offset must point at the xref keyword',
      );
      for (final m in RegExp(
        r'^(\d{10}) 00000 n $',
        multiLine: true,
      ).allMatches(pdf)) {
        final offset = int.parse(m.group(1)!);
        expect(
          RegExp(r'^\d 0 obj').hasMatch(pdf.substring(offset)),
          isTrue,
          reason: 'xref offset $offset must point at its object header',
        );
      }
    });

    test('the lane test is MARKED (integration + slow tags) and loud', () {
      final lane = File(paths.laneTestPath).readAsStringSync();
      expect(
        lane,
        contains("@Tags(['integration', 'slow'])"),
        reason:
            'the library-level annotation precedes the imports '
            '(filtering ignores an annotation placed on main)',
      );
      expect(
        lane.indexOf("@Tags(['integration', 'slow'])"),
        lessThan(lane.indexOf('import ')),
        reason: 'library-scoped: before the first directive',
      );
      expect(
        lane,
        contains("import '../../../lib/tdd/090-ffi-fixture/"),
        reason: 'same directory as the contract test — 3 hops to root',
      );
      expect(lane, contains('subject.convertGolden(input)'));
      expect(
        lane,
        contains("import 'dart:io';"),
        reason:
            'the lane reads fixtures through File — the document '
            'template must import dart:io (a compile gap the e2e '
            'caught: loading failed with Method not found: File)',
      );
      expect(lane, contains('on UnimplementedError catch (error)'));
      expect(lane, isNot(contains('skip:')), reason: 'never skipped silently');
      expect(
        lane,
        contains('golden-expected.md'),
        reason: 'the assertion reads the recorded golden output',
      );
    });

    test('never clobbers recorded golden data on re-write', () async {
      final expectedPath = p.join(paths.fixturesDir, 'golden-expected.md');
      await File(expectedPath).writeAsString('# RECORDED GOLDEN OUTPUT\n');
      final second = await const GoldenHarnessWriter().write(
        behavior: behavior(
          'the pdf-to-markdown ffi binding converts a sample pdf to markdown',
        ),
        projectRoot: tmp.path,
        featureName: '090-ffi-fixture',
        snakeId: 'u1',
      );
      expect(
        second.createdFiles,
        isEmpty,
        reason: 'nothing existing may be rewritten',
      );
      expect(
        File(expectedPath).readAsStringSync(),
        '# RECORDED GOLDEN OUTPUT\n',
      );
    });
  });

  group('OCR variant', () {
    late GoldenHarnessPaths paths;

    setUp(() async {
      paths = await const GoldenHarnessWriter().write(
        behavior: behavior(
          'the ocr ffi binding extracts invoice fields within tolerance',
          id: 'U2',
        ),
        projectRoot: tmp.path,
        featureName: '090-ffi-fixture',
        snakeId: 'u2',
      );
    });

    test('writes a real 1x1 PNG (canonical signature) + the scenario JSON', () {
      final png = File(
        p.join(paths.fixturesDir, 'golden-input.png'),
      ).readAsBytesSync();
      expect(png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ], reason: 'the PNG magic signature — a real, decodable image');
      expect(png.length, greaterThan(30));

      final json = File(
        p.join(paths.fixturesDir, 'golden-expected.json'),
      ).readAsStringSync();
      final scenario = jsonDecode(json) as Map<String, Object?>;
      expect(scenario['behavior'], 'U2');
      expect(
        scenario['seed'],
        GoldenHarnessWriter.scenarioSeed('U2'),
        reason: 'the deterministic seed is encoded in the scenario script',
      );
      expect(
        (scenario['thresholds'] as Map)['fieldAccuracy'],
        0.95,
        reason: 'tolerance thresholds are encoded in the scenario script',
      );
      expect(
        scenario['expected'],
        isNull,
        reason: 'null until recorded — the lane fails loudly before that',
      );
    });

    test(
      'the lane test encodes the tolerance + seed as scenario constants',
      () {
        final lane = File(paths.laneTestPath).readAsStringSync();
        expect(lane, contains('const int kScenarioSeed'));
        expect(lane, contains('const double kMinFieldAccuracy = 0.95;'));
        expect(lane, contains('_fieldAccuracy(extracted, expectedFields)'));
        expect(lane, contains('greaterThanOrEqualTo(kMinFieldAccuracy)'));
        expect(
          lane,
          contains("scenario['expected']"),
          reason: 'fails loudly with a record-it reason until recorded',
        );
        expect(lane, contains("@Tags(['integration', 'slow'])"));
        expect(
          lane.indexOf("@Tags(['integration', 'slow'])"),
          lessThan(lane.indexOf('import ')),
        );
      },
    );
  });
}
