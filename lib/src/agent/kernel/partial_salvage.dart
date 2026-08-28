import 'mission.dart';

/// Salvages partial results from a cancelled mission into the mission
/// record with a `cancelled_partial` outcome (FR-005).
///
/// Even an empty salvage is still recorded as `cancelled_partial` (per the
/// spec edge case: "What happens when a cancelled mission has zero partial
/// results? — The outcome is still recorded as `cancelled_partial` (an
/// empty salvage is still a salvage).").
class PartialSalvager {
  /// Salvages [mission]'s accumulated partials into a `cancelled_partial`
  /// outcome. Mutates [mission]'s `status` and `outcome` fields.
  OutcomeCancelledPartial salvage(Mission mission) {
    // Snapshot current partials (do not clear — they remain observable).
    final snapshot = List<Object>.from(mission.partials, growable: false);
    final outcome = OutcomeCancelledPartial(snapshot);
    mission.outcome = outcome;
    mission.status = MissionStatus.cancelled;
    return outcome;
  }
}
