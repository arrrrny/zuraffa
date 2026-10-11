/// SkinAuditScheduler — subscribe-don't-poll (issue #1102, pilot
/// lesson 5).
///
/// The pilot's auditor rescheduled a post-frame callback on EVERY
/// post frame — `pumpAndSettle` could never settle (the callback
/// chain kept the frame pipeline busy forever). The productized
/// scheduler inverts the direction of control:
///
/// * real signals (dependency changes, route events, view updates)
///   call [markDirty] — nothing schedules itself;
/// * the emitted auditor asks [consumeDirty] once per frame: `true`
///   means "audit NOW", `false` means "the tree is quiet, do
///   nothing";
/// * dirty marks COALESCE — ten signals between two frames still
///   cost exactly one audit.
///
/// The scheduler has no timers, no callbacks, no self-rescheduling:
/// a quiet tree runs zero audits, and `pumpAndSettle` settles.
library;

class SkinAuditScheduler {
  final Set<String> _reasons = {};
  var _dirty = false;
  var _auditCount = 0;

  /// Whether a signal marked the tree dirty since the last audit.
  bool get isDirty => _dirty;

  /// How many audits actually ran (diagnostics: the pilot's
  /// polling auditor would show one per frame; the productized one
  /// shows one per real change).
  int get auditCount => _auditCount;

  /// The reasons the current dirty mark collected (banner
  /// diagnostics + receipts).
  Set<String> get dirtyReasons => Set.unmodifiable(_reasons);

  /// A real signal happened (dependency changed, view updated, route
  /// pushed). Idempotent + coalescing: repeated marks between audits
  /// collapse into one.
  void markDirty(String reason) {
    _dirty = true;
    _reasons.add(reason);
  }

  /// Consumes the dirty mark. Returns `true` exactly once per dirty
  /// mark — the caller runs ONE audit; the next consume without a
  /// new signal returns `false` (no polling loop).
  bool consumeDirty() {
    if (!_dirty) return false;
    _dirty = false;
    _reasons.clear();
    _auditCount++;
    return true;
  }

  /// Resets every counter (test-lane teardown).
  void reset() {
    _dirty = false;
    _reasons.clear();
    _auditCount = 0;
  }
}
