import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/mission_trace_recorder.dart';
import 'package:zuraffa/src/agent/ui_render/rendered_view.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';

void main() {
  group('MissionTraceRecorder', () {
    test(
      'mission_trace_records_rendered_tree_with_schema_version_and_hash',
      () {
        final recorder = MissionTraceRecorder();
        final tree = const UiNode(
          type: 'root',
          children: [
            UiNode(
              type: 'card',
              styleToken: 'primary',
              children: [UiNode(type: 'button', actionId: 'tap_1')],
            ),
          ],
        );

        final view = RenderedView(
          viewId: 'v1',
          tree: tree,
          schemaVersion: '1.0.0',
          contentHash: 'deadbeefdeadbeef',
        );
        recorder.record(view, missionType: 'listing');

        expect(recorder.length, 1);
        final entry = recorder.entries.single;
        expect(entry.viewId, 'v1');
        expect(entry.schemaVersion, '1.0.0');
        expect(entry.contentHash, 'deadbeefdeadbeef');
        expect(entry.missionType, 'listing');
        expect(entry.tree, same(tree));
        expect(entry.recordedAt, isA<DateTime>());
      },
    );

    test('multiple renders are recorded in order', () {
      final recorder = MissionTraceRecorder();
      recorder.record(
        RenderedView(
          viewId: 'v1',
          tree: const UiNode(
            type: 'root',
            children: [UiNode(type: 'text')],
          ),
          schemaVersion: '1.0.0',
          contentHash: 'aaaa',
        ),
      );
      recorder.record(
        RenderedView(
          viewId: 'v2',
          tree: const UiNode(
            type: 'root',
            children: [UiNode(type: 'card')],
          ),
          schemaVersion: '1.0.0',
          contentHash: 'bbbb',
        ),
      );

      expect(recorder.length, 2);
      expect(recorder.entries[0].viewId, 'v1');
      expect(recorder.entries[1].viewId, 'v2');
    });

    test('replay returns the most recent entry for a view id', () {
      final recorder = MissionTraceRecorder();
      recorder.record(
        RenderedView(
          viewId: 'v1',
          tree: const UiNode(
            type: 'root',
            children: [UiNode(type: 'text')],
          ),
          schemaVersion: '1.0.0',
          contentHash: 'aaaa',
        ),
      );
      recorder.record(
        RenderedView(
          viewId: 'v1',
          tree: const UiNode(
            type: 'root',
            children: [UiNode(type: 'card')],
          ),
          schemaVersion: '1.0.0',
          contentHash: 'bbbb',
        ),
      );

      final entry = recorder.replay('v1')!;
      expect(entry.contentHash, 'bbbb', reason: 'last write wins');
    });

    test('replay returns null for unknown view id', () {
      final recorder = MissionTraceRecorder();
      expect(recorder.replay('does-not-exist'), isNull);
    });

    test('inspect returns all entries for audit', () {
      final recorder = MissionTraceRecorder();
      for (var i = 0; i < 3; i++) {
        recorder.record(
          RenderedView(
            viewId: 'v$i',
            tree: const UiNode(type: 'root'),
            schemaVersion: '1.0.0',
            contentHash: 'hash$i',
          ),
        );
      }
      final inspected = recorder.inspect();
      expect(inspected, hasLength(3));
      for (final entry in inspected) {
        expect(entry.contentHash, isNotNull);
        expect(entry.schemaVersion, '1.0.0');
      }
    });

    test('clear resets the trace', () {
      final recorder = MissionTraceRecorder();
      recorder.record(
        RenderedView(
          viewId: 'v1',
          tree: const UiNode(type: 'root'),
          schemaVersion: '1.0.0',
          contentHash: 'aaaa',
        ),
      );
      expect(recorder.isEmpty, isFalse);
      recorder.clear();
      expect(recorder.isEmpty, isTrue);
    });
  });
}
