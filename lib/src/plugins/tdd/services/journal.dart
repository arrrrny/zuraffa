/// The unified TDD journal (spec 1113-unified-tdd-journal, issue #1113):
/// the one machine-parseable record of `run-engine` then `run-skin` that
/// every downstream tool (`zfa tdd theater`, `zfa tdd status`, `zfa tdd
/// prove`) reads.
///
/// Three parts:
///
/// - **[JournalSchema]** — the JSON Schema document
///   (`tdd/journal.schema.json`, draft 2020-12) every written journal
///   validates against. GENERATED from this model (the skin-contract
///   pattern, #1111 FR-005: emitted from the model, never
///   hand-maintained), so the writer and the shipped schema cannot
///   drift.
/// - **[JournalWriter]** — every cycle (engine/skin/meta) writes
///   `tdd/cycle-log.md` (existing, unchanged) AND appends one structured
///   [JournalEntry] to `specs/<feature>/tdd/journal.json`. The entry
///   carries the issue's nine fields — `{feature, cycle:
///   engine|skin|meta, phase, started_at, finished_at, gate_state:
///   green|red|preflight_red|not_assessed, receipts, violations, refs:
///   {engine_receipt, skin_receipt, contract_schema}}` — plus additive
///   extras (`result`, `behaviors`, `counts`, `stopped_at`, `mocks`,
///   `fingerprints`) that downstream tooling (status, prove) reads. The
///   write is atomic (tmp + rename); the schema file lands beside the
///   journal on first append so every feature is self-describing.
/// - **[JournalReader]** — the ONE canonical read API. Journal entries,
///   the receipts its refs point at, the cycle-log content, the
///   per-behavior green evidence, the registered behaviors, and the
///   derived one-line [JournalVerdict] come from here — theater, status
///   and prove never parse journal files themselves.
///
/// The journal's `refs` cross-reference the engine (#1008/#1109) and
/// skin (#1008/#1005) receipts and the skin contract JSON (#1111): one
/// journal, one feature, three structured artifacts — the engine/skin
/// split's "decoupled, contract-glued" promise in machine-parseable form.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'artifact_registry.dart';
import 'cycle_evidence.dart';
import 'lane_receipts.dart';

/// Raised when a journal that EXISTS cannot be read (corrupt JSON, wrong
/// shape): honest failure, never a silent empty stream. A journal that
/// does not exist is NOT an error — it is honest pending state (the
/// feature has not been driven by a journal-writing cycle yet).
class JournalException implements Exception {
  const JournalException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The schema version of the unified journal.
const int journalSchemaVersion = 1;

/// Cycle values: which lane (or the meta-driver) wrote the entry.
const Set<String> journalCycles = {'engine', 'skin', 'meta'};

/// Phase values: what the cycle did.
const Set<String> journalPhases = {
  // A pre-start gate refused before any step spawned (cert-gate,
  // engine-gate) — gate_state is preflight_red.
  'gate',
  // The two-phase red-green-refactor driving loop ran (lane cycles).
  'drive',
  // The meta-driver's stitch entry over both lanes.
  'aggregate',
  // A prove invocation's incremental delta record.
  'prove',
  // Issue #1264: a reset tombstone — the per-behavior evidence
  // invalidation record for the dropped behaviors (behaviors field).
  'reset',
};

/// Gate-state values: the honest state the cycle ended in.
const Set<String> journalGateStates = {
  'green',
  'red',
  // A pre-start preflight refused the cycle before any step.
  'preflight_red',
  // Nothing was ever gated (prove on a feature with no evidence).
  'not_assessed',
};

/// The entry-level schema document — one journal entry's shape (the
/// file-level document wraps these in `entries`, see [JournalSchema]).
Map<String, dynamic> _entrySchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': [
    'feature',
    'cycle',
    'phase',
    'started_at',
    'finished_at',
    'gate_state',
    'receipts',
    'violations',
    'refs',
  ],
  'properties': {
    'feature': {'type': 'string', 'minLength': 1},
    'cycle': {'enum': journalCycles.toList()},
    'phase': {'enum': journalPhases.toList()},
    'started_at': {'type': 'string', 'format': 'date-time'},
    'finished_at': {'type': 'string', 'format': 'date-time'},
    'gate_state': {'enum': journalGateStates.toList()},
    'receipts': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'violations': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'refs': {
      'type': 'object',
      'additionalProperties': false,
      'required': ['engine_receipt', 'skin_receipt', 'contract_schema'],
      'properties': {
        'engine_receipt': {
          'type': ['string', 'null'],
        },
        'skin_receipt': {
          'type': ['string', 'null'],
        },
        'contract_schema': {
          'type': ['string', 'null'],
        },
      },
    },
    // Additive extras (schema-declared, never "additional"):
    'result': {'type': 'string'},
    'behaviors': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'counts': {
      'type': 'object',
      'additionalProperties': {'type': 'integer'},
    },
    'stopped_at': {
      'type': ['string', 'null'],
    },
    'mocks': {
      'type': 'object',
      'additionalProperties': {'type': 'integer'},
      'required': ['total', 'certified'],
      'properties': {
        'total': {'type': 'integer'},
        'certified': {'type': 'integer'},
      },
    },
    // Issue #1329: the failed step's diagnostic evidence, carried by a
    // lane entry that stopped on a step error — the spawned command, the
    // exit code, and the truncated stderr/stdout tail. Optional; never
    // written by green/red cycles without a step failure.
    'error': {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'behavior',
        'step',
        'outcome',
        'exit_code',
        'command',
        'output',
      ],
      'properties': {
        'behavior': {'type': 'string', 'minLength': 1},
        'step': {'type': 'string', 'minLength': 1},
        'outcome': {'type': 'string', 'minLength': 1},
        'exit_code': {'type': 'integer'},
        'command': {'type': 'string'},
        'output': {'type': 'string'},
      },
    },
    'fingerprints': {
      'type': 'object',
      'additionalProperties': {
        'type': 'object',
        'additionalProperties': {
          'type': ['string', 'null'],
        },
        'required': ['subject', 'test'],
        'properties': {
          'subject': {
            'type': ['string', 'null'],
          },
          'test': {
            'type': ['string', 'null'],
          },
        },
      },
    },
    'ungated': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
};

