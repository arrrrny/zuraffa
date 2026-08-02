// X-Ray mock YAML parser and annotation scanner.

import "dart:io";

import "package:flutter/foundation.dart";
import "package:yaml/yaml.dart";

import "xray_mock_entry.dart";

/// Parses mock scenarios from a YAML file.
///
/// Expected format:
/// ```yaml
/// - name: Valid Product A
///   payload: "123456789"
///   type: valid
/// - name: Invalid Barcode
///   payload: "000000"
///   type: error
///   description: Triggers barcode validation failure
/// ```
///
/// The YAML file is a simple list of entries.
/// [name] and [payload] are required; [type] and [description] are optional.
///
/// Returns an empty list if the file does not exist or cannot be parsed.
class XRayMockParser {
  XRayMockParser._();

  /// Parse mock entries from a YAML file at [yamlPath].
  static List<XRayMockEntry> fromYamlFile(String yamlPath) {
    if (kReleaseMode) return const [];

    final file = File(yamlPath);
    if (!file.existsSync()) {
      return const [];
    }

    try {
      final content = file.readAsStringSync();
      return fromYamlString(content);
    } catch (_) {
      return const [];
    }
  }

  /// Parse mock entries from a YAML string.
  static List<XRayMockEntry> fromYamlString(String yamlContent) {
    if (kReleaseMode) return const [];

    try {
      final yaml = loadYaml(yamlContent);
      if (yaml is! YamlList) {
        return const [];
      }

      return yaml
          .map((item) {
            if (item is YamlMap) {
              return XRayMockEntry.fromYamlMap(item);
            }
            return null;
          })
          .whereType<XRayMockEntry>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Parse mock entries from a map (e.g. from annotation fields).
  static List<XRayMockEntry> fromAnnotation({
    required String name,
    required String payload,
    String? type,
  }) {
    if (kReleaseMode) return const [];
    return [
      XRayMockEntry.fromAnnotation(name: name, payload: payload, type: type),
    ];
  }
}

