/// ZAP reference client (spec 071, issue #809, FR-014).
///
/// [ZapClient] speaks the protocol over injectable streams — the same
/// seam a process boundary, an MCP transport (#791), or a test wire
/// provides. It submits missions, collects evidence, checkpoints, and —
/// the point of receipts — INDEPENDENTLY recomputes the evidence chain
/// and verifies the host's `chainDigest`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'zap_chain.dart';
import 'zap_message.dart';
import 'zap_protocol.dart';

/// The reference ZAP client.
class ZapClient {
  ZapClient({required Stream<String> Function() inbound, required this.send})
    : _inboundFactory = inbound;

  /// Builds a client wired to a live [Process] (stdin/stdout NDJSON).
  factory ZapClient.overProcess(Process process) {
    final inbound = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    return ZapClient(
      inbound: () => inbound,
      send: (line) {
        process.stdin.writeln(line.trim());
      },
    );
  }

  /// Sends one NDJSON line to the host.
  final void Function(String line) send;

  /// Inbound line stream factory (late-bound: start() subscribes once).
  final Stream<String> Function() _inboundFactory;

  StreamSubscription<Map<String, Object?>>? _subscription;

  /// Evidence packets received, in wire order.
  final List<EvidencePacket> evidence = [];

  /// Checkpoint replies received.
  final List<CheckpointMessage> checkpoints = [];

  /// Error envelopes received.
  final List<ZapError> errors = [];

  /// Receipts received, in wire order (per session, in order).
  final Map<String, List<ZapReceipt>> _receiptsByMission = {};

  final Map<String, int> _receiptWaiters = {};

  /// Starts consuming the inbound stream. Call once before submitting.
  void start() {
    if (_subscription != null) return;
    _subscription = _inboundWrapped().listen((message) {
      final type = message['type'] as String;
      switch (type) {
        case 'evidence':
          evidence.add(EvidencePacket.fromValidated(message));
          break;
        case 'checkpoint':
          checkpoints.add(CheckpointMessage.fromValidated(message));
          break;
        case 'receipt':
          final receipt = ZapReceipt.fromValidated(message);
          _receiptsByMission
              .putIfAbsent(receipt.missionId, () => <ZapReceipt>[])
              .add(receipt);
          break;
        case 'error':
          errors.add(ZapError.fromValidated(message));
          break;
      }
    });
  }

  Stream<Map<String, Object?>> _inboundWrapped() async* {
    await for (final line in _inboundFactory()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      Map<String, Object?> decoded;
      try {
        decoded = ZapProtocol.decodeLine(trimmed);
      } on FormatException {
        continue; // a reference client never dies on a bad line
      }
      yield decoded;
    }
  }

  /// Submits [mission]; resolves when THIS mission's receipt arrives.
  Future<ZapReceipt> submit(MissionEnvelope mission) {
    final seen = _receiptWaiters[mission.missionId] ?? 0;
    _receiptWaiters[mission.missionId] = seen + 1;
    send(ZapProtocol.encodeLine(mission.toJson()));
    return _awaitReceipt(mission.missionId, seen + 1);
  }

  /// Requests a checkpoint snapshot; resolves with the `saved` reply.
  Future<CheckpointMessage> saveCheckpoint(String missionId) {
    send(
      ZapProtocol.encodeLine(
        ZapProtocol.envelope(
          'checkpoint',
          'c-save-$missionId-${DateTime.now().millisecondsSinceEpoch}',
          DateTime.now().toUtc().toIso8601String(),
          {'missionId': missionId, 'kind': 'save'},
        ),
      ),
    );
    return _awaitCheckpoint(missionId, 'saved');
  }

  /// Requests a restore of [stateId]; resolves with the `restored` reply.
  Future<CheckpointMessage> restoreCheckpoint(
    String missionId,
    String stateId,
  ) {
    send(
      ZapProtocol.encodeLine(
        ZapProtocol.envelope(
          'checkpoint',
          'c-restore-$missionId-${DateTime.now().millisecondsSinceEpoch}',
          DateTime.now().toUtc().toIso8601String(),
          {'missionId': missionId, 'kind': 'restore', 'stateId': stateId},
        ),
      ),
    );
    return _awaitCheckpoint(missionId, 'restored');
  }

  /// Evidence for [missionId], in order.
  List<EvidencePacket> evidenceFor(String missionId) => [
    for (final e in evidence)
      if (e.missionId == missionId) e,
  ];

  /// Recomputes the evidence chain for [missionId] from the packets this
  /// client received — the client side of receipt verification.
  String recomputeChainDigest(String missionId) =>
      zapEvidenceChain([for (final e in evidenceFor(missionId)) e.chainFact]);

  /// Verifies [receipt] against everything this client witnessed: the
  /// verdict, the checks, and — the cryptographic core — the recomputed
  /// chain digest.
  bool verifyReceipt(ZapReceipt receipt) =>
      receipt.isPass &&
      receipt.checks.every((c) => c.ok) &&
      receipt.chainDigest == recomputeChainDigest(receipt.missionId);

  Future<void> close() async {
    await _subscription?.cancel();
  }

  // ----------------------------------------------------------------
  // Waiters (polling with backoff — receipts arrive after evidence)
  // ----------------------------------------------------------------

  Future<ZapReceipt> _awaitReceipt(String missionId, int index) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final receipts = _receiptsByMission[missionId] ?? const [];
      if (receipts.length >= index) return receipts[index - 1];
      final lastError = errors.isNotEmpty ? errors.last : null;
      if (lastError != null && lastError.code == 'internal') {
        throw StateError('host errored: ${lastError.message}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException(
      'no receipt for mission "$missionId" '
      '(index $index)',
    );
  }

  Future<CheckpointMessage> _awaitCheckpoint(
    String missionId,
    String kind,
  ) async {
    final before = checkpoints.length;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      for (var i = before; i < checkpoints.length; i++) {
        final c = checkpoints[i];
        if (c.missionId == missionId && c.kind == kind) return c;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException('no "$kind" reply for mission "$missionId"');
  }
}