/// The JSON Schema generator + entry validator for the unified journal.
///
/// The document is built FROM the vocabulary constants and the entry
/// model's field table — the same discipline `skinContractSchema`
/// applies (#1111): the shipped `tdd/journal.schema.json` is generated,
/// never hand-maintained, so writer and schema cannot drift.
class JournalSchema {
  const JournalSchema._();

  static const String fileName = 'journal.schema.json';

  /// The feature-level schema document (`tdd/journal.schema.json`).
  static Map<String, dynamic> document() => {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': 'zuraffa unified TDD journal',
    'description':
        'One feature, one journal: the machine-parseable '
        'record of run-engine then run-skin (spec 1113, issue #1113). '
        'Every cycle (engine/skin/meta) appends one entry; '
        'tdd/cycle-log.md carries the same content as prose.',
    'type': 'object',
    'additionalProperties': false,
    'required': ['schema', 'feature', 'entries'],
    'properties': {
      'schema': {'const': journalSchemaVersion},
      'feature': {'type': 'string', 'minLength': 1},
      'entries': {'type': 'array', 'items': _entrySchema()},
    },
  };

  /// Validate one decoded entry against the schema's structural rules.
  /// Returns the violation list (empty = valid). This is the same walk
  /// the schema document declares — kept in one place so the tests
  /// validate written journals without an external JSON Schema engine.
  static List<String> validateEntry(Map<String, dynamic> entry) {
    final violations = <String>[];

    String? field(String name) {
      if (!entry.containsKey(name)) {
        violations.add('missing required field "$name"');
        return null;
      }
      return null;
    }

    for (final name in const [
      'feature',
      'cycle',
      'phase',
      'started_at',
      'finished_at',
      'gate_state',
      'receipts',
      'violations',
      'refs',
    ]) {
      field(name);
    }
    if (entry['feature'] is! String || '${entry['feature']}'.isEmpty) {
      violations.add('feature must be a non-empty string');
    }
    if (!journalCycles.contains(entry['cycle'])) {
      violations.add('cycle "${entry['cycle']}" outside $journalCycles');
    }
    if (!journalPhases.contains(entry['phase'])) {
      violations.add('phase "${entry['phase']}" outside $journalPhases');
    }
    if (!journalGateStates.contains(entry['gate_state'])) {
      violations.add(
        'gate_state "${entry['gate_state']}" outside $journalGateStates',
      );
    }
    for (final stamp in const ['started_at', 'finished_at']) {
      final raw = entry[stamp];
      if (raw is! String || DateTime.tryParse(raw) == null) {
        violations.add('$stamp "$raw" is not an ISO-8601 timestamp');
      }
    }
    if (entry['receipts'] is! List ||
        (entry['receipts'] as List).any((r) => r is! String)) {
      violations.add('receipts must be a list of strings');
    }
    if (entry['violations'] is! List ||
        (entry['violations'] as List).any((v) => v is! String)) {
      violations.add('violations must be a list of strings');
    }
    final refs = entry['refs'];
    if (refs is! Map<String, dynamic>) {
      violations.add('refs must be an object');
    } else {
      for (final key in const [
        'engine_receipt',
        'skin_receipt',
        'contract_schema',
      ]) {
        if (!refs.containsKey(key)) {
          violations.add('refs missing "$key"');
        } else if (refs[key] != null && refs[key] is! String) {
          violations.add('refs.$key must be a string or null');
        }
      }
      if (refs.length != 3) {
        violations.add('refs must carry exactly the three ref keys');
      }
    }
    final mocks = entry['mocks'];
    if (mocks != null && mocks is! Map<String, dynamic>) {
      violations.add('mocks must be an object of integers');
    }
    final fingerprints = entry['fingerprints'];
    if (fingerprints != null && fingerprints is! Map<String, dynamic>) {
      violations.add('fingerprints must be an object');
    }
    // Issue #1329: the error object's structural walk (same discipline
    // as the refs triple — required keys, no extras, typed values).
    final error = entry['error'];
    if (error != null) {
      if (error is! Map<String, dynamic>) {
        violations.add('error must be an object');
      } else {
        for (final key in const [
          'behavior',
          'step',
          'outcome',
          'exit_code',
          'command',
          'output',
        ]) {
          if (!error.containsKey(key)) {
            violations.add('error missing "$key"');
          }
        }
        if (error.length != 6) {
          violations.add('error must carry exactly the six evidence keys');
        }
        if (error['exit_code'] is! int) {
          violations.add('error.exit_code must be an integer');
        }
        for (final key in const ['behavior', 'step', 'outcome']) {
          final value = error[key];
          if (value is! String || value.isEmpty) {
            violations.add('error.$key must be a non-empty string');
          }
        }
        for (final key in const ['command', 'output']) {
          if (error[key] is! String) {
            violations.add('error.$key must be a string');
          }
        }
      }
    }
    return violations;
  }
}

