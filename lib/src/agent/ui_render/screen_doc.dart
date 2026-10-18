/// Vocabulary v2 — agent-renderable screen documents (issue #818).
///
/// A `ScreenDoc` is the verifiable intermediate representation an agent emits
/// instead of a raw widget tree: a layout kind (list-detail / form /
/// dashboard), a root [UiNode] tree annotated with semantic roles, labels and
/// data bindings, plus the set of states the screen must cover.
library;

import 'ui_vocabulary_schema.dart';

/// The three layouts the v2 renderer supports (issue #818 first slice).
enum LayoutKind { listDetail, form, dashboard }

/// A vocabulary document describing a screen.
class ScreenDoc {
  /// Layout the renderer should produce.
  final LayoutKind layout;

  /// Human-readable screen name (e.g. "Notes").
  final String name;

  /// Root node of the described screen.
  final UiNode root;

  /// States the screen must render/cover (e.g. loading, empty, error, data).
  final List<String> states;

  /// Optional data bindings declared at document level.
  final List<UiBinding> bindings;

  const ScreenDoc({
    required this.layout,
    required this.name,
    required this.root,
    this.states = const <String>['loading', 'empty', 'error', 'data'],
    this.bindings = const <UiBinding>[],
  });

  /// Serialize to a canonical map (for golden comparison / persistence).
  Map<String, Object?> toJson() => <String, Object?>{
    'layout': layout.name,
    'name': name,
    'states': states,
    'bindings': bindings.map((b) => b.toJson()).toList(),
    'root': _nodeToJson(root),
  };

  static Map<String, Object?> _nodeToJson(UiNode n) => <String, Object?>{
    'type': n.type,
    if (n.role != null) 'role': n.role,
    if (n.label != null) 'label': n.label,
    if (n.styleToken != null) 'styleToken': n.styleToken,
    if (n.actionId != null) 'actionId': n.actionId,
    if (n.props.isNotEmpty) 'props': n.props,
    if (n.bindings.isNotEmpty)
      'bindings': n.bindings.map((b) => b.toJson()).toList(),
    if (n.children.isNotEmpty) 'children': n.children.map(_nodeToJson).toList(),
  };

  factory ScreenDoc.fromJson(Map<String, Object?> json) {
    final layoutName = (json['layout'] ?? 'listDetail').toString();
    final layout = LayoutKind.values.firstWhere(
      (l) => l.name == layoutName,
      orElse: () => LayoutKind.listDetail,
    );
    return ScreenDoc(
      layout: layout,
      name: (json['name'] ?? '').toString(),
      root: _nodeFromJson(json['root'] as Map<String, Object?>? ?? const {}),
      states:
          (json['states'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>['loading', 'empty', 'error', 'data'],
      bindings:
          (json['bindings'] as List?)
              ?.map((e) => UiBinding.fromJson(e as Map<String, Object?>))
              .toList() ??
          const <UiBinding>[],
    );
  }

  static UiNode _nodeFromJson(Map<String, Object?> json) => UiNode(
    type: (json['type'] ?? 'container').toString(),
    role: json['role']?.toString(),
    label: json['label']?.toString(),
    styleToken: json['styleToken']?.toString(),
    actionId: json['actionId']?.toString(),
    props:
        (json['props'] is Map
            ? (json['props'] as Map).cast<String, Object?>()
            : null) ??
        const <String, Object?>{},
    bindings:
        (json['bindings'] as List?)
            ?.map((e) => UiBinding.fromJson(e as Map<String, Object?>))
            .toList() ??
        const <UiBinding>[],
    children:
        (json['children'] as List?)
            ?.map((e) => _nodeFromJson(e as Map<String, Object?>))
            .toList() ??
        const <UiNode>[],
  );
}
