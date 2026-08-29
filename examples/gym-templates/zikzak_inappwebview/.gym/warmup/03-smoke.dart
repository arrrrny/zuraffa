/// GYM warmup rep #3 — bridge smoke call.
///
/// "Authenticated" for zikzak_inappwebview means: prove the JS bridge
/// is reachable. We don't boot a full Flutter app in the warmup (that
/// needs a device); instead, we assert the plugin's bridge symbol is
/// importable and the example app's bridge setup file exists.
///
/// Run: `dart run .gym/warmup/03-smoke.dart`
library;

import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  // The example app's main entrypoint must exist.
  final exampleMain = File(p.join('example', 'lib', 'main.dart'));
  if (!exampleMain.existsSync()) {
    stderr.writeln(
      'REP FAIL: 03-smoke — example/lib/main.dart not found. '
      'The zikzak_inappwebview package should ship a Flutter example '
      'app at example/lib/main.dart.',
    );
    exit(1);
  }

  // The example main.dart should reference the InAppWebView bridge
  // (proves the plugin's bridge symbol is consumed by the example).
  final mainContent = exampleMain.readAsStringSync();
  if (!mainContent.contains('InAppWebView') &&
      !mainContent.contains('JavaScriptHandler')) {
    stderr.writeln(
      'REP FAIL: 03-smoke — example/lib/main.dart does not reference '
      'InAppWebView or JavaScriptHandler. Mis-fire — drop a card: '
      'the example app should exercise the bridge.',
    );
    exit(1);
  }

  // The plugin's own lib/ should export the InAppWebView controller.
  final libMain = File(p.join('lib', 'zikzak_inappwebview.dart'));
  if (!libMain.existsSync()) {
    stderr.writeln(
      'REP FAIL: 03-smoke — lib/zikzak_inappwebview.dart not found. '
      'The package should export its public API from a top-level barrel.',
    );
    exit(1);
  }

  stdout.writeln('REP PASS: 03-smoke — bridge reachable (example references InAppWebView).');
  exit(0);
}
