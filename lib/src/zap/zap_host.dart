/// ZAP host — the framework side of the protocol (spec 071, issue #809,
/// FR-004, FR-005, FR-009..FR-012).
///
/// [ZapHost] processes NDJSON lines sequentially and emits reply lines
/// through an injected callback — the seam `zfa zap serve` wires to
/// stdin/stdout, and tests wire to in-memory lists. The host NEVER dies
/// on a bad message: every rejection is an `error` envelope, and the
/// session keeps serving.
///
/// Session rules (contracts/zap.md §4): the first mission fixes the
/// budget AND the policy; budget and policy violations are rejected
/// BEFORE any step executes; commands run without a shell; the receipt
/// verifies the TDD discipline of the session's certified evidence and
/// carries the digest-chain head the client recomputes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'zap_chain.dart';
import 'zap_executor.dart';
import 'zap_message.dart';
import 'zap_protocol.dart';
import 'zap_validator.dart';

/// The evidence output preview cap (bytes→chars of the printed preview).
const int zapOutputCap = 2000;

/// One session's certified state.
class ZapSession {
  ZapSession({
    required this.missionId,
    required this.budget,
    required this.riskTier,
    required this.toolAllowlist,
  });

  final String missionId;
  final int budget;
  final String riskTier;
  final List<String> toolAllowlist;

  /// Certified evidence facts, in execution order (chain input).
  final List<Map<String, Object?>> evidence = [];

  /// Steps accepted (requested) across missions.
  int stepsTotal = 0;

  int get stepsExecuted => evidence.length;

  Map<String, Object?> snapshot() => <String, Object?>{
    'missionId': missionId,
    'budget': budget,
    'riskTier': riskTier,
    'toolAllowlist': toolAllowlist,
    'stepsTotal': stepsTotal,
    'evidence': [
      for (final e in evidence) {...e},
    ],
  };

  static ZapSession fromSnapshot(Map<String, Object?> snap) {
    final session = ZapSession(
      missionId: snap['missionId'] as String,
      budget: snap['budget'] as int,
      riskTier: snap['riskTier'] as String,
      toolAllowlist: [
        for (final e in (snap['toolAllowlist'] as List)) e as String,
      ],
    )..stepsTotal = snap['stepsTotal'] as int;
    session.evidence.addAll([
      for (final e in (snap['evidence'] as List))
        (e as Map).cast<String, Object?>(),
    ]);
    return session;
  }
}

/// Checkpoint persistence: atomic tmp+rename writes (the
/// `SnapshotStore` discipline from #808), restorable across host
/// processes when the directory is shared.
class ZapCheckpointStore {
  ZapCheckpointStore({this.dir});

  /// Directory holding `<stateId>.json` snapshots; null = memory only.
  final String? dir;

  final Map<String, Map<String, Object?>> _memory = {};

  /// Host-generated stateIds always match this: `cp-` + 12 lowercase
  /// hex chars (the first 12 of the snapshot digest).
  static final RegExp _stateIdPattern = RegExp(r'^cp-[a-f0-9]{12}$');

  /// The digest stamped on a snapshot record: sha256 over the canonical
  /// (sorted-key) JSON of [snapshot]. [save] stamps it; the restore path
  /// recomputes it over whatever is actually on disk, so an edited or
  /// planted checkpoint file is rejected instead of restored.
  static String digestOf(Map<String, Object?> snapshot) =>
      sha256.convert(utf8.encode(jsonEncode(_sorted(snapshot)))).toString();

  /// Saves [snapshot], returning (stateId, digest).
  Future<({String stateId, String digest})> save(
    Map<String, Object?> snapshot,
  ) async {
    final digest = digestOf(snapshot);
    final stateId = 'cp-${digest.substring(0, 12)}';
    final record = <String, Object?>{
      'zap': zapProtocolVersion,
      'schema': 'zap-checkpoint.v1',
      'stateId': stateId,
      'digest': digest,
      'snapshot': snapshot,
    };
    _memory[stateId] = record;
    if (dir != null) {
      final file = File(p.join(dir!, '$stateId.json'));
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(_pretty(record));
      await tmp.rename(file.path);
    }
    return (stateId: stateId, digest: digest);
  }

