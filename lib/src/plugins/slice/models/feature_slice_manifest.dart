/// FeatureSliceManifest (spec 1114): the FEATURE-CENTRIC slice manifest.
///
/// The 043 `SliceManifest` groups files by entity, with the feature as
/// the outer path key. After 1114 the feature is the primary axis:
/// `manifest.feature` IS the [FeatureContract], and
/// entities/routes/layers are children of the feature — engine files
/// attribute to `feature.entities`, skin views to `feature.routes`,
/// every layer to `feature.xrayLayer`.
///
/// Serialized as `slice.yaml` (schema `slice.manifest.v2`) at the slice
/// root `.zfa/slices/<feature-id>/`. Emission is hand-rolled (the repo
/// pins no yaml_writer) with safely quoted string scalars.
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../../../domain/entities/feature_contract/feature_contract.dart';
import '../models/slice_boundary.dart';

/// One file of the slice, attributed to its feature axis parent.
class FeatureSliceFile {
  /// Path relative to the slice root (`engine/entities/user/user.dart`).
  final String relativePath;

  /// The clean-architecture layer tag:
  /// `domain` (engine core) | `data` (engine outer) |
  /// `presentation` (skin) | `contract` | `receipts`.
  final String layer;

  /// The owning contract entity (engine files), when attributable.
  final String? entity;

  /// The owning contract route (skin view files), when attributable.
  final String? route;

  /// sha256 of the file at compose time.
  final String hashAtCut;

  const FeatureSliceFile({
    required this.relativePath,
    required this.layer,
    this.entity,
    this.route,
    required this.hashAtCut,
  });
}

/// One route of the skin half: the contract path and its derived view.
class FeatureSkinRoute {
  /// The route path (`/login/forgot`).
  final String path;

  /// The view class name serving the route (`LoginForgotView`).
  final String view;

  const FeatureSkinRoute({required this.path, required this.view});
}

/// The feature-centric manifest of a composed slice.
class FeatureSliceManifest {
  /// The manifest schema tag.
  final String schema;

  /// When the slice was composed.
  final DateTime createdAt;

  /// THE primary axis: the typed feature contract this slice is the
  /// base of. Entities/routes/layer below are its children.
  final FeatureContract feature;

  /// Where the contract was declared from
  /// (`contract.yaml` | `spec.md:skin-contract` | `spec.md:lanes-core`).
  final String origin;

  /// Absolute path to the source project.
  final String projectRoot;

  /// Git branch of the parent repo at compose time, when known.
  final String? parentBranch;

  /// HEAD sha of the parent repo at compose time, when known.
  final String? parentHead;

  /// The slice root relative to the project root
  /// (`.zfa/slices/<feature-id>`).
  final String sliceRoot;

  /// Engine-half files (entities, usecases, services, repositories,
  /// datasources, mocks, DI) — children of `feature.entities`.
  final List<FeatureSliceFile> engineFiles;

  /// Entity → engine files (the feature's entity children).
  final Map<String, List<String>> engineEntities;

  /// Skin-half files (views, widgets, states, routes) — children of
  /// `feature.routes`.
  final List<FeatureSliceFile> skinFiles;

  /// Route → view mapping of the skin half.
  final List<FeatureSkinRoute> skinRoutes;

  /// The contract JSON file, relative to the slice root.
  final String contractFile;

  /// sha256 of the contract JSON.
  final String contractDigest;

  /// Receipt files, relative to the slice root.
  final List<String> receiptsFiles;

  /// Harness files the composition GENERATED (router barrel, DI
  /// harness, boundary mock) — not agent work, never copied back.
  final List<String> generatedFiles;

  /// The worktree path relative to the project root, once opened.
  final String? worktreePath;

  /// The worktree branch (`slice/<id>`), once opened.
  final String? worktreeBranch;

  /// The worktree HEAD commit, once opened.
  final String? worktreeCommit;

  const FeatureSliceManifest({
    this.schema = 'slice.manifest.v2',
    required this.createdAt,
    required this.feature,
    required this.origin,
    required this.projectRoot,
    this.parentBranch,
    this.parentHead,
    required this.sliceRoot,
    this.engineFiles = const [],
    this.engineEntities = const {},
    this.skinFiles = const [],
    this.skinRoutes = const [],
    this.contractFile = 'contract/contract.json',
    this.contractDigest = '',
    this.receiptsFiles = const [],
    this.generatedFiles = const [],
    this.worktreePath,
    this.worktreeBranch,
    this.worktreeCommit,
  });

