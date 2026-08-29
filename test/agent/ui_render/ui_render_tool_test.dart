import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/semantic_action.dart';
import 'package:zuraffa/src/agent/ui_render/ui_event_channel.dart';
import 'package:zuraffa/src/agent/ui_render/ui_render_event.dart';
import 'package:zuraffa/src/agent/ui_render/ui_render_tool.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';
import 'package:zuraffa/src/agent/ui_render/vocabulary_narrowing.dart';

void main() {
  group('UiRenderTool', () {
    late UiRenderTool tool;

    setUp(() {
      tool = UiRenderTool(idGenerator: _sequentialIds);
      tool.activateMission('default');
    });

    test('ui_render_tool_accepts_valid_tree_returns_view_id', () {
      const tree = UiNode(type: 'root', children: [
        UiNode(type: 'card', styleToken: 'primary', children: [
          UiNode(type: 'text', props: {'label': 'Hello'}),
          UiNode(type: 'button', actionId: 'tap_1'),
        ]),
      ]);

      final view = tool.render(tree);

      expect(view.viewId, isNotEmpty);
      expect(view.tree, same(tree));
      expect(view.schemaVersion, '1.0.0');
      expect(view.contentHash, isNotEmpty);
      expect(view.isActive, isTrue);
    });

    test('render records the view in the mission trace', () {
      const tree = UiNode(type: 'root', children: [UiNode(type: 'text')]);
      final view = tool.render(tree);

      final entry = tool.recorder.replay(view.viewId);
      expect(entry, isNotNull);
      expect(entry!.viewId, view.viewId);
      expect(entry.schemaVersion, view.schemaVersion);
      expect(entry.contentHash, view.contentHash);
      expect(entry.missionType, 'default');
    });

    test('render emits UiRenderEventRender then UiRenderEventDone', () async {
      final channel = UiEventChannel();
      tool = UiRenderTool(
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      const tree = UiNode(type: 'root', children: [UiNode(type: 'text')]);
      tool.render(tree);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      expect(received[0], isA<UiRenderEventRender>());
      expect(received[1], isA<UiRenderEventDone>());
      expect((received[0] as UiRenderEventRender).isPartial, isFalse);
      expect(
        (received[1] as UiRenderEventDone).viewId,
        (received[0] as UiRenderEventRender).view.viewId,
      );
    });

    test('replace_view_id_replaces_existing_view', () async {
      final channel = UiEventChannel();
      tool = UiRenderTool(
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      const first = UiNode(type: 'root', children: [UiNode(type: 'text')]);
      final firstView = tool.render(first);
      final firstId = firstView.viewId;

      const second = UiNode(
        type: 'root',
        children: [UiNode(type: 'card', styleToken: 'primary')],
      );
      final secondView = tool.render(second, replaceViewId: firstId);
      await Future<void>.delayed(Duration.zero);

      // Same view id (FR-001 acceptance 2 — "new tree replaces the previous
      // view content").
      expect(secondView.viewId, firstId);

      // The current view under that id now carries the new tree (the previous
      // render content is superseded).
      expect(tool.view(firstId)!.tree, same(second));
      expect(tool.view(firstId)!.isActive, isTrue);

      // A UiRenderEventReplace is emitted (not UiRenderEventRender).
      await Future<void>.delayed(Duration.zero);
      final replaceEvents =
          received.whereType<UiRenderEventReplace>().toList();
      expect(replaceEvents, hasLength(1));
      expect(replaceEvents.first.replacedViewId, firstId);
      expect(replaceEvents.first.view.viewId, firstId);
    });

    test('ui_render_tool_rejects_unknown_node_type', () {
      const tree = UiNode(type: 'root', children: [
        UiNode(type: 'mystery_widget'),
      ]);
      expect(
        () => tool.render(tree),
        throwsA(isA<UiRenderValidationException>()),
      );
    });

    test('ui_render_tool_rejects_bad_token', () {
      const tree = UiNode(type: 'root', children: [
        UiNode(type: 'card', styleToken: 'rainbow'),
      ]);
      expect(
        () => tool.render(tree),
        throwsA(isA<UiRenderValidationException>()),
      );
    });

    test('ui_render_tool_rejects_cap_overflow', () {
      final children = List<UiNode>.generate(
        10,
        (_) => const UiNode(type: 'text'),
      );
      // Local tool with a tiny cap.
      final smallCapTool = UiRenderTool(
        baseSchema: const UiVocabularySchema(
          allowedNodeTypes: {'root', 'text'},
          allowedStyleTokens: {},
          nodeCap: 5,
        ),
        idGenerator: _sequentialIds,
      );
      smallCapTool.activateMission('default');
      final tree = UiNode(type: 'root', children: children);
      expect(
        () => smallCapTool.render(tree),
        throwsA(isA<UiRenderValidationException>()),
      );
    });

    test('emitError on validation failure', () async {
      final channel = UiEventChannel();
      tool = UiRenderTool(
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      expect(
        () => tool.render(const UiNode(type: 'root', children: [
          UiNode(type: 'mystery_widget'),
        ])),
        throwsA(isA<UiRenderValidationException>()));

      await Future<void>.delayed(Duration.zero);
      expect(
        received.whereType<UiRenderEventError>(),
        hasLength(1),
      );
    });

    test('no_active_mission_error', () {
      final deadTool = UiRenderTool(idGenerator: _sequentialIds);
      // No activateMission called.
      expect(
        () => deadTool.render(const UiNode(type: 'root')),
        throwsA(isA<NoActiveMissionException>()),
      );
    });

    test('replace_view_id_unknown_returns_view_not_found', () {
      expect(
        () => tool.render(
          const UiNode(type: 'root', children: [UiNode(type: 'text')]),
          replaceViewId: 'does-not-exist',
        ),
        throwsA(isA<ViewNotFoundException>()),
      );
    });

    test('rapid_render_calls_last_wins', () {
      // Edge Cases — "two rapid ui.render calls race" — last call wins and
      // replaces the view; earlier calls return `rendered: true` but their
      // content is superseded.
      final first = tool.render(
        const UiNode(type: 'root', children: [UiNode(type: 'text')]),
      );
      final second = tool.render(
        const UiNode(type: 'root', children: [UiNode(type: 'card')]),
      );

      expect(first.viewId, isNot(second.viewId));
      expect(first.isActive, isTrue,
          reason: 'the earlier view itself is valid; "last wins" applies to '
              'what is currently displayed');
      expect(tool.activeView!.viewId, second.viewId,
          reason: 'most-recent render is the active view');
    });

    test('renderProgressive emits partial events then a final render', () async {
      final channel = UiEventChannel();
      tool = UiRenderTool(
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      final received = <UiRenderEventRender>[];
      channel.events
          .transform(StreamTransformer<UiRenderEvent, UiRenderEventRender>.fromHandlers(
            handleData: (event, sink) {
              if (event is UiRenderEventRender) sink.add(event);
            },
          ))
          .listen(received.add);

      final partials = Stream<UiNode>.fromIterable([
        const UiNode(type: 'root', children: [UiNode(type: 'text')]),
        const UiNode(type: 'root', children: [
          UiNode(type: 'text'),
          UiNode(type: 'button'),
        ]),
      ]);

      final views = await tool.renderProgressive(partials).toList();
      await Future<void>.delayed(Duration.zero);

      expect(views, hasLength(2));
      expect(views.first.viewId, views.last.viewId,
          reason: 'partial renders share a view id');
      expect(received.last.isPartial, isFalse,
          reason: 'final render is non-partial');
      expect(received.first.isPartial, isTrue);
    });

    test('vocabulary narrowing applied when mission is configured', () {
      const listing = UiVocabularySchema(
        allowedNodeTypes: {'root', 'card', 'text', 'button'},
        allowedStyleTokens: {'primary', 'secondary'},
        nodeCap: 32,
        schemaVersion: '1.0.0-listing',
        missionType: 'listing',
      );
      const config = VocabularyNarrowingConfig({'listing': listing});

      tool = UiRenderTool(
        narrowingConfig: config,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('listing');

      // `image` is allowed in the base schema but excluded by the listing
      // narrowing.
      const tree = UiNode(type: 'root', children: [
        UiNode(type: 'card', children: [UiNode(type: 'image')]),
      ]);
      expect(
        () => tool.render(tree),
        throwsA(isA<UiRenderValidationException>()),
        reason: 'image is out of the listing subset (FR-005)',
      );
    });

    test('renderProgressive empty stream still emits Done (no host hang)',
        () async {
      final channel = UiEventChannel();
      tool = UiRenderTool(
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      final views = await tool.renderProgressive(const Stream<UiNode>.empty()).toList();
      await Future<void>.delayed(Duration.zero);

      expect(views, isEmpty, reason: 'no partials yielded');
      // The view id was minted, so the host must still receive a Done event
      // or it would await forever.
      expect(
        received.whereType<UiRenderEventDone>(),
        hasLength(1),
        reason: 'empty partials stream still closes the view with Done',
      );
    });

    test('renderProgressive drops stale view on mid-stream validation failure',
        () async {
      final channel = UiEventChannel();
      tool = UiRenderTool(
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      final partials = Stream<UiNode>.fromIterable([
        const UiNode(type: 'root', children: [UiNode(type: 'text')]),
        const UiNode(type: 'root', children: [UiNode(type: 'mystery_widget')]),
      ]);

      final views = await tool.renderProgressive(partials).toList();
      await Future<void>.delayed(Duration.zero);

      // The valid first partial is still yielded, but the failing second one
      // must not leave a partial tree behind.
      expect(views, hasLength(1));
      final viewId = views.first.viewId;
      expect(tool.view(viewId), isNull,
          reason: 'partial view removed after mid-stream failure');
      // The view is closed so the host does not block forever.
      expect(
        received.whereType<UiRenderEventDone>(),
        hasLength(1),
        reason: 'view closed with Done after failure',
      );
    });
  });

  group('UiRenderTool routeInteraction (FR-004 / FR-006)', () {
    test('semantic_action_routed_to_agent', () async {
      final router = CapturingActionRouter();
      final channel = UiEventChannel();
      final tool = UiRenderTool(
        actionRouter: router,
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      // Render a view so the action can be associated with a view id.
      final view = tool.render(const UiNode(type: 'root', children: [
        UiNode(type: 'button', actionId: 'select_offer'),
      ]));

      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      // Simulate the user tapping the button.
      const action = SemanticAction(actionId: 'select_offer', args: {
        'offerId': 42,
      });
      final delivered = await tool.routeInteraction(action);
      await Future<void>.delayed(Duration.zero);

      expect(delivered, isNotNull);
      expect(delivered!.actionId, 'select_offer');
      expect(delivered.args, {'offerId': 42});
      expect(delivered.viewId, view.viewId,
          reason: 'action is stamped with the rendered view id');

      // Router received the action — the loop is closed (FR-004).
      expect(router.delivered, hasLength(1));
      expect(router.delivered.first.actionId, 'select_offer');

      // An interaction event was emitted.
      expect(
        received.whereType<UiRenderEventInteraction>(),
        hasLength(1),
      );
    });

    test('confirm-tier action is blocked until approved (FR-006)', () async {
      final router = CapturingActionRouter();
      final channel = UiEventChannel();
      final tool = UiRenderTool(
        actionRouter: router,
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      const action = SemanticAction(
        actionId: 'buy',
        tier: ActionTier.confirm,
      );

      final future = tool.routeInteraction(action);
      // Yield once to allow the gate to enqueue the pending decision.
      await Future<void>.delayed(Duration.zero);
      expect(router.delivered, isEmpty, reason: 'not yet approved');

      // Approve and await.
      tool.policyGate.approveLatest();
      final delivered = await future;
      await Future<void>.delayed(Duration.zero);

      expect(delivered, isNotNull);
      expect(router.delivered, hasLength(1));
    });

    test('confirm-tier action denied — never reaches the agent', () async {
      final router = CapturingActionRouter();
      final channel = UiEventChannel();
      final tool = UiRenderTool(
        actionRouter: router,
        channel: channel,
        idGenerator: _sequentialIds,
      );
      tool.activateMission('default');

      final received = <UiRenderEvent>[];
      channel.events.listen(received.add);

      const action = SemanticAction(
        actionId: 'buy',
        tier: ActionTier.confirm,
      );
      final future = tool.routeInteraction(action);
      tool.policyGate.denyLatest();
      final delivered = await future;
      await Future<void>.delayed(Duration.zero);

      expect(delivered, isNull, reason: 'denied actions do not reach agent');
      expect(router.delivered, isEmpty);

      // A denied policy event is emitted.
      expect(
        received.whereType<UiRenderEventPolicy>().where((e) => !e.approved),
        hasLength(1),
      );
    });

    test('routeInteraction attributes a view-less action to the active view',
        () async {
      final router = CapturingActionRouter();
      final tool = UiRenderTool(actionRouter: router, idGenerator: _sequentialIds);
      tool.activateMission('default');

      final first = tool.render(const UiNode(type: 'root', children: [
        UiNode(type: 'button', actionId: 'first'),
      ]));
      final second = tool.render(const UiNode(type: 'root', children: [
        UiNode(type: 'button', actionId: 'second'),
      ]));

      // Deactivate the chronologically-last-rendered view (e.g. it was
      // replaced/superseded but is still retained in `_views`). An interaction
      // must NOT be attributed to it.
      tool.view(second.viewId)!.isActive = false;

      // Host emits a view-less SemanticAction. It must be stamped with the
      // *active* view (first), not the last-rendered one (second).
      final action = SemanticAction(actionId: 'tap', args: {'x': 1});
      final delivered = await tool.routeInteraction(action);

      expect(delivered, isNotNull);
      expect(delivered!.viewId, first.viewId,
          reason: 'action attributed to the active view, not the '
              'chronologically-last-rendered one');
    });
  });
}

int _seq = 0;
String _sequentialIds() => 'view_${_seq++}';
