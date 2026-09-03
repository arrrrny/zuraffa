/// ZAP typed message layer (spec 071, issue #809, FR-002..FR-005).
///
/// Hand-written `toJson`/`fromJson` with stable key order (the repo's
/// `MissionDocument`/`GenerationReceipt` convention — NOT
/// json_serializable). `ZapMessage.fromJson` validates STRUCTURALLY first
/// (FR-007): the validator's precise path errors ride the exception, and
/// a wrong protocol version is classified as such before anything else is
/// interpreted.
library;

import 'zap_protocol.dart';
import 'zap_validator.dart';

/// Thrown when a message fails structural validation.
class ZapSchemaException implements Exception {
  ZapSchemaException(this.message, this.issues, {this.classification});

  /// Human summary (`'mission rejected: 3 schema violations'`).
  final String message;

  /// The validator's path-precise issues.
  final List<ZapValidationIssue> issues;

  /// `'schema'` for structural violations, `'version'` for a `zap`
  /// version the host does not speak.
  final String? classification;

  @override
  String toString() =>
      'ZapSchemaException($classification): $message '
      '[${issues.join('; ')}]';
}

/// One mission step — a unit of work under budget and policy.
class MissionStep {
  const MissionStep({
    required this.id,
    required this.command,
    required this.phase,
    this.description,
    this.timeoutSeconds,
  });

  final String id;

  /// Whitespace-tokenized command; executed WITHOUT a shell; the first
  /// token must be in the session allowlist.
  final String command;

  /// `red` | `green` | `refactor` | `verify` — drives the discipline
  /// verdict.
  final String phase;

  final String? description;

  /// 1..600 seconds; the host default applies when null.
  final int? timeoutSeconds;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'command': command,
    'phase': phase,
    if (description != null) 'description': description,
    if (timeoutSeconds != null) 'timeoutSeconds': timeoutSeconds,
  };

  factory MissionStep.fromJson(Map<String, Object?> json) => MissionStep(
    id: json['id'] as String,
    command: json['command'] as String,
    phase: json['phase'] as String,
    description: json['description'] as String?,
    timeoutSeconds: json['timeoutSeconds'] as int?,
  );

  /// The executable token — what the allowlist gates on.
  String get executable => command.trim().split(RegExp(r'\s+')).first;
}

/// One receipt check (`mission-schema`, `budget`, ...).
class ZapCheck {
  const ZapCheck({required this.name, required this.ok, this.detail});

  final String name;
  final bool ok;
  final String? detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'ok': ok,
    if (detail != null) 'detail': detail,
  };

  factory ZapCheck.fromJson(Map<String, Object?> json) => ZapCheck(
    name: json['name'] as String,
    ok: json['ok'] as bool,
    detail: json['detail'] as String?,
  );
}

/// The sealed ZAP message family.
sealed class ZapMessage {
  const ZapMessage({required this.id, required this.ts});

  /// Envelope: message id.
  final String id;

  /// Envelope: ISO-8601 UTC timestamp.
  final String ts;

  /// The wire type of this message.
  String get type;

  /// Wire form with stable key order (`zap` first — the envelope reads
  /// top-down).
  Map<String, Object?> toJson();

  /// Parses [json] (already decoded) into a typed [ZapMessage].
  ///
  /// Throws [ZapSchemaException] — with the validator's path-precise
  /// issues — when the message is not structurally valid, or a
  /// version-classified exception when `zap` is not a version this
  /// implementation speaks.
  static ZapMessage fromJson(Map<String, Object?> json) {
    // Version FIRST: a future/mismatched version must never be parsed as
    // a half-understood message (the contract's §2 rule).
    final version = json['zap'];
    if (version != zapProtocolVersion) {
      throw ZapSchemaException(
        'unsupported ZAP protocol version "$version" '
        '(this host speaks $zapProtocolVersion)',
        [
          ZapValidationIssue(
            path: 'zap',
            message: 'must be "$zapProtocolVersion"; got "$version"',
          ),
        ],
        classification: 'version',
      );
    }

    final validation = ZapValidator.validate(json);
    if (!validation.ok) {
      throw ZapSchemaException(
        'message rejected: ${validation.issues.length} schema '
        'violation(s)',
        validation.issues,
        classification: 'schema',
      );
    }

    final type = json['type'] as String;
    return switch (type) {
      'mission' => MissionEnvelope.fromValidated(json),
      'evidence' => EvidencePacket.fromValidated(json),
      'checkpoint' => CheckpointMessage.fromValidated(json),
      'receipt' => ZapReceipt.fromValidated(json),
      'error' => ZapError.fromValidated(json),
      _ => throw ZapSchemaException('unknown message type "$type"', [
        ZapValidationIssue(
          path: 'type',
          message: 'must be one of ${zapMessageTypes.join('|')}',
        ),
      ], classification: 'schema'),
    };
  }
}

