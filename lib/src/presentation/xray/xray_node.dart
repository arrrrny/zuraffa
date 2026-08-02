import 'package:flutter/widgets.dart';

import 'xray_mode.dart';
import 'xray_scope.dart';

/// A widget that wraps an interactive element with a deterministic [nodeId].
///
/// [XRayNode] is generic over an enum for compile-time safety:
/// ```dart
/// XRayNode(nodeId: ProductViewNode.actionButton, child: ElevatedButton(...))
/// ```
///
/// Renaming or deleting an enum value causes a compiler error at every
/// XRayNode reference point — this is the core safety guarantee.
///
/// When [XRayMode.isEnabled] is false (default), this widget is a pure
/// pass-through — it returns [child] directly with no allocations.
class XRayNode<T extends Enum> extends StatelessWidget {
  /// The strongly-typed node identifier (must be an enum value).
  final T nodeId;

  /// The child widget to wrap.
  final Widget child;

  const XRayNode({
    super.key,
    required this.nodeId,
    required this.child,
  });

  /// Deterministic string ID: `"$viewId.$nodeEnumName"`.
  ///
  /// Only valid when a parent [XRayScope] is present.
  static String nodeIdFor<T extends Enum>(BuildContext context, T nodeId) {
    final scope = XRayScope.maybeOf(context);
    return scope != null
        ? '${scope.viewId}.${nodeId.name}'
        : nodeId.name;
  }

  @override
  Widget build(BuildContext context) {
    if (!XRayMode.isEnabled) {
      return child;
    }

    return _XRayNodeWidget<T>(
      nodeId: nodeId,
      child: child,
    );
  }
}

class _XRayNodeWidget<T extends Enum> extends StatefulWidget {
  final T nodeId;
  final Widget child;

  const _XRayNodeWidget({
    required this.nodeId,
    required this.child,
  });

  @override
  State<_XRayNodeWidget<T>> createState() => _XRayNodeWidgetState<T>();
}

class _XRayNodeWidgetState<T extends Enum>
    extends State<_XRayNodeWidget<T>> {
  XRayScopeState? _cachedScope;

  @override
  void initState() {
    super.initState();
    _cachedScope = XRayScope.maybeOf(context);
    _cachedScope?.register(context, widget.nodeId);
  }

  @override
  void dispose() {
    _cachedScope?.unregister(widget.nodeId);
    _cachedScope = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
