// SPDX-License-Identifier: MIT
//
// BrandingWriter — copies Zuraffa brand assets into generated Flutter/Dart apps.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds the zuraffa repository root by walking upward from [startPath].
/// First it looks for a `pubspec.yaml` declaring `name: zuraffa`. If that
/// walk fails (e.g. /tmp has no ancestor pubspec, or pubspec is missing),
/// it falls back to looking for `assets/zuraffa_app_icons/` in any ancestor
/// — that directory is unique to the zuraffa repo and survives pubspec
/// renames. As a last resort it walks up from `Platform.script`.
String findZuraffaRoot({String? startPath}) {
  // 1) Try a pubspec walk from the requested start (default: CWD).
  final start = startPath ?? _scriptDir();
  final pubspecRoot = _walkUpFor(
    start: start,
    predicate: (dir) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (!pubspec.existsSync()) return false;
      final content = pubspec.readAsStringSync();
      return content.contains('name: zuraffa') ||
          content.contains('"zuraffa"') ||
          content.contains("'zuraffa'");
    },
  );
  if (pubspecRoot != null) return pubspecRoot;

  // 2) Fallback: walk up from Platform.script to find the brand assets
  //    directory — unique marker for the zuraffa repo.
  final brandRoot = _walkUpFor(
    start: File(Platform.script.toFilePath()).parent.path,
    predicate: (dir) =>
        Directory(p.join(dir.path, 'assets', 'zuraffa_app_icons')).existsSync(),
  );
  if (brandRoot != null) return brandRoot;

  // 3) Last resort: walk up from CWD looking for the brand assets.
  return _walkUpFor(
        start: start,
        predicate: (dir) => Directory(
          p.join(dir.path, 'assets', 'zuraffa_app_icons'),
        ).existsSync(),
      ) ??
      start;
}

