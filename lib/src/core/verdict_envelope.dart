/// `VerdictEnvelope` — the ONE canonical `--json` verdict envelope
/// (SPEC 1105, issue #1105).
///
/// The A+ sweep landed `--json` envelopes on most generator commands, but
/// the envelope shapes drifted: `schema: 1` integers (route/state/usecase/
/// mock), `"verdict.v1"` strings (tdd), and `cache.verify.v1` ad-hoc. An
/// agent had to hand-roll a parser per command. This file ends that: one
/// versioned schema, one parser, and every `--json` emitter speaks it.
///
/// The contract (the emitted JSON document):
/// ```jsonc
/// {
///   "schema": "zuraffa.verdict.v1",   // the single canonical identifier
///   "command": "zfa <verb> [args]",   // the producing invocation
///   "verdict": "pass|fail|skip|error|stopped",
///   "exit_class": 0|1|2|3|4|64,       // ExitProtocol code, or the tdd
///                                     //   grandfathered taxonomy label
///                                     //   ("ok", "complete", ...) until
///                                     //   those verbs migrate
///   "subject": {"kind": "route|state|usecase|cache|mock|entity|...",
///               "id": "<Entity>"},
///   "artifacts": {"created": [...], "modified": [...], "deleted": [...]},
///   "receipts": [".zfa/receipts/..."],
///   "findings": [{"kind": "...", "fix": "zfa ...", "file": "...",
///                 "member": "...", "...": "extras"}],
///   "drifts": ["..."],
///   "details": { ... plugin-specific extras, the only free-form surface },
///   "timestamp": "2026-09-05T12:00:00.000Z"
/// }
/// ```
///
/// Versioning and backwards compatibility (the vision forbids silent
/// lies): `VerdictEnvelope.fromJson` throws [VerdictSchemaException] the
/// moment `schema` is anything but `zuraffa.verdict.v1`. An old envelope
/// (`schema: 1`, `verdict.v1`, `cache.verify.v1`) breaks loudly — it is
/// never silently re-interpreted.
///
/// The `details` map is the only plugin-specific surface; everything else
/// is uniform across emitters. `feature` and `fix` are grandfathered tdd
/// fields (SPEC 964/1106): they stay optional top-level keys so the tdd
/// verbs keep their exact shape with only the schema string changed.
///
/// The envelope is the LAST stdout line of a `--json` run; existing text
/// output above it stays human-readable.
library;

import 'dart:convert';

/// The verdict categories the canonical envelope can carry.
///
/// `pass | fail | skip | error` is the issue #1105 base set; `stopped` is
/// the tdd family's shipped taxonomy (SPEC 964) carried so the tdd verbs
/// keep their shape under the canonical schema.
enum VerdictKind { pass, fail, skip, error, stopped }

/// Thrown when an envelope does not speak the canonical schema — the loud
/// break old parsers must produce instead of a silent mis-parse.
class VerdictSchemaException implements Exception {
  final String message;

  VerdictSchemaException(this.message);

  @override
  String toString() => 'VerdictSchemaException: $message';
}

/// WHAT the verdict is about: an entity, feature, route, cache, mock,
/// state or usecase surface. Extra keys ride along (e.g. `entity` for the
/// SPEC 1106 datasource subjects).
class VerdictSubject {
  final String kind;
  final String? id;
  final Map<String, Object?> extra;

  const VerdictSubject({required this.kind, this.id, this.extra = const {}});

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    if (id != null) 'id': id,
    ...extra,
  };

  factory VerdictSubject.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind is! String || kind.isEmpty) {
      throw VerdictSchemaException(
        'subject.kind must be a non-empty string, got: `$kind`',
      );
    }
    return VerdictSubject(
      kind: kind,
      id: json['id'] as String?,
      extra: {
        for (final entry in json.entries)
          if (entry.key != 'kind' && entry.key != 'id') entry.key: entry.value,
      },
    );
  }
}

/// The file-level effect of the run: what was created, modified, deleted.
class VerdictArtifacts {
  final List<String> created;
  final List<String> modified;
  final List<String> deleted;

