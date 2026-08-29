/// Pure-Dart XRay configuration constants and helpers.
///
/// The CLI (`zfa xray enable/disable/status`) and the Flutter
/// overlay both read/write the same JSON flag file.
/// This file has zero Flutter dependencies so the CLI can run
/// in a pure Dart process.
library;

import 'dart:convert';
import 'dart:io';

/// Path to the persistent X-Ray config file.
const String kXrayConfigPath = '.dart_tool/zuraffa/xray.json';

/// Backwards-compatible alias for [kXrayConfigPath] — the rest of the
/// codebase still imports `xrayConfigPath`, so we keep both names
/// pointing at the same path.
const String xrayConfigPath = kXrayConfigPath;

/// Compile-time release-mode flag — `true` ONLY when the VM is started
/// with `--dart-define=dart.vm.product=true` (release / AOT builds).
///
/// This is the pure-Dart equivalent of Flutter's `kReleaseMode` /
/// `kDebugMode` and exists so the CLI / codegen / MCP server can
/// branch on release mode without pulling `package:flutter`.
///
/// Track 4.2 — Spec 036 (issue #181, FR-007, SC-004).
const bool kXrayReleaseMode = bool.fromEnvironment('dart.vm.product');

/// Whether X-Ray should be active in the current build.
///
/// Returns `false` in release mode, `true` otherwise.
bool shouldXRayBeActiveInCurrentBuild() => !kXrayReleaseMode;

/// Join [root] with [kXrayConfigPath] so subcommands can be invoked
/// hermetically against a sandbox (mirrors `zfa xray deck --root`).
String xrayConfigPathFor(String? root) {
  if (root == null || root.isEmpty) return kXrayConfigPath;
  // The path under .dart_tool is relative; resolve it against root.
  final normalized = root.endsWith('/') ? root.substring(0, root.length - 1) : root;
  return '$normalized/$kXrayConfigPath';
}

/// Read the X-Ray config file. Returns `null` if missing/malformed.
Map<String, dynamic>? readXrayConfig() {
  final file = File(xrayConfigPath);
  if (!file.existsSync()) return null;
  try {
    final content = file.readAsStringSync();
    return json.decode(content) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Write the X-Ray config file.
void writeXrayConfig(Map<String, dynamic> config) {
  final dir = File(xrayConfigPath).parent;
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final file = File(xrayConfigPath);
  file.writeAsStringSync(json.encode(config));
}

/// Check if the X-Ray config flag is set to enabled.
bool isXrayConfigEnabled() {
  final config = readXrayConfig();
  return config?['enabled'] == true;
}