/// Issue #1329: one failed step's diagnostic evidence, carried by the
/// lane journal entry's optional `error` object — the spawned command,
/// the exit code, and the truncated stderr/stdout tail, so a transient
/// step failure is debuggable from the journal alone (the entry no
/// longer reads only `"violations": ["stopped_at=<id>:<step>"]`). The
/// object is schema-declared (see [_entrySchema]'s `error` property) so
/// writer and shipped schema cannot drift.
class JournalStepError {
  const JournalStepError({
    required this.behavior,
    required this.step,
    required this.outcome,
    required this.exitCode,
    required this.command,
    required this.output,
  });

  /// The failed step's behavior id.
  final String behavior;

  /// The step that failed (`gen` | `verify-red` | `make` | `refactor`).
  final String step;

  /// The step's own failure outcome token (`error`, `crashed`,
  /// `runner-error`, ...).
  final String outcome;

  /// The step process's exit code (-1 when nothing spawned).
  final int exitCode;

  /// The spawned command line, joined for display.
  final String command;

  /// The step's stderr/stdout tail (the same truncated tail the
  /// cycle-log error entry records).
  final String output;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'behavior': behavior,
    'step': step,
    'outcome': outcome,
    'exit_code': exitCode,
    'command': command,
    'output': output,
  };

  /// Tolerant decode: null for a missing or malformed object (a legacy
  /// journal never carries the field; a hand-edited one must not crash
  /// the reader).
  static JournalStepError? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final behavior = raw['behavior'];
    final step = raw['step'];
    final outcome = raw['outcome'];
    final exitCode = raw['exit_code'];
    final command = raw['command'];
    final output = raw['output'];
    if (behavior is! String ||
        step is! String ||
        outcome is! String ||
        exitCode is! int ||
        command is! String ||
        output is! String) {
      return null;
    }
    return JournalStepError(
      behavior: behavior,
      step: step,
      outcome: outcome,
      exitCode: exitCode,
      command: command,
      output: output,
    );
  }
}

/// One journal entry — one cycle's record (the issue's nine fields plus
/// the additive extras downstream tooling reads).
class JournalEntry {
  const JournalEntry({
    required this.feature,
    required this.cycle,
    required this.phase,
    required this.startedAt,
    required this.finishedAt,
    required this.gateState,
    this.receipts = const [],
    this.violations = const [],
    this.engineReceipt,
    this.skinReceipt,
    this.contractSchema,
    this.result,
    this.behaviors = const [],
    this.counts,
    this.stoppedAt,
    this.mocks,
    this.fingerprints,
    this.ungated = const [],
    this.error,
  });

  final String feature;

  /// engine | skin | meta.
  final String cycle;

  /// gate | drive | aggregate | prove.
  final String phase;

  /// ISO-8601 UTC timestamps.
  final String startedAt;
  final String finishedAt;

  /// green | red | preflight_red | not_assessed.
  final String gateState;

  /// Feature-relative paths of the receipts this cycle wrote/read
  /// (e.g. `tdd/04-engine-receipt.json`).
  final List<String> receipts;

  /// Honest violations: the stopped_at of a red lane, the gate refusal,
  /// the skipped-widget ids.
  final List<String> violations;

  /// refs.engine_receipt — the engine lane receipt (#1008/#1109).
  final String? engineReceipt;

  /// refs.skin_receipt — the skin lane receipt (#1008/#1005).
  final String? skinReceipt;

  /// refs.contract_schema — the skin contract JSON (#1111).
  final String? contractSchema;

  /// The driver's own result name (complete | stopped | runner-error |
  /// ... | clean | delta for prove).
  final String? result;

  /// The lane's behavior ids in list order.
  final List<String> behaviors;

  /// The lane's receipt counts (total/pending/red/green/done).
  final Map<String, int>? counts;

  /// `behavior:step` when the lane stopped honestly.
  final String? stoppedAt;