  const VerdictArtifacts({
    this.created = const <String>[],
    this.modified = const <String>[],
    this.deleted = const <String>[],
  });

  const VerdictArtifacts.empty()
    : created = const <String>[],
      modified = const <String>[],
      deleted = const <String>[];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'created': created,
    'modified': modified,
    'deleted': deleted,
  };

  factory VerdictArtifacts.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) {
      final raw = json[key];
      if (raw == null) return const <String>[];
      if (raw is! List) {
        throw VerdictSchemaException(
          'artifacts.$key must be a list, got: ${raw.runtimeType}',
        );
      }
      return List<String>.from(raw);
    }

    return VerdictArtifacts(
      created: list('created'),
      modified: list('modified'),
      deleted: list('deleted'),
    );
  }
}

/// One structured finding: what is wrong ([kind]), how to heal it ([fix]),
/// and where ([file], [member]). Unknown keys from richer emitters ride
/// along in [extra] (e.g. `detail`, `path`, `line`) — the canonical keys
/// are the floor, never a ceiling.
class VerdictFinding {
  final String kind;
  final String? fix;
  final String? file;
  final String? member;
  final Map<String, Object?> extra;

  const VerdictFinding({
    required this.kind,
    this.fix,
    this.file,
    this.member,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    if (fix != null) 'fix': fix,
    if (file != null) 'file': file,
    if (member != null) 'member': member,
    ...extra,
  };

  factory VerdictFinding.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind is! String || kind.isEmpty) {
      throw VerdictSchemaException(
        'finding.kind must be a non-empty string, got: `$kind`',
      );
    }
    return VerdictFinding(
      kind: kind,
      fix: json['fix'] as String?,
      file: json['file'] as String?,
      member: json['member'] as String?,
      extra: {
        for (final entry in json.entries)
          if (!{'kind', 'fix', 'file', 'member'}.contains(entry.key))
            entry.key: entry.value,
      },
    );
  }
}

/// The uniform versioned JSON verdict every `--json` command emits.
class VerdictEnvelope {
  /// The single canonical schema identifier; consumers grep for it and
  /// `fromJson` refuses anything else.
  static const String canonicalSchema = 'zuraffa.verdict.v1';

  VerdictEnvelope({
    required this.command,
    required this.verdict,
    this.exitClass,
    this.exitClassLabel,
    this.feature,
    this.fix,
    this.subject,
    VerdictArtifacts? artifacts,
    List<String>? receipts,
    List<VerdictFinding>? findings,
    List<String>? drifts,
    Map<String, Object?>? details,
    this.explain,
    DateTime? timestamp,
  }) : artifacts = artifacts ?? const VerdictArtifacts.empty(),
       receipts = receipts ?? <String>[],
       findings = findings ?? <VerdictFinding>[],
       drifts = drifts ?? <String>[],
       details = details ?? <String, Object?>{},
       timestamp = timestamp ?? DateTime.now().toUtc();

  /// The producing invocation (e.g. `zfa route create Product`).
  final String command;

  /// The verdict category.
  final VerdictKind verdict;

  /// The ExitProtocol exit code the run maps to (0 success, 1 failure,
  /// 2 usage, 3 drift, 4 conflict, 64 legacy usage). Null when the run
  /// carries only the grandfathered label form.
  final int? exitClass;

  /// The grandfathered tdd taxonomy label (`ok`, `complete`, `stopped`,
  /// `runner-error`, ...). Either this or [exitClass] is emitted as
  /// `exit_class`; never both.
  final String? exitClassLabel;

  /// The feature the command operated on, if any (grandfathered tdd).
  final String? feature;

  /// The machine-actionable remediation line, when one exists
  /// (grandfathered tdd top-level form).
  final String? fix;

  /// WHAT the verdict is about.
  final VerdictSubject? subject;

  /// The file-level effect of the run.
  final VerdictArtifacts artifacts;

  /// Receipt paths the run produced (`.zfa/receipts/...`).
  final List<String> receipts;

  /// Structured per-finding records.
  final List<VerdictFinding> findings;

