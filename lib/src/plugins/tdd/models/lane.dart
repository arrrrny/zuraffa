/// Lane declarations for the engine/skin split (issue #1000).
///
/// A spec's `## Lanes` section declares which behaviors are pure Dart
/// engine ([Lane.core] — `flutter_allowed: false`), Flutter skin
/// ([Lane.skin] — `flutter_allowed: true`, optionally carrying the
/// AdaptiveViewSlots the skin must provide), or the shared seam
/// ([Lane.both] — `flutter_allowed: conditionally`, asserted on both
/// sides).
///
/// The declaration is the rung-1 lane contract — the engine/skin axis
/// analog of the `**Type**` subject-kind markers: declarations win,
/// gaps refuse (never default silently), and `zfa tdd plan` enforces the
/// boundary at plan time (the noFlutter guard).
library;

/// One declared lane of the spec's `## Lanes` section.
class LaneDeclaration {
  const LaneDeclaration({
    required this.lane,
    required this.behaviorIds,
    this.flutterAllowed = '',
    this.adaptiveSlots = const [],
    this.annotations = const {},
  });

  /// The declared lane name, normalized uppercase (`CORE`, `SKIN`,
  /// `BOTH`). An unknown name parses verbatim; plan refuses it (the
  /// grammar is CORE/SKIN/BOTH only).
  final String lane;

  /// The declared behavior ids, with `U1-U6` ranges expanded and
  /// parenthetical annotations stripped (`A3 (acceptance: ...)` -> `A3`).
  final List<String> behaviorIds;

  /// The verbatim `flutter_allowed` value (`false` / `true` /
  /// `conditionally`) — documentation the noFlutter guard consults for
  /// the CORE lane.
  final String flutterAllowed;

  /// The SKIN lane's `adaptive_slots` — the adaptive-layout contract
  /// slots (e.g. `mobile`, `ios`, `android`, `macos`) the skin must
  /// provide; rendered into `04-SKIN.md` and `04-CONTRACT.md`.
  final List<String> adaptiveSlots;

  /// Parenthetical annotations keyed by behavior id — the lane's
  /// hand-written description for ids the spec prose does not derive
  /// (the `W1-W4` skin rows).
  final Map<String, String> annotations;

  @override
  String toString() =>
      'LaneDeclaration($lane, behaviors: $behaviorIds, '
      'flutterAllowed: "$flutterAllowed", adaptiveSlots: $adaptiveSlots)';
}

/// The engine/skin lane a behavior belongs to (issue #1000).
enum Lane {
  /// Pure Dart engine — zero Flutter references, plan-enforced.
  core,

  /// Flutter skin — AdaptiveViewSlots contract slots.
  skin,

  /// The shared seam — one behavior asserted on both sides.
  both;

  /// The lane name as the spec grammar writes it.
  String get label => switch (this) {
    Lane.core => 'CORE',
    Lane.skin => 'SKIN',
    Lane.both => 'BOTH',
  };

  /// Parse the declared lane name (case-insensitive); null when the
  /// name is not one of the three grammar lanes.
  static Lane? parse(String name) {
    final normalized = name.trim().toUpperCase();
    for (final lane in Lane.values) {
      if (lane.label == normalized) return lane;
    }
    return null;
  }

  /// Whether behaviors of this lane are destined for the engine plan
  /// (`04-ENGINE.md`): CORE outright, BOTH as the engine-side copy of
  /// the seam.
  bool get destinedForEngine => this == Lane.core || this == Lane.both;

  /// Whether behaviors of this lane are destined for the skin plan
  /// (`04-SKIN.md`): SKIN outright, BOTH as the skin-side copy.
  bool get destinedForSkin => this == Lane.skin || this == Lane.both;
}
