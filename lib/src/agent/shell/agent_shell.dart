import 'dart:async';

import 'file_lease_table.dart';
import 'lease_guard.dart';
import 'mission_document.dart';
import 'shell_protocol.dart';

/// Executes one step of a mission.
///
/// [aborted] is the cooperative kill -9 check (same pattern as the
/// kernel's `CancelToken`): the runner MUST bail out without reporting
/// success once it turns true — a step that never completed must never be
/// logged, and the durable snapshot must stay at the previous cursor.
typedef ShellRunner =
    Future<Object?> Function(
      MissionDocument doc,
      String stepId,
      bool Function() aborted,
    );

/// `zfa agent shell` — the v0 daemon (issue #808).
///
/// A long-lived shell that agents connect to over an NDJSON message
/// stream. Inside:
/// - **File leases** — real-time, crash-safe ownership via
///   [FileLeaseTable] + [LeaseGuard] (acquire / release / steal-on-timeout).
/// - **Mission documents** — durable, resumable missions via
///   [SnapshotStore]: submit, step, snapshot, `kill -9`, resume.
/// - **Budget meters** — per-mission call/token budgets surfacing as
///   `budget.tick` / `budget.breach` events on the NDJSON stream, backed
///   by the same dimensions as the policy shell's `MissionBudget`.
///
/// Missions survive disconnects: when an agent dies mid-mission, the
/// durable snapshot stays at the last completed step and a FRESH agent
/// (or a fresh daemon process over the same snapshot store) resumes
/// exactly where the last one died.
class AgentShell {
  AgentShell({
    SnapshotStore? snapshots,
    FileLeaseTable? leases,
    ShellRunner? runner,
    this.defaultLeaseTtl = const Duration(minutes: 5),
  }) : snapshots = snapshots ?? SnapshotStore('.zfa/agent-shell'),
       leases = leases ?? FileLeaseTable(),
       _runner = runner ?? _defaultRunner;

  final SnapshotStore snapshots;
  final FileLeaseTable leases;
  final ShellRunner _runner;
  final Duration defaultLeaseTtl;

  final Map<String, _Session> _sessions = <String, _Session>{};
  bool _killed = false;

  static Future<Object?> _defaultRunner(
    MissionDocument doc,
    String stepId,
    bool Function() aborted,
  ) async => 'step:$stepId';

  // ────────────────────────────────────────────────────────── sessions ──

  /// Attach an agent session.
  ///
  /// [inbound] carries request envelopes (already decoded NDJSON maps);
  /// the returned stream yields response + event envelopes for THIS agent
  /// (lease grants, mission progress, budget ticks, breaches, ...).
  Stream<Map<String, Object?>> attach(
    String agentId,
    Stream<Map<String, Object?>> inbound,
  ) {
    leases.sweepExpired();
    final previous = _sessions[agentId];
    if (previous != null) _closeSession(previous);

    final out = StreamController<Map<String, Object?>>.broadcast();
    final session = _Session(agentId, out);
    _sessions[agentId] = session;

    late StreamSubscription<Map<String, Object?>> sub;
    sub = inbound.listen(
      (msg) => _onMessage(session, msg),
      onDone: () => _closeSession(session),
      onError: (_) => _closeSession(session),
    );
    session.inboundSub = sub;
    out.onCancel = () => _closeSession(session);
    return out.stream;
  }

  /// Hard stop (kill -9 semantics): every in-flight step is aborted, no
  /// further durable writes happen. A fresh [AgentShell] over the same
  /// [SnapshotStore] resumes from the last durable cursor.
  Future<void> kill() async {
    _killed = true;
    for (final session in _sessions.values.toList(growable: false)) {
      session.activeRun?.aborted = true;
      _closeSession(session);
    }
    _sessions.clear();
  }

  /// Graceful shutdown.
  Future<void> dispose() => kill();

  // ───────────────────────────────────────────────────────── protocol ──

