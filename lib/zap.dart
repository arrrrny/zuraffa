/// ZAP — Zuraffa Agent Protocol (spec 071, issue #809) public API.
///
/// Import this barrel to drive a ZAP host (or embed one) from your own
/// code — no `package:zuraffa/src/...` implementation imports needed:
///
/// ```dart
/// import 'package:zuraffa/zap.dart';
///
/// final host = await Process.start('dart', ['bin/zfa.dart', 'zap', 'serve']);
/// final client = ZapClient.overProcess(host)..start();
/// final receipt = await client.submit(mission);
/// if (!client.verifyReceipt(receipt)) throw 'the host lied';
/// ```
///
/// The wire contract itself lives in
/// `specs/071-zuraffa-agent-protocol/contracts/zap.md`; the schemas and
/// golden examples third parties build against are under
/// `specs/071-zuraffa-agent-protocol/schemas/` and `golden/`.
library;

/// Wire constants + NDJSON codec (`zapProtocolVersion`, `ZapProtocol`).
export 'src/zap/zap_protocol.dart';

/// Draft-07 schema maps (`ZapSchema`).
export 'src/zap/zap_schema.dart';

/// Structural validator (`ZapValidator`, `ZapValidationIssue`,
/// `ZapValidationResult`).
export 'src/zap/zap_validator.dart';

/// Typed message layer (`MissionEnvelope`, `MissionStep`,
/// `EvidencePacket`, `CheckpointMessage`, `ZapReceipt`, `ZapCheck`,
/// `ZapError`, `ZapMessage`, `ZapSchemaException`).
export 'src/zap/zap_message.dart';

/// Evidence chain (`zapEvidenceChain`, `zapChainLink`,
/// `zapGenesisLink`).
export 'src/zap/zap_chain.dart';

/// Golden examples (`ZapGoldens`) + the canonical JSON serialization the
/// exporter writes (`zapCanonicalJson`).
export 'src/zap/zap_golden.dart';

/// Step executors (`ZapStepExecutor`, `SubprocessZapStepExecutor`,
/// `ScriptedZapStepExecutor`, `ZapStepRun`).
export 'src/zap/zap_executor.dart';

/// The host (`ZapHost`, `ZapSession`, `ZapCheckpointStore`).
export 'src/zap/zap_host.dart';

/// The reference client (`ZapClient`).
export 'src/zap/zap_client.dart';

/// The conformance suite (`ZapConformance`, `ZapConformanceReport`,
/// `ZapConformanceCheck`).
export 'src/zap/zap_conformance.dart';
