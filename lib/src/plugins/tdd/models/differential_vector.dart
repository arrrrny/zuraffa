/// The differential result vector (bug #805 — generator differential
/// testing, vision slice v0).
///
/// One [EntryVector] per (corpus entry, generator ref) pair holds one
/// [StepVector] per driven step plus the artifact inventory. The
/// vector records BEHAVIOR — exit codes, outcome classes, machine
/// tokens, dart-test pass/fail counts, and artifact paths — never
/// bytes, so harmless formatting drift never masks a real behavioral
/// divergence and a real one can never hide behind byte-identity.
library;

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _listHash<T>(List<T> list) => Object.hashAll(list);

/// The behavioral class of one driven step.
///
/// - `complete`: exit 0 — the generator contract held.
/// - `failed`: non-zero exit — the generator ran and reported failure
///   (or emitted no machine line at all).
/// - `hang`: the step outlived the wall-clock budget and was killed —
///   the #744 class the differential gate exists to catch before merge.
enum DifferentialStepOutcome { complete, failed, hang }

/// One driven step's observed behavior.
class StepVector {
  const StepVector({
    required this.label,
    required this.exitCode,
    required this.outcome,
    this.token,
    this.passCount,
    this.failCount,
  });

  factory StepVector.fromJson(Map<String, dynamic> json) => StepVector(
    label: json['label'] as String,
    exitCode: json['exit'] as int,
    outcome: DifferentialStepOutcome.values.byName(json['outcome'] as String),
    token: json['token'] as String?,
    passCount: json['pass'] as int?,
    failCount: json['fail'] as int?,
  );

  /// The human-readable step name (e.g. `gen U2`, `dart test test/tdd`).
  final String label;

  /// The child's exit code; `-1` for a killed (hang) step.
  final int exitCode;

  /// The behavioral outcome class.
  final DifferentialStepOutcome outcome;

  /// The machine token parsed from the step's summary contract (gen's
  /// JSON `verdict`, make's `outcome=` label, run's `result=`); null
  /// when the child spoke no machine line — itself an observation the
  /// compare surfaces, never silently normalized away.
  final String? token;

  /// dart-test pass counter (`+n`) for test steps; null otherwise.
  final int? passCount;

  /// dart-test fail counter (`-n`) for test steps; null otherwise.
  final int? failCount;

  Map<String, dynamic> toJson() => {
    'label': label,
    'exit': exitCode,
    'outcome': outcome.name,
    'token': token,
    'pass': passCount,
    'fail': failCount,
  };

  StepVector copyWithOutcome(DifferentialStepOutcome outcome) => StepVector(
    label: label,
    exitCode: exitCode,
    outcome: outcome,
    token: token,
    passCount: passCount,
    failCount: failCount,
  );

  @override
  bool operator ==(Object other) =>
      other is StepVector &&
      other.label == label &&
      other.exitCode == exitCode &&
      other.outcome == outcome &&
      other.token == token &&
      other.passCount == passCount &&
      other.failCount == failCount;

  @override
  int get hashCode =>
      Object.hash(label, exitCode, outcome, token, passCount, failCount);

  @override
  String toString() =>
      'StepVector($label, exit: $exitCode, outcome: ${outcome.name}'
      '${token == null ? '' : ', token: $token'}'
      '${passCount == null ? '' : ', +$passCount -$failCount'})';
}

/// One (corpus entry, generator ref) pair's full behavioral vector.
class EntryVector {
  EntryVector({
    required this.entry,
    required this.ref,
    required this.steps,
    List<String>? artifacts,
  }) : artifacts = List<String>.of(artifacts ?? const <String>[])..sort();

  final String entry;

  /// The ref as given on the command line (`--from` / `--to` value).
  final String ref;

  final List<StepVector> steps;

  /// Sorted relative artifact paths under the entry's artifact roots —
  /// the inventory dimension (paths, deliberately not bytes).
  final List<String> artifacts;

  /// The comma-joined per-step outcome names in step order — the
  /// one-line behavioral fingerprint (`hang` vs `complete, complete`).
  String get outcomeSummary => steps.map((s) => s.outcome.name).join(', ');

  @override
  bool operator ==(Object other) =>
      other is EntryVector &&
      other.entry == entry &&
      other.ref == ref &&
      _listEquals(other.steps, steps) &&
      _listEquals(other.artifacts, artifacts);