  /// Loads the record for [stateId], from disk when persistent.
  ///
  /// [stateId] is host-generated (`cp-<12 hex>`): anything else is
  /// refused BEFORE it reaches the filesystem, so a client-controlled
  /// id can never traverse out of [dir] via an absolute path or `../`.
  Future<Map<String, Object?>?> load(String stateId) async {
    if (!_stateIdPattern.hasMatch(stateId)) return null;
    final cached = _memory[stateId];
    if (cached != null) return cached;
    if (dir != null) {
      final file = File(p.join(dir!, '$stateId.json'));
      if (await file.exists()) {
        final record = (jsonDecode(await file.readAsString()) as Map)
            .cast<String, Object?>();
        _memory[stateId] = record;
        return record;
      }
    }
    return null;
  }

  /// Deterministic key order for the canonical bytes.
  static Object? _sorted(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final key in (value.keys.toList()..sort()))
          key as String: _sorted(value[key]),
      };
    }
    if (value is List) {
      return [for (final item in value) _sorted(item)];
    }
    return value;
  }

  static String _pretty(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);
}

/// The ZAP host: one line in, zero or more reply lines out.
class ZapHost {
  ZapHost({
    ZapStepExecutor? executor,
    this.workingDirectory,
    this.checkpointDir,
    this.defaultStepTimeout = const Duration(seconds: 60),
  }) : executor = executor ?? const SubprocessZapStepExecutor(),
       _checkpoints = ZapCheckpointStore(dir: checkpointDir);

  final ZapStepExecutor executor;
  final String? workingDirectory;
  final String? checkpointDir;
  final Duration defaultStepTimeout;

  final Uuid _uuid = const Uuid();
  final Map<String, ZapSession> _sessions = {};
  final ZapCheckpointStore _checkpoints;

  /// Processes one inbound NDJSON [line]; every reply is emitted through
  /// [emit] as a complete NDJSON line. Never throws for message-level
  /// problems — they become `error` envelopes.
  Future<void> handleLine(
    String line, {
    required FutureOr<void> Function(String reply) emit,
  }) async {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    Map<String, Object?>? decoded;
    try {
      decoded = ZapProtocol.decodeLine(trimmed);
    } on FormatException catch (e) {
      _emitError(
        emit,
        code: 'schema',
        message:
            'line is not a valid ZAP '
            'NDJSON message: ${e.message}',
        details: [e.toString()],
      );
      return;
    }

    // Version gate before anything else is interpreted.
    if (decoded['zap'] != zapProtocolVersion) {
      _emitError(
        emit,
        code: 'version',
        message:
            'unsupported ZAP protocol version '
            '"${decoded['zap']}" (this host speaks $zapProtocolVersion)',
        inReplyTo: decoded['id'] is String ? decoded['id'] as String : null,
      );
      return;
    }

    // Structural validation (schema).
    final validation = ZapValidator.validate(decoded);
    if (!validation.ok) {
      _emitError(
        emit,
        code: 'schema',
        message:
            'message rejected: ${validation.issues.length} schema '
            'violation(s)',
        inReplyTo: decoded['id'] is String ? decoded['id'] as String : null,
        details: [for (final i in validation.issues) i.toString()],
      );
      return;
    }

    final type = decoded['type'] as String;

    // Direction gate: only missions and checkpoint save/restore come in.
    if (type != 'mission') {
      final kind = decoded['kind'];
      final inboundKind = kind == 'save' || kind == 'restore';
      if (type != 'checkpoint' || !inboundKind) {
        _emitError(
          emit,
          code: 'direction',
          message:
              '"$type${type == 'checkpoint' ? ' ($kind)' : ''}" is a '
              'host-to-agent message; only mission and checkpoint '
              'save/restore may be sent inbound',
          inReplyTo: decoded['id'] as String?,
        );
        return;
      }
      await _handleCheckpoint(decoded, emit);
      return;
    }

    await _handleMission(decoded, emit);
  }

