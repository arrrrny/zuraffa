/// GoldenHarnessWriter — emits the MARKED INTEGRATION LANE half of an
/// `ffi` gen (bug #835, remediation 1–3): the golden fixture assertion
/// test plus the golden input/output fixture files it asserts against.
///
/// For an ffi behavior `zfa tdd gen` writes THREE surfaces:
///
///   - the contract lane (`BehaviorTestWriter` ffi branch): binding
///     contract assertions in the default tier — the loop gates on it;
///   - the subject harness (`SubjectWriter` ffi branch): the seams the
///     tests assert through;
///   - THE GOLDEN LANE (this writer): a fixture-level assertion test
///     tagged `@Tags(['integration', 'slow'])` — the marked lane — plus
///     the golden fixtures. The lane never runs in the default tier
///     (`slow` is excluded by the generated `dart_test.yaml`); it is
///     gated by `dart test --preset=integration`, wired to CI. It is
///     never skipped silently: an unwired binding or an unrecorded
///     golden output FAILS loudly — that failure is the designed red.
///
/// Two fixture variants, selected by the behavior description:
///   - document conversion (default): a real, minimal, deterministic
///     single-page `golden-input.pdf` (valid enough for any PDF parser —
///     synthesized with correct xref offsets, ASCII-only) and a
///     `golden-expected.md` scaffold the implementer records the golden
///     markdown into;
///   - OCR (description mentions ocr/tesseract): a real 1x1
///     `golden-input.png` (embedded canonical bytes) and a
///     `golden-expected.json` scenario script carrying the deterministic
///     seed and the tolerance thresholds plus the `expected` field map
///     (null until recorded).
///
/// Every emitted file is deterministic for a given behavior (no
/// timestamps, no randomness — the scenario seed is a stable FNV-1a
/// derivative of the behavior id), so re-generation is byte-stable and
/// the files are golden-recordable by hand.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';

/// The paths this writer produced for one behavior.
class GoldenHarnessPaths {
  const GoldenHarnessPaths({
    required this.laneTestPath,
    required this.fixturesDir,
    required this.createdFiles,
    required this.ocr,
  });

  /// The marked integration-lane test file.
  final String laneTestPath;

  /// The directory holding the golden fixtures.
  final String fixturesDir;

  /// The fixture files the writer actually created this invocation
  /// (existing files are never clobbered — recorded golden data is
  /// inviolable, the same contract as the entity-reuse guarantee).
  final List<String> createdFiles;

  /// Whether the OCR variant was selected.
  final bool ocr;
}

class GoldenHarnessWriter {
  const GoldenHarnessWriter();

  /// Whether [description] declares the OCR variant of the native
  /// boundary (invoice OCR / tesseract extraction) rather than the
  /// document-conversion one.
  static bool isOcr(String description) {
    final d = description.toLowerCase();
    return d.contains('ocr') || d.contains('tesseract');
  }

