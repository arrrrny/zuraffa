/// SliceManifest model (spec 043 data model).
library;

import 'package:yaml/yaml.dart';

import 'slice_boundary.dart';
import 'slice_depth.dart';
import 'slice_file.dart';

/// Supported export targets (FR-017, FR-018).
enum SliceExportFormat {
  /// `.tar.gz` archive with a filtered `pubspec.yaml`.
  tarGz,

  /// Private GitHub repository with `SLICE.md` as README.
  github;

  /// Parses a `--format` CLI value (`tar.gz` or `github`).
  static SliceExportFormat parse(String value) {
    return switch (value) {
      'tar.gz' => SliceExportFormat.tarGz,
      'github' => SliceExportFormat.github,
      _ => throw ArgumentError.value(value, 'value', 'Unknown export format'),
    };
  }
}

/// The persistent record of a slice, serialized as `slice.yaml` (FR-004).
class SliceManifest {
  /// Creates a manifest.
  const SliceManifest({
    required this.name,
    required this.createdAt,
    required this.depth,
    required this.entries,
    required this.projectRoot,
    required this.packageName,
    required this.branch,
    required this.files,
    required this.boundaries,
    this.exportedTo,
  });

  /// Slice name (e.g. `profile_feature`).
  final String name;

  /// When the slice was cut.
  final DateTime createdAt;

  /// Extraction depth.
  final SliceDepth depth;

  /// Entry point paths relative to the project root.
  final List<String> entries;

  /// Absolute path to the source project.
  final String projectRoot;

  /// Dart package name from pubspec.yaml.
  final String packageName;

  /// Git branch at cut time.
  final String branch;

  /// Export target (GitHub repo URL or tarball path); null until exported.
  final String? exportedTo;

  /// All files included in the slice.
  final List<SliceFile> files;

  /// Interfaces at the traversal edge.
  final List<SliceBoundary> boundaries;

  /// Returns a copy with the given fields replaced.
  SliceManifest copyWith({
    String? name,
    DateTime? createdAt,
    SliceDepth? depth,
    List<String>? entries,
    String? projectRoot,
    String? packageName,
    String? branch,
    String? exportedTo,
    List<SliceFile>? files,
    List<SliceBoundary>? boundaries,
  }) {
    return SliceManifest(
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      depth: depth ?? this.depth,
      entries: entries ?? this.entries,
      projectRoot: projectRoot ?? this.projectRoot,
      packageName: packageName ?? this.packageName,
      branch: branch ?? this.branch,
      exportedTo: exportedTo ?? this.exportedTo,
      files: files ?? this.files,
      boundaries: boundaries ?? this.boundaries,
    );
  }

  /// Serializes to the `slice.yaml` document body.
  ///
  /// Emission is hand-rolled (the repo pins no yaml_writer) with every value
  /// a plain YAML scalar; only [createdAt] is quoted so the ISO timestamp is
  /// read back as a string, not a YAML timestamp.
  String toYaml() {
    final buffer = StringBuffer();
    buffer.writeln('name: $name');
    buffer.writeln('createdAt: "${createdAt.toIso8601String()}"');
    buffer.writeln('depth: ${depth.name}');
    buffer.writeln('projectRoot: $projectRoot');
    buffer.writeln('packageName: $packageName');
    buffer.writeln('branch: $branch');
    if (exportedTo != null) {
      buffer.writeln('exportedTo: $exportedTo');
    }
    buffer.writeln('entries:');
    if (entries.isEmpty) {
      buffer.writeln('  []');
    } else {
      for (final entry in entries) {
        buffer.writeln('  - $entry');
      }
    }
    buffer.writeln('files:');
    if (files.isEmpty) {
      buffer.writeln('  []');
    } else {
      for (final file in files) {
        buffer.writeln('  - path: ${file.relativePath}');
        buffer.writeln('    ownership: ${file.ownership.name}');
        buffer.writeln('    hashAtCut: ${file.hashAtCut}');
        buffer.writeln('    layer: ${file.layer}');
      }
    }
    buffer.writeln('boundaries:');
    if (boundaries.isEmpty) {
      buffer.writeln('  []');
    } else {
      for (final boundary in boundaries) {
        buffer.writeln('  - typeName: ${boundary.typeName}');
        buffer.writeln('    interfaceFile: ${boundary.interfaceFile}');
        buffer.writeln(
          '    diRegistrationFile: ${boundary.diRegistrationFile ?? 'null'}',
        );
        buffer.writeln('    mockStrategy: ${boundary.mockStrategy}');
      }
    }
    return buffer.toString();
  }

  /// Parses a `slice.yaml` document body.
  static SliceManifest fromYaml(String source) {
    final dynamic doc;
    try {
      doc = loadYaml(source);
    } on YamlException {
      throw const SliceManifestYamlError('corrupt slice.yaml');
    }
    if (doc is! Map) {
      throw const SliceManifestYamlError('corrupt slice.yaml: not a mapping');
    }
    final name = doc['name'];
    final createdAt = doc['createdAt'];
    final depth = doc['depth'];
    if (name is! String ||
        createdAt is! String ||
        depth is! String) {
      throw const SliceManifestYamlError(
        'corrupt slice.yaml: missing name/createdAt/depth',
      );
    }
    return SliceManifest(
      name: name,
      createdAt: DateTime.parse(createdAt),
      depth: SliceDepth.parse(depth),
      entries: _stringList(doc['entries']),
      projectRoot: doc['projectRoot'] as String? ?? '',
      packageName: doc['packageName'] as String? ?? '',
      branch: doc['branch'] as String? ?? '',
      exportedTo: doc['exportedTo'] as String?,
      files: _files(doc['files']),
      boundaries: _boundaries(doc['boundaries']),
    );
  }

  static List<String> _stringList(dynamic node) {
    if (node is List) {
      return node.whereType<String>().toList();
    }
    return const [];
  }

  static List<SliceFile> _files(dynamic node) {
    if (node is! List) return const [];
    return node
        .whereType<Map>()
        .map((file) {
          return SliceFile(
            relativePath: file['path'] as String? ?? '',
            ownership: switch (file['ownership']) {
              'shared' => FileOwnership.shared,
              'framework' => FileOwnership.framework,
              _ => FileOwnership.owned,
            },
            hashAtCut: file['hashAtCut'] as String? ?? '',
            layer: file['layer'] as String? ?? 'other',
          );
        })
        .toList();
  }

  static List<SliceBoundary> _boundaries(dynamic node) {
    if (node is! List) return const [];
    return node
        .whereType<Map>()
        .map((boundary) {
          return SliceBoundary(
            typeName: boundary['typeName'] as String? ?? '',
            interfaceFile: boundary['interfaceFile'] as String? ?? '',
            diRegistrationFile:
                boundary['diRegistrationFile'] == 'null' ||
                    boundary['diRegistrationFile'] == null
                ? null
                : boundary['diRegistrationFile'] as String,
            mockStrategy: boundary['mockStrategy'] as String? ?? 'auto',
          );
        })
        .toList();
  }
}

/// Internal marker distinguishing YAML-level corruption from IO errors.
class SliceManifestYamlError implements Exception {
  /// Creates the corruption marker with a [message].
  const SliceManifestYamlError(this.message);

  /// What went wrong.
  final String message;
}
