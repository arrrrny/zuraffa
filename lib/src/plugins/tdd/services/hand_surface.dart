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

  /// Whether the seam at [seamPath] (project-relative) is a shape
  /// `zfa tdd wire` can parse and rewrite (bug #1752). A wrapped
  /// (multi-line) arrow-throw seam is wireable only when it carries the
  /// contract-seam provenance marker (`issue #1007`); the FFI harness
  /// (bug #835) and hand-written wrapped seams are not. A missing file
  /// reads as wireable (the canonical display fallback — the hint stays
  /// actionable for a seam that has not landed on disk).
  static bool seamIsWireable({
    required String projectRoot,
    required String seamPath,
  }) {
    final file = File(p.join(projectRoot, seamPath));
    if (!file.existsSync()) return true;
    String raw;
    try {
      raw = file.readAsStringSync();
    } catch (_) {
      return true;
    }
    final singleLine = RegExp(
      r'^[A-Za-z_][A-Za-z0-9_]*(?:<[^()<>=]*(?:<[^()<>=]*>)?[^()<>=]*>)?'
      r'[ \t]*\??'
      r'[ \t]+[A-Za-z_][A-Za-z0-9_]*'
      r'\([^)]*\)'
      r'[ \t]*=>[ \t]*throw UnimplementedError\(',
      multiLine: true,
    ).hasMatch(raw);
    if (singleLine) return true;
    final wrapped = RegExp(r'=>\s*\n\s*throw').hasMatch(raw);
    if (!wrapped) return false;
    return raw.contains('CONTRACT SEAM (issue #1007)');
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

  /// Whether the trace head names a non-entity production type (an
  /// interface, repository, usecase, controller, provider, service, …)
  /// rather than a generated domain entity. Such types never have (and
  /// never should have) an entity file under `lib/src/domain/entities`,
  /// so `zfa tdd wire --entity <Name>` can never succeed for them and the
  /// hint must NOT prescribe `zfa entity create -n <Name>`.
  ///
  /// Detection (issue #1889): a known non-entity name suffix, or a source
  /// file DECLARING the type anywhere under `lib/` outside the entities
  /// directory. The declaration check keeps a coincidentally named file
  /// (`foo.dart` for `Foo` that never declares `Foo`) from suppressing the
  /// entity-create prerequisite. A name that is neither (e.g.
  /// `Calculator`) is treated as an entity that may still need creating.
  static bool isNonEntityProductionType({
    required String entityName,
    required String projectRoot,
  }) {
    final name = entityName.trim();
    if (name.isEmpty) return false;
    const nonEntitySuffixes = <String>[
      'DataSource',
      'Repository',
      'UseCase',
      'Controller',
      'Provider',
      'Service',
      'Gateway',
      'Client',
      'Store',
      'Handler',
      'Adapter',
      'Manager',
      'Facade',
      'Interactor',
      'Presenter',
      'ViewModel',
      'Bloc',
      'Cubit',
      'Notifier',
      'Api',
      'Endpoint',
    ];
    for (final suffix in nonEntitySuffixes) {
      if (name.endsWith(suffix) && name.length > suffix.length) {
        return true;
      }
    }
    final target = '${toSnakeCase(name)}.dart';
    final candidates = _libFileIndex(projectRoot)[target];
    if (candidates == null) return false;
    for (final candidate in candidates) {
      if (_declaresType(candidate, name)) return true;
    }
    return false;
  }

  /// Per-[projectRoot] index of `lib/` source files outside the entities
  /// directory, keyed by basename (issue #1889 review). `hintLine` runs
  /// once per blocked behavior, so walking the whole `lib/` tree on every
  /// call is O(tree size) per behavior; the hint builders are messaging
  /// only and one `tdd run` sees a stable tree, so a per-process cache is
  /// enough. A probe error reads as an empty index ("absent") — the
  /// hand-implement instruction is the always-valid guidance there.
  static final Map<String, Map<String, List<String>>> _libFileIndexByRoot =
      <String, Map<String, List<String>>>{};

  static Map<String, List<String>> _libFileIndex(String projectRoot) {
    final root = p.normalize(p.absolute(projectRoot));
    final cached = _libFileIndexByRoot[root];
    if (cached != null) return cached;
    final index = <String, List<String>>{};
    final libRoot = Directory(p.join(root, 'lib'));
    if (libRoot.existsSync()) {
      final entitiesRoot = p.join(root, 'lib', 'src', 'domain', 'entities');
      try {
        for (final entry in libRoot.listSync(recursive: true)) {
          if (entry is! File) continue;
          if (p.isWithin(entitiesRoot, entry.path)) continue;
          index
              .putIfAbsent(p.basename(entry.path), () => <String>[])
              .add(entry.path);
        }
      } catch (_) {
        // A probe error reads as "absent" (see the method doc above).
      }
    }
    return _libFileIndexByRoot[root] = index;
  }

  /// Whether the source at [path] DECLARES [typeName] as a class, mixin,
  /// enum, typedef, or extension — the filesystem signal's guard against
  /// a coincidentally named file (issue #1889 review).
  static bool _declaresType(String path, String typeName) {
    String source;
    try {
      source = File(path).readAsStringSync();
    } catch (_) {
      return false;
    }
    final declaration = RegExp(
      r'\b(?:class|mixin|enum|typedef|extension)\s+'
      '${RegExp.escape(typeName)}'
      r'\b',
    );
    return declaration.hasMatch(source);
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
    final nonEntity =
        entity != null &&
        isNonEntityProductionType(entityName: entity, projectRoot: projectRoot);
    // Bug #1752: prescribe the wire command only when the seam on disk is
    // a shape `zfa tdd wire` can actually parse (and the traced entity
    // exists). A seam wire refuses (the FFI harness's wrapped shape, or a
    // hand-written wrapped seam) degrades to the hand-implement
    // instruction instead — never a dead-end command.
    // Issue #1889: a non-entity production type (interface, repository,
    // usecase, controller, …) is never wireable, even when a same-named
    // file happens to exist — never suggest `zfa entity create` for it.
    final wireable = entity == null
        ? true
        : !nonEntity &&
              entityExists(projectRoot: projectRoot, entityName: entity) &&
              seamIsWireable(projectRoot: projectRoot, seamPath: seamPath);
    if (entity == null || wireable) {
      return 'hand surface: seam $seamPath — implement the declared '
          'contract$contractPart there (e.g. '
          '`${wireCommandFor(behaviorId, contract: contract)}`)';
    }
    if (nonEntity) {
      return 'hand surface: seam $seamPath — implement the declared '
          'contract$contractPart there by hand (removing the '
          'UnimplementedError and implementing the production behavior '
          'directly)';
    }
    if (!entityExists(projectRoot: projectRoot, entityName: entity)) {
      return 'hand surface: seam $seamPath — implement the declared '
          'contract$contractPart there by hand (no generated entity "$entity" '
          'exists; the wire step needs `zfa entity create -n $entity` first)';
    }
    return 'hand surface: seam $seamPath — implement the declared '
        'contract$contractPart there by hand (the seam shape is not one '
        '`zfa tdd wire` can rewrite; implement it directly)';
  }
}