  /// The deterministic scenario seed for [behaviorId] — a stable FNV-1a
  /// derivative (NOT `String.hashCode`, which varies across runs), so the
  /// generated scenario script is reproducible byte-for-byte.
  static int scenarioSeed(String behaviorId) {
    var h = 0x811C9DC5;
    for (final cu in behaviorId.codeUnits) {
      h ^= cu & 0xFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
      h ^= (cu >> 8) & 0xFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h % 100000;
  }

  /// Write the golden lane test + fixtures for [behavior] under
  /// [projectRoot] (`test/tdd/<feature-slug>/...`, the bug #827
  /// namespace). Existing files are never overwritten.
  Future<GoldenHarnessPaths> write({
    required Behavior behavior,
    required String projectRoot,
    required String featureName,
    required String snakeId,
  }) async {
    final ocr = isOcr(behavior.description);
    final testDir = p.join(projectRoot, 'test', 'tdd', featureName);
    final fixturesDir = p.join(testDir, 'fixtures', snakeId);
    final laneTestPath = p.join(testDir, '${snakeId}_golden_test.dart');
    await Directory(fixturesDir).create(recursive: true);

    final created = <String>[];
    Future<void> writeIfMissing(String path, String content) async {
      final file = File(path);
      if (await file.exists()) return;
      await file.writeAsString(content);
      created.add(path);
    }

    // Binary fixtures are written AS BYTES — a writeAsString would
    // UTF-8-encode them and corrupt every byte >= 0x80 (a test caught
    // exactly that on the 0x89 PNG signature).
    Future<void> writeBytesIfMissing(String path, List<int> bytes) async {
      final file = File(path);
      if (await file.exists()) return;
      await file.writeAsBytes(bytes);
      created.add(path);
    }

    final inputName = ocr ? 'golden-input.png' : 'golden-input.pdf';
    final expectedName = ocr ? 'golden-expected.json' : 'golden-expected.md';
    final inputPath = p.join(fixturesDir, inputName);
    final expectedPath = p.join(fixturesDir, expectedName);

    if (ocr) {
      await writeBytesIfMissing(inputPath, base64Decode(_kOnePixelPngBase64));
      await writeIfMissing(expectedPath, _renderOcrScenarioScaffold(behavior));
    } else {
      await writeIfMissing(inputPath, _minimalPdf('sample'));
      await writeIfMissing(expectedPath, _renderDocumentScaffold(behavior));
    }

    // The relative subject import: the lane test sits in the SAME
    // directory as the contract test (`test/tdd/<feature>/`), so the
    // relative hop to the project root is the same three levels the
    // contract pair uses (../../../lib/tdd/<feature>/<file>).
    final subjectRel = p
        .join(
          '..',
          '..',
          '..',
          'lib',
          'tdd',
          featureName,
          '${snakeId}_subject.dart',
        )
        .replaceAll(r'\', '/');
    final fixturesRel = 'test/tdd/$featureName/fixtures/$snakeId';

    final lane = ocr
        ? _renderOcrLaneTest(
            behavior,
            subjectRel,
            fixturesRel,
            inputName,
            expectedName,
          )
        : _renderDocumentLaneTest(
            behavior,
            subjectRel,
            fixturesRel,
            inputName,
            expectedName,
          );
    await writeIfMissing(laneTestPath, lane);

    return GoldenHarnessPaths(
      laneTestPath: laneTestPath,
      fixturesDir: fixturesDir,
      createdFiles: created,
      ocr: ocr,
    );
  }

  // -----------------------------------------------------------------
  // Emitted file templates.
  // -----------------------------------------------------------------

  String _renderDocumentScaffold(Behavior b) =>
      '''
# Golden expected output — ${b.id}

<!-- Record the golden output the wired binding produces for
     `golden-input.pdf` below (replacing this scaffold), then re-run the
     integration lane: dart test --preset=integration
     Until recorded, the lane assertion fails loudly — it is a gate,
     never a silent skip (bug #835). -->
''';

  String _renderOcrScenarioScaffold(Behavior b) {
    final seed = scenarioSeed(b.id);
    return jsonEncode({
      'behavior': b.id,
      'seed': seed,
      'thresholds': {'fieldAccuracy': 0.95},
      // The recorded field map: {"<field>": "<expected value>", ...}.
      // Null until recorded — the lane fails loudly before that.
      'expected': null,
    });
  }

  String _renderDocumentLaneTest(
    Behavior b,
    String subjectRel,
    String fixturesRel,
    String inputName,
    String expectedName,
  ) {
    final escapedGroup = '${b.id} golden fixtures (${b.sourceCriterion})'
        .replaceAll("'", "\\'");
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ffi
// description: ${b.description}
//
// GOLDEN FIXTURE lane (bug #835) — the marked integration tier. The
// fixture-level assertion for this native-boundary behavior runs HERE,
// not in the default tier: tagged `integration` + `slow`, gated by
// `dart test --preset=integration` (wired to CI). This test is NEVER
// skipped silently: an unwired binding or an unrecorded golden output
// fails loudly — that failure is the designed red.
@Tags(['integration', 'slow'])
import 'dart:io';

import 'package:test/test.dart';

import '$subjectRel' as subject;

void main() {
  group('$escapedGroup', () {
    test('${b.id} \\u2014 golden fixture: sample -> expected', () {
      final input =
          File('$fixturesRel/$inputName').readAsStringSync();
      final expected =
          File('$fixturesRel/$expectedName').readAsStringSync();
      final Object? result = _captured(() => subject.convertGolden(input));
      expect(result, equals(expected),
          reason: 'record the golden output for ${b.id} into '
              '$expectedName (the output the wired production binding '
              'produces for the recorded sample input) — until recorded '
              'the lane fails loudly: it is a gate, never a silent skip');
    });
  });
}

/// Captures an [UnimplementedError] thrown by an unwired harness seam as
/// the assertion's actual value, so the unwired state fails through an
/// assertion (honest red) instead of an uncaught error.
Object? _captured(Object? Function() invoke) {
  try {
    return invoke();
  } on UnimplementedError catch (error) {
    return error;
  }
}
''';
  }

  String _renderOcrLaneTest(
    Behavior b,
    String subjectRel,
    String fixturesRel,
    String inputName,
    String expectedName,
  ) {
    final escapedGroup = '${b.id} golden fixtures (${b.sourceCriterion})'
        .replaceAll("'", "\\'");
    final seed = scenarioSeed(b.id);
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ffi
// description: ${b.description}
//
// GOLDEN FIXTURE lane (bug #835, OCR variant) — the marked integration
// tier. The extraction assertion runs HERE, not in the default tier:
// tagged `integration` + `slow`, gated by
// `dart test --preset=integration` (wired to CI). Never skipped
// silently: an unwired binding or an unrecorded golden extraction fails
// loudly — that failure is the designed red.
//
// The OCR scenario script (tolerance thresholds + deterministic seed)
// is encoded below and in `$expectedName`:
// the extraction pipeline must run with [kScenarioSeed]; the comparison
// itself is fully deterministic (field accuracy against the recorded
// golden map).
@Tags(['integration', 'slow'])
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '$subjectRel' as subject;

/// Deterministic scenario seed for ${b.id} (derived from the behavior id
/// at generation time). The extraction pipeline must run with this seed.
const int kScenarioSeed = $seed;

/// Minimum acceptable field accuracy for the extraction (tolerance
/// threshold encoded in this scenario script).
const double kMinFieldAccuracy = 0.95;

void main() {
  group('$escapedGroup', () {
    test('${b.id} \\u2014 golden OCR extraction within tolerance', () {
      final expectedJson =
          File('$fixturesRel/$expectedName').readAsStringSync();
      final scenario = jsonDecode(expectedJson) as Map<String, Object?>;
      final recorded = scenario['expected'];
      expect(recorded, isNotNull,
          reason: 'record the golden extraction JSON for ${b.id} into '
              '$expectedName ({"expected": {"<field>": "<value>", ...}} '
              'as produced by the wired binding over the sample image '
              'with seed \$kScenarioSeed) — until recorded the lane '
              'fails loudly: it is a gate, never a silent skip');
      final expectedFields = (recorded as Map).cast<String, Object?>();
      final imageB64 =
          base64Encode(File('$fixturesRel/$inputName').readAsBytesSync());
      final Object? result = _captured(() => subject.convertGolden(imageB64));
      expect(result, isA<String>(),
          reason: 'convertGolden must return the extraction JSON');
      final extracted =
          jsonDecode(result! as String) as Map<String, Object?>;
      final accuracy = _fieldAccuracy(extracted, expectedFields);
      expect(accuracy, greaterThanOrEqualTo(kMinFieldAccuracy),
          reason: 'extraction field accuracy \${accuracy.toStringAsFixed(3)} '
              'is below the encoded tolerance threshold '
              '\$kMinFieldAccuracy (seed \$kScenarioSeed)');
    });
  });
}

/// Deterministic field accuracy: the share of the recorded golden fields
/// the extraction reproduced exactly (trimmed string comparison). No
/// randomness anywhere — the same inputs always yield the same verdict.
double _fieldAccuracy(
  Map<String, Object?> extracted,
  Map<String, Object?> expected,
) {
  if (expected.isEmpty) return 1.0;
  var hits = 0;
  for (final entry in expected.entries) {
    final got = extracted[entry.key];
    if (got == null) continue;
    if (got.toString().trim() == entry.value.toString().trim()) hits++;
  }
  return hits / expected.length;
}

/// Captures an [UnimplementedError] thrown by an unwired harness seam as
/// the assertion's actual value, so the unwired state fails through an
/// assertion (honest red) instead of an uncaught error.
Object? _captured(Object? Function() invoke) {
  try {
    return invoke();
  } on UnimplementedError catch (error) {
    return error;
  }
}
''';
  }

  // -----------------------------------------------------------------
  // Deterministic fixture bytes.
  // -----------------------------------------------------------------

  /// A canonical 1x1 transparent PNG (the image fixture for the OCR
  /// variant) — real, decodable, byte-stable.
  static const String _kOnePixelPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  /// Build a minimal, VALID single-page PDF containing [text] — real
  /// enough for any PDF parser (correct object offsets in the xref
  /// table, ASCII-only content), deterministic for a given [text].
  static String _minimalPdf(String text) {
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
          '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      '<< /Length ${_pdfStreamBody(text).length} >>\nstream\n'
          '${_pdfStreamBody(text)}'
          'endstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    final buf = StringBuffer()..writeln('%PDF-1.4');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(buf.length);
      buf
        ..write('${i + 1} 0 obj')
        ..writeln()
        ..writeln(objects[i])
        ..writeln('endobj');
    }
    final xrefOffset = buf.length;
    buf
      ..writeln('xref')
      ..writeln('0 ${objects.length + 1}')
      ..writeln('0000000000 65535 f ');
    for (final offset in offsets) {
      buf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buf
      ..writeln('trailer')
      ..writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>')
      ..writeln('startxref')
      ..writeln('$xrefOffset')
      ..writeln('%%EOF');
    return buf.toString();
  }

  static String _pdfStreamBody(String text) =>
      'BT /F1 12 Tf 72 720 Td ($text) Tj ET\n';
}
