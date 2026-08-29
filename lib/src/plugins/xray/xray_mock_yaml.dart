// X-Ray mock YAML parser — shared helper that parses a YAML document
// containing `{name, payload, type?}` entries into a
// `List<XRayMockEntry>`.
//
// This is a PURE-DART parser used by:
//   - the existing `zfa xray deck --yaml <path>` CLI (currently inline-
//     parsed; this helper makes the parsing reusable + testable in
//     isolation);
//   - the future generated `<entity>_xray_deck.dart` files (which will
//     call `XRayMockYaml.parseFile('assets/mocks/foo.yaml')` at boot
//     and `XRayControlDeck.instance.registerEntries(...)` to populate
//     the deck).
//
// Track 4.3 — Spec 034 (issue #185, FR-002).
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'xray_mock_entry.dart';
import 'xray_mock_type.dart';

/// Pure-Dart YAML parser for X-Ray mock scenario files.
class XRayMockYaml {
  /// Parse a YAML string into a list of [XRayMockEntry].
  ///
  /// Throws [FormatException] with a message identifying the offending
  /// entry index + missing field name when required fields are absent.
  static List<XRayMockEntry> parse(String yamlContent) {
    if (yamlContent.trim().isEmpty) return const [];

    final dynamic loaded = loadYaml(yamlContent);

    if (loaded == null) return const [];
    if (loaded is! List) {
      throw FormatException(
        'XRayMockYaml: expected a YAML list at the top level, got '
        '${loaded.runtimeType}',
      );
    }

    final entries = <XRayMockEntry>[];
    for (var i = 0; i < loaded.length; i++) {
      final raw = loaded[i];
      if (raw is! Map) {
        throw FormatException(
          'XRayMockYaml: entry at index $i is not a map '
          '(got ${raw.runtimeType})',
        );
      }
      final name = raw['name'];
      final payload = raw['payload'];
      final typeStr = raw['type'];

      if (name == null) {
        throw FormatException(
          'XRayMockYaml: entry at index $i is missing the required '
          '`name` field',
        );
      }
      if (payload == null) {
        throw FormatException(
          'XRayMockYaml: entry at index $i is missing the required '
          '`payload` field',
        );
      }

      entries.add(XRayMockEntry(
        name: name.toString(),
        payload: payload.toString(),
        type: XRayMockType.fromString(typeStr?.toString()),
      ));
    }
    return entries;
  }

  /// Read [path] from disk and call [parse].
  static List<XRayMockEntry> parseFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException(
        'XRayMockYaml: file not found',
        path,
      );
    }
    return parse(file.readAsStringSync());
  }
}
