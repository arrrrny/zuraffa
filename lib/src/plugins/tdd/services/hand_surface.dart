/// The hand-surface vocabulary for blocked contracts (issue #1589).
///
/// A BLOCKED contract verdict (issue #1007) parks the cycle until the
/// declared contract is implemented BY HAND — but the pre-#1589 stops never
/// said where or how. The hand surface is the pair the operator needs to
/// act on the verdict without archaeology:
///
///   - the SEAM: the file that carries the implementation — the subject
///     (`lib/tdd/<feature>/<id>_subject.dart`, the throwing stub the
///     contract test imports) preferred over the generated contract test
///     (the #827 namespaced layout, the legacy flat fallback — the same
///     resolution the run driver's change-signal probes use). The test is
///     a generated, registry-owned artifact; the subject is where the
///     declared contract gets its implementation (issue #1625), and
///   - the WIRE command: `zfa tdd wire <id> --entity <Name>` — the
///     subject-wiring step that binds the generated subject stub to the
///     traced entity (bug #610's pipeline step). The entity is derived
///     from the behavior's dotted contract trace (`User.validateEmail` ->
///     `User`) and the example is printed ONLY when that entity actually
///     exists — otherwise the hint degrades to the hand-implement
///     instruction + the `zfa entity create` prerequisite, never a command
///     that `zfa tdd wire` itself would refuse (issue #1625). Without a
///     dot there is no entity to check and the command degrades to its
///     bare form.
///
/// Messaging only: nothing here mutates state, writes files, or changes
/// any verdict — every call site prints what these helpers return.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'entity_lookup.dart';

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

  /// Whether the generated entity [entityName] exists under [projectRoot]:
  /// the canonical `<entities>/<snake>/<snake>.dart` path first, then a
  /// recursive scan fallback (config can move the output dir) — the same
  /// resolution `locateEntityFile` performs for the wire command itself,
  /// mirrored synchronously because the hint builders are pure string
  /// functions. A probe error reads as "absent": the hand-implement
  /// instruction is the always-valid guidance in a broken tree.
  static bool entityExists({
    required String projectRoot,
    required String entityName,
  }) {
    final snake = toSnakeCase(entityName);
    final entitiesRoot = Directory(
      p.join(projectRoot, 'lib', 'src', 'domain', 'entities'),
    );
    try {
      final canonical = File(p.join(entitiesRoot.path, snake, '$snake.dart'));
      if (canonical.existsSync()) return true;
      if (!entitiesRoot.existsSync()) return false;
      final target = '$snake.dart';
      for (final entity in entitiesRoot.listSync(recursive: true)) {
        if (entity is File && p.basename(entity.path) == target) return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// The seam file path for [behaviorId], project-relative POSIX. The
  /// SUBJECT seam wins when it is on disk
  /// (`lib/tdd/<feature>/<snake>_subject.dart` — the throwing stub the
  /// contract test imports; implementing the declared contract happens
  /// there, not in the generated test, issue #1625), the existing #827
  /// namespaced test second (`test/tdd/<feature>/<snake>_test.dart`), the
  /// legacy flat fallback third (`test/tdd/<snake>_test.dart`) — the SAME
  /// two test resolutions the run driver's `_existingGeneratedTestPath` and
  /// the routing provenance preflight use, the `contract:` prefix retained
  /// (`contract:A1` -> `contract_a1_subject.dart` / `contract_a1_test.dart`).
  ///
  /// When none exists yet the canonical expected path is the SUBJECT — the
  /// file the operator creates and implements in — so the stop stays
  /// actionable for a seam that has not landed on disk. That fallback is
  /// DISPLAY ONLY: a caller handing a path to a gate (the driver's
  /// `--parked-seam`) must resolve through existence first (see
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
      // Issue #1625: the subject is the hand surface — the implementation
      // seam the contract test imports and that throws the BLOCKED verdict.
      p.join(projectRoot, 'lib', 'tdd', feature, '${snakeId}_subject.dart'),
      p.join(projectRoot, 'test', 'tdd', feature, '${snakeId}_test.dart'),
      p.join(projectRoot, 'test', 'tdd', '${snakeId}_test.dart'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return p.relative(candidate, from: projectRoot).replaceAll(r'\', '/');
      }
    }
    return p
        .join('lib', 'tdd', feature, '${snakeId}_subject.dart')
        .replaceAll(r'\', '/');
  }

  /// The one-line hand-surface hint the blocked stops print:
  /// `hand surface: seam <path> — implement the declared contract <c>
  /// there (e.g. `zfa tdd wire <id> --entity <E>`)`.
  ///
  /// Issue #1625: the with-entity wire example is printed ONLY when the
  /// traced entity actually exists under [projectRoot] — `zfa tdd wire`
  /// refuses a missing entity, so suggesting the command in that shape
  /// hands the operator a second dead end. When the entity is absent the
  /// hint carries the hand-implement instruction (the [seamPath] — the
  /// subject seam, per [seamPathFor]'s subject-first preference) plus the
  /// `zfa entity create` prerequisite instead.
  static String hintLine({
    required String behaviorId,
    required String seamPath,
    String? contract,
    required String projectRoot,
  }) {
    final contractPart = (contract == null || contract.trim().isEmpty)
        ? ''
        : ' ${contract.trim()}';
    final entity = entityFromContract(contract);
    if (entity == null ||
        entityExists(projectRoot: projectRoot, entityName: entity)) {
      return 'hand surface: seam $seamPath — implement the declared '
          'contract$contractPart there (e.g. '
          '`${wireCommandFor(behaviorId, contract: contract)}`)';
    }
    return 'hand surface: seam $seamPath — implement the declared '
        'contract$contractPart there by hand (no generated entity "$entity" '
        'exists; the wire step needs `zfa entity create -n $entity` first)';
  }
}