  /// The cert-gate's mock accounting for the engine lane
  /// ({total, certified}) — the status verdict's `mocks c/t` segment.
  final Map<String, int>? mocks;

  /// The prove entry's per-behavior file fingerprints
  /// ({id: {subject: sha256|null, test: sha256|null}}) — the baseline
  /// the next prove's delta walks.
  final Map<String, Map<String, String?>>? fingerprints;

  /// The prove entry's reported ungated behavior ids.
  final List<String> ungated;

  /// Issue #1329: the failed step's diagnostic evidence when this cycle
  /// stopped on a step error — null for every other terminal outcome.
  final JournalStepError? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'feature': feature,
    'cycle': cycle,
    'phase': phase,
    'started_at': startedAt,
    'finished_at': finishedAt,
    'gate_state': gateState,
    'receipts': receipts,
    'violations': violations,
    'refs': {
      'engine_receipt': engineReceipt,
      'skin_receipt': skinReceipt,
      'contract_schema': contractSchema,
    },
    if (result != null) 'result': result,
    'behaviors': behaviors,
    if (counts != null) 'counts': counts,
    'stopped_at': stoppedAt,
    if (mocks != null) 'mocks': mocks,
    if (fingerprints != null) 'fingerprints': fingerprints,
    if (ungated.isNotEmpty) 'ungated': ungated,
    if (error != null) 'error': error!.toJson(),
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    feature: json['feature'] as String,
    cycle: json['cycle'] as String,
    phase: json['phase'] as String,
    startedAt: json['started_at'] as String,
    finishedAt: json['finished_at'] as String,
    gateState: json['gate_state'] as String,
    receipts: [
      for (final r in (json['receipts'] as List? ?? const [])) r as String,
    ],
    violations: [
      for (final v in (json['violations'] as List? ?? const [])) v as String,
    ],
    engineReceipt:
        (json['refs'] as Map<String, dynamic>?)?['engine_receipt'] as String?,
    skinReceipt:
        (json['refs'] as Map<String, dynamic>?)?['skin_receipt'] as String?,
    contractSchema:
        (json['refs'] as Map<String, dynamic>?)?['contract_schema'] as String?,
    result: json['result'] as String?,
    behaviors: [
      for (final b in (json['behaviors'] as List? ?? const [])) b as String,
    ],
    counts: (json['counts'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    ),
    stoppedAt: json['stopped_at'] as String?,
    mocks: (json['mocks'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    ),
    fingerprints: _fingerprintsFromJson(
      json['fingerprints'] as Map<String, dynamic>?,
    ),
    ungated: [
      for (final u in (json['ungated'] as List? ?? const [])) u as String,
    ],
    error: JournalStepError.fromJson(json['error']),
  );

  static Map<String, Map<String, String?>>? _fingerprintsFromJson(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return null;
    return raw.map((id, fp) {
      final map = fp as Map<String, dynamic>;
      return MapEntry(id, {
        'subject': map['subject'] as String?,
        'test': map['test'] as String?,
      });
    });
  }
}

/// Appends entries to `specs/<feature>/tdd/journal.json` — the one
/// writer every cycle (engine/skin/meta, via the shared driver core, the
/// commands' gate refusals, and prove) funnels through. Atomic
/// (tmp + rename), and `tdd/journal.schema.json` lands beside the
/// journal on first append.
class JournalWriter {
  const JournalWriter(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  static const String journalFileName = 'journal.json';

  /// Issue #1264: the tombstone entry's phase — a reset's per-behavior
  /// evidence invalidation record.
  static const String resetPhase = 'reset';

  /// Issue #1264: append [behaviorIds]' reset tombstone — the
  /// per-behavior evidence invalidation record that tells every later
  /// reader (the run driver's reconciliation, above all) that these
  /// behaviors' surviving cycle-log evidence no longer describes the
  /// tree (their artifacts were dropped). Append-only: prior entries are
  /// preserved, exactly like every other journal write.
  Future<void> appendResetTombstone({required List<String> behaviorIds}) async {
    if (behaviorIds.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await append(
      JournalEntry(
        feature: p.basename(featureDir),
        cycle: 'meta',
        phase: resetPhase,
        startedAt: now,
        finishedAt: now,
        gateState: 'not_assessed',
        result: 'reset',
        behaviors: behaviorIds,
      ),
    );
  }

  String get journalPath => p.join(featureDir, 'tdd', journalFileName);

  String get schemaPath => p.join(featureDir, 'tdd', JournalSchema.fileName);

  /// The feature-relative (tdd/) receipt paths the refs name — the
  /// conventional homes the driver writes them to.
  static String get engineReceiptRef => 'tdd/${LaneReceipts.engineReceiptName}';

  static String get skinReceiptRef => 'tdd/${LaneReceipts.skinReceiptName}';

  static String get contractSchemaRef => 'tdd/04-skin-contract.schema.json';

  /// The refs triple for a feature directory: each ref set when its
  /// artifact exists on disk, else null (an honest null — the issue's
  /// refs are a cross-reference record, not a wish list).
  Future<({String? engine, String? skin, String? contract})> resolveRefs({
    String? engineOverride,
    String? skinOverride,
  }) async {
    final engine = engineOverride ?? engineReceiptRef;
    final skin = skinOverride ?? skinReceiptRef;
    final engineFile = File(p.join(featureDir, engine));
    final skinFile = File(p.join(featureDir, skin));
    final contractFile = File(p.join(featureDir, contractSchemaRef));
    return (
      engine: await engineFile.exists() ? engine : null,
      skin: await skinFile.exists() ? skin : null,
      contract: await contractFile.exists() ? contractSchemaRef : null,
    );
  }

  /// Append [entry]. Creates the journal (and writes the schema file)
  /// on first use; preserves prior entries.
  Future<void> append(JournalEntry entry) async {
    final dir = Directory(p.join(featureDir, 'tdd'));
    await dir.create(recursive: true);

    // The schema file beside the journal (idempotent, first append).
    final schemaFile = File(schemaPath);
    if (!await schemaFile.exists()) {
      const encoder = JsonEncoder.withIndent('  ');
      final tmp = File('${schemaFile.path}.tmp');
      await tmp.writeAsString('${encoder.convert(JournalSchema.document())}\n');
      await tmp.rename(schemaFile.path);
    }

    // Read-modify-write, atomically.
    final file = File(journalPath);
    Map<String, dynamic> journal;
    if (await file.exists()) {
      final raw = await file.readAsString();
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('top-level value is not an object');
        }
        journal = decoded;
      } on FormatException catch (e) {
        throw JournalException(
          'corrupt journal at ${file.path} (${e.message}); delete it and '
          're-run the cycle to record a fresh stream',
        );
      }
    } else {
      journal = {
        'schema': journalSchemaVersion,
        'feature': entry.feature,
        'entries': <Object>[],
      };
    }
    final entries = (journal['entries'] as List? ?? []).toList();
    entries.add(entry.toJson());
    journal['entries'] = entries;
    journal['schema'] = journalSchemaVersion;
    journal['feature'] = entry.feature;

    const encoder = JsonEncoder.withIndent('  ');
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString('${encoder.convert(journal)}\n');
    await tmp.rename(file.path);
  }
}

/// One registered behavior the journal tools reason about: the registry
/// record's id + the two files a prove fingerprints.
class JournalBehavior {
  const JournalBehavior({
    required this.id,
    required this.subjectPath,
    required this.testPath,
  });