  /// Drift/diff findings the verdict is about (empty when none).
  final List<String> drifts;

  /// Plugin-specific extras — the only free-form surface of the schema.
  final Map<String, Object?> details;

  /// The additive `--explain` block (issue #1122): a plugin-defined
  /// structure describing what the run did. Absent unless the emitter
  /// set it — the base envelope is byte-compatible either way.
  final Map<String, dynamic>? explain;

  /// ISO 8601 UTC timestamp; injected in tests for determinism.
  final DateTime timestamp;

  /// Returns a copy carrying the additive `--explain` block (issue
  /// #1122) without mutating the base envelope.
  VerdictEnvelope withExplain(Map<String, dynamic> explain) =>
      VerdictEnvelope(
        command: command,
        verdict: verdict,
        exitClass: exitClass,
        exitClassLabel: exitClassLabel,
        feature: feature,
        fix: fix,
        subject: subject,
        artifacts: artifacts,
        receipts: receipts,
        findings: findings,
        drifts: drifts,
        details: details,
        explain: explain,
        timestamp: timestamp,
      );

  /// The default ExitProtocol code for a verdict when the emitter does
  /// not declare one: pass exits 0, everything else exits 1.
  static int defaultExitClass(VerdictKind verdict) =>
      verdict == VerdictKind.pass ? 0 : 1;

