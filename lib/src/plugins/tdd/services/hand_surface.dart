/// The hand-surface vocabulary for blocked contracts (issue #1589).
///
/// A BLOCKED contract verdict (issue #1007) parks the cycle until the
/// declared contract is implemented BY HAND — but the pre-#1589 stops never
/// said where or how. The hand surface is the pair the operator needs to
/// act on the verdict without archaeology:
///
///   - the SEAM: the generated contract test for the behavior (the #827
///     namespaced layout first, the legacy flat fallback second — the same
///     resolution the run driver's change-signal probes use), and
///   - the WIRE command: `zfa tdd wire <id> --entity <Name>` — the
///     subject-wiring step that binds the generated subject stub to the
///     traced entity (bug #610's pipeline step). The entity is derived
///     from the behavior's dotted contract trace (`User.validateEmail` ->
///     `User`); without a dot the command degrades to its bare form.
///
/// Messaging only: nothing here mutates state, writes files, or changes
/// any verdict — every call site prints what these helpers return.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class HandSurface {
  const HandSurface._();

  /// The entity a `zfa tdd wire` invocation binds the subject to, derived
  /// from the behavior's dotted contract trace (`User.validateEmail` ->
  /// `User`). Null when the trace is empty or carries no dot — the caller
  /// then degrades to the bare wire command.
  static String? entityFromContract(String? contract) {
    if (contract == null) return null;
    final trimmed = contract.trim();
    final dot = trimmed.indexOf('.');
    if (dot <= 0) return null;
    return trimmed.substring(0, dot);
  }

  /// The `zfa tdd wire` command for [behaviorId], carrying `--entity`
  /// when [contract] traces a dotted contract (the common shape: the
  /// first segment IS the traced entity).
  static String wireCommandFor(String behaviorId, {String? contract}) {
    final entity = entityFromContract(contract);
    return entity == null
        ? 'zfa tdd wire $behaviorId'
        : 'zfa tdd wire $behaviorId --entity $entity';
  }

  /// The seam file path for [behaviorId], project-relative POSIX. The
  /// existing #827 namespaced file wins (`test/tdd/<feature>/<snake>_test.dart`),
  /// the legacy flat fallback second (`test/tdd/<snake>_test.dart`) — the
  /// SAME two resolutions the run driver's `_existingGeneratedTestPath` and
  /// the routing provenance preflight use, the `contract:` prefix retained
  /// (`contract:A1` -> `contract_a1_test.dart`).
  ///
  /// When neither exists yet the canonical expected path is returned, so the
  /// stop stays actionable for a seam that has not landed on disk. That
  /// fallback is DISPLAY ONLY: a caller handing a path to a gate (the
  /// driver's `--parked-seam`) must resolve through existence first (see
  /// `_existingSeamRelativePath`), otherwise the gate would tolerate a file
  /// the verdict never saw parked.
  static String seamPathFor({
    required String projectRoot,
    required String feature,
    required String behaviorId,
  }) {
    final snakeId = behaviorId.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final candidates = [
      p.join(projectRoot, 'test', 'tdd', feature, '${snakeId}_test.dart'),
      p.join(projectRoot, 'test', 'tdd', '${snakeId}_test.dart'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return p.relative(candidate, from: projectRoot).replaceAll(r'\', '/');
      }
    }
    return p
        .join('test', 'tdd', feature, '${snakeId}_test.dart')
        .replaceAll(r'\', '/');
  }

  /// The one-line hand-surface hint the blocked stops print:
  /// `hand surface: seam <path> — implement the declared contract <c>
  /// there (e.g. `zfa tdd wire <id> --entity <E>`)`.
  static String hintLine({
    required String behaviorId,
    required String seamPath,
    String? contract,
  }) {
    final contractPart = (contract == null || contract.trim().isEmpty)
        ? ''
        : ' ${contract.trim()}';
    return 'hand surface: seam $seamPath — implement the declared '
        'contract$contractPart there (e.g. '
        '`${wireCommandFor(behaviorId, contract: contract)}`)';
  }
}
