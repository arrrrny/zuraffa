/// Reads a feature spec.md and extracts entity declarations.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Result of reading a spec file.
class SpecReadResult {
  /// Creates a [SpecReadResult].
  const SpecReadResult({
    required this.featureSlug,
    required this.entities,
    required this.specVersion,
    this.xrayMarkers = const {},
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
}

/// Structurally parses a feature `spec.md` to extract entities.
class SpecReader {
  /// Reads and parses the spec at [spec].
  ///
  /// The feature slug is derived from the parent directory name of [spec].
  SpecReadResult read(File spec) {
    final bytes = spec.readAsBytesSync();
    final digest = sha256.convert(bytes);
    final specVersion = digest.toString();

    final dirName = p.basename(p.dirname(spec.path));
    final content = utf8.decode(bytes);

    final entities = _extractEntities(content);
    final xrayMarkers = _extractXrayMarkers(content);

    return SpecReadResult(
      featureSlug: dirName,
      entities: entities,
      specVersion: specVersion,
      xrayMarkers: xrayMarkers,
    );
  }

  /// Extracts entity names from the `Key Entities` heading (any markdown
  /// level) bold entries. Multi-word names are normalized to PascalCase.
  List<String> _extractEntities(String content) {
    final lines = content.split('\n');
    var inKeyEntities = false;
    final entities = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();

      if (RegExp(r'^#{1,6}\s+key entities\s*$', caseSensitive: false)
          .hasMatch(trimmed)) {
        inKeyEntities = true;
        continue;
      }

      // Stop at the next heading.
      if (inKeyEntities && trimmed.startsWith('#')) {
        break;
      }

      if (inKeyEntities) {
        // Match bold entries like `- **EntityName**` or `- **Entity Name** — desc`.
        final match = RegExp(r'^-?\s*\*\*([A-Za-z][A-Za-z0-9 ]*?)\*\*')
            .firstMatch(trimmed);
        if (match != null) {
          entities.add(match.group(1)!.replaceAll(' ', ''));
        }
      }
    }

    return entities;
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
