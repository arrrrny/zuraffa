// X-Ray scope overlay — renders dimming and neon bounding boxes over
// every registered XRayNode within a scope.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'xray_colors.dart';
import 'xray_detail_panel.dart';
import 'xray_mode.dart';
import 'xray_node_metadata.dart';
import 'xray_scope.dart';

/// Internal widget that wraps an [XRayScope]'s child with the visual overlay.
///
/// Renders:
/// 1. The original child (app content)
/// 2. A semi-transparent dimming layer (only for root scopes)
/// 3. Neon bounding boxes for each registered node
///
/// Touch passthrough: the dimming layer uses [IgnorePointer]; bounding box
/// interiors pass through touches. Only the nodeId label is tappable for
/// inspection.
class XRayScopeOverlay extends StatefulWidget {
  final XRayScopeState scope;
  final Widget child;

  const XRayScopeOverlay({super.key, required this.scope, required this.child});

  @override
  State<XRayScopeOverlay> createState() => XRayScopeOverlayState();
}

class XRayScopeOverlayState extends State<XRayScopeOverlay> {
  final Map<String, Rect> _nodeRects = {};
  Timer? _measureTimer;
  String? _selectedNodeId;

  bool get _isRootScope {
    return widget.scope.context.findAncestorStateOfType<XRayScopeState>() ==
        null;
  }

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(XRayScopeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _nodeRects.clear();
      _scheduleMeasure();
    }
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    super.dispose();
  }

  void _scheduleMeasure() {
    _measureTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureNodes();
      _measureTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted && XRayMode.isEnabled) {
          _measureNodes();
        }
      });
    });
  }

  void _measureNodes() {
    if (!mounted) return;
    final thisRenderBox = context.findRenderObject() as RenderBox?;
    if (thisRenderBox == null || !thisRenderBox.hasSize) return;

    final newRects = <String, Rect>{};
    for (final node in widget.scope.tree) {
      final nodeRenderBox = node.context.findRenderObject() as RenderBox?;
      if (nodeRenderBox != null && nodeRenderBox.hasSize) {
        try {
          final offset = nodeRenderBox.localToGlobal(
            Offset.zero,
            ancestor: thisRenderBox,
          );
          newRects[node.id] = offset & nodeRenderBox.size;
        } catch (_) {
          // Node may not be a descendant of this overlay.
        }
      }
    }

    if (newRects.length != _nodeRects.length ||
        !_mapsEqual(newRects, _nodeRects)) {
      setState(() {
        _nodeRects.clear();
        _nodeRects.addAll(newRects);
      });
    }
  }

  bool _mapsEqual(Map<String, Rect> a, Map<String, Rect> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final viewColor = XRayColors.forView(widget.scope.viewId);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Original child.
        widget.child,

        // 2. Dimming layer — only for root scopes.
        if (_isRootScope)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: const Color(0x66000000),
              ),
            ),
          ),

        // 3. Neon bounding boxes.
        for (final entry in _nodeRects.entries)
          _buildBoundingBox(
            rect: entry.value,
            nodeId: entry.key,
            viewColor: viewColor,
          ),

        // 4. Detail panel.
        if (_selectedNodeId != null) _buildDetailPanel(),
      ],
    );
  }

  Widget _buildBoundingBox({
    required Rect rect,
    required String nodeId,
    required Color viewColor,
  }) {
    final metadata = XRayMetadataRegistry.forNode(nodeId);
    final isEnabled = metadata?.isEnabled ?? true;
    final actionName = metadata?.actionName;
    final stateJson = metadata?.stateJson;

    final stateParts = <String>[];
    if (stateJson != null) {
      if (stateJson['loading'] == true) {
        stateParts.add('LOADING');
      } else if (stateJson['error'] != null) {
        stateParts.add('ERROR');
      } else {
        stateParts.add('OK');
      }
    }
    if (!isEnabled) stateParts.add('DISABLED');
    final stateText = stateParts.isEmpty ? null : stateParts.join(' | ');

    return Positioned(
      left: rect.left - 2,
      top: rect.top - 2,
      width: rect.width + 4,
      height: rect.height + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Border painting — wrapped in IgnorePointer so touches pass through.
          IgnorePointer(
            child: CustomPaint(
              painter: _NeonBorderPainter(
                color: viewColor,
                isEnabled: isEnabled,
              ),
            ),
          ),
          // Top label — TAPPABLE for detail inspection.
          Positioned(
            left: 0,
            top: -18,
            child: GestureDetector(
              onTap: () => _onBoxTapped(nodeId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: XRayColors.labelBackgroundFor(viewColor),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  nodeId,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          // Bottom label — read-only, IgnorePointer.
          if (actionName != null || stateText != null)
            Positioned(
              left: 0,
              bottom: -16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: XRayColors.labelBackgroundFor(viewColor),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    [
                      actionName,
                      stateText,
                    ].whereType<String>().join(' \u00B7 '),
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onBoxTapped(String nodeId) {
    setState(() {
      _selectedNodeId = _selectedNodeId == nodeId ? null : nodeId;
    });
  }

  Widget _buildDetailPanel() {
    final nodeId = _selectedNodeId!;
    final metadata = XRayMetadataRegistry.forNode(nodeId);
    return XRayDetailPanel(
      nodeId: nodeId,
      metadata: metadata,
      viewColor: XRayColors.forView(widget.scope.viewId),
      onClose: () => setState(() => _selectedNodeId = null),
    );
  }
}

/// [CustomPainter] that draws a neon-glow border around a bounding box.
class _NeonBorderPainter extends CustomPainter {
  final Color color;
  final bool isEnabled;

  _NeonBorderPainter({required this.color, required this.isEnabled});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = isEnabled ? color : color.withOpacity(0.4);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = XRayColors.glowFor(color).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);

    canvas.drawRect(rect, glowPaint);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_NeonBorderPainter oldDelegate) =>
      color != oldDelegate.color || isEnabled != oldDelegate.isEnabled;
}
