/// Shared fixture helpers for tdd plugin tests that drive the real CLI
/// entry point on a temp project (bug 846 harness, bug 919 follow-on).
///
/// The 919 test suite plans specs authored from the zuraffa-1.0 template,
/// which carries a strict `**Template Version**` gate — so every helper
/// here defaults to a known-good version marker. Tests that need to
/// exercise missing or unknown versions can pass `versionMarker: null`
/// or a different value.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

const String kZuraffaTemplateMarker = '**Template Version**: `zuraffa-1.0`';

/// A self-contained spec body that plan can derive at least one
/// acceptance behavior from (without it, the coverage gate fails on a
/// spec with no Given/Then). Kept tiny on purpose — the test files
/// add the structure they care about (entities, dependencies, layer
/// contracts, etc.).
const String kMinimalAcceptance = '''
## Acceptance Scenarios

1. **Given** a fresh state **When** the user invokes the feature
   **Then** the system responds
''';

/// Write a full spec to `<featureDir>/spec.md`.
///
/// If [versionMarker] is non-null and [versionMarker] is `kZuraffaTemplateMarker`
/// (the default), the marker line is inserted just before the first
/// heading. Pass `versionMarker: ''` to write a spec WITHOUT the
/// marker, or any other string to write a custom version.
Future<void> writeSpec(
  String featureDir,
  String body, {
  String? versionMarker = kZuraffaTemplateMarker,
}) async {
  final buffer = StringBuffer();
  if (versionMarker != null && versionMarker.isNotEmpty) {
    buffer.writeln(versionMarker);
    buffer.writeln();
  }
  buffer.write(body);
  await File(p.join(featureDir, 'spec.md')).writeAsString(buffer.toString());
}

/// Write a bare spec containing only a given body — no template marker
/// injected. Useful for tests that need to exercise the missing-marker
/// gate.
Future<void> writeRawSpec(String featureDir, String body) async {
  await File(p.join(featureDir, 'spec.md')).writeAsString(body);
}

/// Build a feature directory under [tmpDir] for the given feature name.
String makeFeatureDir(String tmpDir, String featureName) {
  final dir = p.join(tmpDir, 'specs', featureName);
  Directory(dir).createSync(recursive: true);
  return dir;
}