  /// The JSON encoding of this envelope. The single-line form (no
  /// indent) is the contract — the envelope is the LAST stdout line,
  /// and a multi-line pretty-print would break line-oriented consumers.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': canonicalSchema,
    'command': command,
    'verdict': verdict.name,
    'exit_class': exitClass ?? exitClassLabel ?? defaultExitClass(verdict),
    if (feature != null && feature!.isNotEmpty) 'feature': feature,
    if (subject != null) 'subject': subject!.toJson(),
    'artifacts': artifacts.toJson(),
    'receipts': receipts,
    'findings': [for (final f in findings) f.toJson()],
    'drifts': drifts,
    if (fix != null && fix!.isNotEmpty) 'fix': fix,
    'details': details,
    // Issue #1122: the additive `--explain` block — absent unless the
    // flag was requested (route create/verify); the base envelope is
    // byte-compatible either way.
    if (explain != null) 'explain': explain,
    'timestamp': timestamp.toIso8601String(),
  };

  /// The single-line wire form.
  String toJsonLine() => jsonEncode(toJson());

  /// The ONE parser (issue #1105 order 3): decodes any emitter's output
  /// into a typed [VerdictEnvelope], and throws [VerdictSchemaException]
  /// the moment the document does not speak `zuraffa.verdict.v1` — old
  /// parsers break loudly, never silently.
  ///
  /// The exit-class duality is handled here: the canonical integer form
  /// (ExitProtocol) parses into [exitClass]; the tdd label form parses
  /// into [exitClassLabel] and re-encodes as the same label (round-trip
  /// honesty — the parser never upgrades a label behind the producer's
  /// back).
  static VerdictEnvelope fromJson(Map<String, dynamic> json) {
    final schemaValue = json['schema'];
    if (schemaValue != canonicalSchema) {
      throw VerdictSchemaException(
        'unsupported --json envelope schema: `$schemaValue` '
        '(expected `$canonicalSchema`); the drifted shape must break '
        'loudly, not parse silently',
      );
    }

    final command = json['command'];
    if (command is! String || command.isEmpty) {
      throw VerdictSchemaException(
        'command must be a non-empty string, got: `$command`',
      );
    }

    final verdictValue = json['verdict'];
    VerdictKind? verdict;
    for (final candidate in VerdictKind.values) {
      if (candidate.name == verdictValue) {
        verdict = candidate;
        break;
      }
    }
    if (verdict == null) {
      throw VerdictSchemaException(
        'verdict must be one of '
        '${VerdictKind.values.map((v) => v.name).join('|')}, '
        'got: `$verdictValue`',
      );
    }

    int? exitClass;
    String? exitClassLabel;
    final exitRaw = json['exit_class'];
    if (exitRaw is int) {
      exitClass = exitRaw;
    } else if (exitRaw is String) {
      exitClassLabel = exitRaw;
    } else if (exitRaw != null) {
      throw VerdictSchemaException(
        'exit_class must be an ExitProtocol code or a taxonomy label, '
        'got: `${exitRaw.runtimeType}`',
      );
    }

    final timestampValue = json['timestamp'];
    final timestamp = timestampValue == null
        ? null
        : DateTime.tryParse(timestampValue.toString());
    if (timestampValue != null && timestamp == null) {
      throw VerdictSchemaException(
        'timestamp must be ISO 8601, got: `$timestampValue`',
      );
    }

    final subjectJson = json['subject'];
    final findingsJson = json['findings'];
    final artifactsJson = json['artifacts'];

    return VerdictEnvelope(
      command: command,
      verdict: verdict,
      exitClass: exitClass,
      exitClassLabel: exitClassLabel,
      feature: json['feature'] as String?,
      fix: json['fix'] as String?,
      subject: subjectJson is Map<String, dynamic>
          ? VerdictSubject.fromJson(subjectJson)
          : null,
      artifacts: artifactsJson is Map<String, dynamic>
          ? VerdictArtifacts.fromJson(artifactsJson)
          : const VerdictArtifacts.empty(),
      receipts: json['receipts'] is List
          ? List<String>.from(json['receipts'] as List)
          : const <String>[],
      findings: findingsJson is List
          ? findingsJson
                .whereType<Map<String, dynamic>>()
                .map(VerdictFinding.fromJson)
                .toList()
          : const <VerdictFinding>[],
      drifts: json['drifts'] is List
          ? List<String>.from(json['drifts'] as List)
          : const <String>[],
      details: json['details'] is Map<String, dynamic>
          ? Map<String, Object?>.from(json['details'] as Map<String, dynamic>)
          : const <String, Object?>{},
      timestamp: timestamp ?? DateTime.now().toUtc(),
    );
  }

  /// Mixed-stream extraction for the MCP tool-call boundary (and any
  /// consumer reading a whole stdout capture): scans the text bottom-up
  /// for the last JSON object line that speaks the canonical schema and
  /// parses it. Returns null when the output carries no canonical
  /// envelope — a drifted shape is not an envelope, it is foreign text.
  static VerdictEnvelope? tryParse(String output) {
    for (final line in output.split('\n').reversed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          if (decoded['schema'] == canonicalSchema) {
            return VerdictEnvelope.fromJson(decoded);
          }
          // A JSON object with a foreign (or absent) schema key: not a
          // canonical envelope. Keep scanning for an envelope line.
        }
      } on FormatException {
        // Not a JSON line — keep scanning.
      } on VerdictSchemaException {
        // A malformed canonical envelope: keep scanning.
      }
    }
    return null;
  }

  /// Emits the envelope as the LAST stdout line (the contract tdd
  /// established; the CLI convention every emitter follows).
  static void emit(VerdictEnvelope envelope) {
    // ignore: avoid_print
    print(envelope.toJsonLine());
  }
}

// ---------------------------------------------------------------------------
// SPEC 1124 (merged from master): the repository `--json` envelope emitter.
// Repository commands and their tests reference this class name; both speak
// the canonical zuraffa.verdict.v1 schema.
// ---------------------------------------------------------------------------

