/// `RunStateStore` — atomic persistence for the per-feature
/// `tdd/run-state.json` (spec 049-tdd-run, FR-004/FR-006 / U7-U11).
///
/// Contract:
/// - [save] writes via a temp file + rename, so a crash mid-write leaves
///   the previous file intact.
/// - [load] validates the file's JSON shape and reports corruption with a
///   message naming the corruption and the recovery path (delete the file
///   to restart from PENDING, or repair it to valid run-state JSON).
/// - [refusalReason] implements the concurrency guard: a non-null
///   in-flight marker whose recorded owner pid is alive and is not this
///   process means a second run is in flight and must be refused.
/// - Behaviors whose rows disappeared from the test list are retained in
///   the file with a `dropped` marker (audit trail), never deleted.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import '../models/run_state.dart';

/// Raised when `tdd/run-state.json` is unreadable or invalid. The message
/// names the corruption and the recovery path (U9).
class RunStateCorruptException implements Exception {
  const RunStateCorruptException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RunStateStore {
  RunStateStore(this.featureDir, {bool Function(int pid)? pidAlive})
    : _pidAlive = pidAlive ?? _processIsAlive;

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// Injectable pid-liveness probe (tests). Defaults to a signal-0 probe.
  final bool Function(int pid) _pidAlive;

  String get path => p.join(featureDir, 'tdd', 'run-state.json');

  /// The name the feature directory implies (validated against the file's
  /// own `feature` field on load).
  String get _expectedFeature => p.basename(featureDir);

  /// Load the persisted state, or `null` when no state file exists.
  ///
  /// Throws [RunStateCorruptException] when the file exists but cannot be
  /// parsed into a valid run state.
  Future<RunState?> load() async {
    final file = File(path);
    if (!await file.exists()) return null;
    String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (e) {
      throw RunStateCorruptException(
        'corrupted run-state.json at $path (cannot read: ${e.message}). '
        'Recovery: delete the file to restart every behavior from PENDING, '
        'or repair it to valid run-state JSON.',
      );
    }
    return _validated(raw, path, _expectedFeature);
  }

  /// The `dropped` ids recorded in the current state file (empty when the
  /// file is absent or records none).
  Future<List<String>> readDropped() async {
    final file = File(path);
    if (!await file.exists()) return const [];
    try {
      final map = jsonDecode(await file.readAsString());
      if (map is! Map<String, dynamic>) return const [];
      final dropped = map['dropped'];
      if (dropped is! List) return const [];
      return dropped.whereType<String>().toList()..sort();
    } on FormatException {
      // load() is the corruption gate; a caller reaching here with a broken
      // file sees the corruption error first.
      return const [];
    }
  }

  /// Non-null when a live foreign process holds the in-flight marker — the
  /// caller must refuse to start a second concurrent run (U10).
  String? refusalReason(RunState? state) {
    final behaviorId = state?.inFlightBehaviorId;
    if (behaviorId == null) return null;
    final owner = state!.inFlightOwnerPid;
    // No recorded owner, or the owner is this process: no positive evidence
    // of a concurrent run — resumable.
    if (owner == null || owner == pid) return null;
    if (!_pidAlive(owner)) return null;
    return 'a run is already in flight for behavior "$behaviorId" '
        '(step ${state.inFlightStep}, pid $owner); refusing to start a '
        'second concurrent run. The state file was left untouched. If pid '
        '$owner is stale, wait for it to exit or delete $path to restart.';
  }

  /// The ids in [state] that are absent from [activeBehaviorIds]: rows
  /// removed from the test list, retained as dropped (U11).
  List<String> computeDropped(RunState state, Set<String> activeBehaviorIds) {
    return state.behaviorStates.keys
        .where((id) => !activeBehaviorIds.contains(id))
        .toList()
      ..sort();
  }

  /// Atomically persist [state]. When [activeBehaviorIds] is given, ids in
  /// the state that are not in it are recorded under a `dropped` marker
  /// (audit trail; they stay in `behavior_states`).
  Future<void> save(RunState state, {Set<String>? activeBehaviorIds}) async {
    final map = jsonDecode(state.toJson()) as Map<String, dynamic>;
    if (activeBehaviorIds != null) {
      map['dropped'] = computeDropped(state, activeBehaviorIds);
    }
    await Directory(p.dirname(path)).create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    await tmp.rename(path);
  }

  static bool _processIsAlive(int pid) {
    try {
      // Signal 0 probes existence without signaling; the shell builtin is
      // the portable way to send it from Dart (ProcessSignal's public
      // constructor is private).
      final result = Process.runSync('kill', ['-0', pid.toString()]);
      return result.exitCode == 0;
    } on Object {
      // Cannot probe (no kill binary, permissions): assume alive so the
      // refusal errs on the side of state integrity.
      return true;
    }
  }
}

const List<String> _kSteps = ['gen', 'verify-red', 'make', 'refactor'];

/// Decode helper shared with validation: parses [raw] and validates the
/// run-state shape, mapping every parse failure to a corruption error
/// naming the recovery path.
RunState _validated(String raw, String path, String expectedFeature) {
  Never corrupt(String cause) => throw RunStateCorruptException(
    'corrupted run-state.json at $path ($cause). Recovery: delete the '
    'file to restart every behavior from PENDING, or repair it to '
    'valid run-state JSON.',
  );

  final Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      corrupt('top-level value is not an object');
    }
    map = decoded;
  } on FormatException catch (e) {
    corrupt('invalid JSON: ${e.message}');
  }
  if (map['feature'] is! String) corrupt('missing "feature" string');
  if (map['feature'] != expectedFeature) {
    corrupt(
      '"feature" is "${map['feature']}" but the directory is '
      '"$expectedFeature"',
    );
  }
  final statesRaw = map['behavior_states'];
  if (statesRaw != null && statesRaw is! Map) {
    corrupt('"behavior_states" is not an object');
  }
  final states = <String, BehaviorState>{};
  final statesMap = statesRaw as Map?;
  if (statesMap != null) {
    for (final key in statesMap.keys) {
      final value = statesMap[key];
      if (value is! String) {
        corrupt('"behavior_states.$key" is not a state name');
      }
      final state = BehaviorState.values
          .where((s) => s.name == value)
          .firstOrNull;
      if (state == null) corrupt('unknown behavior state "$value"');
      states[key as String] = state;
    }
  }
  final inFlightStep = map['in_flight_step'];
  if (inFlightStep != null && inFlightStep is! String) {
    corrupt('"in_flight_step" is not a string');
  }
  if (inFlightStep is String && !_kSteps.contains(inFlightStep)) {
    corrupt('unknown in-flight step "$inFlightStep"');
  }
  final inFlightId = map['in_flight_behavior_id'];
  if (inFlightId != null && inFlightId is! String) {
    corrupt('"in_flight_behavior_id" is not a string');
  }
  return RunState(
    feature: map['feature'] as String,
    behaviorStates: Map.unmodifiable(states),
    inFlightBehaviorId: inFlightId as String?,
    inFlightStep: inFlightStep as String?,
    inFlightOwnerPid: map['in_flight_owner_pid'] is num
        ? (map['in_flight_owner_pid'] as num).toInt()
        : null,
  );
}
