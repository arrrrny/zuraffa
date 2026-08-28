import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/ui_event_channel.dart';
import 'package:zuraffa/src/agent/ui_render/ui_render_event.dart';
import 'package:zuraffa/src/agent/ui_render/rendered_view.dart';
import 'package:zuraffa/src/agent/ui_render/semantic_action.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';

void main() {
  group('UiEventChannel', () {
    test('emitRender emits UiRenderEventRender', () async {
      final channel = UiEventChannel();
      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      final view = RenderedView(
        viewId: 'v1',
        tree: const UiNode(type: 'root', children: [UiNode(type: 'text')]),
        schemaVersion: '1.0.0',
        contentHash: 'deadbeefdeadbeef',
      );
      channel.emitRender(view);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first, isA<UiRenderEventRender>());
      expect((received.first as UiRenderEventRender).view.viewId, 'v1');
    });

    test('ui_event_channel_progressive_rendering — partial events accumulate',
        () async {
      // FR-003 acceptance 3: "intermediate nodes arrive before the full tree
      // completes — the UI progressively renders each partial result so the
      // user sees content building up."
      final channel = UiEventChannel();
      final received = <UiRenderEventRender>[];
      channel.events.transform(
        StreamTransformer<UiRenderEvent, UiRenderEventRender>.fromHandlers(
          handleData: (event, sink) {
            if (event is UiRenderEventRender) sink.add(event);
          },
        ),
      ).listen(received.add);

      // Three partial trees stream in — each progressively larger.
      final partials = [
        RenderedView(
          viewId: 'v1',
          tree: const UiNode(type: 'root'),
          schemaVersion: '1.0.0',
          contentHash: 'hash1',
        ),
        RenderedView(
          viewId: 'v1',
          tree: const UiNode(type: 'root', children: [UiNode(type: 'text')]),
          schemaVersion: '1.0.0',
          contentHash: 'hash2',
        ),
        RenderedView(
          viewId: 'v1',
          tree: const UiNode(
              type: 'root',
              children: [UiNode(type: 'text'), UiNode(type: 'button')]),
          schemaVersion: '1.0.0',
          contentHash: 'hash3',
        ),
      ];

      for (var i = 0; i < partials.length; i++) {
        channel.emitRender(partials[i], isPartial: i < partials.length - 1);
      }
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(3));
      expect(received[0].isPartial, isTrue, reason: 'first partial');
      expect(received[1].isPartial, isTrue, reason: 'middle partial');
      expect(received[2].isPartial, isFalse, reason: 'final render');
      // Each subsequent partial grows the tree.
      expect(
        received[0].view.tree.nodeCount,
        lessThan(received[1].view.tree.nodeCount),
      );
      expect(
        received[1].view.tree.nodeCount,
        lessThan(received[2].view.tree.nodeCount),
      );
    });

    test('broadcast — multiple subscribers all receive events', () async {
      final channel = UiEventChannel();
      final a = <UiRenderEvent>[];
      final b = <UiRenderEvent>[];
      channel.events.listen(a.add);
      channel.events.listen(b.add);

      const action = SemanticAction(actionId: 'tap_1');
      channel.emitInteraction(action);
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });

    test('emitPolicy records approve/deny decisions', () async {
      final channel = UiEventChannel();
      final received = <UiRenderEventPolicy>[];
      channel.events.transform(
        StreamTransformer<UiRenderEvent, UiRenderEventPolicy>.fromHandlers(
          handleData: (event, sink) {
            if (event is UiRenderEventPolicy) sink.add(event);
          },
        ),
      ).listen(received.add);

      const action = SemanticAction(actionId: 'buy', tier: ActionTier.confirm);
      channel.emitPolicy(action, approved: false);
      channel.emitPolicy(action, approved: true);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      expect(received[0].approved, isFalse);
      expect(received[1].approved, isTrue);
    });

    test('close stops further emits silently', () async {
      final channel = UiEventChannel();
      await channel.close();
      // No throw — just a silent no-op.
      channel.emitRender(RenderedView(
        viewId: 'v1',
        tree: const UiNode(type: 'root'),
        schemaVersion: '1.0.0',
        contentHash: 'deadbeefdeadbeef',
      ));
      expect(channel.isClosed, isTrue);
    });
  });
}