  void _onMessage(_Session session, Map<String, Object?> msg) {
    if (_killed) return;
    final type = msg['type'] as String?;
    switch (type) {
      case 'hello':
        _emit(
          session,
          ShellProtocol.event(
            'hello.welcome',
            agentId: session.id,
            extra: {'snapshotDir': snapshots.rootPath},
          ),
        );
      case 'lease.acquire':
        _handleLeaseAcquire(session, msg);
      case 'lease.release':
        _handleLeaseRelease(session, msg);
      case 'mission.submit':
        _handleMissionSubmit(session, msg);
      case 'mission.resume':
        _handleMissionResume(session, msg);
      default:
        _emit(
          session,
          ShellProtocol.event(
            'error',
            agentId: session.id,
            extra: {'message': 'unknown message type: $type'},
          ),
        );
    }
  }

  void _handleLeaseAcquire(_Session session, Map<String, Object?> msg) {
    final scope = msg['scope'] as String?;
    if (scope == null) {
      _emit(
        session,
        ShellProtocol.event(
          'error',
          agentId: session.id,
          extra: {'message': 'lease.acquire: scope?'},
        ),
      );
      return;
    }
    final grant = _grantLease(session.id, scope);
    if (grant.granted) {
      _emit(
        session,
        ShellProtocol.event(
          'lease.granted',
          agentId: session.id,
          extra: <String, Object?>{
            'scope': grant.lease!.scope,
            'expiresAt': grant.lease!.expiresAt.toIso8601String(),
            if (grant.stoleFrom != null) 'stoleFrom': grant.stoleFrom,
          },
        ),
      );
    } else {
      _emit(
        session,
        ShellProtocol.event(
          'lease.denied',
          agentId: session.id,
          extra: <String, Object?>{
            'scope': scope,
            'conflict': <String, Object?>{
              'holderId': grant.conflict!.holderId,
              'scope': grant.conflict!.scope,
              'expiresAt': grant.conflict!.expiresAt.toIso8601String(),
            },
          },
        ),
      );
    }
  }

  void _handleLeaseRelease(_Session session, Map<String, Object?> msg) {
    final scope = msg['scope'] as String?;
    if (scope == null) {
      _emit(
        session,
        ShellProtocol.event(
          'error',
          agentId: session.id,
          extra: {'message': 'lease.release: scope?'},
        ),
      );
      return;
    }
    try {
      leases.release(agentId: session.id, scope: scope);
      _emit(
        session,
        ShellProtocol.event(
          'lease.released',
          agentId: session.id,
          extra: {'scope': scope},
        ),
      );
    } on LeaseNotHeld catch (e) {
      _emit(
        session,
        ShellProtocol.event(
          'error',
          agentId: session.id,
          extra: {'message': '$e'},
        ),
      );
    }
  }

  void _handleMissionSubmit(_Session session, Map<String, Object?> msg) {
    final raw = msg['document'];
    if (raw is! Map) {
      _emit(
        session,
        ShellProtocol.event(
          'error',
          agentId: session.id,
          extra: {'message': 'mission.submit: document?'},
        ),
      );
      return;
    }
    final doc = MissionDocument.fromJson((raw).cast<String, Object?>());
    _emit(
      session,
      ShellProtocol.event(
        'mission.accepted',
        agentId: session.id,
        missionId: doc.missionId,
        extra: {'document': doc.toJson()},
      ),
    );
    _startRun(session, doc);
  }

  void _handleMissionResume(_Session session, Map<String, Object?> msg) {
    final missionId = msg['missionId'] as String?;
    if (missionId == null) {
      _emit(
        session,
        ShellProtocol.event(
          'error',
          agentId: session.id,
          extra: {'message': 'mission.resume: missionId?'},
        ),
      );
      return;
    }
    final doc = snapshots.load(missionId);
    if (doc == null) {
      _emit(
        session,
        ShellProtocol.event(
          'mission.not_found',
          agentId: session.id,
          missionId: missionId,
        ),
      );
      return;
    }
    if (doc.isComplete || doc.status == MissionDocumentStatus.completed) {
      _emit(
        session,
        ShellProtocol.event(
          'mission.completed',
          agentId: session.id,
          missionId: missionId,
          extra: {'document': doc.toJson()},
        ),
      );
      return;
    }
    _emit(
      session,
      ShellProtocol.event(
        'mission.resumed',
        agentId: session.id,
        missionId: missionId,
        extra: {'document': doc.toJson()},
      ),
    );
    _startRun(session, doc);
  }

  // ──────────────────────────────────────────────────── mission loop ──

  void _startRun(_Session session, MissionDocument doc) {
    final run = _MissionRun(doc, session);
    session.activeRun = run;
    // Fire-and-forget: the loop pushes events through the session stream.
    unawaited(_runSteps(run));
  }