  // ----------------------------------------------------------------
  // Missions
  // ----------------------------------------------------------------

  Future<void> _handleMission(
    Map<String, Object?> decoded,
    FutureOr<void> Function(String) emit,
  ) async {
    final mission = MissionEnvelope.fromValidated(decoded);
    final id = mission.id;
    final session = _sessions[mission.missionId];

    if (session == null) {
      // First mission: it fixes the budget and the policy.
      if (mission.steps.length > mission.maxSteps) {
        _emitError(
          emit,
          code: 'budget',
          message:
              'mission requests ${mission.steps.length} step(s) '
              'but the budget is ${mission.maxSteps}',
          inReplyTo: id,
        );
        return;
      }
      for (final step in mission.steps) {
        final violation = _allowlistViolation(step, mission.toolAllowlist);
        if (violation != null) {
          _emitError(emit, code: 'policy', message: violation, inReplyTo: id);
          return;
        }
      }
      final created = ZapSession(
        missionId: mission.missionId,
        budget: mission.maxSteps,
        riskTier: mission.riskTier,
        toolAllowlist: mission.toolAllowlist,
      )..stepsTotal = mission.steps.length;
      _sessions[mission.missionId] = created;
      await _execute(created, mission, emit);
      return;
    }

    // Continuing mission: policy must not drift, budget must not
    // escalate, and the cumulative count must fit.
    if (mission.maxSteps > session.budget) {
      _emitError(
        emit,
        code: 'budget',
        message:
            'session budget is fixed at ${session.budget} by the '
            'first mission; this mission tries to raise it to '
            '${mission.maxSteps} (self-escalation is rejected)',
        inReplyTo: id,
      );
      return;
    }
    if (mission.riskTier != session.riskTier ||
        !_sameSet(mission.toolAllowlist, session.toolAllowlist)) {
      _emitError(
        emit,
        code: 'policy',
        message:
            'session policy is fixed by the first mission '
            '(riskTier=${session.riskTier}, '
            'allowlist=${session.toolAllowlist.join(',')}); this mission '
            'drifts it (riskTier=${mission.riskTier}, '
            'allowlist=${mission.toolAllowlist.join(',')})',
        inReplyTo: id,
      );
      return;
    }
    final cumulative = session.stepsExecuted + mission.steps.length;
    if (cumulative > session.budget) {
      _emitError(
        emit,
        code: 'budget',
        message:
            'mission would run ${mission.steps.length} more step(s); '
            'the session has ${session.budget - session.stepsExecuted} of '
            'its ${session.budget}-step budget left',
        inReplyTo: id,
      );
      return;
    }
    for (final step in mission.steps) {
      final violation = _allowlistViolation(step, session.toolAllowlist);
      if (violation != null) {
        _emitError(emit, code: 'policy', message: violation, inReplyTo: id);
        return;
      }
    }

    session.stepsTotal += mission.steps.length;
    await _execute(session, mission, emit);
  }

  Future<void> _execute(
    ZapSession session,
    MissionEnvelope mission,
    FutureOr<void> Function(String) emit,
  ) async {
    final workDir = workingDirectory ?? Directory.current.path;
    for (final step in mission.steps) {
      final timeout = step.timeoutSeconds != null
          ? Duration(seconds: step.timeoutSeconds!)
          : defaultStepTimeout;
      final run = await executor.run(
        step,
        workingDirectory: workDir,
        timeout: timeout,
      );
      final preview = run.output.length > zapOutputCap
          ? '${run.output.substring(0, zapOutputCap - 24)}'
                '…[+${run.output.length - zapOutputCap + 24} chars]'
          : run.output;
      final evidence = EvidencePacket(
        id: 'e-${_uuid.v4()}',
        ts: DateTime.now().toUtc().toIso8601String(),
        missionId: session.missionId,
        stepId: run.stepId,
        phase: run.phase,
        command: run.command,
        exit: run.exit,
        digest: run.digest,
        at: run.at,
        durationMs: run.durationMs,
        output: preview,
      );
      session.evidence.add(evidence.chainFact);
      await emit(ZapProtocol.encodeLine(evidence.toJson()));
    }

    // The receipt: verdict from the checks, chainDigest from the
    // session's certified evidence.
    final checks = _receiptChecks(session);
    final verdict = checks.every((c) => c.ok) ? 'pass' : 'fail';
    final receipt = ZapReceipt(
      id: 'r-${_uuid.v4()}',
      ts: DateTime.now().toUtc().toIso8601String(),
      missionId: session.missionId,
      verdict: verdict,
      exit: verdict == 'pass' ? 0 : 1,
      chainDigest: zapEvidenceChain(session.evidence),
      stepsExecuted: session.stepsExecuted,
      stepsTotal: session.stepsTotal,
      checks: checks,
      at: DateTime.now().toUtc().toIso8601String(),
    );
    await emit(ZapProtocol.encodeLine(receipt.toJson()));
  }

