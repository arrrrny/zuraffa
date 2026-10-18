/// Vocabulary v2 — a sample "notes app" screen document (issue #818).
///
/// Provides a ready-made [ScreenDoc] for the notes app so the renderer and
/// verifier have a concrete, golden-comparable artifact.
library;

import 'screen_doc.dart';
import 'ui_vocabulary_schema.dart';

/// Builds the canonical notes-app screen document (list-detail layout).
ScreenDoc buildNotesScreenDoc() {
  return ScreenDoc(
    layout: LayoutKind.listDetail,
    name: 'Notes',
    states: const <String>['loading', 'empty', 'error', 'data'],
    root: UiNode(
      type: 'list',
      role: 'list',
      label: 'Notes list',
      props: const <String, Object?>{'width': 360, 'height': 640},
      bindings: const <UiBinding>[UiBinding(source: 'notes', target: 'items')],
      children: <UiNode>[
        UiNode(
          type: 'card',
          role: 'card',
          label: 'Note card',
          props: const <String, Object?>{'width': 360, 'height': 72},
          actionId: 'open_note',
          children: <UiNode>[
            UiNode(
              type: 'text',
              role: 'text',
              label: 'Note title',
              props: const <String, Object?>{'width': 48, 'height': 48},
              bindings: const <UiBinding>[
                UiBinding(source: 'note.title', target: 'text'),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
