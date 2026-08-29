import 'mission.dart';
import 'mission_coalescer.dart';

/// Snapshot of the kernel's current state for operator introspection
/// (FR-008).
class IntrospectionSnapshot {
  IntrospectionSnapshot({
    required this.activeMissions,
    required this.waitingSubscribers,
    required this.coalescingWindow,
  });

  /// Active coalescing groups, indexed by canonical key.
  final Map<String, ActiveMissionInfo> activeMissions;

  /// Per-key subscriber count (keyed by canonical key).
  final Map<String, int> waitingSubscribers;

  /// Configured coalescing window duration.
  final Duration coalescingWindow;
}

/// Info about one active coalescing group.
class ActiveMissionInfo {
  ActiveMissionInfo({
    required this.missionId,
    required this.key,
    required this.status,
    required this.subscriberCount,
  });

  final String missionId;
  final MissionKey key;
  final MissionStatus status;
  final int subscriberCount;
}

/// Provides introspection endpoints for the kernel.
class Introspection {
  Introspection({required this.coalescingWindow, required this.activeGroups});

  /// Current coalescing window duration.
  final Duration coalescingWindow;

  /// Live map of canonical-key → active coalescing group. Read-only view.
  final Map<String, CoalescingGroup> activeGroups;

  /// Returns a snapshot of the kernel's active missions and subscriber
  /// counts.
  IntrospectionSnapshot snapshot() {
    final active = <String, ActiveMissionInfo>{};
    final waiting = <String, int>{};
    activeGroups.forEach((canonical, group) {
      final mission = group.mission;
      active[canonical] = ActiveMissionInfo(
        missionId: mission.id,
        key: mission.key,
        status: mission.status,
        subscriberCount: group.subscribers.length,
      );
      waiting[canonical] = group.subscribers.length;
    });
    return IntrospectionSnapshot(
      activeMissions: active,
      waitingSubscribers: waiting,
      coalescingWindow: coalescingWindow,
    );
  }
}
