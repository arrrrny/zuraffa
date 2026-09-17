/// `MakePostState` — the driving run's record of make's certified
/// post-state (issue #1652: the phase-1 refactor digest gate).
///
/// On a forward run, behavior k's make green-applies and behavior k's
/// phase-1 refactor spawn follows it with zero external edits in between
/// — yet that spawn re-paid the full pipeline (full-suite preflight,
/// pass registry, re-proof) because the #1624/#1588 pass-batch ledger
/// can never inherit: forward progress changes `lib/` on every make, so
/// each spawn's tree differs from the LAST REFRACTOR's proved tree, by
/// construction. What each spawn's tree DOES equal is the THIS MAKE's
/// certified post-state — and make just ran its live green evidence on
/// exactly that tree.
///
/// The driving run writes this record the moment a make certifies the
/// current tree with live evidence — a `green` application (issue #1652),
/// or the #694 already-green `skipped` transition whose target-test
/// re-run just certified the current (post-hand-edit) tree (issue
/// #1676; a driver-owned, best-effort write — `make_command` itself
/// never reads or writes it):
///
/// ```json
/// {
///   "captured_at": "...",
///   "behavior_id": "U2",
///   "suite": "dart test",
///   "baseline_key": "<sha256 of the --suite-baseline file bytes, or ''>",
///   "config_key": "<sha256 of dart_test.yaml + pubspec.lock>",
///   "exempt_behaviors": [],
///   "lib_digest": "<sha256 of the sorted lib/ tree fingerprints>",
///   "test_digest": "<sha256 of the sorted test/ tree fingerprints>",
///   "green_verdict": "make U2 outcome=green exit 0 (post-generation green evidence)"
/// }
/// ```
///
/// On the `skipped` outcome the verdict names the skip transition's own
/// evidence (`outcome=skipped … skip-transition target-test green
/// evidence …`, issue #1676) — the inheritance stays honest about which
/// run certified the tree.
///
/// A `--pass-batch` refactor spawn whose context and trees match the
/// record (same suite template, same baseline content, same suite
/// configuration, same exempt set, byte-identical `lib/` AND `test/`)
/// inherits the pipeline — the same inherit semantics, honest evidence,
/// and fallback rules as the #1588 ledger hit, one record earlier in the
/// chain. The inheritance is named honestly: the evidence is make's
/// post-generation green evidence — the FULL SUITE did not run at this
/// tree, and the full gate still runs at the phase-2b batch pass,
/// feature completion, and nightly (spec 069 T001).
///
/// The record is derived data describing ONE moment: rewritten by every
/// certifying make (green-applied or skipped, issue #1676), inert once
/// the tree moves on (a digest mismatch sends the
/// next spawn through the full pipeline — the safe fallback for every
/// non-match), never trusted when corrupt, and never a substitute for
/// the refactor-proved ledger (which keeps precedence).
library;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'pass_batch_ledger.dart';

/// The parsed make-post-state.json snapshot (the tree state one
/// certifying make — green-applied or skipped — left behind) plus the
/// gate context keys it is valid under.
class MakePostState {
  MakePostState({
    required this.capturedAt,
    required this.behaviorId,
    required this.suite,
    required this.baselineKey,
    required this.configKey,
    required List<String> exemptBehaviors,
    required this.libDigest,
    required this.testDigest,
    required this.greenVerdict,
  }) : exemptBehaviors = List<String>.of(exemptBehaviors)..sort();

  /// The record file name inside the feature's `tdd/` directory.
  static const fileName = 'make-post-state.json';

  /// The record path for a feature directory.
  static String pathFor({required String featureDir}) =>
      p.join(featureDir, 'tdd', fileName);

  /// ISO-8601 capture time of the recorded make-green.
  final String capturedAt;

  /// The behavior whose make certified the recorded tree.
  final String behaviorId;

  /// The suite command template the make's green evidence ran under.
  final String suite;

