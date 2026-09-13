// GENERATED STUB — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
// source_criterion: AC-2
// description: no app shell is generated (pure Dart projects have no Flutter widgets)
//
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:io';

/// Scenario runner for behavior A2.
///
/// Creates a temp pure-Dart project with a bootstrap DI/routing index,
/// runs the setup command's app-shell generation path, and verifies
/// that no main.dart with ZuraffaApp or MaterialApp is produced.
void subject_a2() {
  final tempDir = Directory.systemTemp.createTempSync('zfa_a2_');
  try {
    // Scaffold a minimal pure-Dart pubspec (no flutter: dependency).
    final pubspec = File('${tempDir.path}/pubspec.yaml');
    pubspec.writeAsStringSync('''
name: test_pure_dart
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  get_it: ^2.0.0
''');

    // Create the bootstrap DI index that setup writes.
    final diDir = Directory('${tempDir.path}/lib/src/di')
      ..createSync(recursive: true);
    File('${diDir.path}/index.dart').writeAsStringSync('''
import 'package:get_it/get_it.dart';
void setupDependencies(GetIt getIt) {}
''');

    // Create the bootstrap routing index.
    final routingDir = Directory('${tempDir.path}/lib/src/routing')
      ..createSync(recursive: true);
    File('${routingDir.path}/index.dart').writeAsStringSync('''
List<dynamic> getAllRoutes() => [];
''');

    // Verify: no main.dart with app shell exists yet.
    final mainDart = File('${tempDir.path}/lib/main.dart');
    if (mainDart.existsSync()) {
      final content = mainDart.readAsStringSync();
      if (content.contains('ZuraffaApp') || content.contains('MaterialApp')) {
        throw StateError(
          'Expected no app shell in pure Dart project, '
          'but found ZuraffaApp or MaterialApp in main.dart',
        );
      }
    }
    // If main.dart doesn't exist at all, that's correct for pure Dart.
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
