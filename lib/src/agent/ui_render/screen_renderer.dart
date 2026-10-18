/// Vocabulary v2 — renderer for the three supported layouts (issue #818).
///
/// Takes a [ScreenDoc] and produces a concrete [UiNode] tree laid out for the
/// requested layout. The renderer is pure-Dart and deterministic so its output
/// can be golden-compared.
library;

import 'screen_doc.dart';
import 'ui_vocabulary_schema.dart';

/// Renders a [ScreenDoc] into a layout-specific [UiNode] tree.
class ScreenRenderer {
  const ScreenRenderer();

  /// Render [doc] according to its [LayoutKind].
  UiNode render(ScreenDoc doc) {
    switch (doc.layout) {
      case LayoutKind.listDetail:
        return _renderListDetail(doc);
      case LayoutKind.form:
        return _renderForm(doc);
      case LayoutKind.dashboard:
        return _renderDashboard(doc);
    }
  }

  UiNode _renderListDetail(ScreenDoc doc) {
    return UiNode(
      type: 'container',
      role: 'screen',
      label: doc.name,
      props: <String, Object?>{'layout': 'list-detail'},
      children: <UiNode>[
        UiNode(
          type: 'container',
          role: 'list',
          label: '${doc.name} list',
          props: const <String, Object?>{'region': 'list'},
          children: <UiNode>[doc.root],
        ),
        UiNode(
          type: 'container',
          role: 'detail',
          label: '${doc.name} detail',
          props: const <String, Object?>{'region': 'detail'},
        ),
      ],
    );
  }

  UiNode _renderForm(ScreenDoc doc) {
    return UiNode(
      type: 'container',
      role: 'screen',
      label: doc.name,
      props: const <String, Object?>{'layout': 'form'},
      children: <UiNode>[
        UiNode(
          type: 'container',
          role: 'form',
          label: '${doc.name} form',
          props: const <String, Object?>{'region': 'form'},
          children: <UiNode>[doc.root],
        ),
        UiNode(
          type: 'container',
          role: 'actions',
          label: 'form actions',
          props: const <String, Object?>{'region': 'actions'},
        ),
      ],
    );
  }

  UiNode _renderDashboard(ScreenDoc doc) {
    return UiNode(
      type: 'container',
      role: 'screen',
      label: doc.name,
      props: const <String, Object?>{'layout': 'dashboard'},
      children: <UiNode>[
        UiNode(
          type: 'container',
          role: 'header',
          label: '${doc.name} header',
          props: const <String, Object?>{'region': 'header'},
        ),
        UiNode(
          type: 'container',
          role: 'body',
          label: '${doc.name} body',
          props: const <String, Object?>{'region': 'body'},
          children: <UiNode>[doc.root],
        ),
        UiNode(
          type: 'container',
          role: 'footer',
          label: '${doc.name} footer',
          props: const <String, Object?>{'region': 'footer'},
        ),
      ],
    );
  }
}
