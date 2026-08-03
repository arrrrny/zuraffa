// X-Ray mock YAML parser and annotation scanner.

import "package:flutter/foundation.dart";
import "package:yaml/yaml.dart";

import "xray_mock_entry.dart";
import "xray_mock_parser_stub.dart"
    if (dart.library.io) "xray_mock_parser_io.dart" as platform;

/// Parses mock scenarios from a YAML file or string.
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
  ///
  /// NOTE: This method uses dart:io and is only available on native platforms
  /// (not web). For Flutter web, use [fromYamlString] with asset loading via
  /// rootBundle.loadString instead.
  ///
  /// For runtime use in Flutter apps with asset files, prefer loading via
  /// rootBundle and parsing with [fromYamlString]. This method is primarily
  /// intended for CLI/build-time usage.
  static List<XRayMockEntry> fromYamlFile(String yamlPath) {
    if (kReleaseMode) return const [];
    return platform.readYamlFile(yamlPath, fromYamlString);
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

