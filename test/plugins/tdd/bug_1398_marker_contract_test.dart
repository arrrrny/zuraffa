// Bug #1398 — the make interrupt marker contract (unit tier).
//
// The make step's write-ahead crash marker: a make that dies mid-flight
// (SIGKILL / process death) leaves a durable, behavior-named record that a
// graceful exit never leaves behind (spec 1398 FR-1/FR-5, SC-6).
//
// Contract under test:
//   U1: begin writes an atomic, behavior-named in-progress record.
//   U2: pendingFor reads a same-behavior in-progress record.
//   U3: pendingFor treats missing / corrupt / foreign-behavior markers as
//       absent (fail closed — never blocks, never adopts).
//   U4: clear removes the marker idempotently and never throws on a
//       missing file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/make_interrupt.dart';

void main() {
  late Directory root;
  late String featureDir;
  late String markerPath;
  late MakeInterruptMarker marker;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bug_1398_marker_');
    featureDir = p.join(root.path, 'specs', '090-bug-1398-marker');
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    marker = MakeInterruptMarker(featureDir: featureDir);
    markerPath = p.join(featureDir, 'tdd', 'make-interrupt.json');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  group('bug 1398: MakeInterruptMarker contract', () {
    test(
      'U1: begin writes an atomic, behavior-named in-progress record',
      () async {
        await marker.begin(behavior: 'A1');

        final file = File(markerPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'the marker survives on disk',
        );
        final decoded =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(decoded['schema'], 1);
        expect(decoded['feature'], '090-bug-1398-marker');
        expect(decoded['behavior'], 'A1');
        expect(decoded['status'], 'in-progress');
        expect(
          decoded['pid'],
          isNonNegative,
          reason: 'the make pid, for audit',
        );
        final at = DateTime.tryParse(decoded['at'] as String? ?? '');
        expect(at, isNotNull, reason: 'a UTC timestamp proves the write time');
        expect(at!.isUtc, isTrue);
        // The atomic write leaves no temp file behind.
        expect(File('$markerPath.tmp').existsSync(), isFalse);
      },
    );

    test('U2: pendingFor reads a same-behavior in-progress record', () async {
      await marker.begin(behavior: 'A1');

      final pending = await marker.pendingFor('A1');
      expect(pending, isNotNull);
      expect(pending!['behavior'], 'A1');
      expect(pending['status'], 'in-progress');
    });

    test(
      'U3: pendingFor fails closed on missing / corrupt / foreign markers',
      () async {
        // Missing: no marker at all.
        expect(await marker.pendingFor('A1'), isNull);

        // Corrupt: unparseable bytes behave exactly like absence.
        File(markerPath).writeAsStringSync('{not json');
        expect(
          await marker.pendingFor('A1'),
          isNull,
          reason: 'a corrupt marker never blocks a make (fail closed)',
        );

        // Wrong shape: valid JSON, not a marker object.
        File(markerPath).writeAsStringSync('["A1"]');
        expect(await marker.pendingFor('A1'), isNull);

        // Foreign behavior: another make's marker is not this behavior's.
        File(markerPath).writeAsStringSync(
          jsonEncode({
            'schema': 1,
            'feature': '090-bug-1398-marker',
            'behavior': 'A2',
            'pid': 1,
            'at': '2026-09-16T00:00:00.000Z',
            'status': 'in-progress',
          }),
        );
        expect(
          await marker.pendingFor('A1'),
          isNull,
          reason: 'a foreign-behavior marker never adopts A1',
        );

        // A non-pending status is not an in-flight make.
        File(markerPath).writeAsStringSync(
          jsonEncode({
            'schema': 1,
            'feature': '090-bug-1398-marker',
            'behavior': 'A1',
            'pid': 1,
            'at': '2026-09-16T00:00:00.000Z',
            'status': 'cleared',
          }),
        );
        expect(await marker.pendingFor('A1'), isNull);
      },
    );

    test(
      'U4: clear removes the marker idempotently and never throws',
      () async {
        // Clear on a missing marker: a no-op, not an error.
        await marker.clear();
        expect(File(markerPath).existsSync(), isFalse);

        await marker.begin(behavior: 'A1');
        await marker.clear();
        expect(
          File(markerPath).existsSync(),
          isFalse,
          reason: 'clear removes the marker file',
        );
        // Idempotent: clearing twice stays quiet.
        await marker.clear();
        expect(File(markerPath).existsSync(), isFalse);
      },
    );
  });
}
