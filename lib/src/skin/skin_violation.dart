/// SkinViolation — what a broken runtime skin contract surfaces on
/// the impossible-to-miss banner (issue #1102).
///
/// The pilot's banner line was `[google-text] Continue with Google
/// renders` — row id in brackets, then the human requirement. That
/// display shape is the contract here: `toDisplayLine()` is what the
/// emitted `SkinViolationBanner` renders, and the pilot demo receipts
/// grepped exactly this line.
library;

/// Which half of the runtime contract was breached.
enum SkinViolationKind {
  /// A widget-tree row failed its check on an audited frame.
  widget,

  /// A route push did not conform to the route contract table.
  route;

  /// The stable machine name (JSON / receipts).
  String get label => switch (this) {
    SkinViolationKind.widget => 'widget',
    SkinViolationKind.route => 'route',
  };
}

/// One live contract breach: the row that failed, why it exists, and
/// (for route breaches) the route that was pushed.
class SkinViolation {
  /// A widget-contract breach.
  const SkinViolation.widget({
    required this.rowId,
    required this.requirement,
    required this.message,
  }) : kind = SkinViolationKind.widget,
       route = null;

  /// A route-contract breach (the observer's `didPush` verdict).
  const SkinViolation.route({
    required this.rowId,
    required this.requirement,
    required this.message,
    required this.route,
  }) : kind = SkinViolationKind.route;

  /// Which half of the contract was breached.
  final SkinViolationKind kind;

  /// The contract row's id (`google-text`, `route:debug-thing`).
  final String rowId;

  /// The human requirement the row encodes — what the banner shows
  /// after the id.
  final String requirement;

  /// Machine detail (what was observed vs expected).
  final String message;

  /// The pushed route name, for route breaches; null for widget
  /// breaches.
  final String? route;

  /// The banner line: `[<rowId>] <requirement>` (the pilot shape).
  String toDisplayLine() => '[$rowId] $requirement';

  /// Machine-readable shape (JSON envelope / receipts).
  Map<String, Object?> toJson() => {
    'kind': kind.label,
    'rowId': rowId,
    'requirement': requirement,
    'message': message,
    if (route != null) 'route': route,
  };

  /// Identity is the contract breach, not the clock: two violations
  /// for the same row+requirement+message+route are the SAME live
  /// finding regardless of when each was observed — the bus relies
  /// on this for change detection (no banner churn while the same
  /// chaos edit stays on screen).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkinViolation &&
          other.kind == kind &&
          other.rowId == rowId &&
          other.requirement == requirement &&
          other.message == message &&
          other.route == route;

  @override
  int get hashCode => Object.hash(kind, rowId, requirement, message, route);

  @override
  String toString() => toDisplayLine();
}
