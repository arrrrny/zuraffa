/// `CorpusPlan` — the rewrite-plan input the corpus runner consumes with
/// `--plan` (bug #836, spec 051-corpus-harness one level up): the declared
/// dependency edges topologically order the manifest before anything is
/// driven, and the declared FR/AC criteria feed the plan-gap ledger.
///
/// Two file shapes parse to the same model:
///
/// 1. A markdown rewrite plan (`rewrite-plan.md`) — dependency edge lines
///    carry an arrow between two feature tokens, prose tolerated:
///
///        ## Dependencies
///        - F002→F001
///        - F003 -> F002
///
///    (`A→B` means A depends on B — B is driven first.) Criteria lines
///    name the FRs/ACs a feature declares, one feature per line:
///
///        ## Criteria
///        - F001: FR-1, FR-2
///        - F002: AC-1, US2.AC3
///
/// 2. A TUPEC inventory (`inventory.json`):
///
///        {"features": [
///          {"id": "F001", "name": "001-f", "dependencies": [],
///           "criteria": ["FR-1"]},
///          {"id": "F002", "dependencies": ["F001"]}
///        ]}
///
///    `name` maps a plan id onto the manifest feature name (defaults to
///    the id itself); `requirements` is accepted as an alias for
///    `criteria`, `dependsOn` for `dependencies`.
///
/// The model is pure: parsing and ordering never touch the filesystem.
library;

import 'dart:convert';

import 'corpus_manifest.dart';

/// Raised when a plan cannot be parsed, references a feature outside the
/// manifest, or contains a dependency cycle. The message names the plan
/// and the recovery path (the honest runner-error outcome — nothing is
/// driven on a plan error).
class CorpusPlanException implements Exception {
  const CorpusPlanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One plan row: a feature id, the manifest feature name it maps to, the
/// plan ids it depends on (driven first), and the FR/AC criteria it
/// declares (the plan-gap coverage source).
class CorpusPlanFeature {
  const CorpusPlanFeature({
    required this.id,
    required this.name,
    required this.dependsOn,
    required this.criteria,
  });

  /// The plan's own feature token (e.g. `F002`).
  final String id;

  /// The manifest feature name this row drives (the `name` mapping when
  /// given, else the id).
  final String name;

  /// Plan ids this feature depends on — each must be driven first.
  final Set<String> dependsOn;

  /// Declared FR/AC criterion tokens (normalized uppercase).
  final List<String> criteria;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dependsOn': dependsOn.toList(),
    'criteria': criteria,
  };
}

/// The parsed plan: rows plus the dependency graph over manifest feature
/// names.
class CorpusPlan {
  const CorpusPlan({required this.features});

  final List<CorpusPlanFeature> features;

  /// The manifest feature names this plan drives, in plan row order.
  List<String> get featureNames =>
      features.map((f) => f.name).toList(growable: false);