/// Agent → host: request work under budget and policy.
class MissionEnvelope extends ZapMessage {
  const MissionEnvelope({
    required super.id,
    required super.ts,
    required this.missionId,
    required this.agent,
    required this.goal,
    required this.maxSteps,
    required this.riskTier,
    required this.toolAllowlist,
    required this.steps,
    this.feature,
  });

  final String missionId;
  final String agent;
  final String goal;
  final String? feature;

  /// Session step budget — FIXED by the first mission.
  final int maxSteps;

  /// `standard` | `elevated` | `admin`.
  final String riskTier;

  /// Allowed executables (session policy).
  final List<String> toolAllowlist;

  final List<MissionStep> steps;

  @override
  String get type => 'mission';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': type,
    'id': id,
    'ts': ts,
    'missionId': missionId,
    'agent': agent,
    'goal': goal,
    if (feature != null) 'feature': feature,
    'budget': {'maxSteps': maxSteps},
    'policy': {'riskTier': riskTier, 'toolAllowlist': toolAllowlist},
    'steps': [for (final s in steps) s.toJson()],
  };

  static MissionEnvelope fromValidated(Map<String, Object?> json) {
    final policy = json['policy'] as Map<String, Object?>;
    final budget = json['budget'] as Map<String, Object?>;
    return MissionEnvelope(
      id: json['id'] as String,
      ts: json['ts'] as String,
      missionId: json['missionId'] as String,
      agent: json['agent'] as String,
      goal: json['goal'] as String,
      feature: json['feature'] as String?,
      maxSteps: budget['maxSteps'] as int,
      riskTier: policy['riskTier'] as String,
      toolAllowlist: [
        for (final e in policy['toolAllowlist'] as List) e as String,
      ],
      steps: [
        for (final s in json['steps'] as List)
          MissionStep.fromJson((s as Map).cast<String, Object?>()),
      ],
    );
  }
}

/// Host → agent: certified step outcome.
class EvidencePacket extends ZapMessage {
  const EvidencePacket({
    required super.id,
    required super.ts,
    required this.missionId,
    required this.stepId,
    required this.phase,
    required this.command,
    required this.exit,
    required this.digest,
    required this.at,
    this.durationMs,
    this.output,
  });

  final String missionId;
  final String stepId;
  final String phase;
  final String command;
  final int exit;
  final String digest;
  final String at;
  final int? durationMs;
  final String? output;

  @override
  String get type => 'evidence';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': type,
    'id': id,
    'ts': ts,
    'missionId': missionId,
    'stepId': stepId,
    'phase': phase,
    'command': command,
    'exit': exit,
    'digest': digest,
    'at': at,
    if (durationMs != null) 'durationMs': durationMs,
    if (output != null) 'output': output,
  };

  static EvidencePacket fromValidated(Map<String, Object?> json) =>
      EvidencePacket(
        id: json['id'] as String,
        ts: json['ts'] as String,
        missionId: json['missionId'] as String,
        stepId: json['stepId'] as String,
        phase: json['phase'] as String,
        command: json['command'] as String,
        exit: json['exit'] as int,
        digest: json['digest'] as String,
        at: json['at'] as String,
        durationMs: json['durationMs'] as int?,
        output: json['output'] as String?,
      );

  /// The certified facts of this packet — the evidence-chain input.
  Map<String, Object?> get chainFact => <String, Object?>{
    'missionId': missionId,
    'stepId': stepId,
    'phase': phase,
    'command': command,
    'exit': exit,
    'digest': digest,
    'at': at,
  };
}

