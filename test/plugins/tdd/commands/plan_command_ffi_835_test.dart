// Bug #835 (tdd-ffi-ocr-harness): `zfa tdd plan` preserves hand-written
// ffi rows. Plan derives only acceptance/unit behaviors from spec.md, so
// a native-boundary row would otherwise be silently re-homed as a plain
// unit row (or dropped) on every re-plan — the RED repro captured exactly
// that destruction. An ffi row whose traces match a spec-derived
// criterion WINS: the spec-derived behavior for that criterion is
// suppressed, and the round-trip is stable (plan preserves what it
// renders).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmpDir;
  final featureName = '090-ffi-fixture';

  Future<void> seedSpecAndList({
    required String listContent,
    bool withSpec = true,
  }) async {
    final specDir = Directory(p.join(tmpDir.path, 'specs', featureName));
    await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
    if (withSpec) {
      await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for $featureName

## Acceptance Scenarios

1. **Given** a sample pdf **When** the operator converts it **Then** the output matches the golden fixture

## Functional Requirements

- **FR-001**: The system shall convert a sample pdf to markdown through the pdf-to-markdown ffi binding.
''');
    }
    await File(
      p.join(specDir.path, 'tdd', 'test-list.md'),
    ).writeAsString(listContent);
  }

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plan_ffi_835_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  List<String> planArgs() => [
    'tdd',
    'plan',
    '--project',
    tmpDir.path,
    featureName,
  ];

  group('Bug #835 — plan preserves hand-written ffi rows', () {
    test('a native loop section survives re-planning verbatim', () async {
      await seedSpecAndList(
        listContent:
            '''
# Test List for $featureName

## Inner loop: unit behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U9 | unrelated unit behavior | FR-099 | PENDING |

## Native loop: ffi behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U2 | the ocr ffi binding extracts invoice fields within tolerance | FR-002 | PENDING |
''',
      );
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());

      final rows = await TestListReader(
        p.join(tmpDir.path, 'specs', featureName),
      ).read();
      final ffi = rows.where((r) => r.kind == BehaviorKind.ffi).toList();
      expect(ffi, hasLength(1), reason: 'the native row survived');
      expect(ffi.single.id, 'U2');
      expect(
        ffi.single.description,
        'the ocr ffi binding extracts invoice fields within tolerance',
        reason: 'the hand-written prose is preserved verbatim',
      );
      expect(ffi.single.state, BehaviorState.pending);
    });

    test(
      'an ffi row whose traces match a spec FR claims that criterion',
      () async {
        // The hand-written native row traces FR-001 — the same criterion
        // the spec parse would derive a plain unit behavior from. The
        // explicit native declaration wins; no duplicate U1 row remains.
        await seedSpecAndList(
          listContent:
              '''
# Test List for $featureName

## Native loop: ffi behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U1 | the pdf-to-markdown ffi binding converts a sample pdf to markdown | FR-001 | PENDING |
''',
        );
        await CliRunner(exitOnCompletion: false).runCapturing(planArgs());

        final rows = await TestListReader(
          p.join(tmpDir.path, 'specs', featureName),
        ).read();
        expect(
          rows.where((r) => r.kind == BehaviorKind.unit),
          isEmpty,
          reason:
              'the spec-derived unit row for FR-001 is suppressed — '
              'the explicit native declaration claims that criterion',
        );
        final ffi = rows.where((r) => r.kind == BehaviorKind.ffi).toList();
        expect(ffi, hasLength(1));
        expect(ffi.single.id, 'U1');
      },
    );

    test(
      'a spec without native rows renders byte-stable legacy output',
      () async {
        await seedSpecAndList(
          listContent:
              '''
# Test List for $featureName

## Native loop: ffi behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U2 | the ocr ffi binding extracts invoice fields within tolerance | FR-002 | PENDING |
''',
          withSpec: false,
        );
        // A spec with an acceptance scenario but NO native FR: the ffi row
        // is preserved even though the spec parse no longer emits any unit
        // behavior for it (the declaration is hand-authored, not derived).
        await File(
          p.join(tmpDir.path, 'specs', featureName, 'spec.md'),
        ).writeAsString('''
# Spec for $featureName

## Acceptance Scenarios

1. **Given** a sample **When** converted **Then** the output matches
''');
        // plan's summary line goes to raw stdout (not the capturable
        // zone), so the file is the assertion surface.
        await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
        final rows = await TestListReader(
          p.join(tmpDir.path, 'specs', featureName),
        ).read();
        expect(rows.where((r) => r.kind == BehaviorKind.ffi), hasLength(1));
      },
    );
  });
}
