// X-Ray mock parser — IO implementation (`dart:io` platforms).
//
// Reads a YAML mock-scenario file from the file system and parses it
// through the shared [XRayMockParser.fromYamlString] logic. Used for
// CLI/build-time tooling; Flutter web falls back to the stub.

import "dart:io";

import "xray_mock_entry.dart";

/// Reads and parses mock entries from [path].
///
/// Returns an empty list if the file does not exist or cannot be read
/// or parsed, matching the tolerant behaviour of
/// [XRayMockParser.fromYamlString].
List<XRayMockEntry> readYamlFile(
  String path,
  List<XRayMockEntry> Function(String) parse,
) {
  try {
    final file = File(path);
    if (!file.existsSync()) return const [];
    return parse(file.readAsStringSync());
  } catch (_) {
    return const [];
  }
}
