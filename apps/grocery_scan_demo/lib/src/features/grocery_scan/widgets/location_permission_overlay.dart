import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../theme/app_theme.dart';

/// First-run location permission overlay.
///
/// Mock of the OS permission prompt — the feature needs location so nearby
/// stores and their distances ("Walmart · 1.4 mi") can be shown on the camera.
class LocationPermissionOverlay extends StatefulWidget {
  const LocationPermissionOverlay({super.key, required this.onResult});

  /// Called with `true` when the user allows location access.
  final ValueChanged<bool> onResult;

  @override
  State<LocationPermissionOverlay> createState() =>
      _LocationPermissionOverlayState();
}

class _LocationPermissionOverlayState extends State<LocationPermissionOverlay> {
  bool _requesting = false;

  Future<void> _decide(bool allow) async {
    if (_requesting) return;
    if (!allow) {
      widget.onResult(false);
      return;
    }
    setState(() => _requesting = true);
    // Simulated OS latency is inside the provider; here we only animate.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    widget.onResult(true);
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.62),
            AppTheme.background.withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.94, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppTheme.backgroundRaised.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: shad.colorScheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        shad.colorScheme.primary.withValues(alpha: 0.35),
                        shad.colorScheme.primary.withValues(alpha: 0.10),
                      ],
                    ),
                  ),
                  child: Icon(
                    LucideIcons.mapPin,
                    size: 30,
                    color: shad.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Compare prices in-store',
                  style: TextStyle(
                    color: shad.colorScheme.foreground,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ZikZak finds the item in front of your camera and shows '
                  'live prices from stores near you — Walmart is 1.4 mi away. '
                  'Location is only used while the camera is open.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: shad.colorScheme.mutedForeground,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                ShadButton(
                  size: ShadButtonSize.lg,
                  onPressed: _requesting ? null : () => _decide(true),
                  child: _requesting
                      ? SizedBox(
                          width: 180,
                          child: ShadProgress(
                            value: null,
                            minHeight: 4,
                            color: shad.colorScheme.primaryForeground,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.mapPin, size: 16),
                            SizedBox(width: 8),
                            Text('Allow location'),
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _requesting ? null : () => _decide(false),
                  child: Text(
                    'Not now',
                    style: TextStyle(color: shad.colorScheme.mutedForeground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
