/// skin-contract.v1 — the typed declaration of a spec's skin surface
/// (issue #1164, stage 1/4 of #1111).
///
/// The contract is the DECLARATION; the runtime kit (`lib/src/skin/`)
/// is the enforcement. One vocabulary, two roles: row shapes align with
/// `SkinContractRow` and platform slots with `SkinTargetPlatform`, but
/// this module has no runtime dependencies.
///
/// Every class below carries a declarative [SkinContractFieldSpec] table.
/// The parser and the JSON Schema generator both walk those tables, so
/// model, parser, and schema cannot drift apart (#1111: the schema is
/// generated FROM the model, never hand-maintained).
library;

/// The kind of value a contract field carries.
enum SkinContractFieldType { string, boolean }

/// One field of a contract class, shared by the parser and the schema
/// generator.
class SkinContractFieldSpec {
  final String name;
  final SkinContractFieldType type;
  final bool required;

  /// Allowed values (enum constraint), when the field is an enum.
  final List<String>? values;

  /// A regex the string value must match, when applicable.
  final String? pattern;

  const SkinContractFieldSpec(
    this.name,
    this.type, {
    this.required = true,
    this.values,
    this.pattern,
  });
}

/// `routes[]` — one declared route: path to view.
class ContractRoute {
  final String path;
  final String view;

  const ContractRoute({required this.path, required this.view});

  static const List<SkinContractFieldSpec> fields = [
    SkinContractFieldSpec('path', SkinContractFieldType.string, pattern: r'^/'),
    SkinContractFieldSpec(
      'view',
      SkinContractFieldType.string,
      pattern: r'^[A-Z][A-Za-z0-9]*$',
    ),
  ];

  Map<String, dynamic> toJson() => {'path': path, 'view': view};

  @override
  bool operator ==(Object other) =>
      other is ContractRoute && other.path == path && other.view == view;

  @override
  int get hashCode => Object.hash(path, view);
}

/// `states[]` — one view's declared state handling.
class ContractState {
  final String view;
  final bool loading;
  final String error; // none | toaster | inline
  final bool empty;

  const ContractState({
    required this.view,
    required this.loading,
    required this.error,
    required this.empty,
  });

  static const List<SkinContractFieldSpec> fields = [
    SkinContractFieldSpec('view', SkinContractFieldType.string),
    SkinContractFieldSpec('loading', SkinContractFieldType.boolean),
    SkinContractFieldSpec(
      'error',
      SkinContractFieldType.string,
      values: ['none', 'toaster', 'inline'],
    ),
    SkinContractFieldSpec('empty', SkinContractFieldType.boolean),
  ];

  Map<String, dynamic> toJson() => {
    'view': view,
    'loading': loading,
    'error': error,
    'empty': empty,
  };

  @override
  bool operator ==(Object other) =>
      other is ContractState &&
      other.view == view &&
      other.loading == loading &&
      other.error == error &&
      other.empty == empty;

  @override
  int get hashCode => Object.hash(view, loading, error, empty);
}

/// `platformRows[]` — one view's adaptive-slot declaration per platform.
class ContractPlatformRow {
  final String view;
  final bool mobile;
  final bool ios;
  final bool android;
  final bool macos;

  const ContractPlatformRow({
    required this.view,
    required this.mobile,
    required this.ios,
    required this.android,
    required this.macos,
  });

  static const List<SkinContractFieldSpec> fields = [
    SkinContractFieldSpec('view', SkinContractFieldType.string),
    SkinContractFieldSpec('mobile', SkinContractFieldType.boolean),
    SkinContractFieldSpec('ios', SkinContractFieldType.boolean),
    SkinContractFieldSpec('android', SkinContractFieldType.boolean),
    SkinContractFieldSpec('macos', SkinContractFieldType.boolean),
  ];

  Map<String, dynamic> toJson() => {
    'view': view,
    'mobile': mobile,
    'ios': ios,
    'android': android,
    'macos': macos,
  };

  @override
  bool operator ==(Object other) =>
      other is ContractPlatformRow &&
      other.view == view &&
      other.mobile == mobile &&
      other.ios == ios &&
      other.android == android &&
      other.macos == macos;

  @override
  int get hashCode => Object.hash(view, mobile, ios, android, macos);
}

/// `stateRows[]` — one audit-row declaration for the runtime kit.
class ContractStateRow {
  final String view;
  final String row;
  final String kind; // observer | listener | builder

  const ContractStateRow({
    required this.view,
    required this.row,
    required this.kind,
  });

  static const List<SkinContractFieldSpec> fields = [
    SkinContractFieldSpec('view', SkinContractFieldType.string),
    SkinContractFieldSpec('row', SkinContractFieldType.string),
    SkinContractFieldSpec(
      'kind',
      SkinContractFieldType.string,
      values: ['observer', 'listener', 'builder'],
    ),
  ];

  Map<String, dynamic> toJson() => {'view': view, 'row': row, 'kind': kind};

  @override
  bool operator ==(Object other) =>
      other is ContractStateRow &&
      other.view == view &&
      other.row == row &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(view, row, kind);
}

/// The v1 skin contract: a spec's declared skin surface.
class SkinContract {
  static const String schemaVersionV1 = '1';

  final String schemaVersion;
  final List<ContractRoute> routes;
  final List<ContractState> states;
  final List<ContractPlatformRow> platformRows;
  final List<ContractStateRow> stateRows;

  const SkinContract({
    required this.schemaVersion,
    required this.routes,
    required this.states,
    required this.platformRows,
    required this.stateRows,
  });

  /// The contract's own field table — the sections the parser requires
  /// and the schema generator emits.
  static const Map<String, List<SkinContractFieldSpec>> sections = {
    'routes': ContractRoute.fields,
    'states': ContractState.fields,
    'platformRows': ContractPlatformRow.fields,
    'stateRows': ContractStateRow.fields,
  };

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'routes': [for (final r in routes) r.toJson()],
    'states': [for (final s in states) s.toJson()],
    'platformRows': [for (final p in platformRows) p.toJson()],
    'stateRows': [for (final s in stateRows) s.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is SkinContract &&
      other.schemaVersion == schemaVersion &&
      _listEq(other.routes, routes) &&
      _listEq(other.states, states) &&
      _listEq(other.platformRows, platformRows) &&
      _listEq(other.stateRows, stateRows);

  @override
  int get hashCode =>
      Object.hash(schemaVersion, routes, states, platformRows, stateRows);

  static bool _listEq<T>(List<T> a, List<T> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);
}