/// `--json` emitters (issue #1105, consumed by SPEC 1124).
///
/// Issue #1105 ratifies ONE envelope schema for the whole A+ fleet:
///
/// ```json
/// {
///   "schema": "zuraffa.verdict.v1",
///   "command": "zfa repository create",
///   "verdict": "pass | fail | skip | error",
///   "exit_class": 0 | 1 | 2 | 3 | 4,
///   "subject": {"kind": "repository", "entity": "Product"},
///   "findings": [{"side": "...", "kind": "...", "fix": "..."}],
///   "details": {"...": "plugin-specific extras live here — the only
///                       plugin-specific surface of the envelope"},
///   "timestamp": "2026-09-07T00:00:00.000Z"
/// }
/// ```
///
/// with `exit_class` matching the ratified zfa exit protocol
/// (`ExitProtocol`: 0 success, 1 failure, 2 usage, 3 drift, 4 conflict).
///
/// The envelope is the LAST stdout line, single-line (the contract every
/// existing emitter shares — a pretty-print would break line-oriented
/// consumers). Human output printed above it stays untouched, so the
/// no-`--json` channel is unchanged.
///
/// Naming note: the tdd plugin's `VerdictEnvelope`
/// (`lib/src/plugins/tdd/models/verdict_envelope.dart`) keeps its class
/// name and its `verdict.v1` schema string — migrating every emitter to
/// THIS canonical schema is issue #1105's own sweep, deliberately outside
/// SPEC 1124's one-PR scope (which only wires the repository create verb).
/// This class carries the fully-qualified schema name so the two can never
/// be confused by grep or by parser.
/// The verdict categories the canonical envelope can carry (issue #1105:
/// `pass | fail | skip | error`).
enum VerdictStatus { pass, fail, skip, error }

/// The canonical `zuraffa.verdict.v1` envelope (issue #1105).
class ZuraffaVerdictEnvelope {
  ZuraffaVerdictEnvelope({
    required this.command,
    required this.status,
    required this.exitClass,
    this.subject,
    List<Map<String, Object?>>? findings,
    this.manifest,
    List<String>? drifts,
    Map<String, Object?>? details,
    DateTime? timestamp,
  }) : findings = findings ?? const <Map<String, Object?>>[],
       drifts = drifts ?? const <String>[],
       details = details ?? const <String, Object?>{},
       timestamp = timestamp ?? DateTime.now().toUtc();

  /// The single canonical schema identifier; consumers grep for it.
  static const String schema = 'zuraffa.verdict.v1';

  /// The canonical command the verdict is about (e.g. `zfa repository
  /// create`) — the invocation grammar form, not the argv echo.
  final String command;

  /// The verdict category.
  final VerdictStatus status;

  /// The exit protocol code this run exited with (`ExitProtocol`: 0
  /// success, 1 failure, 2 usage, 3 drift, 4 conflict).
  final int exitClass;

  /// WHAT the verdict is about, e.g. `{kind: 'repository', entity:
  /// 'Product'}`. Null omits the key from the JSON.
  final Map<String, Object?>? subject;

  /// Structured per-finding records (gate mismatches, refusals), each
  /// carrying the machine-actionable remediation under `fix`.
  final List<Map<String, Object?>> findings;

  /// The contract manifest binding, when the run wrote one:
  /// `{path, sha256, methods}`. Null omits the key — a failed gate
  /// writes no manifest and the envelope must not claim one.
  final Map<String, Object?>? manifest;

  /// Drift/diff findings the verdict is about (empty when none).
  final List<String> drifts;

  /// Plugin-specific extras (the only plugin-specific surface — issue
  /// #1105).
  final Map<String, Object?> details;

  /// ISO 8601 UTC timestamp; injectable in tests for determinism.
  final DateTime timestamp;

  /// The JSON encoding of this envelope as a map (stable key order).
  Map<String, Object?> toJson() => {
    'schema': schema,
    'command': command,
    'verdict': status.name,
    'exit_class': exitClass,
    if (subject != null) 'subject': subject,
    'findings': findings,
    if (manifest != null) 'manifest': manifest,
    'drifts': drifts,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  /// The single-line form — the LAST stdout line contract.
  String toJsonLine() => jsonEncode(toJson());

  /// The convenience constructor emitters use: builds and prints in one
  /// call. The envelope is the LAST stdout line.
  static void emit({
    required String command,
    required VerdictStatus status,
    required int exitClass,
    Map<String, Object?>? subject,
    List<Map<String, Object?>>? findings,
    Map<String, Object?>? manifest,
    List<String>? drifts,
    Map<String, Object?>? details,
  }) {
    // ignore: avoid_print
    print(
      ZuraffaVerdictEnvelope(
        command: command,
        status: status,
        exitClass: exitClass,
        subject: subject,
        findings: findings,
        manifest: manifest,
        drifts: drifts,
        details: details,
      ).toJsonLine(),
    );
  }
}