  final String id;

  /// Absolute or repo-relative subject path (null when the registry
  /// record carried none).
  final String? subjectPath;

  /// Absolute or repo-relative test path.
  final String? testPath;
}

/// The derived one-line verdict `zfa tdd status` prints from the
/// journal (issue #1113's shape):
///
///     004-login-ui | engine ✅ 5/5 | skin ✅ 4/4 (3 platforms) |
///     mocks 6/6 certified | 0 violations
class JournalVerdict {
  const JournalVerdict({
    required this.feature,
    required this.engineVerdict,
    required this.skinVerdict,
    required this.engineDone,
    required this.engineTotal,
    required this.skinDone,
    required this.skinTotal,
    required this.platforms,
    required this.mockCertified,
    required this.mockTotal,
    required this.violations,
    this.notes = const [],
  });

  final String feature;

  /// green | red | error | absent (the receipt vocabulary).
  final String engineVerdict;
  final String skinVerdict;

  /// Receipt counts per lane (0 when the receipt is absent).
  final int engineDone;
  final int engineTotal;
  final int skinDone;
  final int skinTotal;

  /// Distinct platform slots the skin receipt observed (skin.v1
  /// `platform_slot_fills`); 0 when the lane receipt carries none.
  final int platforms;

  /// The cert-gate's accounting from the engine cycle entry.
  final int mockCertified;
  final int mockTotal;

  /// Total violations across every journal entry.
  final int violations;

  /// Honest degradation notes (a corrupt receipt read as `error`).
  final List<String> notes;

  /// Exit-0 rule (unchanged from spec 1008): both lanes green.
  bool get bothGreen =>
      engineVerdict == 'green' && skinVerdict == 'green' && notes.isEmpty;

  String _lane(String name, String verdict, int done, int total) {
    final mark = switch (verdict) {
      'green' => '✅',
      'absent' => '—',
      _ => '❌',
    };
    if (verdict == 'absent') return '$name $mark absent';
    return '$name $mark $done/$total';
  }

  /// The one-line verdict.
  String get oneLine {
    final segments = [
      feature,
      _lane('engine', engineVerdict, engineDone, engineTotal),
      '${_lane('skin', skinVerdict, skinDone, skinTotal)} ($platforms '
          'platforms)',
      'mocks $mockCertified/$mockTotal certified',
      '$violations violations',
    ];
    return segments.join(' | ');
  }
}

/// The whole canonical stream for one feature — everything JournalReader
/// hands a tool, so the tool never opens a journal file itself.
class FeatureJournal {
  const FeatureJournal({
    required this.feature,
    required this.featureDir,
    required this.journalPresent,
    required this.entries,
    required this.receipts,
    required this.cycleLog,
    required this.greenEvidence,
    required this.behaviors,
    required this.verdict,
  });