  static const Object _unset = Object();

  /// Returns a copy with the given fields replaced.
  FeatureSliceManifest copyWith({
    DateTime? createdAt,
    FeatureContract? feature,
    String? origin,
    String? projectRoot,
    Object? parentBranch = _unset,
    Object? parentHead = _unset,
    String? sliceRoot,
    List<FeatureSliceFile>? engineFiles,
    Map<String, List<String>>? engineEntities,
    List<FeatureSliceFile>? skinFiles,
    List<FeatureSkinRoute>? skinRoutes,
    String? contractFile,
    String? contractDigest,
    List<String>? receiptsFiles,
    List<String>? generatedFiles,
    Object? worktreePath = _unset,
    Object? worktreeBranch = _unset,
    Object? worktreeCommit = _unset,
  }) {
    return FeatureSliceManifest(
      schema: schema,
      createdAt: createdAt ?? this.createdAt,
      feature: feature ?? this.feature,
      origin: origin ?? this.origin,
      projectRoot: projectRoot ?? this.projectRoot,
      parentBranch: parentBranch == _unset
          ? this.parentBranch
          : parentBranch as String?,
      parentHead: parentHead == _unset
          ? this.parentHead
          : parentHead as String?,
      sliceRoot: sliceRoot ?? this.sliceRoot,
      engineFiles: engineFiles ?? this.engineFiles,
      engineEntities: engineEntities ?? this.engineEntities,
      skinFiles: skinFiles ?? this.skinFiles,
      skinRoutes: skinRoutes ?? this.skinRoutes,
      contractFile: contractFile ?? this.contractFile,
      contractDigest: contractDigest ?? this.contractDigest,
      receiptsFiles: receiptsFiles ?? this.receiptsFiles,
      generatedFiles: generatedFiles ?? this.generatedFiles,
      worktreePath: worktreePath == _unset
          ? this.worktreePath
          : worktreePath as String?,
      worktreeBranch: worktreeBranch == _unset
          ? this.worktreeBranch
          : worktreeBranch as String?,
      worktreeCommit: worktreeCommit == _unset
          ? this.worktreeCommit
          : worktreeCommit as String?,
    );
  }

