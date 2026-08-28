/// Mission Trace Recorder — records rendered trees in mission traces with
/// schema version + content hash for replay and dashboard inspection
/// (spec FR-008, US6 acceptance 2).
library;

import 'rendered_view.dart';
import 'ui_vocabulary_schema.dart';

/// One recorded entry in a mission's render trace.
class MissionTraceEntry {
  /// View id of the rendered tree.
  final String viewId;

  /// The validated tree at the time of render.
  final UiNode tree;

  /// Schema version under which the tree was validated.
  final String schemaVersion;

  /// Content hash of the tree (FNV-1a 64-bit, hex).
  final String contentHash;

  /// Mission-type tag active at render time (may differ across entries if the
  /// mission switched narrowing mid-flight).
  final String? missionType;

  /// Wall-clock time the render was recorded.
  final DateTime recordedAt;

  const MissionTraceEntry({
    required this.viewId,
    required this.tree,
    required this.schemaVersion,
    required this.contentHash,
    this.missionType,
    required this.recordedAt,
  });

  @override
  String toString() =>
      'MissionTraceEntry(viewId=$viewId, schemaVersion=$schemaVersion, '
      'contentHash=$contentHash, missionType=$missionType, '
      'recordedAt=$recordedAt)';
}

/// Records each rendered tree in a mission's trace (FR-008).
///
/// Pure-Dart, in-memory — persistence to disk/DB is out of scope (per spec
/// Assumptions: persistence flows through the existing mission store). The
/// recorder is the source of truth for replay / dashboard inspection within a
/// single mission lifetime.
class MissionTraceRecorder {
  final List<MissionTraceEntry> _entries = <MissionTraceEntry>[];

  /// All recorded entries, oldest first.
  List<MissionTraceEntry> get entries =>
      List<MissionTraceEntry>.unmodifiable(_entries);

  /// Record a rendered view (FR-008). Called by `UiRenderTool.render` on every
  /// successful render — including replacements (a replacement creates a new
  /// entry with the same viewId and an updated contentHash).
  void record(RenderedView view, {String? missionType}) {
    _entries.add(MissionTraceEntry(
      viewId: view.viewId,
      tree: view.tree,
      schemaVersion: view.schemaVersion,
      contentHash: view.contentHash,
      missionType: missionType,
      recordedAt: DateTime.now(),
    ));
  }

  /// Replay the recorded tree for a given view id (US6 acceptance 1 —
  /// "user navigates back to the mission result"). Returns the most recent
  /// entry for the given id (last-write-wins, matching the Edge Cases spec).
  MissionTraceEntry? replay(String viewId) {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].viewId == viewId) return _entries[i];
    }
    return null;
  }

  /// Inspect every recorded entry (US6 acceptance 2 — "operator inspects the
  /// trace"). Each entry carries the schema version and content hash so
  /// operators can audit / diff renders.
  List<MissionTraceEntry> inspect() => entries;

  /// Whether any entry has been recorded.
  bool get isEmpty => _entries.isEmpty;

  /// Number of recorded entries.
  int get length => _entries.length;

  /// Clear all entries (mission reset).
  void clear() => _entries.clear();
}
