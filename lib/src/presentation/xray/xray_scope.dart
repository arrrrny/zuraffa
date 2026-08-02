import 'package:flutter/widgets.dart';

import 'xray_mode.dart';
import 'xray_scope_overlay.dart';

/// Information about a registered X-Ray node.
class XRayNodeInfo {
  /// The deterministic node ID string (e.g. "ProductView.actionButton").
  final String id;

  /// The enum value name (e.g. "actionButton").
  final String enumName;

  /// The node's BuildContext (for later bounding-box capture in Track 4.2).
  final BuildContext context;

  const XRayNodeInfo({
    required this.id,
    required this.enumName,
    required this.context,
  });
}

/// A widget that wraps a view and provides X-Ray scope context.
///
/// [XRayScope] maintains a registry of child [XRayNode] widgets and
/// exposes [tree] for traversing all registered nodes.
///
/// When [XRayMode.isEnabled] is false (default), this is a pure pass-through.
///
/// Usage in generated code:
/// ```dart
/// Widget get view {
///   return XRayScope(
///     viewId: 'ProductView',
///     child: Scaffold(
///       key: globalKey,
///       appBar: AppBar(title: const Text('Product')),
///       body: ControlledWidgetBuilder<...>(...),
///     ),
///   );
/// }
/// ```
class XRayScope extends StatefulWidget {
  /// Unique identifier for this view scope (e.g. 'ProductView').
  final String viewId;

  /// Optional metadata about the view.
  final Map<String, String>? metadata;

  /// The view widget tree.
  final Widget child;

  const XRayScope({
    super.key,
    required this.viewId,
    this.metadata,
    required this.child,
  });

  /// Find the nearest [XRayScopeState] from [context].
  static XRayScopeState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<XRayScopeState>();
  }

  @override
  State<XRayScope> createState() => XRayScopeState();
}

class XRayScopeState extends State<XRayScope> {
  final Map<String, XRayNodeInfo> _nodes = {};
  bool _active = false;

  /// The view ID for this scope.
  String get viewId => widget.viewId;

  /// Whether X-Ray mode is currently active for this scope.
  bool get isActive => _active;

  /// Returns a traversable list of all registered nodes in registration order.
  List<XRayNodeInfo> get tree => _nodes.values.toList();

  /// Look up a node by its deterministic string ID.
  XRayNodeInfo? nodeById(String id) => _nodes[id];

  /// Register a node with this scope.
  void register<T extends Enum>(BuildContext context, T nodeId) {
    final id = '${widget.viewId}.${nodeId.name}';
    _nodes[id] = XRayNodeInfo(
      id: id,
      enumName: nodeId.name,
      context: context,
    );
  }

  /// Unregister a node from this scope.
  void unregister<T extends Enum>(T nodeId) {
    final id = '${widget.viewId}.${nodeId.name}';
    _nodes.remove(id);
  }

  @override
  void initState() {
    super.initState();
    _active = XRayMode.isEnabled;
    XRayMode.notifier.addListener(_onXRayModeChanged);
  }

  @override
  void dispose() {
    XRayMode.notifier.removeListener(_onXRayModeChanged);
    super.dispose();
  }

  void _onXRayModeChanged() {
    final shouldActivate = XRayMode.isEnabled;
    if (shouldActivate != _active) {
      setState(() {
        _active = shouldActivate;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldActivate = XRayMode.isEnabled;
    if (shouldActivate != _active) {
      setState(() {
        _active = shouldActivate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return widget.child;
    }

    return _XRayScopeInherited(
      state: this,
      child: XRayScopeOverlay(
        scope: this,
        child: widget.child,
      ),
    );
  }
}

class _XRayScopeInherited extends InheritedWidget {
  final XRayScopeState state;

  const _XRayScopeInherited({
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_XRayScopeInherited oldWidget) => true;
}