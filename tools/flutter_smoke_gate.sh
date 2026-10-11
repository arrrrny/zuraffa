#!/usr/bin/env bash
# Issue #1189 — Flutter-consumer smoke gate.
#
# Proves, on every CI run, that a Flutter app consuming zuraffa from this
# checkout resolves and compiles WITHOUT any dependency_overrides. This is
# the gate that was missing when `analyzer: ^14.3.0` and `test: any` shipped
# as regular dependencies: CI's `dart pub get --no-example` /
# `flutter packages get --no-example` skips example/ resolution entirely,
# so a constraint that breaks every Flutter consumer used to go green.
#
# The gate has three stages:
#   1. example/ — the committed Flutter consumer (zuraffa path dep +
#      flutter_test) must `flutter pub get` clean.
#   2. synthesized tiny app — a throwaway app depending on ONLY core +
#      flutter_test (the minimal bug-report repro) must `flutter pub get`
#      clean. This catches graphs example/ cannot (example carries extra
#      deps like hive_ce_flutter that can mask or shift conflicts).
#   3. smoke compile — the tiny app's test imports package:zuraffa (whose
#      public surface exports src/core/ast/*, which hard-import
#      package:analyzer) and runs under `flutter test`, proving the
#      consumer graph still carries everything zuraffa's shipped code
#      needs at compile time.
#
# Exit 0 = Flutter consumers are safe. Non-zero = constraint regression;
# do not ship the pubspec change under review.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_APP=""

cleanup() {
  if [[ -n "$TMP_APP" && -d "$TMP_APP" ]]; then
    rm -rf "$TMP_APP"
  fi
}
trap cleanup EXIT

say() { printf '[flutter-smoke-gate] %s\n' "$*"; }

command -v flutter >/dev/null 2>&1 || {
  say "FAIL: flutter is not on PATH (CI sets it up via subosito/flutter-action)."
  exit 1
}
say "flutter $(flutter --version 2>/dev/null | head -1)"

# ---------------------------------------------------------------- stage 1
say "stage 1/3: example/ (committed Flutter consumer) pub get"
( cd "$REPO_ROOT/example" && flutter pub get ) || {
  say "FAIL: example/ failed to resolve — Flutter consumers are broken (#1189 regression)."
  exit 1
}
say "stage 1 OK: example/ resolved"

# ---------------------------------------------------------------- stage 2
say "stage 2/3: synthesized tiny app (core + flutter_test only) pub get"
TMP_APP="$(mktemp -d)"
cat > "$TMP_APP/pubspec.yaml" <<EOF
name: zuraffa_flutter_smoke
description: Throwaway Flutter-consumer gate for issue #1189. Never committed.
publish_to: none

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: $REPO_ROOT

dev_dependencies:
  flutter_test:
    sdk: flutter
EOF

mkdir -p "$TMP_APP/lib" "$TMP_APP/test"
cat > "$TMP_APP/lib/main.dart" <<'EOF'
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

void main() => runApp(const SmokeApp());

class SmokeApp extends StatelessWidget {
  const SmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: Center(child: Text('smoke'))));
  }
}
EOF

cat > "$TMP_APP/test/smoke_test.dart" <<'EOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  test('zuraffa public surface resolves and compiles under flutter_test', () {
    // The import above pulls zuraffa.dart's full public export surface —
    // including src/core/ast/*, which hard-import package:analyzer. If a
    // constraint change ever drops analyzer (or anything else zuraffa's
    // shipped code needs) out of the consumer graph, this file fails to
    // compile and the gate goes red before a publish can ship it.
    final result = Result<int, String>.success(1189);
    expect(result.isSuccess, isTrue);
  });
}
EOF

( cd "$TMP_APP" && flutter pub get ) || {
  say "FAIL: tiny app (core + flutter_test) failed to resolve — this is the #1189 bug signature."
  exit 1
}
say "stage 2 OK: tiny app resolved with zero dependency_overrides"

# ---------------------------------------------------------------- stage 3
say "stage 3/3: flutter test (compile proof of the public surface)"
( cd "$TMP_APP" && flutter test --reporter compact ) || {
  say "FAIL: smoke test did not pass — consumer graph is missing something zuraffa's compiled surface needs."
  exit 1
}
say "stage 3 OK: zuraffa compiles under the Flutter consumer graph"

say "PASS: Flutter consumers resolve and compile without dependency_overrides (#1189 gate green)."
