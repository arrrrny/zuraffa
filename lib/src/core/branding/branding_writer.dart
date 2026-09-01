// SPDX-License-Identifier: MIT
//
// BrandingWriter — copies Zuraffa brand assets into generated Flutter/Dart apps.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Writes Zuraffa brand assets into a generated app project.
class BrandingWriter {
  /// The root directory of the zuraffa repository.
  /// Auto-detected from the location of this library file.
  static String get zuraffaRoot {
    // Derive from the location of this source file: lib/src/core/branding/ ->
    // three levels up from lib/src/core/branding/ reaches the repo root.
    final scriptUri = Platform.script.toFilePath();
    final brandingDir = p.dirname(scriptUri); // branding/
    final coreDir = p.dirname(brandingDir);   // src/core/
    final srcDir = p.dirname(coreDir);        // lib/src/
    return p.dirname(srcDir);                 // repo root
  }

  final String _zuraffaRoot;

  /// Default brand asset source relative to zuraffa root.
  static const _defaultBrandAssetDir = 'assets/zuraffa_app_icons';

  BrandingWriter({String? zuraffaRoot})
      : _zuraffaRoot = zuraffaRoot ?? BrandingWriter.zuraffaRoot;

  String get _brandAssetsSource => p.join(_zuraffaRoot, _defaultBrandAssetDir);

  /// Copies brand assets for a Flutter app:
  /// - app icons to android/app/src/main/res/ and ios/
  /// - store listing images to assets/
  /// - Zuraffa assets to assets/zuraffa_app_icons/
  Future<void> writeFlutterBranding({
    required String projectRoot,
    required bool dryRun,
    required bool verbose,
  }) async {
    if (dryRun) return;
    await _copyBrandAssetsToAssets(projectRoot);
  }

  /// Copies brand assets for a Dart CLI package:
  /// - Zuraffa logo to assets/
  /// - README header update
  Future<void> writeDartBranding({
    required String projectRoot,
    required bool dryRun,
    required bool verbose,
  }) async {
    if (dryRun) return;
    await _copyBrandAssetsToAssets(projectRoot);
  }

  /// Copies brand assets to {projectRoot}/assets/zuraffa_app_icons/.
  /// Idempotent: skips if destination already exists.
  Future<void> _copyBrandAssetsToAssets(String projectRoot) async {
    final destDir = Directory(p.join(projectRoot, 'assets', 'zuraffa_app_icons'));
    if (destDir.existsSync()) return; // already branded
    destDir.createSync(recursive: true);
    final sourceDir = Directory(_brandAssetsSource);
    await for (final entity in sourceDir.list()) {
      if (entity is File) {
        final destPath = p.join(destDir.path, p.basename(entity.path));
        await entity.copy(destPath);
      }
    }
  }
}