  @override
  int get hashCode =>
      Object.hash(entry, ref, _listHash(steps), _listHash(artifacts));

  @override
  String toString() =>
      'EntryVector($entry@$ref, steps: ${steps.length}, '
      'artifacts: ${artifacts.length})';
}

/// One behavioral divergence between the two refs' vectors for an
/// entry, already rendered for the report.
class VectorFinding {
  const VectorFinding({
    required this.kind,
    required this.detail,
    this.regression = true,
  });

  /// `step` (outcome/token divergence or a step-shape change),
  /// `step-improved` (an outcome that got BETTER on the head side),
  /// `counts` (pass/fail divergence), `artifact-added`, or
  /// `artifact-removed`.
  final String kind;

  final String detail;

  /// Whether this finding is a REGRESSION (the head side behaves worse
  /// than the baseline — the only class that fails the gate). A
  /// behavior change in the improving direction (`failed` → `complete`,
  /// a lost `hang`, a repaired artifact inventory) is reported but must
  /// not block a PR whose whole point is to fix the generator.
  final bool regression;

  @override
  String toString() => detail;
}

/// Severity rank of a step outcome: lower is better. `complete` (the
/// generator contract held) < `failed` (reported failure) < `hang`
/// (killed — the worst observable class).
int _outcomeSeverity(DifferentialStepOutcome outcome) => switch (outcome) {
  DifferentialStepOutcome.complete => 0,
  DifferentialStepOutcome.failed => 1,
  DifferentialStepOutcome.hang => 2,
};

/// Compares the two refs' vectors for one entry. Empty means the pair
/// behaved identically in every recorded dimension.
///
/// Directional contract (issue #805, as amended): a finding is a
/// REGRESSION — and fails the gate — only when the head side behaves
/// WORSE than the baseline. A strictly better outcome (`failed` →
/// `complete`, `hang` → `failed`/`complete`) is reported as a
/// `step-improved` finding with [VectorFinding.regression] false; the
/// improvement subsumes that step's token/count dimensions (they cannot
/// be meaningfully compared across an outcome change). A lost artifact
/// is a regression; a new artifact is reported but non-fatal (a fix
/// legitimately emits files the broken baseline never produced).
List<VectorFinding> compareEntryVectors({
  required EntryVector from,
  required EntryVector to,
}) {
  final findings = <VectorFinding>[];
  final maxSteps = from.steps.length > to.steps.length
      ? from.steps.length
      : to.steps.length;
  for (var i = 0; i < maxSteps; i++) {
    final a = i < from.steps.length ? from.steps[i] : null;
    final b = i < to.steps.length ? to.steps[i] : null;
    if (a == null || b == null) {
      final extra = a ?? b!;
      findings.add(
        VectorFinding(
          kind: 'step',
          detail:
              '${extra.label}: only ${a == null ? to.ref : from.ref} '
              'ran this step',
        ),
      );
      continue;
    }
    if (a.outcome != b.outcome) {
      final improved =
          _outcomeSeverity(b.outcome) < _outcomeSeverity(a.outcome);
      findings.add(
        VectorFinding(
          kind: improved ? 'step-improved' : 'step',
          regression: !improved,
          detail: '${a.label}: ${a.outcome.name} vs ${b.outcome.name}',
        ),
      );
      continue;
    }
    if (a.token != b.token) {
      findings.add(
        VectorFinding(
          kind: 'step',
          detail:
              '${a.label}: token ${a.token ?? '(none)'} vs '
              '${b.token ?? '(none)'}',
        ),
      );
    }
    if (a.passCount != b.passCount || a.failCount != b.failCount) {
      String side(StepVector s) => s.passCount == null
          ? '(no counts)'
          : '+${s.passCount} -${s.failCount}';
      findings.add(
        VectorFinding(
          kind: 'counts',
          detail: '${a.label}: ${side(a)} vs ${side(b)}',
        ),
      );
    }
  }
  final fromArtifacts = from.artifacts.toSet();
  final toArtifacts = to.artifacts.toSet();
  for (final path in toArtifacts.difference(fromArtifacts)) {
    findings.add(
      VectorFinding(kind: 'artifact-added', detail: path, regression: false),
    );
  }
  for (final path in fromArtifacts.difference(toArtifacts)) {
    findings.add(VectorFinding(kind: 'artifact-removed', detail: path));
  }
  return findings;
}