/// Agent ↔ host: save/restore session state.
class CheckpointMessage extends ZapMessage {
  const CheckpointMessage({
    required super.id,
    required super.ts,
    required this.missionId,
    required this.kind,
    this.stateId,
    this.digest,
    this.steps,
    this.at,
  });

  final String missionId;

  /// `save` | `restore` (requests) / `saved` | `restored` (replies).
  final String kind;

  final String? stateId;
  final String? digest;
  final int? steps;
  final String? at;

  @override
  String get type => 'checkpoint';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': type,
    'id': id,
    'ts': ts,
    'missionId': missionId,
    'kind': kind,
    if (stateId != null) 'stateId': stateId,
    if (digest != null) 'digest': digest,
    if (steps != null) 'steps': steps,
    if (at != null) 'at': at,
  };

  static CheckpointMessage fromValidated(Map<String, Object?> json) =>
      CheckpointMessage(
        id: json['id'] as String,
        ts: json['ts'] as String,
        missionId: json['missionId'] as String,
        kind: json['kind'] as String,
        stateId: json['stateId'] as String?,
        digest: json['digest'] as String?,
        steps: json['steps'] as int?,
        at: json['at'] as String?,
      );
}

/// Host → agent: the verified verdict.
class ZapReceipt extends ZapMessage {
  const ZapReceipt({
    required super.id,
    required super.ts,
    required this.missionId,
    required this.verdict,
    required this.exit,
    required this.chainDigest,
    required this.stepsExecuted,
    required this.stepsTotal,
    required this.checks,
    required this.at,
  });

  final String missionId;

  /// `pass` | `fail` — pass iff every check is ok.
  final String verdict;

  /// 0 (pass) | 1 (fail) — the client's exit code.
  final int exit;

  /// Head of the evidence chain — the client recomputes and compares.
  final String chainDigest;

  final int stepsExecuted;
  final int stepsTotal;
  final List<ZapCheck> checks;
  final String at;

  @override
  String get type => 'receipt';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': type,
    'id': id,
    'ts': ts,
    'missionId': missionId,
    'verdict': verdict,
    'exit': exit,
    'chainDigest': chainDigest,
    'stepsExecuted': stepsExecuted,
    'stepsTotal': stepsTotal,
    'checks': [for (final c in checks) c.toJson()],
    'at': at,
  };

  static ZapReceipt fromValidated(Map<String, Object?> json) => ZapReceipt(
    id: json['id'] as String,
    ts: json['ts'] as String,
    missionId: json['missionId'] as String,
    verdict: json['verdict'] as String,
    exit: json['exit'] as int,
    chainDigest: json['chainDigest'] as String,
    stepsExecuted: json['stepsExecuted'] as int,
    stepsTotal: json['stepsTotal'] as int,
    checks: [
      for (final c in json['checks'] as List)
        ZapCheck.fromJson((c as Map).cast<String, Object?>()),
    ],
    at: json['at'] as String,
  );

  bool get isPass => verdict == 'pass' && exit == 0;
}

/// Host → agent: structural rejection (the auxiliary type).
class ZapError extends ZapMessage {
  const ZapError({
    required super.id,
    required super.ts,
    required this.code,
    required this.message,
    this.inReplyTo,
    this.details,
  });

  final String code;
  final String message;
  final String? inReplyTo;
  final List<String>? details;

  @override
  String get type => 'error';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': type,
    'id': id,
    'ts': ts,
    'code': code,
    'message': message,
    if (inReplyTo != null) 'inReplyTo': inReplyTo,
    if (details != null && details!.isNotEmpty) 'details': details,
  };

  static ZapError fromValidated(Map<String, Object?> json) => ZapError(
    id: json['id'] as String,
    ts: json['ts'] as String,
    code: json['code'] as String,
    message: json['message'] as String,
    inReplyTo: json['inReplyTo'] as String?,
    details: [for (final d in (json['details'] as List?) ?? []) d as String],
  );
}