  /// Serializes to the `slice.yaml` document body. Feature-first: the
  /// `feature:` block leads, engine/skin/contract/receipts nest below.
  String toYaml() {
    final buffer = StringBuffer();
    buffer.writeln('schema: ${_yamlString(schema)}');
    buffer.writeln('createdAt: ${_yamlString(createdAt.toIso8601String())}');
    buffer.writeln('origin: ${_yamlString(origin)}');
    buffer.writeln('projectRoot: ${_yamlString(projectRoot)}');
    buffer.writeln('parentBranch: ${_yamlNullable(parentBranch)}');
    buffer.writeln('parentHead: ${_yamlNullable(parentHead)}');
    buffer.writeln('sliceRoot: ${_yamlString(sliceRoot)}');
    buffer.writeln('feature:');
    buffer.writeln('  id: ${_yamlString(feature.id)}');
    buffer.writeln('  display_name: ${_yamlString(feature.displayName)}');
    buffer.writeln('  xray_layer: ${_yamlNullable(feature.xrayLayer?.name)}');
    buffer.writeln('  entities:');
    _writeStringList(buffer, feature.entities ?? const <String>[], indent: 4);
    buffer.writeln('  routes:');
    _writeStringList(
      buffer,
      (feature.routes ?? const <String>{}).toList()..sort(),
      indent: 4,
    );
    buffer.writeln('  boundary:');
    final boundary = feature.boundary;
    if (boundary == null) {
      buffer.writeln('    null');
    } else {
      buffer.writeln('    type_name: ${_yamlString(boundary.typeName)}');
      buffer.writeln(
        '    interface_file: ${_yamlString(boundary.interfaceFile)}',
      );
      buffer.writeln(
        '    di_registration_file: '
        '${_yamlNullable(boundary.diRegistrationFile)}',
      );
      buffer.writeln(
        '    mock_strategy: ${_yamlString(boundary.mockStrategy)}',
      );
    }
    buffer.writeln('engine:');
    buffer.writeln('  files:');
    if (engineFiles.isEmpty) {
      buffer.writeln('    []');
    } else {
      for (final file in engineFiles) {
        buffer.writeln('    - path: ${_yamlString(file.relativePath)}');
        buffer.writeln('      layer: ${_yamlString(file.layer)}');
        buffer.writeln('      entity: ${_yamlNullable(file.entity)}');
        buffer.writeln('      hashAtCut: ${_yamlString(file.hashAtCut)}');
      }
    }
    buffer.writeln('  entities:');
    if (engineEntities.isEmpty) {
      buffer.writeln('    []');
    } else {
      final entities = engineEntities.keys.toList()..sort();
      for (final entity in entities) {
        buffer.writeln('    ${_yamlString(entity)}:');
        _writeStringList(buffer, engineEntities[entity] ?? const [], indent: 6);
      }
    }
    buffer.writeln('skin:');
    buffer.writeln('  files:');
    if (skinFiles.isEmpty) {
      buffer.writeln('    []');
    } else {
      for (final file in skinFiles) {
        buffer.writeln('    - path: ${_yamlString(file.relativePath)}');
        buffer.writeln('      layer: ${_yamlString(file.layer)}');
        buffer.writeln('      route: ${_yamlNullable(file.route)}');
        buffer.writeln('      hashAtCut: ${_yamlString(file.hashAtCut)}');
      }
    }
    buffer.writeln('  routes:');
    if (skinRoutes.isEmpty) {
      buffer.writeln('    []');
    } else {
      for (final route in skinRoutes) {
        buffer.writeln('    - path: ${_yamlString(route.path)}');
        buffer.writeln('      view: ${_yamlString(route.view)}');
      }
    }
    buffer.writeln('contract:');
    buffer.writeln('  file: ${_yamlString(contractFile)}');
    buffer.writeln('  digest: ${_yamlString(contractDigest)}');
    buffer.writeln('receipts:');
    _writeStringList(buffer, receiptsFiles, indent: 2);
    buffer.writeln('generatedFiles:');
    _writeStringList(buffer, generatedFiles, indent: 2);
    buffer.writeln('worktree:');
    buffer.writeln('  path: ${_yamlNullable(worktreePath)}');
    buffer.writeln('  branch: ${_yamlNullable(worktreeBranch)}');
    buffer.writeln('  commit: ${_yamlNullable(worktreeCommit)}');
    return buffer.toString();
  }

  static void _writeStringList(
    StringBuffer buffer,
    List<String> values, {
    required int indent,
  }) {
    if (values.isEmpty) {
      buffer.writeln('${' ' * indent}[]');
      return;
    }
    for (final value in values) {
      buffer.writeln('${' ' * indent}- ${_yamlString(value)}');
    }
  }

  static String _yamlString(String value) => jsonEncode(value);

  static String _yamlNullable(String? value) =>
      value == null ? 'null' : _yamlString(value);

