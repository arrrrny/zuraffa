import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../theme/app_theme.dart';
import '../models/scan_mode.dart';

/// Floating vertical dock with the scan-mode overlay buttons.
///
/// The "fruit" and "meat" buttons switch the camera from barcode scanning to
/// ML Kit object detection; the "text" button switches to text detection of
/// in-store price tags. Tapping the active mode re-runs its scan.
class ScanModeDock extends StatelessWidget {
  const ScanModeDock({
    super.key,
    required this.activeMode,
    required this.enabled,
    this.onModeTap,
  });

  final ScanMode activeMode;

  /// Dock is disabled while a scan / compare is in progress.
  final bool enabled;

  final ValueChanged<ScanMode>? onModeTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final mode in ScanMode.values) ...[
          _DockButton(
            mode: mode,
            active: mode == activeMode,
            enabled: enabled,
            color: shad.colorScheme.primary,
            onTap: () => onModeTap?.call(mode),
          ),
          if (mode != ScanMode.values.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.mode,
    required this.active,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final ScanMode mode;
  final bool active;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final fg = active ? shad.colorScheme.primaryForeground : shad.colorScheme.foreground;

    return Tooltip(
      message: mode.label,
      waitDuration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: active
                ? color
                : AppTheme.backgroundRaised.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? color
                  : shad.colorScheme.border.withValues(alpha: 0.8),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(mode.icon, size: 21, color: fg),
              if (active)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
