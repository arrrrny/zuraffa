/// Shared test helper: captures all `print()` output from a zone-scoped body.
///
/// Mirrors the skeleton plugin's helper (same feature-local convention as the
/// TDD profile records for `test/plugins/benchmark/helpers/`).
library;

import 'dart:async';

/// Runs [body] and returns everything printed (via [ZoneSpecification.print])
/// as a single newline-joined string.
Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}