  final String feature;
  final String featureDir;

  /// Whether `tdd/journal.json` exists (absence is honest pending
  /// state, never an error).
  final bool journalPresent;

  /// Every parsed entry, in file order (oldest first).
  final List<JournalEntry> entries;

  /// The refs-followed lane receipts: engine + skin, decoded. Null lane
  /// value = receipt absent (or corrupt — named in
  /// [JournalVerdict.notes]).
  final Map<String, Map<String, dynamic>?> receipts;

  /// The raw `tdd/cycle-log.md` content ('' when absent) — the journal's
  /// prose mirror. The rich per-step parse stays with the consumer
  /// (theater's timeline parser); the READ comes from here.
  final String cycleLog;

  /// Latest green-evidence timestamp per behavior id (from the
  /// cycle-log's green entries) — a behavior is GATED when its evidence
  /// exists and the files it exercised are unchanged since the last
  /// prove.
  final Map<String, String> greenEvidence;

  /// The registered behaviors (artifact registry records; empty when no
  /// registry).
  final List<JournalBehavior> behaviors;

  /// The derived one-line verdict.
  final JournalVerdict verdict;

  /// The last prove entry, null when prove never ran.
  JournalEntry? get lastProve {
    for (final entry in entries.reversed) {
      if (entry.phase == 'prove') return entry;
    }
    return null;
  }

  /// The last engine-lane entry (null when the engine lane never ran
  /// under journal-writing cycles).
  JournalEntry? get lastEngineCycle {
    for (final entry in entries.reversed) {
      if (entry.cycle == 'engine' && entry.phase == 'drive') return entry;
    }
    return null;
  }

  /// The last skin-lane entry.
  JournalEntry? get lastSkinCycle {
    for (final entry in entries.reversed) {
      if (entry.cycle == 'skin' && entry.phase == 'drive') return entry;
    }
    return null;
  }

  /// The last meta entry (the run meta-driver's aggregate record).
  JournalEntry? get lastMeta {
    for (final entry in entries.reversed) {
      if (entry.cycle == 'meta' && entry.phase == 'aggregate') return entry;
    }
    return null;
  }

  /// Entries filtered by cycle, in file order.
  List<JournalEntry> entriesOf(String cycle) =>
      entries.where((e) => e.cycle == cycle).toList();
}

/// The ONE canonical read API (issue #1113 requirement 2): any tool —
/// theater, status, prove, simulate — reads the journal stream through
/// here, not N file-format parsers.
class JournalReader {
  const JournalReader();

  static const _engineLane = 'engine';
  static const _skinLane = 'skin';

  /// Issue #1264: the behavior ids the feature's LAST reset tombstone
  /// invalidated — the empty set when no tombstone exists. The run
  /// driver's reconciliation subtracts these from the cycle-log evidence
  /// sets, so a reset's dropped behaviors re-drive instead of skipping
  /// as "already done" off surviving green evidence.
  static Future<Set<String>> tombstonedBehaviors(String featureDir) async =>
      (await lastResetTombstone(featureDir)).behaviors;

