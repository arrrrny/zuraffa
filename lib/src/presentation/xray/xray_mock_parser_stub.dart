// X-Ray mock parser — non-IO (web) stub implementation.
//
// This is the default conditional-import branch used on platforms
// without `dart:io` (e.g. Flutter web). File-based YAML reading is a
// native/CLI-only concern; on web, load the YAML via `rootBundle` and
// parse with [XRayMockParser.fromYamlString] instead.

import "xray_mock_entry.dart";

/// No-op file reader for platforms without `dart:io`.
///
/// Always returns an empty list. See [XRayMockParser.fromYamlFile] for
/// the native-only caveat.
List<XRayMockEntry> readYamlFile(
  String path,
  List<XRayMockEntry> Function(String) parse,
) {
  return const [];
}