  List<ZapCheck> _receiptChecks(ZapSession session) {
    final timeouts = session.evidence
        .where((e) => e['exit'] == zapTimeoutExit)
        .map((e) => e['stepId'] as String)
        .toList();

    return [
      const ZapCheck(name: 'mission-schema', ok: true),
      ZapCheck(
        name: 'budget',
        ok: session.stepsExecuted <= session.budget,
        detail: session.stepsExecuted <= session.budget
            ? '${session.stepsExecuted}/${session.budget} steps spent'
            : 'budget exceeded: ${session.stepsExecuted}/${session.budget}',
      ),
      const ZapCheck(name: 'policy', ok: true),
      ZapCheck(
        name: 'steps-executed',
        ok: timeouts.isEmpty,
        detail: timeouts.isEmpty
            ? '${session.stepsExecuted} step(s) completed'
            : 'step(s) timed out: ${timeouts.join(', ')} (exit '
                  '$zapTimeoutExit)',
      ),
      _disciplineCheck(session),
      ZapCheck(
        name: 'evidence-chain',
        ok: true,
        detail:
            'sha256 chain over ${session.evidence.length} certified '
            'fact(s), genesis-linked',
      ),
    ];
  }

  /// FR-012 — the cumulative TDD discipline rules, each named when
  /// violated. The order rule: at least one red must PRECEDE the first
  /// green/verify.
  ZapCheck _disciplineCheck(ZapSession session) {
    final evidence = session.evidence;
    for (final e in evidence) {
      if (e['phase'] == 'red' && e['exit'] == 0) {
        return ZapCheck(
          name: 'tdd-discipline',
          ok: false,
          detail:
              'red step "${e['stepId']}" exited 0 — a red that '
              'passes is a test that never failed',
        );
      }
      if ((e['phase'] == 'green' || e['phase'] == 'verify') && e['exit'] != 0) {
        return ZapCheck(
          name: 'tdd-discipline',
          ok: false,
          detail:
              'green/verify step "${e['stepId']}" exited '
              '${e['exit']} — the loop is not green',
        );
      }
    }
    final firstGreenIndex = evidence.indexWhere(
      (e) => e['phase'] == 'green' || e['phase'] == 'verify',
    );
    if (firstGreenIndex == -1) {
      // No green certified yet — the order rule is vacuously satisfied.
      return const ZapCheck(
        name: 'tdd-discipline',
        ok: true,
        detail:
            'no green/verify certified yet; every phase exit so far '
            'is honest',
      );
    }
    final redBeforeGreen = evidence
        .take(firstGreenIndex)
        .any((e) => e['phase'] == 'red');
    if (!redBeforeGreen) {
      final hasRed = evidence.any((e) => e['phase'] == 'red');
      return ZapCheck(
        name: 'tdd-discipline',
        ok: false,
        detail: hasRed
            ? 'the first green/verify step '
                  '"${evidence[firstGreenIndex]['stepId']}" was certified '
                  'before any red — the loop went green without a '
                  'witnessed failing test first'
            : 'a green was certified but no red was ever witnessed — '
                  'the loop skipped the failing-test phase',
      );
    }
    return const ZapCheck(
      name: 'tdd-discipline',
      ok: true,
      detail:
          'red failed before green passed; every phase exit is '
          'honest',
    );
  }

