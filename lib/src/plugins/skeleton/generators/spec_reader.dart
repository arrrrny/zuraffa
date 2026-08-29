/// Reads a feature spec.md and extracts entity declarations.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/bone.dart';

/// Error thrown when a spec cannot be parsed (042: unsupported field types).
class SpecReadError implements Exception {
  /// Creates a [SpecReadError].
  const SpecReadError(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'SpecReadError: $message';
}

/// Result of reading a spec file.
class SpecReadResult {
  /// Creates a [SpecReadResult].
  const SpecReadResult({
    required this.featureSlug,
    required this.entities,
    required this.specVersion,
    this.xrayMarkers = const {},
    this.entityFields = const {},
  });

  /// Kebab-case slug derived from the spec's directory name.
  final String featureSlug;

  /// Entity names extracted from `## Key Entities` bold entries.
  final List<String> entities;

  /// SHA-256 hex digest of the spec file bytes (no `sha256:` prefix).
  final String specVersion;

  /// Xray overlay markers extracted from `<!-- xray: ... -->` comments.
  ///
  /// Keys are marker names; values are the content after `xray: `.
  final Map<String, String> xrayMarkers;

  /// Fields per entity parsed from indented `- name: Type` lines under each
  /// `## Key Entities` bold entry (042). Entities without field lines map to
  /// an empty list.
  final Map<String, List<EntityField>> entityFields;
}

/// Structurally parses a feature `spec.md` to extract entities.
class SpecReader {
  /// Reads and parses the spec at [spec].
  ///
  /// The feature slug is derived from the parent directory name of [spec].
  ///
  /// Throws [SpecReadError] when the spec declares an entity field with an
  /// unsupported type.
  SpecReadResult read(File spec) {
    final bytes = spec.readAsBytesSync();
    final digest = sha256.convert(bytes);
    final specVersion = digest.toString();

    final dirName = p.basename(p.dirname(spec.path));
    final content = utf8.decode(bytes);

    final entities = <String>[];
    final entityFields = <String, List<EntityField>>{};
    _extractEntities(content, entities, entityFields);
    final xrayMarkers = _extractXrayMarkers(content);

    return SpecReadResult(
      featureSlug: dirName,
      entities: entities,
      specVersion: specVersion,
      xrayMarkers: xrayMarkers,
      entityFields: entityFields,
    );
  }

  /// Extracts entity names from the `Key Entities` heading (any markdown
  /// level) bold entries, plus their field declarations (042).
  ///
  /// Multi-word names are normalized to PascalCase. Fields are declared on
  /// indented `- name: Type` / `- name?: Type` lines directly below the bold
  /// entry; they bind to the entity above them and stop at the next heading
  /// or bold entry.
  void _extractEntities(
    String content,
    List<String> entities,
    Map<String, List<EntityField>> entityFields,
  ) {
    final lines = content.split('\n');
    var inKeyEntities = false;
    String? currentEntity;

    final boldPattern = RegExp(r'^-?\s*\*\*([A-Za-z][A-Za-z0-9 ]*?)\*\*');
    // Indented list item carrying a `name: Type` pair. Nullability may be
    // written either way: `name?: Type` or `name: Type?`.
    final fieldPattern = RegExp(
      r'^(\s+)-\s+([A-Za-z_][A-Za-z0-9_]*)(\?)?\s*:\s*(\S.*?)\s*$',
    );

    for (final line in lines) {
      final trimmed = line.trim();

      if (RegExp(
        r'^#{1,6}\s+key entities\s*$',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        inKeyEntities = true;
        continue;
      }

      // Stop at the next heading.
      if (inKeyEntities && trimmed.startsWith('#')) {
        break;
      }

      if (!inKeyEntities) continue;

      final boldMatch = boldPattern.firstMatch(trimmed);
      if (boldMatch != null) {
        currentEntity = boldMatch.group(1)!.replaceAll(' ', '');
        entities.add(currentEntity);
        entityFields[currentEntity] = <EntityField>[];
        continue;
      }

      final fieldMatch = fieldPattern.firstMatch(line);
      if (fieldMatch != null && currentEntity != null) {
        final name = fieldMatch.group(2)!;
        var nullable = fieldMatch.group(3) != null;
        var type = fieldMatch.group(4)!;
        if (type.endsWith('?')) {
          nullable = true;
          type = type.substring(0, type.length - 1);
        }
        if (!EntityField.isSupportedType(type)) {
          throw SpecReadError(
            'Spec declares unsupported type "$type" for field "$name" on '
            'entity "$currentEntity". Supported types: '
            '${EntityField.supportedTypes.join(', ')}.',
          );
        }
        entityFields[currentEntity]!.add(
          EntityField(name: name, type: type, nullable: nullable),
        );
      }
    }
  }

  /// Extracts xray overlay markers from `<!-- xray: key: value -->` comments.
  Map<String, String> _extractXrayMarkers(String content) {
    final markers = <String, String>{};
    final pattern = RegExp(r'<!--\s*xray:\s*(\w[\w.-]*):\s*(.*?)\s*-->');
    for (final match in pattern.allMatches(content)) {
      markers[match.group(1)!] = match.group(2)!;
    }
    return markers;
  }
}