  /// Parses a `slice.yaml` document body.
  static FeatureSliceManifest fromYaml(String source) {
    final dynamic doc;
    try {
      doc = loadYaml(source);
    } on YamlException {
      throw const FeatureSliceManifestYamlError('corrupt slice.yaml');
    }
    if (doc is! Map) {
      throw const FeatureSliceManifestYamlError(
        'corrupt slice.yaml: not a mapping',
      );
    }
    try {
      final schema = doc['schema'] as String?;
      if (schema == null) {
        throw const FeatureSliceManifestYamlError(
          'corrupt slice.yaml: missing schema',
        );
      }
      final createdAt = doc['createdAt'] as String?;
      if (createdAt == null) {
        throw const FeatureSliceManifestYamlError(
          'corrupt slice.yaml: missing createdAt',
        );
      }
      final featureNode = doc['feature'];
      if (featureNode is! Map) {
        throw const FeatureSliceManifestYamlError(
          'corrupt slice.yaml: missing the feature axis',
        );
      }
      final featureId = featureNode['id'] as String?;
      if (featureId == null || featureId.isEmpty) {
        throw const FeatureSliceManifestYamlError(
          'corrupt slice.yaml: feature.id missing',
        );
      }

      final boundaryNode = featureNode['boundary'];
      final SliceBoundary? boundary;
      if (boundaryNode is Map) {
        boundary = SliceBoundary(
          typeName: boundaryNode['type_name'] as String? ?? '',
          interfaceFile: boundaryNode['interface_file'] as String? ?? '',
          diRegistrationFile:
              boundaryNode['di_registration_file'] == 'null' ||
                  boundaryNode['di_registration_file'] == null
              ? null
              : boundaryNode['di_registration_file'] as String,
          mockStrategy: boundaryNode['mock_strategy'] as String? ?? 'auto',
        );
      } else {
        boundary = null;
      }

      final xrayLayerValue = featureNode['xray_layer'];
      final XRayLayer? xrayLayer =
          xrayLayerValue == null || xrayLayerValue == 'null'
          ? null
          : XRayLayer.parse(xrayLayerValue.toString());

      return FeatureSliceManifest(
        schema: schema,
        createdAt: DateTime.parse(createdAt),
        feature: FeatureContract(
          id: featureId,
          displayName: featureNode['display_name'] as String? ?? featureId,
          entities: _stringList(featureNode['entities']),
          boundary: boundary,
          routes: {for (final r in _stringList(featureNode['routes'])) r},
          xrayLayer: xrayLayer,
        ),
        origin: doc['origin'] as String? ?? 'contract.yaml',
        projectRoot: doc['projectRoot'] as String? ?? '',
        parentBranch: _nullableString(doc['parentBranch']),
        parentHead: _nullableString(doc['parentHead']),
        sliceRoot: doc['sliceRoot'] as String? ?? '',
        engineFiles: _featureFiles(doc['engine'], entityKey: true),
        engineEntities: _entityMap(doc['engine']),
        skinFiles: _featureFiles(doc['skin'], entityKey: false),
        skinRoutes: _skinRoutes(doc['skin']),
        contractFile:
            (doc['contract'] as Map?)?['file'] as String? ??
            'contract/contract.json',
        contractDigest: (doc['contract'] as Map?)?['digest'] as String? ?? '',
        receiptsFiles: _stringList(doc['receipts']),
        generatedFiles: _stringList(doc['generatedFiles']),
        worktreePath: _worktreeField(doc['worktree'], 'path'),
        worktreeBranch: _worktreeField(doc['worktree'], 'branch'),
        worktreeCommit: _worktreeField(doc['worktree'], 'commit'),
      );
    } on FeatureSliceManifestYamlError {
      rethrow;
    } on Object {
      throw const FeatureSliceManifestYamlError(
        'corrupt slice.yaml: invalid values',
      );
    }
  }

  static String? _nullableString(dynamic node) =>
      node == null || node == 'null' ? null : node.toString();

  static List<String> _stringList(dynamic node) {
    if (node is List) {
      return node.whereType<String>().toList();
    }
    return const [];
  }

  static List<FeatureSliceFile> _featureFiles(
    dynamic section, {
    required bool entityKey,
  }) {
    if (section is! Map) return const [];
    final files = section['files'];
    if (files is! List) return const [];
    return files.whereType<Map>().map((file) {
      return FeatureSliceFile(
        relativePath: file['path'] as String? ?? '',
        layer: file['layer'] as String? ?? 'other',
        entity: entityKey ? _nullableString(file['entity']) : null,
        route: entityKey ? null : _nullableString(file['route']),
        hashAtCut: file['hashAtCut'] as String? ?? '',
      );
    }).toList();
  }

  static Map<String, List<String>> _entityMap(dynamic section) {
    if (section is! Map) return const {};
    final entities = section['entities'];
    if (entities is! Map) return const {};
    return {
      for (final entry in entities.entries)
        entry.key.toString(): _stringList(entry.value),
    };
  }

  static List<FeatureSkinRoute> _skinRoutes(dynamic section) {
    if (section is! Map) return const [];
    final routes = section['routes'];
    if (routes is! List) return const [];
    return routes.whereType<Map>().map((route) {
      return FeatureSkinRoute(
        path: route['path'] as String? ?? '',
        view: route['view'] as String? ?? '',
      );
    }).toList();
  }

  static String? _worktreeField(dynamic node, String key) {
    if (node is! Map) return null;
    return _nullableString(node[key]);
  }
}

/// Internal marker distinguishing YAML-level corruption from IO errors.
class FeatureSliceManifestYamlError implements Exception {
  /// Creates the corruption marker with a [message].
  const FeatureSliceManifestYamlError(this.message);

  /// What went wrong.
  final String message;
}
