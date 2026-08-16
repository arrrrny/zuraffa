// X-Ray deck barrel writer — maintains the `xray_decks.dart` barrel
// that aggregates per-entity `register<Entity>XRayDeck()` calls.
//
// Used by `zfa xray deck --entity <Entity>` (issue #360). The barrel is
// created by `zfa app shell --xray` (via `AppShellBuilder.buildXRayDecksBarrel`)
// and then each `zfa xray deck --entity <Entity>` invocation appends:
//   1. An import of the generated `<entity>_xray_deck.dart` file.
//   2. A `register<Entity>XRayDeck();` call inside `registerAllXRayDecks()`.
//
// The writer is idempotent: running it twice with the same entity does
// not duplicate the import or the call.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Result of updating the barrel.
class BarrelUpdateResult {
  /// The barrel file path.
  final String path;

  /// `true` if the import was added (was missing before).
  final bool importAdded;

  /// `true` if the registration call was added (was missing before).
  final bool callAdded;

  /// `true` if the barrel was created (did not exist before).
  final bool created;

  /// Human-readable status message.
  final String message;

  const BarrelUpdateResult({
    required this.path,
    required this.importAdded,
    required this.callAdded,
    required this.created,
    required this.message,
  });
}

/// Maintains the `xray_decks.dart` barrel file.
///
/// The barrel lives at `<projectRoot>/lib/src/xray/xray_decks.dart` and
/// exports `void registerAllXRayDecks()` that the generated `main.dart`
/// calls after starting the bridge server.
class XRayDeckBarrelWriter {
  /// The barrel file name within the xray output directory.
  static const String barrelFileName = 'xray_decks.dart';

  final String projectRoot;

  /// The output directory for xray glue files (default `lib/src`).
  final String outputDir;

  const XRayDeckBarrelWriter({
    this.projectRoot = '.',
    this.outputDir = 'lib/src',
  });

  /// Returns the barrel file path.
  String get barrelPath => p.join(projectRoot, outputDir, 'xray', barrelFileName);

  /// Updates the barrel to include the registration for [entityName].
  ///
  /// [deckFilePath] is the absolute path to the generated deck file
  /// (e.g. `lib/src/xray/user_xray_deck.dart`). The import is written
  /// as a relative import from the barrel to the deck file.
  /// [registerFunctionName] is the name of the registration function
  /// (e.g. `registerUserXRayDeck`).
  ///
  /// If the barrel does not exist, it is created with the default
  /// scaffold (matching `AppShellBuilder.buildXRayDecksBarrel`).
  /// If it exists, the import and call are appended idempotently.
  BarrelUpdateResult update({
    required String entityName,
    required String deckFilePath,
    required String registerFunctionName,
    bool dryRun = false,
  }) {
    final barrelFile = File(barrelPath);
    final barrelExists = barrelFile.existsSync();

    if (!barrelExists) {
      // Create the barrel with the default scaffold + the first entry.
      final scaffold = _buildScaffoldWithEntry(
        entityName: entityName,
        deckFilePath: deckFilePath,
        registerFunctionName: registerFunctionName,
      );
      if (!dryRun) {
        barrelFile.parent.createSync(recursive: true);
        barrelFile.writeAsStringSync(scaffold);
      }
      return BarrelUpdateResult(
        path: barrelPath,
        importAdded: true,
        callAdded: true,
        created: true,
        message: dryRun
            ? 'would create barrel with $registerFunctionName() entry'
            : 'created barrel with $registerFunctionName() entry',
      );
    }

    // Barrel exists — read and update.
    var content = barrelFile.readAsStringSync();
    var importAdded = false;
    var callAdded = false;

    // Compute the relative import path from the barrel to the deck file.
    final relativeDeckPath = p.relative(
      deckFilePath,
      from: p.dirname(barrelPath),
    );
    final importLine = "import '$relativeDeckPath';";

    // Add the import if missing.
    if (!content.contains(importLine)) {
      // Insert after the last import line.
      final importPattern = RegExp(
        r'^(import\s+[^\n]+\n)+',
        multiLine: true,
      );
      final importMatch = importPattern.firstMatch(content);
      if (importMatch != null) {
        content =
            '${content.substring(0, importMatch.end)}'
            '$importLine\n'
            '${content.substring(importMatch.end)}';
      } else {
        // No imports — insert after the header comment.
        final firstBlank = content.indexOf('\n\n');
        if (firstBlank >= 0) {
          content =
              '${content.substring(0, firstBlank + 2)}'
              '$importLine\n'
              '${content.substring(firstBlank + 2)}';
        } else {
          content = '$importLine\n$content';
        }
      }
      importAdded = true;
    }

    // Add the registration call if missing.
    final callLine = '  $registerFunctionName();';
    if (!content.contains(callLine)) {
      // Insert inside registerAllXRayDecks(), after `if (kReleaseMode) return;`.
      final releaseGuard = '  if (kReleaseMode) return;';
      final insertPos = content.indexOf(releaseGuard);
      if (insertPos >= 0) {
        final afterGuard =
            insertPos + releaseGuard.length;
        content =
            '${content.substring(0, afterGuard)}\n'
            '$callLine'
            '${content.substring(afterGuard)}';
        callAdded = true;
      } else {
        // No release guard — insert before the closing brace of
        // registerAllXRayDecks().
        final closingBrace = content.lastIndexOf('}');
        if (closingBrace >= 0) {
          content =
              '${content.substring(0, closingBrace)}'
              '$callLine\n'
              '${content.substring(closingBrace)}';
          callAdded = true;
        }
      }
    }

    if ((importAdded || callAdded) && !dryRun) {
      barrelFile.writeAsStringSync(content);
    }

    return BarrelUpdateResult(
      path: barrelPath,
      importAdded: importAdded,
      callAdded: callAdded,
      created: false,
      message: (importAdded || callAdded)
          ? (dryRun
              ? 'would update barrel: '
                  '${importAdded ? "+import " : ""}'
                  '${callAdded ? "+call" : ""}'
                  ' for $entityName'
              : 'updated barrel for $entityName')
          : 'barrel already up to date for $entityName',
    );
  }

  /// Builds the barrel scaffold with the first entry already included.
  String _buildScaffoldWithEntry({
    required String entityName,
    required String deckFilePath,
    required String registerFunctionName,
  }) {
    final relativeDeckPath = p.relative(
      deckFilePath,
      from: p.dirname(barrelPath),
    );
    return [
      '// Generated by zfa — X-Ray Control Deck registration barrel.',
      '// This file is maintained by `zfa xray deck`. Each invocation',
      '// appends a `register<Entity>XRayDeck()` call below. Safe to',
      '// edit manually — `zfa xray deck` preserves existing calls.',
      '',
      "import 'package:flutter/foundation.dart';",
      "import '$relativeDeckPath';",
      '',
      '/// Registers all X-Ray Control Deck entries generated by `zfa xray deck`.',
      '/// No-op in release mode.',
      'void registerAllXRayDecks() {',
      '  if (kReleaseMode) return;',
      '  $registerFunctionName();',
      '}',
      '',
    ].join('\n');
  }
}
