#!/usr/bin/env bash
# flutter_consumer_smoke.sh — the Flutter-consumer smoke gate (issue
# #1197 constraint hygiene, per #1189).
#
# A regular-dep bump in the core pubspec (the analyzer family is the
# repeat offender) can resolve fine for pure-Dart consumers while
# breaking Flutter resolution entirely — the app's pub solve dies
# before a single file compiles. This gate catches that BEFORE
# publish: materialize a minimal Flutter consumer that depends on the
# CURRENT core via path, run `flutter pub get` (the resolution gate)
# and `flutter analyze` (the compile gate) on a barrel-importing app.
#
# Requires the Flutter SDK on PATH. CI: the flutter-smoke-gate job in
# .github/workflows/skew-matrix.yaml (and the pre-publish gate wired
# into release.yml).
#
# Usage:  tools/flutter_consumer_smoke.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "FATAL: flutter not on PATH — this gate needs the Flutter SDK"; exit 2
fi

WORK="$(mktemp -d /tmp/zfa1197_flutter_smoke.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

CONSUMER="$WORK/flutter_consumer"
mkdir -p "$CONSUMER/lib"

cat > "$CONSUMER/pubspec.yaml" <<YAML
name: zfa_flutter_smoke
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  # Path dependency on the CURRENT core: what a release candidate
  # would resolve to. flutter pub get here is the #1189 tripwire —
  # an analyzer-family regular dep that breaks Flutter solve fails
  # THIS step, not a published consumer's.
  zuraffa:
    path: $ROOT
YAML

cat > "$CONSUMER/lib/main.dart" <<'DART'
import 'package:flutter/material.dart';
import 'package:zuraffa/skin.dart';

// Minimal Flutter consumer: exercises the skin barrel (the post-6.1.0
// surface, issue #1197) inside a real Flutter resolution.
void main() {
  final table = RouteContractTable.fromRouteNames(['home']);
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('skew gate: ${table.allowedRoutes.length} route(s)'),
        ),
      ),
    ),
  );
}
DART

echo "== flutter smoke gate: consumer=$CONSUMER"
(cd "$CONSUMER" && flutter pub get --no-example)
echo "   flutter pub get: OK (Flutter resolution unbroken)"
(cd "$CONSUMER" && flutter analyze --no-pub)
echo "== flutter smoke gate: GREEN — resolution + compile clean"