  Future<void> _runSteps(_MissionRun run) async {
    var doc = run.doc;
    if (doc.status == MissionDocumentStatus.pending) {
      doc = doc.withStatus(MissionDocumentStatus.running);
      snapshots.save(doc);
    }
    while (true) {
      if (run.aborted || _killed) return;

      final step = doc.nextStep;
      if (step == null) break;

      // Budget meter: one call per step, tick on the NDJSON stream.
      run.calls++;
      final spec = doc.budget;
      final maxCalls = spec?.maxCalls;
      if (maxCalls != null && run.calls > maxCalls) {
        snapshots.save(doc.withStatus(MissionDocumentStatus.failed));
        _emit(
          run.session,
          ShellProtocol.event(
            'budget.breach',
            agentId: run.session.id,
            missionId: doc.missionId,
            extra: <String, Object?>{
              'dimension': 'calls',
              'current': run.calls,
              'max': maxCalls,
            },
          ),
        );
        _emit(
          run.session,
          ShellProtocol.event(
            'mission.failed',
            agentId: run.session.id,
            missionId: doc.missionId,
            extra: <String, Object?>{
              'reason': 'budget exhausted: calls ${run.calls}/$maxCalls',
            },
          ),
        );
        run.session.activeRun = null;
        return;
      }
      _emit(
        run.session,
        ShellProtocol.event(
          'budget.tick',
          agentId: run.session.id,
          missionId: doc.missionId,
          extra: <String, Object?>{
            'usedCalls': run.calls,
            'remainingCalls': maxCalls == null ? null : maxCalls - run.calls,
            'remainingTokens': spec?.maxTokens == null ? null : spec!.maxTokens,
          },
        ),
      );

      doc = doc.markStepRunning(step.id);
      snapshots.save(doc);

      Object? result;
      try {
        result = await _runner(doc, step.id, () => run.aborted || _killed);
      } catch (e) {
        if (run.aborted || _killed) return;
        snapshots.save(doc.withStatus(MissionDocumentStatus.failed));
        _emit(
          run.session,
          ShellProtocol.event(
            'mission.failed',
            agentId: run.session.id,
            missionId: doc.missionId,
            extra: {'reason': 'step ${step.id} failed: $e'},
          ),
        );
        run.session.activeRun = null;
        return;
      }

      // kill -9 boundary: a step that was in flight when the agent died
      // must NOT advance the durable state.
      if (run.aborted || _killed) return;

      doc = doc.withStepDone(step.id);
      snapshots.save(doc);
      _emit(
        run.session,
        ShellProtocol.event(
          'mission.step.done',
          agentId: run.session.id,
          missionId: doc.missionId,
          extra: <String, Object?>{
            'stepId': step.id,
            'result': result,
            'cursor': doc.cursor,
          },
        ),
      );
    }

    doc = doc.withStatus(MissionDocumentStatus.completed);
    snapshots.save(doc);
    _emit(
      run.session,
      ShellProtocol.event(
        'mission.completed',
        agentId: run.session.id,
        missionId: doc.missionId,
        extra: {'document': doc.toJson()},
      ),
    );
    run.session.activeRun = null;
  }

  // ──────────────────────────────────────────────────────────── misc ──

  LeaseGrant _grantLease(String agentId, String scope) =>
      leases.acquire(agentId: agentId, scope: scope, ttl: defaultLeaseTtl);

  void _emit(_Session session, Map<String, Object?> event) {
    if (_killed) return;
    if (session.out.isClosed) return;
    session.out.add(event);
  }

  void _closeSession(_Session session) {
    session.activeRun?.aborted = true;
    session.inboundSub?.cancel();
    if (!session.out.isClosed) session.out.close();
    if (identical(_sessions[session.id], session)) {
      _sessions.remove(session.id);
    }
  }
}

class _Session {
  _Session(this.id, this.out);

  final String id;
  final StreamController<Map<String, Object?>> out;
  StreamSubscription<Map<String, Object?>>? inboundSub;
  _MissionRun? activeRun;
}

class _MissionRun {
  _MissionRun(this.doc, this.session);

  MissionDocument doc;
  final _Session session;
  bool aborted = false;
  int calls = 0;
}