  // ----------------------------------------------------------------
  // Checkpoints
  // ----------------------------------------------------------------

  Future<void> _handleCheckpoint(
    Map<String, Object?> decoded,
    FutureOr<void> Function(String) emit,
  ) async {
    final message = CheckpointMessage.fromValidated(decoded);
    final id = message.id;

    if (message.kind == 'save') {
      final session = _sessions[message.missionId];
      if (session == null) {
        _emitError(
          emit,
          code: 'unknown-mission',
          message:
              'no session for mission "${message.missionId}" — '
              'submit a mission before checkpointing',
          inReplyTo: id,
        );
        return;
      }
      final saved = await _checkpoints.save(session.snapshot());
      final reply = CheckpointMessage(
        id: 'c-${_uuid.v4()}',
        ts: DateTime.now().toUtc().toIso8601String(),
        missionId: message.missionId,
        kind: 'saved',
        stateId: saved.stateId,
        digest: saved.digest,
        steps: session.stepsExecuted,
        at: DateTime.now().toUtc().toIso8601String(),
      );
      await emit(ZapProtocol.encodeLine(reply.toJson()));
      return;
    }

    // restore
    final stateId = message.stateId;
    if (stateId == null) {
      _emitError(
        emit,
        code: 'schema',
        message: 'a restore requires a stateId',
        inReplyTo: id,
      );
      return;
    }
    final record = await _checkpoints.load(stateId);
    final snapshot = record?['snapshot'];
    if (record == null || snapshot is! Map) {
      _emitError(
        emit,
        code: 'bad-checkpoint',
        message:
            'no checkpoint "$stateId" in this host\'s checkpoint '
            'store',
        inReplyTo: id,
      );
      return;
    }
    final snap = snapshot.cast<String, Object?>();
    // Tamper gate: the record on disk must still hash to the digest the
    // host certified at save time. A planted or hand-edited checkpoint
    // file is rejected instead of restored as a session.
    if (ZapCheckpointStore.digestOf(snap) != record['digest']) {
      _emitError(
        emit,
        code: 'bad-checkpoint',
        message:
            'checkpoint "$stateId" failed its digest check — the '
            'persisted record does not match the digest certified at '
            'save time',
        inReplyTo: id,
      );
      return;
    }
    if (snap['missionId'] != message.missionId) {
      _emitError(
        emit,
        code: 'bad-checkpoint',
        message:
            'checkpoint "$stateId" belongs to mission '
            '"${snap['missionId']}", not "${message.missionId}"',
        inReplyTo: id,
      );
      return;
    }
    _sessions[message.missionId] = ZapSession.fromSnapshot(snap);
    final reply = CheckpointMessage(
      id: 'c-${_uuid.v4()}',
      ts: DateTime.now().toUtc().toIso8601String(),
      missionId: message.missionId,
      kind: 'restored',
      stateId: stateId,
      digest: record['digest'] as String?,
      steps: (snap['evidence'] as List?)?.length ?? 0,
      at: DateTime.now().toUtc().toIso8601String(),
    );
    await emit(ZapProtocol.encodeLine(reply.toJson()));
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------

  static String? _allowlistViolation(MissionStep step, List<String> allow) {
    if (allow.contains(step.executable)) return null;
    return 'command executable "${step.executable}" is not in the session '
        'tool allowlist (${allow.join(', ')}) — the step was rejected '
        'before execution';
  }

  static bool _sameSet(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  Future<void> _emitError(
    FutureOr<void> Function(String) emit, {
    required String code,
    required String message,
    String? inReplyTo,
    List<String>? details,
  }) async {
    final error = ZapError(
      id: 'x-${_uuid.v4()}',
      ts: DateTime.now().toUtc().toIso8601String(),
      code: code,
      message: message,
      inReplyTo: inReplyTo,
      details: details,
    );
    await emit(ZapProtocol.encodeLine(error.toJson()));
  }
}
