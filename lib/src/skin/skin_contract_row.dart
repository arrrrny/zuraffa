/// SkinContractRow — one row of the runtime skin contract (issue
/// #1102).
///
/// A row is `id` + `requirement` + a pure check over [TreeFacts]. The
/// 006-login-skin pilot's rows were exactly this shape (closure over
/// the live facts); the named helpers below encode the three row
/// families the pilot proved:
///
/// * `textRenders` — the chaos-edit catcher: a specific string must
///   render (`[google-text] Continue with Google renders`);
/// * `anchorExists` — the typed `zfa:` anchor must be on screen;
/// * `progressIndicator` — the loading scrim must exist (the row
///   family that caught the real macOS bug — pilot lesson 1).
///
/// Every helper takes optional platform gating (pilot lesson 8): the
/// gate reads `facts.platform`, which the emitted walker captures
/// from `Theme.of(context).platform` — the same override-aware source
/// the layout gates on, so the auditor and the skin can never
/// disagree about platform. A row gated to a platform the facts do
/// not report SKIPS (conforms): unknown platform is never a phantom
/// violation.
library;

import 'tree_facts.dart';

/// The check signature: pure function of the audited facts.
typedef SkinContractCheck = bool Function(TreeFacts facts);

class SkinContractRow {
  /// Creates a row from a raw check closure.
  const SkinContractRow({
    required this.id,
    required this.requirement,
    required this.check,
  });

  /// A row requiring [text] to render in the live tree.
  ///
  /// The pilot demo's `google-text` row: after the chaos edit
  /// `'Continue with Google'` → `'Continue with Goggle'`, this row
  /// fails on the first audited frame and the banner appears — zero
  /// test runs, zero rebuilds.
  factory SkinContractRow.textRenders({
    required String id,
    required String text,
    SkinTargetPlatform? platform,
  }) => SkinContractRow(
    id: id,
    requirement: '$text renders${_gateSuffix(platform)}',
    check: (facts) => _gated(platform, facts) && facts.texts.contains(text),
  );

  /// A row requiring the typed anchor [anchor] (a `zfa:` contractId)
  /// to be present in the live tree.
  factory SkinContractRow.anchorExists({
    required String id,
    required String anchor,
    SkinTargetPlatform? platform,
  }) => SkinContractRow(
    id: id,
    requirement:
        'anchor ${_anchorKey(anchor)} exists'
        '${_gateSuffix(platform)}',
    check: (facts) =>
        _gated(platform, facts) && facts.anchors.contains(_anchorKey(anchor)),
  );

  /// A row requiring a progress indicator (loading scrim) on screen.
  factory SkinContractRow.progressIndicator({
    required String id,
    SkinTargetPlatform? platform,
  }) => SkinContractRow(
    id: id,
    requirement:
        'a loading scrim renders while content loads'
        '${_gateSuffix(platform)}',
    check: (facts) => _gated(platform, facts) && facts.hasProgressIndicator,
  );

  /// The row's id — the `[bracketed]` part of the banner line.
  final String id;

  /// The human requirement — what the banner shows after the id.
  final String requirement;

  /// The pure check over the audited facts.
  final SkinContractCheck check;

  /// Runs the check against [facts].
  bool evaluate(TreeFacts facts) => check(facts);

  static String _anchorKey(String contractId) =>
      contractId.startsWith('zfa:') ? contractId : 'zfa:$contractId';

  static String _gateSuffix(SkinTargetPlatform? platform) =>
      platform == null ? '' : ' on ${platform.label}';

  /// Gating: a row gated to a platform consumes only facts that
  /// report that platform. Facts that report a DIFFERENT platform
  /// fail the gate (the skin is on the wrong slot); facts with NO
  /// platform leave the row SKIPPED — conforming — never flagged:
  /// the auditor must not hallucinate a platform the Theme did not
  /// report.
  static bool _gated(SkinTargetPlatform? platform, TreeFacts facts) =>
      platform == null || facts.platform == null || facts.platform == platform;

  @override
  String toString() => 'SkinContractRow($id: $requirement)';
}