  /// Parse [raw] (the file's text) from [path]. The shape is chosen by
  /// content — a JSON object is an inventory, anything else is markdown.
  /// Every unusable shape is a [CorpusPlanException] naming the file.
  static CorpusPlan parse(String raw, {required String path}) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) return _parseJson(trimmed, path);
    return _parseMarkdown(raw, path);
  }

  // -----------------------------------------------------------------
  // Markdown shape
  // -----------------------------------------------------------------

  static final RegExp _arrow = RegExp(
    r'([A-Za-z0-9_.\-]+)\s*(?:→|->)\s*([A-Za-z0-9_.\-]+)',
  );
  static final RegExp _criteriaLine = RegExp(
    r'^[-*\s]*([A-Za-z0-9_.\-]+)\s*:\s*(.+)$',
  );
  static final RegExp _criterionToken = RegExp(
    r'(?:FR|AC|US|NFR)[-_.]?[0-9]+(?:\.[A-Za-z0-9]+)?',
    caseSensitive: false,
  );

  static CorpusPlan _parseMarkdown(String raw, String path) {
    final rows = <String, CorpusPlanFeature>{};
    final criteriaByRow = <String, List<String>>{};
    void edge(String left, String right) {
      final row = rows.putIfAbsent(
        left,
        () => CorpusPlanFeature(
          id: left,
          name: left,
          dependsOn: <String>{},
          criteria: const [],
        ),
      );
      row.dependsOn.add(right);
      // The dependency side is a feature too (it must be driven first).
      rows.putIfAbsent(
        right,
        () => CorpusPlanFeature(
          id: right,
          name: right,
          dependsOn: <String>{},
          criteria: const [],
        ),
      );
    }

    for (final line in raw.split('\n')) {
      final arrowMatch = _arrow.firstMatch(line);
      if (arrowMatch != null) {
        edge(arrowMatch.group(1)!, arrowMatch.group(2)!);
        continue;
      }
      final criteriaMatch = _criteriaLine.firstMatch(line.trim());
      if (criteriaMatch != null) {
        final id = criteriaMatch.group(1)!;
        final value = criteriaMatch.group(2)!;
        final tokens = _criterionToken
            .allMatches(value)
            .map((m) => m.group(0)!.toUpperCase())
            .toList();
        if (tokens.isEmpty) continue;
        rows.putIfAbsent(
          id,
          () => CorpusPlanFeature(
            id: id,
            name: id,
            dependsOn: <String>{},
            criteria: const [],
          ),
        );
        criteriaByRow.putIfAbsent(id, () => <String>[]).addAll(tokens);
      }
    }
    if (rows.isEmpty) {
      // A plan with no edge and no criteria lines is a valid no-op: it
      // declares no constraints, so the manifest order is preserved (the
      // runner says so). Only an unreadable/unshapeable plan is an error.
      return const CorpusPlan(features: []);
    }
    final resolved = [
      for (final row in rows.values)
        CorpusPlanFeature(
          id: row.id,
          name: row.name,
          dependsOn: Set.of(row.dependsOn),
          criteria: List.of(criteriaByRow[row.id] ?? const []),
        ),
    ];
    return CorpusPlan(features: List.unmodifiable(resolved));
  }

  // -----------------------------------------------------------------
  // TUPEC inventory shape
  // -----------------------------------------------------------------

  static CorpusPlan _parseJson(String raw, String path) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw CorpusPlanException(
        'corpus plan $path is neither valid JSON nor a markdown plan '
        '(invalid JSON: ${e.message}).',
      );
    }
    if (decoded is! Map || decoded['features'] is! List) {
      throw CorpusPlanException(
        'corpus plan $path (inventory) must be an object with a '
        '"features" list — {"features": [{"id": ..., "name": ..., '
        '"dependencies": [...], "criteria": [...]}]}.',
      );
    }
    final rows = <CorpusPlanFeature>[];
    final list = decoded['features'] as List;
    for (var i = 0; i < list.length; i++) {
      final row = list[i];
      if (row is! Map) {
        throw CorpusPlanException(
          'corpus plan $path: features[$i] is not an object',
        );
      }
      final id = row['id'];
      if (id is! String || id.isEmpty) {
        throw CorpusPlanException(
          'corpus plan $path: features[$i] is missing a non-empty "id"',
        );
      }
      final name = row['name'] is String && (row['name'] as String).isNotEmpty
          ? row['name'] as String
          : id;
      final depsRaw = row['dependencies'] ?? row['dependsOn'] ?? const [];
      if (depsRaw is! List) {
        throw CorpusPlanException(
          'corpus plan $path: features[$i] "dependencies" is not a list',
        );
      }
      final deps = <String>{};
      for (final dep in depsRaw) {
        if (dep is! String || dep.isEmpty) {
          throw CorpusPlanException(
            'corpus plan $path: features[$i] has a non-string dependency',
          );
        }
        deps.add(dep);
      }
      final criteriaRaw = row['criteria'] ?? row['requirements'] ?? const [];
      if (criteriaRaw is! List) {
        throw CorpusPlanException(
          'corpus plan $path: features[$i] "criteria" is not a list',
        );
      }
      final criteria = criteriaRaw
          .whereType<String>()
          .map((c) => c.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toList();
      rows.add(
        CorpusPlanFeature(
          id: id,
          name: name,
          dependsOn: deps,
          criteria: criteria,
        ),
      );
    }
    if (rows.isEmpty) {
      // An inventory with an empty features list declares no constraints.
      return const CorpusPlan(features: []);
    }
    return CorpusPlan(features: List.unmodifiable(rows));
  }

  // -----------------------------------------------------------------
  // Topological ordering (stable Kahn over the manifest order)
  // -----------------------------------------------------------------

  /// Order [manifest]'s features so every declared dependency is driven
  /// first, breaking ties by manifest order (a stable, deterministic
  /// order). Unknown plan features and unknown dependency references are
  /// honest plan errors; a cycle is one too.
  ///
  /// Dependencies are resolved feature-name-wise: a plan edge `A -> B`
  /// drives B's manifest feature before A's. A dependency that names a
  /// manifest feature directly (not a plan row id) is honored as-is.
  static List<CorpusFeature> orderManifest(
    CorpusManifest manifest,
    CorpusPlan plan,
  ) {
    final byName = {for (final f in manifest.features) f.name: f};
    final planByName = {for (final f in plan.features) f.name: f};
    // Plan ids resolve independently of names: a TUPEC row may depend on
    // an id ("F001") while the manifest knows the mapped name ("f1-base").
    final planById = {for (final f in plan.features) f.id: f};

    for (final row in plan.features) {
      if (!byName.containsKey(row.name)) {
        throw CorpusPlanException(
          'corpus plan references feature "${row.name}" (row ${row.id}) '
          'which is not in the corpus manifest — the runner drives '
          'manifest features only. Recovery: align the plan with the '
          'manifest (or re-run the corpus import).',
        );
      }
    }

    // Edge graph over MANIFEST feature names: `deps[name]` = the set of
    // manifest features that must be driven before `name`.
    final deps = <String, Set<String>>{
      for (final f in manifest.features) f.name: <String>{},
    };
    for (final row in plan.features) {
      for (final depId in row.dependsOn) {
        final depName =
            planById[depId]?.name ?? planByName[depId]?.name ?? depId;
        if (!byName.containsKey(depName)) {
          throw CorpusPlanException(
            'corpus plan row ${row.name} depends on "$depId" which is '
            'not in the corpus manifest — the runner drives manifest '
            'features only. Recovery: align the plan with the manifest.',
          );
        }
        if (depName != row.name) deps[row.name]!.add(depName);
      }
    }

    // Kahn's algorithm; the ready set is scanned in manifest order so
    // independent features keep their manifest position (stable).
    final ordered = <CorpusFeature>[];
    final remaining = Map.of(deps);
    while (remaining.isNotEmpty) {
      String? next;
      for (final feature in manifest.features) {
        final name = feature.name;
        if (!remaining.containsKey(name)) continue;
        if (remaining[name]!.isEmpty) {
          next = name;
          break;
        }
      }
      if (next == null) {
        final cycle = remaining.keys.toList()..sort();
        throw CorpusPlanException(
          'corpus plan has a dependency cycle involving: '
          '${cycle.join(', ')} — topological ordering is impossible. '
          'Recovery: break the cycle in the plan (a corpus cannot be '
          'driven in a circular dependency order).',
        );
      }
      final feature = byName[next]!;
      ordered.add(feature);
      remaining.remove(next);
      for (final pending in remaining.values) {
        pending.remove(next);
      }
    }
    return ordered;
  }
}
