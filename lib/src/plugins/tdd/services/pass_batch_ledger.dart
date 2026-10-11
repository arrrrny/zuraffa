/// `PassBatchLedger` — the phase-2 refactor pass's per-feature batch gate
/// (issue #1588: one suite preflight for the batch, no redundant pass
/// registry spawns on an unchanged tree).
///
/// The phase-2b refactor pass spawns `zfa tdd refactor` once per green
/// behavior. Every spawn re-paid the full pipeline — full-suite preflight,
/// whole-project pass registry (`zfa build`, `dart format lib/`,
/// `dart fix --apply lib/`), and a re-proof — even though the previous
/// spawn just proved the byte-identical tree state (~32-44s each, ~2.7 min
/// for zero passes on the calculator corpus). #741 fixed the same
/// economics for make/verify-red with the once-per-run suite baseline;
/// the refactor pass was never included.
///
/// The ledger is the refactor-side twin of that cache. When the DRIVING
/// run opts in (`--pass-batch`, a driver-only flag — a flag-less
/// standalone refactor never reads or writes it, keeping spec 048 FR-001's
/// absolute-green contract unchanged), the command records the gate it
/// just proved:
///
/// ```json
/// {
///   "captured_at": "...",
///   "suite": "dart test",
///   "baseline_key": "<sha256 of the --suite-baseline file bytes, or ''>",
///   "config_key": "<sha256 of the suite config: dart_test.yaml + pubspec.lock>",
///   "exempt_behaviors": ["contract:C1"],
///   "lib_digest": "<sha256 of the sorted lib/ tree fingerprints>",
///   "test_digest": "<sha256 of the sorted test/ tree fingerprints>",
///   "preflight_verdict": "...",
///   "reproof_verdict": "..."
/// }
/// ```
///
/// A later invocation in the SAME pass (same suite template, same baseline
/// content, same suite configuration — the repo-root `dart_test.yaml` and
/// `pubspec.lock` the suite runs under — same exempt set, byte-identical
/// `lib/` AND `test/` trees) inherits that gate: no preflight, no pass
/// registry, no re-proof — a clean no-op with an honest evidence line. An
/// invocation carrying `--full-reproof` never inherits: an explicit request
/// for the strongest proof is always answered by running it. Any context
/// mismatch, tree drift, or corrupt file falls back to the full pipeline
/// (safe failure — the ledger is derived data, recomputed by every green
/// application; the cycle-log entry remains the tamper-evident record,
/// mirroring PassRegistryTracker's stance).
///
/// The full gate still exists, frequency engineered (spec 069 T001): the
/// full suite runs at feature completion (`zfa tdd verify`'s preflight)
/// and nightly (the corpus lane). The ledger only removes REDUNDANT
/// re-proofs of an unchanged tree within one phase-2 pass.
///
/// The ledger's byte-identity precondition is exactly why it can never
/// inherit during FORWARD progress: every make changes `lib/`, so the
/// next spawn's tree differs from the last refactor's proved tree by
/// construction (issue #1652). That rung is served by the sibling
/// `MakePostState` record (`tdd/make-post-state.json`, written by the
/// driving run at every make green-application): a `--pass-batch` spawn
/// checks the ledger FIRST (a refactor-proved full-pipeline gate keeps
/// precedence) and falls back to the make-certified post-state, whose
/// inheritance names make's target-test evidence honestly — the full
/// suite gate itself stays at the phase-2b batch pass, feature
/// completion, and nightly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'tree_snapshot.dart';

/// The parsed pass-batch.json snapshot (the gate one green application
/// proved) plus the context keys it is valid under.
class PassBatchLedger {
  PassBatchLedger({
    required this.capturedAt,
    required this.suite,
    required this.baselineKey,
    required this.configKey,
    required List<String> exemptBehaviors,
    required this.libDigest,
    required this.testDigest,
    required this.preflightVerdict,
    required this.reproofVerdict,
  }) : exemptBehaviors = List<String>.of(exemptBehaviors)..sort();

  /// The ledger file name inside the feature's `tdd/` directory.
  static const fileName = 'pass-batch.json';

  /// The ledger path for a feature directory.
  static String pathFor({required String featureDir}) =>
      p.join(featureDir, 'tdd', fileName);

  /// ISO-8601 capture time of the recorded gate.
  final String capturedAt;

  /// The suite command template the gate ran under.
  final String suite;

  /// Content fingerprint of the `--suite-baseline` file (empty string
  /// when the invocation carried no baseline). Any baseline rewrite —
  /// including a fresh run's new `captured_at` — changes the key.
  final String baselineKey;

  /// Content fingerprint of the repo-root suite configuration the gate ran
  /// under — `dart_test.yaml` and `pubspec.lock`, when present
  /// ([configKeyFor]). What the suite runs depends on inputs outside
  /// `lib/`/`test/` (tag exclusions, presets, timeouts, dependency
  /// resolution), so a ledger recorded under a different configuration is
  /// a different gate.
  final String configKey;

