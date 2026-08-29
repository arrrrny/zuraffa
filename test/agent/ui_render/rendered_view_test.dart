import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/rendered_view.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';

void main() {
  group('RenderedView', () {
    test('rendered_view_coexists_with_host_chrome — renderSlot contract', () {
      // The host chrome owns navigation, sheets, tab bars. The agent-rendered
      // view occupies a named slot (FR-007). The default slot is
      // `mission-canvas` — the contract is that the host chrome and the
      // agent view never overlap because the host only renders chrome outside
      // the named slot.
      final view = RenderedView(
        viewId: 'v1',
        tree: const UiNode(
          type: 'root',
          children: [
            UiNode(type: 'text', props: {'label': 'hi'}),
          ],
        ),
        schemaVersion: '1.0.0',
        contentHash: 'deadbeefdeadbeef',
      );
      expect(view.renderSlot, 'mission-canvas');
      expect(view.renderSlot, isNot('nav-bar'));
      expect(view.renderSlot, isNot('tab-bar'));
      expect(view.renderSlot, isNot('sheet'));
      expect(view.isActive, isTrue);
    });

    test('custom render slot is honored', () {
      final view = RenderedView(
        viewId: 'v1',
        tree: const UiNode(type: 'root'),
        schemaVersion: '1.0.0',
        contentHash: 'deadbeefdeadbeef',
        renderSlot: 'results-pane',
      );
      expect(view.renderSlot, 'results-pane');
    });

    test('contentHash is deterministic for equivalent trees', () {
      const a = UiNode(
        type: 'root',
        children: [UiNode(type: 'card', styleToken: 'primary')],
      );
      const b = UiNode(
        type: 'root',
        children: [UiNode(type: 'card', styleToken: 'primary')],
      );
      expect(computeContentHash(a), computeContentHash(b));
    });

    test('contentHash differs for different trees', () {
      const a = UiNode(
        type: 'root',
        children: [UiNode(type: 'card', styleToken: 'primary')],
      );
      const b = UiNode(
        type: 'root',
        children: [UiNode(type: 'card', styleToken: 'secondary')],
      );
      expect(computeContentHash(a), isNot(computeContentHash(b)));
    });

    test('contentHash is stable across prop key insertion order', () {
      const a = UiNode(type: 'text', props: {'a': 1, 'b': 2});
      const b = UiNode(type: 'text', props: {'b': 2, 'a': 1});
      expect(computeContentHash(a), computeContentHash(b));
    });
  });
}
