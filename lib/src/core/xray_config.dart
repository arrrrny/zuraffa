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
const String xrayConfigPath = '.dart_tool/zuraffa/xray.json';

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
  final dir = Directory(xrayConfigPath.substring(0, xrayConfigPath.lastIndexOf('/')));
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
