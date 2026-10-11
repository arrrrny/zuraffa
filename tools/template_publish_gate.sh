#!/usr/bin/env bash
# template_publish_gate.sh — BUG 1198 (part of #908 P0): the loop is the
# template's referee. Templates that fail the TDD loop BLOCK publish.
#
# Runs the template self-hosting suite (test/templates/self_hosting/):
#   1. pure-Dart lane  — per-template trust-tier suites (structural +
#      compile + behavioral) and byte-stability diff guards for every
#      generator template (usecase, service, repository, datasource,
#      mock, di, view/skin, state, route), against a fixture entity.
#   2. flutter lane    — the downstream-compile gate: ALL templates emitted
#      into a minimal Flutter package must analyze clean (the
#      #1189/#1190-class import/dep drift referee at template level).
#
# Any failure exits non-zero — CI and the release workflow call this
# before anything is built/published.
#
# Usage:
#   tools/template_publish_gate.sh              # both lanes
#   SKIP_FLUTTER_LANE=1 tools/template_publish_gate.sh   # pure-Dart only
#       (pure-Dart-only environments; the flutter lane must still run in
#        a Flutter-capable environment before publish)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SUITE="test/templates/self_hosting"

if [ ! -d "$SUITE" ]; then
  echo "template publish gate: suite directory missing: $SUITE" >&2
  exit 1
fi

echo "== template publish gate (bug 1198): pure-Dart lane =="
dart test "$SUITE" --exclude-tags flutter

if [ "${SKIP_FLUTTER_LANE:-0}" = "1" ]; then
  echo "== template publish gate: flutter lane SKIPPED (SKIP_FLUTTER_LANE=1) =="
  echo "   NOTE: publish still requires the flutter lane elsewhere."
else
  echo "== template publish gate (bug 1198): flutter lane (downstream gate) =="
  flutter test "$SUITE" --tags flutter
fi

echo "== template publish gate: PASS — every template passed the loop =="