  /// Issue #1331: the feature's LAST reset tombstone — the invalidated
  /// behavior ids WITH the reset's timestamp. Consumers (make's re-drive
  /// adoption probe) compare the timestamp against the surviving
  /// evidence's `- at:` to separate the re-drive class (the surviving
  /// certification predates the tombstone — stale by decree) from a live
  /// drift (the evidence postdates the reset — authoritative again).
  ///
  /// Fail-closed: a missing journal, a corrupt one, or a tombstone
  /// without a parseable `started_at` returns an empty behavior set
  /// (never an adoption class); the #1036 refusal then stands exactly as
  /// before this probe existed.
  static Future<({Set<String> behaviors, DateTime? at})> lastResetTombstone(
    String featureDir,
  ) async {
    final file = File(p.join(featureDir, 'tdd', JournalWriter.journalFileName));
    if (!await file.exists()) {
      return (behaviors: const <String>{}, at: null);
    }
    final List<dynamic> entries;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return (behaviors: const <String>{}, at: null);
      }
      entries = decoded['entries'] as List? ?? const [];
    } on FormatException {
      // A corrupt journal reports no tombstone — the driver's own
      // JournalReader consumers surface the corruption honestly, and the
      // adoption probe must never adopt off an unreadable stream.
      return (behaviors: const <String>{}, at: null);
    }
    for (final raw in entries.reversed) {
      if (raw is! Map<String, dynamic>) continue;
      if (raw['phase'] != JournalWriter.resetPhase) continue;
      final behaviors = raw['behaviors'];
      if (behaviors is! List) {
        return (behaviors: const <String>{}, at: null);
      }
      final at = DateTime.tryParse(raw['started_at'] as String? ?? '');
      return (behaviors: behaviors.whereType<String>().toSet(), at: at);
    }
    return (behaviors: const <String>{}, at: null);
  }

  /// Load [feature]'s whole journal stream under [projectRoot].
  ///
  /// Throws [JournalException] for a feature directory that does not
  /// exist or a journal.json that exists but will not parse; absence of
  /// the journal, of receipts, of the cycle-log or of the registry is
  /// honest pending state, never an error.
  Future<FeatureJournal> read({
    required String feature,
    required String projectRoot,
  }) async {
    final featureDir = p.join(projectRoot, 'specs', feature);
    if (!await Directory(featureDir).exists()) {
      throw JournalException(
        'no feature directory at specs/$feature (project root: '
        '$projectRoot)',
      );
    }

    // 1. The journal entries.
    final journalFile = File(p.join(featureDir, 'tdd', 'journal.json'));
    final entries = <JournalEntry>[];
    var journalPresent = false;
    if (await journalFile.exists()) {
      journalPresent = true;
      try {
        final decoded = jsonDecode(await journalFile.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('top-level value is not an object');
        }
        // Spec 1113 legacy tolerance: a pre-1113 interrupted run could
        // leave the bug-#828 write-ahead TRANSACTION marker at this path
        // (the transaction file is `tdd/transaction.json` now). Read it
        // as an empty journal — the marker was never a unified entry
        // stream, and its absence of proof is an intent to re-drive, not
        // a corrupt journal.
        if (decoded.containsKey('status') &&
            decoded.containsKey('behavior') &&
            !decoded.containsKey('entries')) {
          // Legacy transaction marker: nothing to parse.
        } else {
          final rawEntries = decoded['entries'];
          if (rawEntries is! List) {
            throw const FormatException('"entries" is not a list');
          }
          for (final raw in rawEntries) {
            final map = raw as Map<String, dynamic>;
            entries.add(JournalEntry.fromJson(map));
          }
        }
      } on FormatException catch (e) {
        throw JournalException(
          'corrupt journal at ${journalFile.path} (${e.message}); delete it '
          'and re-run the cycle to record a fresh stream',
        );
      } on TypeError catch (e) {
        throw JournalException(
          'corrupt journal at ${journalFile.path} ($e); delete it and '
          're-run the cycle to record a fresh stream',
        );
      }
    }

    // 2. The refs-followed receipts: the LAST entry naming each ref
    //    wins, else the conventional receipt homes (so pre-journal
    //    features still render).
    final notes = <String>[];
    final receipts = <String, Map<String, dynamic>?>{};
    for (final lane in const [_engineLane, _skinLane]) {
      var ref = lane == _engineLane
          ? JournalWriter.engineReceiptRef
          : JournalWriter.skinReceiptRef;
      for (final entry in entries) {
        final named = lane == _engineLane
            ? entry.engineReceipt
            : entry.skinReceipt;
        if (named != null) ref = named;
      }
      final file = File(p.join(featureDir, ref));
      if (!await file.exists()) {
        receipts[lane] = null;
        continue;
      }
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('top-level value is not an object');
        }
        receipts[lane] = decoded;
      } on FormatException {
        receipts[lane] = null;
        notes.add(
          'corrupt $lane receipt at $ref read as error — delete it and '
          're-run the lane',
        );
      }
    }

    // 3. The cycle-log content (the journal's prose mirror).
    final cycleLogFile = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    final cycleLog = await cycleLogFile.exists()
        ? await cycleLogFile.readAsString()
        : '';

    // 4. Per-behavior green evidence (the shared CycleEvidence parser —
    //    the doctor and replay's own source, so the journal reader and
    //    the evidence sets never disagree).
    final greenEvidence = <String, String>{};
    try {
      for (final entry in await CycleEvidence(featureDir).entries()) {
        if (entry.kind != 'green') continue;
        // Append order is chronological: the LAST green wins.
        greenEvidence[entry.behaviorId] = entry.at ?? '';
      }
    } on FileSystemException {
      // A missing cycle-log yields no evidence — honest pending state.
    }

    // 4b. Issue #1264: the store-to-tree check for the derived verdict —
    //     green evidence whose backing test file is gone. A lane receipt
    //     claiming green for such behaviors is a stale verdict (reset
    //     drops the artifacts but never the append-only evidence), and
    //     status must not report green on nonexistent tests.
    final orphanedGreen = <String>{};
    try {
      orphanedGreen.addAll(
        await CycleEvidence(
          featureDir,
        ).orphanedGreenEvidence(projectRoot: projectRoot),
      );
    } on FileSystemException {
      // No cycle-log: nothing to orphan.
    }

    // 5. The registered behaviors.
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final behaviors = <JournalBehavior>[];
    for (final record in records) {
      behaviors.add(
        JournalBehavior(
          id: record.behaviorId,
          subjectPath: record.subjectPath.isEmpty ? null : record.subjectPath,
          testPath: record.testPath.isEmpty ? null : record.testPath,
        ),
      );
    }

    // 6. The derived verdict.
    final verdict = _deriveVerdict(
      feature: feature,
      entries: entries,
      receipts: receipts,
      notes: notes,
      orphanedGreen: orphanedGreen,
    );

    return FeatureJournal(
      feature: feature,
      featureDir: featureDir,
      journalPresent: journalPresent,
      entries: entries,
      receipts: receipts,
      cycleLog: cycleLog,
      greenEvidence: greenEvidence,
      behaviors: behaviors,
      verdict: verdict,
    );
  }

  static JournalVerdict _deriveVerdict({
    required String feature,
    required List<JournalEntry> entries,
    required Map<String, Map<String, dynamic>?> receipts,
    required List<String> notes,
    Set<String> orphanedGreen = const {},
  }) {
    String verdictOf(
      Map<String, dynamic>? receipt, {
      bool conformance = false,
    }) {
      if (receipt == null) return 'absent';
      // A skin.v1 conformance receipt (#1005) carries no `verdict`
      // field — its verdict is whether every behavior conformed.
      if (conformance) {
        final rows = receipt['behaviors'] as List? ?? const [];
        final conformed = rows.where(
          (row) => (row as Map<String, dynamic>)['conformance'] == true,
        );
        return rows.isEmpty || conformed.length == rows.length
            ? 'green'
            : 'red';
      }
      return receipt['verdict'] as String? ?? 'error';
    }

    // Lane-schema receipts (#1008) carry counts; the skin.v1 conformance
    // receipt (#1005) carries per-behavior rows — done = the conformed
    // behaviors, total = all rows.
    ({int done, int total}) countsOf(
      Map<String, dynamic>? receipt, {
      bool conformance = false,
    }) {
      if (receipt == null) return (done: 0, total: 0);
      if (conformance) {
        final rows = receipt['behaviors'] as List? ?? const [];
        var done = 0;
        for (final row in rows) {
          if ((row as Map<String, dynamic>)['conformance'] == true) done++;
        }
        return (done: done, total: rows.length);
      }
      final counts = receipt['counts'] as Map<String, dynamic>?;
      if (counts == null) return (done: 0, total: 0);
      return (
        done: (counts['done'] as num?)?.toInt() ?? 0,
        total: (counts['total'] as num?)?.toInt() ?? 0,
      );
    }

    final engine = receipts[_engineLane];
    final skin = receipts[_skinLane];
    final isSkinV1 = skin?['schema'] == 'skin.v1';
    final engineCounts = countsOf(engine);
    final skinCounts = countsOf(skin, conformance: isSkinV1);

    // Platforms: the distinct slots the skin.v1 receipt observed.
    var platforms = 0;
    if (isSkinV1) {
      final slots = skin?['platform_slot_fills'] as List? ?? const [];
      platforms = slots.toSet().length;
    }

    // Mocks: the last engine entry's cert-gate accounting.
    var mockTotal = 0;
    var mockCertified = 0;
    for (final entry in entries.reversed) {
      if (entry.cycle == 'engine' && entry.mocks != null) {
        mockTotal = entry.mocks?['total'] ?? 0;
        mockCertified = entry.mocks?['certified'] ?? 0;
        break;
      }
    }

    // Violations: every entry's honest violations, summed.
    var violations = 0;
    for (final entry in entries) {
      violations += entry.violations.length;
    }

    // Issue #1264: the store-to-tree demotion — a lane receipt claiming
    // green for a behavior whose green evidence has no backing test file
    // on disk is a stale verdict (reset drops the artifacts but never
    // the append-only evidence). Such a lane is NOT green; the verdict
    // demotes to red and the note names the drift and the one recovery.
    String demoted(String lane, String verdict, Map<String, dynamic>? receipt) {
      if (verdict != 'green' || orphanedGreen.isEmpty) return verdict;
      final named = receipt?['behaviors'] as List? ?? const [];
      final orphaned =
          named.whereType<String>().where(orphanedGreen.contains).toList()
            ..sort();
      if (orphaned.isEmpty) return verdict;
      notes.add(
        'evidence-without-artifact: $lane receipt claims green for '
        '${orphaned.join(', ')} whose green evidence names a test file '
        'missing from disk — run `zfa tdd run $feature` to re-drive them',
      );
      return 'red';
    }

    final engineVerdict = demoted(_engineLane, verdictOf(engine), engine);
    final skinVerdict = demoted(
      _skinLane,
      verdictOf(skin, conformance: isSkinV1),
      skin,
    );

    return JournalVerdict(
      feature: feature,
      engineVerdict: engineVerdict,
      skinVerdict: skinVerdict,
      engineDone: engineCounts.done,
      engineTotal: engineCounts.total,
      skinDone: skinCounts.done,
      skinTotal: skinCounts.total,
      platforms: platforms,
      mockCertified: mockCertified,
      mockTotal: mockTotal,
      violations: violations,
      notes: notes,
    );
  }
}

/// sha256 of [path]'s bytes; null when the file does not exist — the
/// prove baseline's fingerprint primitive (a file appearing or
/// disappearing is a change).
Future<String?> journalFileFingerprint(String? path) async {
  if (path == null || path.isEmpty) return null;
  try {
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  } on FileSystemException {
    return null;
  }
}
