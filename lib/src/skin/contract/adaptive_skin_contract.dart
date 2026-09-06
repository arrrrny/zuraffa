/// adaptive-skin-contract.v1 — the typed declaration of a spec's
/// adaptive skin surface (issue #1004: Skin contract slots, the
/// adaptive-layout platform matrix in the spec).
///
/// The contract is the DECLARATION: the spec's `## Skin Contract`
/// section, authored as a yaml block. `zfa tdd plan` renders it into
/// `tdd/04-SKIN.md` as typed rows (the platform matrix, the state
/// machine, the routes) plus a machine-parseable JSON block generated
/// from this model — never prose the loop would have to guess through
/// (#964: the widget lane inventing finders from scenario literals is
/// exactly the failure this contract removes).
///
/// Companion to skin-contract.v1 (issue #1164, the fenced-JSON
/// per-view contract): one vocabulary family, two declaration forms —
/// the #1164 form declares per-view rows, this form declares the
/// adaptive-layout platform matrix, state machine, and route table.
///
/// Every field carries a declarative spec table where a shape is
/// shared: the parser and the JSON Schema generator both walk the
/// same tables, so model, parser, and schema cannot drift apart
/// (#1111: the schema is generated FROM the model, never
/// hand-maintained).
library;

/// The kind of value a contract field carries.
enum AdaptiveContractFieldType { string }

/// One field of a contract row class, shared by the parser and the
/// schema generator.
class AdaptiveContractFieldSpec {
  final String name;
  final AdaptiveContractFieldType type;
  final bool required;

  /// A regex the string value must match, when applicable.
  final String? pattern;

  const AdaptiveContractFieldSpec(
    this.name,
    this.type, {
    this.required = true,
    this.pattern,
  });
}

/// `routes[]` — one declared route of the skin's route table, derived
/// from the declared route name: the navigation target, the screen
/// class, and the route path.
class AdaptiveRouteContract {
  final String target;
  final String screenClass;
  final String path;

  const AdaptiveRouteContract({
    required this.target,
    required this.screenClass,
    required this.path,
  });

  /// The field table the parser's name validation and the schema
  /// generator's route def both walk.
  static const List<AdaptiveContractFieldSpec> fields = [
    AdaptiveContractFieldSpec(
      'target',
      AdaptiveContractFieldType.string,
      pattern: AdaptiveSkinContract.namePattern,
    ),
    AdaptiveContractFieldSpec(
      'screenClass',
      AdaptiveContractFieldType.string,
      pattern: r'^[A-Z][A-Za-z0-9]*$',
    ),
    AdaptiveContractFieldSpec(
      'path',
      AdaptiveContractFieldType.string,
      pattern: r'^/',
    ),
  ];

  /// Derives the full route contract from a declared route name:
  /// `deal_list` -> target `deal_list`, screen class `DealListScreen`,
  /// path `/deal_list`.
  factory AdaptiveRouteContract.fromTarget(String target) =>
      AdaptiveRouteContract(
        target: target,
        screenClass: screenClassFor(target),
        path: '/$target',
      );

  /// `deal_list` -> `DealListScreen`: every `_`-separated segment
  /// capitalized, suffixed with the screen class marker.
  static String screenClassFor(String target) =>
      '${target.split('_').map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}').join()}Screen';

  Map<String, dynamic> toJson() => {
    'target': target,
    'screenClass': screenClass,
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      other is AdaptiveRouteContract &&
      other.target == target &&
      other.screenClass == screenClass &&
      other.path == path;

  @override
  int get hashCode => Object.hash(target, screenClass, path);
}

/// The v1 adaptive skin contract: the spec's declared adaptive skin
/// surface (issue #1004).
class AdaptiveSkinContract {
  static const String schemaVersionV1 = '1';

  /// The name pattern every declared identifier must match (slots,
  /// states, route targets, platform names, override keys).
  static const String namePattern = r'^[a-z][a-z0-9_]*$';

  /// The state names that mark alternate (non-happy-path) states.
  static const Set<String> alternateStateNames = {'error', 'empty'};

  final String schemaVersion;
  final List<String> adaptiveSlots;
  final Map<String, Map<String, String>> platformOverrides;
  final List<String> states;

  /// The declared route names — the raw spec declaration; the derived
  /// route table is [routeContracts].
  final List<String> routeNames;

  const AdaptiveSkinContract({
    this.schemaVersion = schemaVersionV1,
    required this.adaptiveSlots,
    required this.platformOverrides,
    required this.states,
    required this.routeNames,
  });

  /// The happy-path chain: the declared states before the first
  /// alternate state name — `initial -> loading -> data` for the
  /// canonical `[initial, loading, data, error, empty]` declaration.
  List<String> get happyPathStates {
    final cut = states.indexWhere(alternateStateNames.contains);
    return cut < 0 ? List.of(states) : states.sublist(0, cut);
  }

  /// The alternate states: everything from the first `error`/`empty`
  /// onward — branch states reachable off the happy path.
  List<String> get alternateStates {
    final cut = states.indexWhere(alternateStateNames.contains);
    return cut < 0 ? const [] : states.sublist(cut);
  }

  /// The derived route table: one [AdaptiveRouteContract] per declared
  /// route name, in declaration order.
  List<AdaptiveRouteContract> get routeContracts => [
    for (final name in routeNames) AdaptiveRouteContract.fromTarget(name),
  ];

  /// The machine contract: the JSON the plan writes into 04-SKIN.md
  /// and the loop referees the skin against. Generated from this
  /// model — the schema generator walks the same field tables.
  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'adaptiveSlots': List.of(adaptiveSlots),
    'platformOverrides': {
      for (final entry in platformOverrides.entries)
        entry.key: Map.of(entry.value),
    },
    'states': List.of(states),
    'routes': [for (final r in routeContracts) r.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is AdaptiveSkinContract &&
      other.schemaVersion == schemaVersion &&
      _listEq(other.adaptiveSlots, adaptiveSlots) &&
      _mapEq(other.platformOverrides, platformOverrides) &&
      _listEq(other.states, states) &&
      _listEq(other.routeNames, routeNames);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    Object.hashAll(adaptiveSlots),
    // Value-based hashing: map entries hash by identity, so the
    // override map hashes its keys and values (both strings) instead.
    Object.hashAll(
      platformOverrides.entries.map(
        (e) => Object.hash(
          e.key,
          Object.hashAll(e.value.keys),
          Object.hashAll(e.value.values),
        ),
      ),
    ),
    Object.hashAll(states),
    Object.hashAll(routeNames),
  );

  static bool _listEq<T>(List<T> a, List<T> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

  static bool _mapEq(
    Map<String, Map<String, String>> a,
    Map<String, Map<String, String>> b,
  ) =>
      a.length == b.length &&
      a.entries.every(
        (e) =>
            b.containsKey(e.key) &&
            _listEq(
              e.value.entries.map((x) => '${x.key}=${x.value}').toList(),
              b[e.key]!.entries.map((x) => '${x.key}=${x.value}').toList(),
            ),
      );
}