  /// The exempt behavior ids the gate tolerated (issue #1588 parked
  /// exemption), kept in canonical sorted order at construction so the
  /// positional comparison in [matches] is order-insensitive. A different
  /// exempt set is a different gate.
  final List<String> exemptBehaviors;

  /// Whole-tree digest of `lib/` at the proved state.
  final String libDigest;

  /// Whole-tree digest of `test/` at the proved state.
  final String testDigest;

  /// The honest verdict strings recorded for the evidence entry.
  final String preflightVerdict;
  final String reproofVerdict;

  /// Whether this ledger matches the CURRENT invocation's context exactly.
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

  /// Order-insensitive list equality: both sides are compared as sorted
  /// copies, so a caller handing an unsorted exempt list cannot make a
  /// canonical ledger miss.
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
    'suite': suite,
    'baseline_key': baselineKey,
    'config_key': configKey,
    'exempt_behaviors': exemptBehaviors,
    'lib_digest': libDigest,
    'test_digest': testDigest,
    'preflight_verdict': preflightVerdict,
    'reproof_verdict': reproofVerdict,
  };

  /// Load a ledger snapshot. Returns null when the file is missing,
  /// unreadable, corrupt, or typed wrong (a ledger written before the
  /// config key existed reads as typed wrong) — the caller runs the full
  /// pipeline (safe failure, never an inherited gate from bad data).
  static Future<PassBatchLedger?> read(String featureDir) async {
    try {
      final raw = await File(pathFor(featureDir: featureDir)).readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final capturedAt = json['captured_at'];
      final suite = json['suite'];
      final baselineKey = json['baseline_key'];
      final configKey = json['config_key'];
      final exempt = json['exempt_behaviors'];
      final libDigest = json['lib_digest'];
      final testDigest = json['test_digest'];
      final preflightVerdict = json['preflight_verdict'];
      final reproofVerdict = json['reproof_verdict'];
      if (capturedAt is! String ||
          suite is! String ||
          baselineKey is! String ||
          configKey is! String ||
          exempt is! List ||
          libDigest is! String ||
          testDigest is! String ||
          preflightVerdict is! String ||
          reproofVerdict is! String ||
          // A partially-mistyped list (`[42]`) is a corrupt record, not a
          // coerced `[]` — otherwise it could false-match when the
          // surviving elements coincide with the effective exempt set.
          !exempt.every((e) => e is String)) {
        return null;
      }
      return PassBatchLedger(
        capturedAt: capturedAt,
        suite: suite,
        baselineKey: baselineKey,
        configKey: configKey,
        exemptBehaviors: List<String>.from(exempt),
        libDigest: libDigest,
        testDigest: testDigest,
        preflightVerdict: preflightVerdict,
        reproofVerdict: reproofVerdict,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persist the gate a green application just proved. A write failure is
  /// the caller's problem to surface as a warning only — a missing ledger
  /// costs the NEXT spawn one full pipeline, never correctness.
  Future<String> write({required String featureDir}) async {
    final file = File(pathFor(featureDir: featureDir));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(toJson()));
    return file.path;
  }

  /// The stable whole-tree digest of a [TreeSnapshot]: the sha256 of the
  /// sorted `path fingerprint` lines. Two captures of the same tree state
  /// always agree; any content, shape, or presence change flips it.
  static String treeDigest(TreeSnapshot snapshot) {
    final lines = snapshot.entries.keys.toList()..sort();
    final digest = sha256.convert(
      utf8.encode(lines.map((k) => '$k ${snapshot.entries[k]}').join('\n')),
    );
    return digest.toString();
  }

  /// The content fingerprint of the baseline file the invocation was
  /// handed (empty string when absent or unreadable — a missing baseline
  /// is simply a different gate key, and a corrupt one falls back to the
  /// absolute-green contract downstream anyway).
  static Future<String> baselineKeyFor(String? suiteBaselinePath) async {
    if (suiteBaselinePath == null || suiteBaselinePath.isEmpty) return '';
    try {
      final bytes = await File(suiteBaselinePath).readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (_) {
      return '';
    }
  }

  /// The content fingerprint of the repo-root suite CONFIGURATION the
  /// invocation runs under: `dart_test.yaml` (tag exclusions, presets,
  /// timeouts) and `pubspec.lock` (dependency resolution), when present.
  /// Neither lives in the `lib/`/`test/` trees the gate otherwise keys on,
  /// so folding them in keeps "byte-identical inputs ⇒ the same gate"
  /// true across separate runs. An absent file contributes its name only
  /// (still a stable key).
  static Future<String> configKeyFor(String projectRoot) async {
    final parts = <String>[];
    for (final name in const ['dart_test.yaml', 'pubspec.lock']) {
      try {
        final bytes = await File(p.join(projectRoot, name)).readAsBytes();
        parts.add('$name ${sha256.convert(bytes)}');
      } catch (_) {
        parts.add('$name -');
      }
    }
    return sha256.convert(utf8.encode(parts.join('\n'))).toString();
  }
}
