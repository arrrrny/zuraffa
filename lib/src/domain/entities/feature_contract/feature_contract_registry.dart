/// FeatureContractRegistry (spec 1098): the typed answer to "does this
/// feature exist, what does it own, where are its boundaries?".
///
/// Contracts live as declared facts at `specs/<feature-id>/contract.yaml`
/// — the same specs tree the slice composition already treats as the
/// feature's receipts. A project with no contract files yields an empty
/// registry, and every consumer treats an empty registry as "validation
/// off" so existing projects scaffold exactly as before.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../../plugins/slice/models/slice_boundary.dart';
import 'feature_contract.dart';

/// The canonical contract file name inside a feature's spec dir.
const String kFeatureContractFileName = 'contract.yaml';

/// Parses [yamlText] into a typed [FeatureContract].
///
/// Throws [ArgumentError] when the contract declares no `id`.
FeatureContract parseFeatureContractYaml(
  String yamlText, {
  String? sourcePath,
}) {
  final doc = loadYamlNode(yamlText);
  if (doc is! YamlMap) {
    throw ArgumentError(
      'Feature contract must be a YAML map'
      '${sourcePath != null ? ' ($sourcePath)' : ''}.',
    );
  }
  final map = <String, dynamic>{
    for (final entry in doc.entries) entry.key.toString(): entry.value,
  };

  final id = map['id']?.toString().trim() ?? '';
  if (id.isEmpty) {
    throw ArgumentError(
      'Feature contract requires a non-empty `id`'
      '${sourcePath != null ? ' ($sourcePath)' : ''}.',
    );
  }
  if (!FeatureContractId.isValidKebab(id)) {
    throw ArgumentError.value(
      id,
      'id',
      'Feature contract id must be kebab-case',
    );
  }

  return FeatureContract(
    id: id,
    displayName: map['display_name']?.toString() ?? id,
    entities: _stringList(map['entities']) ?? const <String>[],
    boundary: _boundaryFrom(map['boundary']),
    routes: {
      for (final route in _stringList(map['routes']) ?? const <String>[]) route,
    },
    xrayLayer: map['xray_layer'] == null
        ? null
        : XRayLayer.parse(map['xray_layer'].toString()),
    argSchema: map['arg_schema'] is Map
        ? Map<String, dynamic>.from(map['arg_schema'] as Map)
        : null,
  );
}

List<String>? _stringList(dynamic value) {
  if (value is YamlList) {
    return [for (final item in value) item.toString()];
  }
  if (value is List) {
    return [for (final item in value) item.toString()];
  }
  if (value is String && value.trim().isNotEmpty) {
    return [value.trim()];
  }
  return null;
}

SliceBoundary? _boundaryFrom(dynamic value) {
  if (value is! YamlMap && value is! Map) return null;
  final map = value is YamlMap
      ? {for (final entry in value.entries) entry.key.toString(): entry.value}
      : Map<String, dynamic>.from(value as Map);
  final typeName = map['type_name']?.toString() ?? '';
  final interfaceFile = map['interface_file']?.toString() ?? '';
  if (typeName.isEmpty || interfaceFile.isEmpty) return null;
  return SliceBoundary(
    typeName: typeName,
    interfaceFile: interfaceFile,
    diRegistrationFile: map['di_registration_file']?.toString(),
    mockStrategy: map['mock_strategy']?.toString() ?? 'auto',
  );
}

/// Keystroke-level identity checks for feature contract ids.
abstract final class FeatureContractId {
  /// Kebab-case: lowercase letters/digits separated by single dashes,
  /// no leading/trailing dash, never empty.
  static final RegExp _kebab = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  /// Whether [id] is a valid stable kebab feature id.
  static bool isValidKebab(String id) => _kebab.hasMatch(id);
}

/// An in-memory registry of known feature contracts.
class FeatureContractRegistry {
  final Map<String, FeatureContract> _byId = {};

  /// Creates a registry seeded with [contracts] (later ids win).
  FeatureContractRegistry({List<FeatureContract> contracts = const []}) {
    for (final contract in contracts) {
      register(contract);
    }
  }

  /// All registered contracts.
  List<FeatureContract> get contracts => List.unmodifiable(_byId.values);

  /// The known feature ids.
  Set<String> get knownIds => _byId.keys.toSet();

  /// Whether any contract is registered. When false, every consumer
  /// treats contract validation as off (back-compat).
  bool get isNotEmpty => _byId.isNotEmpty;

  /// Registers [contract]; a later registration with the same id replaces
  /// the earlier one.
  void register(FeatureContract contract) {
    _byId[contract.id] = contract;
  }

  /// The contract with [id], or `null`.
  FeatureContract? findById(String id) => _byId[id];

  /// The contract with [id], or a [StateError] listing the known ids —
  /// the actionable failure an agent needs to self-correct.
  FeatureContract require(String id) {
    final contract = _byId[id];
    if (contract != null) return contract;
    final known = _byId.keys.toList()..sort();
    throw StateError(
      'Unknown feature contract: "$id". Known contracts: '
      '${known.isEmpty ? "(none)" : known.join(", ")}.',
    );
  }

  /// Scans `<projectRoot>/specs/*/contract.yaml` and returns every
  /// discoverable contract. A specs dir without a contract file, or with
  /// an unparseable one, is skipped (declared facts only — never guess).
  static FeatureContractRegistry scanProject(String projectRoot) {
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (!specsDir.existsSync()) return FeatureContractRegistry();
    final contracts = <FeatureContract>[];
    for (final entity in specsDir.listSync()) {
      if (entity is! Directory) continue;
      final contract = loadFromSpecDir(entity.path);
      if (contract != null) contracts.add(contract);
    }
    return FeatureContractRegistry(contracts: contracts);
  }

  /// Loads the contract declared at `specs/<dirName>/contract.yaml`, or
  /// `null` when absent/unparseable.
  static FeatureContract? loadFromSpecDir(String specDirPath) {
    final file = File(p.join(specDirPath, kFeatureContractFileName));
    if (!file.existsSync()) return null;
    try {
      final contract = parseFeatureContractYaml(
        file.readAsStringSync(),
        sourcePath: file.path,
      );
      return contract;
    } on ArgumentError {
      return null;
    } on YamlException {
      return null;
    }
  }
}