String? _walkUpFor({
  required String start,
  required bool Function(Directory) predicate,
}) {
  var dir = Directory(p.normalize(p.absolute(start)));
  if (!dir.existsSync()) dir = dir.parent;
  while (true) {
    if (predicate(dir)) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

String _scriptDir() {
  try {
    return Directory.current.path;
  } catch (_) {
    try {
      return File(Platform.script.toFilePath()).parent.path;
    } catch (_) {
      return Platform.script.toFilePath();
    }
  }
}

/// Writes Zuraffa brand assets into a generated app project.
class BrandingWriter {
  /// The root directory of the zuraffa repository.
  /// Uses [findZuraffaRoot] so callers that omit `zuraffaRoot` get a
  /// CI-safe walk rather than a `Platform.script`-derived path.
  static String get zuraffaRoot => findZuraffaRoot();

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
  /// - removes default Flutter logo files
  /// - updates pubspec.yaml
  Future<void> writeFlutterBranding({
    required String projectRoot,
    required bool dryRun,
    required bool verbose,
  }) async {
    if (dryRun) return;

    await _copyBrandAssetsToAssets(projectRoot);
    await _copyIconFiles(projectRoot);
    await _updatePubspecAssets(projectRoot);
    await _removeFlutterDefaults(projectRoot);
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
    await _updateReadme(projectRoot);
  }

  /// Copies brand assets to {projectRoot}/assets/zuraffa_app_icons/.
  /// Idempotent: skips if destination already exists.
  Future<void> _copyBrandAssetsToAssets(String projectRoot) async {
    final destDir = Directory(
      p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
    );
    if (destDir.existsSync()) return; // already branded
    final sourceDir = Directory(_brandAssetsSource);
    if (!sourceDir.existsSync()) {
      // Graceful degradation: the brand assets may not be checked out
      // (e.g. minimal CI clone). Skip silently — callers pass verbose:true
      // to surface this. See spec 053 edge case.
      return;
    }
    destDir.createSync(recursive: true);
    await for (final entity in sourceDir.list()) {
      if (entity is File) {
        final destPath = p.join(destDir.path, p.basename(entity.path));
        await entity.copy(destPath);
      }
    }
  }

  /// Copies iOS and Android app icons to platform-specific directories.
  Future<void> _copyIconFiles(String projectRoot) async {
    // iOS icons — source is Assets.xcassets/ at brand root, dest is ios/Runner/Assets.xcassets/
    final iosSource = Directory(p.join(_brandAssetsSource, 'Assets.xcassets'));
    final iosDest = Directory(
      p.join(projectRoot, 'ios', 'Runner', 'Assets.xcassets'),
    );
    if (iosSource.existsSync()) {
      if (!iosDest.existsSync()) iosDest.createSync(recursive: true);
      await for (final entity in iosSource.list(recursive: true)) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: iosSource.path);
          final destPath = p.join(iosDest.path, rel);
          File(destPath).parent.createSync(recursive: true);
          await entity.copy(destPath);
        }
      }
    }

    // Android icons
    final androidSource = Directory(p.join(_brandAssetsSource, 'android'));
    final androidRes = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'res'),
    );
    if (!androidRes.existsSync()) androidRes.createSync(recursive: true);
    if (androidSource.existsSync()) {
      await for (final entity in androidSource.list(recursive: true)) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: androidSource.path);
          final destPath = p.join(androidRes.path, rel);
          File(destPath).parent.createSync(recursive: true);
          await entity.copy(destPath);
        }
      }
    }
  }

  /// Adds assets/zuraffa_app_icons/ to pubspec.yaml flutter assets section.
  ///
  /// Issue #735: the pubspec entry must never reference a directory that
  /// does not exist. [_copyBrandAssetsToAssets] silently skips directory
  /// creation when the brand asset source is absent (minimal CI clone,
  /// `findZuraffaRoot` failure, globally-activated zfa), so the destination
  /// can stay missing while this method injects `assets/zuraffa_app_icons/`
  /// — and every subsequent `flutter test` run then fails with
  /// "unable to find directory entry in pubspec.yaml". The directory is
  /// therefore created here whenever the pubspec references it (already or
  /// about to), which also repairs projects affected before the fix when
  /// setup is re-run.
  Future<void> _updatePubspecAssets(String projectRoot) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return;

    var content = pubspecFile.readAsStringSync();
    final alreadyAdded = content.contains('zuraffa_app_icons');
    final willInject =
        !alreadyAdded &&
        (content.contains('uses-material-design: true') ||
            content.contains('flutter:'));

    // Write the entry only when the directory it references exists on disk.
    // Creating it here (possibly empty when nothing could be copied) keeps
    // the pubspec reference from dangling regardless of whether
    // [_copyBrandAssetsToAssets] ran or its source was present.
    if (alreadyAdded || willInject) {
      final iconsDir = Directory(
        p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
      );
      if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);
    }

    if (alreadyAdded) return; // already added

    // Inject after "uses-material-design: true"
    if (content.contains('uses-material-design: true')) {
      content = content.replaceFirst(
        'uses-material-design: true',
        'uses-material-design: true\n  assets:\n    - assets/zuraffa_app_icons/',
      );
    } else if (content.contains('flutter:')) {
      // Block-style "flutter:" (no inline { — newline-terminated). Insert
      // "assets:" as a child of the block on the next line.
      content = content.replaceFirst(
        RegExp(r'flutter:\s*\n'),
        'flutter:\n  assets:\n    - assets/zuraffa_app_icons/\n',
      );
    }
    await pubspecFile.writeAsString(content);
  }

  /// Prepends a Zuraffa banner to README.md.
  Future<void> _updateReadme(String projectRoot) async {
    final readme = File(p.join(projectRoot, 'README.md'));
    if (!readme.existsSync()) return;

    final content = readme.readAsStringSync();
    if (content.contains('Zuraffa')) return; // already branded

    final banner = '''# Zuraffa

> Built with [Zuraffa](https://github.com/arrrrny/zuraffa) — the Flutter/Dart project generator.

''';
    await readme.writeAsString(banner + content);
  }

  /// Removes default Flutter logo files from the target project.
  Future<void> _removeFlutterDefaults(String projectRoot) async {
    final assetsDir = Directory(p.join(projectRoot, 'assets'));
    if (!assetsDir.existsSync()) return;

    for (final name in ['flutter.png', 'flutter_animated.png']) {
      final file = File(p.join(assetsDir.path, name));
      if (file.existsSync()) await file.delete();
    }

    // Also delete default Flutter logo images nested in Android res dirs
    // (e.g. drawable/flutter.png).
    final androidRes = Directory(
      p.join(projectRoot, 'android', 'app', 'src', 'main', 'res'),
    );
    if (!androidRes.existsSync()) return;

    await for (final entity in androidRes.list(recursive: true)) {
      if (entity is File) {
        final name = p.basename(entity.path).toLowerCase();
        if (name == 'flutter.png' || name == 'flutter_animated.png') {
          await entity.delete();
        }
      }
    }
  }
}
