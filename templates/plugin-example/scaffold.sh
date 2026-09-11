#!/usr/bin/env bash
# Scaffold a zuraffa plugin-example app per templates/plugin-example/TEMPLATE.md.
#
# Usage: scaffold.sh <example-dir> <plugin-import> [plugin-package-name]
#   example-dir   where the app is created (e.g. ../my_plugin/example)
#   plugin-import the plugin's package import (e.g. zuraffa_permissions)
#
# After running, fill the `// TODO(template):` hooks (one panel per plugin
# operation) and the README operation table, then run the verification
# checklist from TEMPLATE.md.
set -euo pipefail

DIR="${1:?usage: scaffold.sh <example-dir> <plugin-import> [plugin-package-name]}"
IMPORT="${2:?usage: scaffold.sh <example-dir> <plugin-import> [plugin-package-name]}"
PKG="${3:-$IMPORT}"
CLASS="$(echo "$PKG" | sed -E 's/[_-](.)/\U\1/g; s/^(.)/\U\1/')"

if [ -d "$DIR" ]; then
  echo "refusing: $DIR already exists" >&2
  exit 1
fi

NAME="$(basename "$DIR")"
PARENT="$(cd "$(dirname "$DIR")" && pwd)"
cd "$PARENT"
zfa setup "$NAME" --flutter --platforms=ios,macos,android --org=dev.zuraffa --no-git

cd "$NAME"
rm -rf lib test build.yaml dart_test.yaml .specify .zfa.json
rm -f pubspec.yaml  # rewritten below

cat >| pubspec.yaml <<PUBSPEC
name: ${PKG}_example
description: "Demonstrates every ${PKG} operation end to end on android, ios and macos."
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.13.2

dependencies:
  flutter:
    sdk: flutter
  get_it: ^9.2.1
  ${PKG}:
    path: ../

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
PUBSPEC

mkdir -p lib test
cat >| lib/main.dart <<MAINDART
// The ${PKG} example: every plugin operation, wired end to end, on
// android, ios and macos. See TEMPLATE.md for the shape and the README
// for the operation table.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:${PKG}/${PKG}.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(template): the plugin's composition root binding, e.g.
  //   register${CLASS}Dependencies(GetIt.instance);
  // and resolve the app-facing service from GetIt. Injectable on the app
  // widget so widget tests run the simulator without channels.
  final service = ... ; // TODO(template): resolve or construct the service
  runApp(${CLASS}ExampleApp(initialService: service));
}

class ${CLASS}ExampleApp extends StatelessWidget {
  const ${CLASS}ExampleApp({super.key, this.initialService});

  final Object? initialService; // TODO(template): the app-facing service type

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${PKG} example',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF7B61FF), useMaterial3: true),
      home: const Placeholder(),
    );
  }
}

// TODO(template): the page widget — one panel per plugin operation (the
// panels are the API tour), an app-bar switch to the plugin's in-memory
// simulator adapter, a verbatim error banner, and the simulator's
// producer-side buttons. Reference the finished implementations:
//   ~/Developer/zuraffa_intents/example/lib/main.dart
//   ~/Developer/zuraffa_permissions/packages/zuraffa_permissions/example/lib
MAINDART

cat >| test/widget_test.dart <<TESTDART
// Executable documentation: the complete flow over the simulator adapter.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:${PKG}/${PKG}.dart';

void main() {
  testWidgets('every operation works end to end', (tester) async {
    // TODO(template): construct the app with an in-memory service and
    // drive each panel: act -> assert outcome (include the carrier/field
    // mapping) -> cover the error path. Reference the finished tests:
    //   zuraffa_intents/example/test/widget_test.dart
    //   zuraffa_permissions/packages/zuraffa_permissions/example/test
    expect(true, isTrue, reason: 'unimplemented template test');
  });
}
TESTDART

cat >| README.md <<READMED
# ${PKG} example

A fully working ${PKG} demo on **android, ios and macos**.

| Plugin operation | Where in the app |
| --- | --- |
| TODO(template): one row per operation | TODO(template) |

## Run

\`\`\`sh
flutter pub get
flutter run            # pick an android / ios / macos device
\`\`\`

## Platform integration

- **Android** — TODO(template): app-manifest snippets the plugin needs
  (intent filters / permission declarations).
- **iOS/macOS** — TODO(template): Xcode-target setup (extensions, usage
  descriptions).
READMED

sed -i '' 's/^  analyzer: .*//' pubspec.yaml 2>/dev/null || true
echo "scaffolded $DIR — fill the TODO(template) hooks, then verify per TEMPLATE.md"