  /// Content fingerprint of the `--suite-baseline` file (empty string
  /// when absent) — the same key [PassBatchLedger.baselineKeyFor] gives
  /// the refactor side.
  final String baselineKey;

  /// Content fingerprint of the repo-root suite configuration — the
  /// same key [PassBatchLedger.configKeyFor] gives the refactor side.
  final String configKey;

  /// The exempt behavior ids the driving run had parked/blocked at the
  /// make-green (the set it hands the refactor as `--exempt-behaviors`),
  /// kept in canonical sorted order at construction.
  final List<String> exemptBehaviors;

  /// Whole-tree digest of `lib/` at the certified state.
  final String libDigest;

  /// Whole-tree digest of `test/` at the certified state.
  final String testDigest;

  /// The honest verdict string naming make's own evidence — the record
  /// inherits a make green, never a full-suite preflight.
  final String greenVerdict;

  /// Whether this record matches the CURRENT refactor invocation's
  /// context exactly (the same comparison [PassBatchLedger.matches]
  /// performs for the ledger).
  bool matches({
    required String suite,
    required String baselineKey,
    required String configKey,
    required List<String> exemptBehaviors,
    required String libDigest,
    required String testDigest,
  }) {
    return this.suite == suite &&
        this.baselineKey == baselineKey &&
        this.configKey == configKey &&
        this.libDigest == libDigest &&
        this.testDigest == testDigest &&
        _listEquals(this.exemptBehaviors, exemptBehaviors);
  }

  /// Order-insensitive list equality (mirrors
  /// `PassBatchLedger._listEquals`): both sides are compared as sorted
  /// copies, so an unsorted exempt list cannot make a canonical record
  /// miss.
  static bool _listEquals(List<String> a, List<String> b) {
    final left = List<String>.of(a)..sort();
    final right = List<String>.of(b)..sort();
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'captured_at': capturedAt,
    'behavior_id': behaviorId,
    'suite': suite,
    'baseline_key': baselineKey,
    'config_key': configKey,
    'exempt_behaviors': exemptBehaviors,
    'lib_digest': libDigest,
    'test_digest': testDigest,
    'green_verdict': greenVerdict,
  };

  /// Load a record. Returns null when the file is missing, unreadable,
  /// corrupt, or typed wrong — the caller runs the full pipeline (safe
  /// failure, never an inherited gate from bad data; the same stance as
  /// [PassBatchLedger.read]).
  static Future<MakePostState?> read(String featureDir) async {
    try {
      final raw = await File(pathFor(featureDir: featureDir)).readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final capturedAt = json['captured_at'];
      final behaviorId = json['behavior_id'];
      final suite = json['suite'];
      final baselineKey = json['baseline_key'];
      final configKey = json['config_key'];
      final exempt = json['exempt_behaviors'];
      final libDigest = json['lib_digest'];
      final testDigest = json['test_digest'];
      final greenVerdict = json['green_verdict'];
      if (capturedAt is! String ||
          behaviorId is! String ||
          suite is! String ||
          baselineKey is! String ||
          configKey is! String ||
          exempt is! List ||
          libDigest is! String ||
          testDigest is! String ||
          greenVerdict is! String ||
          // A partially-mistyped list (`[42]`) is a corrupt record, not a
          // coerced `[]` — otherwise it could false-match when the
          // surviving elements coincide with the effective exempt set.
          !exempt.every((e) => e is String)) {
        return null;
      }
      return MakePostState(
        capturedAt: capturedAt,
        behaviorId: behaviorId,
        suite: suite,
        baselineKey: baselineKey,
        configKey: configKey,
        exemptBehaviors: List<String>.from(exempt),
        libDigest: libDigest,
        testDigest: testDigest,
        greenVerdict: greenVerdict,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persist the certified post-state. A write failure is the caller's
  /// warning to surface — a missing record costs the NEXT refactor one
  /// full pipeline, never correctness.
  Future<String> write({required String featureDir}) async {
    final file = File(pathFor(featureDir: featureDir));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(toJson()));
    return file.path;
  }
}
