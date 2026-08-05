import 'dart:io';

/// Cached project root, resolved once and reused across all test files.
String? _cachedProjectRoot;

/// Returns the absolute path to the zuraffa project root.
///
/// Resolution order:
/// 1. Return cached value if already resolved.
/// 2. Walk up from [Platform.script] (immune to CWD for absolute URIs).
/// 3. Walk up from [Directory.current] (fallback, may be poisoned).
/// 4. [git rev-parse --show-toplevel] (works from anywhere inside the repo).
///
/// Throws [StateError] if the root cannot be determined.
String findProjectRoot() {
  if (_cachedProjectRoot != null) return _cachedProjectRoot!;

  String? resolve() {
    // Strategy 1: Walk up from Platform.script.
    try {
      final scriptPath = Platform.script.toFilePath();
      if (scriptPath.startsWith('/')) {
        var dir = Directory(scriptPath).parent;
        for (var i = 0; i < 10; i++) {
          final pubspec = File('${dir.path}/pubspec.yaml');
          if (pubspec.existsSync()) {
            final c = pubspec.readAsStringSync();
            if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true)
                .hasMatch(c)) {
              return dir.path;
            }
          }
          final parent = dir.parent;
          if (parent.path == dir.path) break;
          dir = parent;
        }
      }
    } catch (_) {
      // toFilePath() may fail when CWD is deleted.
      // Try the raw URI path component as a fallback.
      try {
        final raw = Platform.script.path;
        if (raw.startsWith('/')) {
          var dir = Directory(raw).parent;
          for (var i = 0; i < 10; i++) {
            final pubspec = File('${dir.path}/pubspec.yaml');
            if (pubspec.existsSync()) {
              final c = pubspec.readAsStringSync();
              if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true)
                  .hasMatch(c)) {
                return dir.path;
              }
            }
            final parent = dir.parent;
            if (parent.path == dir.path) break;
            dir = parent;
          }
        }
      } catch (_) {}
    }

    // Strategy 2: Walk up from CWD.
    try {
      var dir = Directory.current;
      for (var i = 0; i < 15; i++) {
        final pubspec = File('${dir.path}/pubspec.yaml');
        if (pubspec.existsSync()) {
          final c = pubspec.readAsStringSync();
          if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true)
              .hasMatch(c)) {
            return dir.path;
          }
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}

    // Strategy 3: git rev-parse.
    try {
      final result =
          Process.runSync('git', ['rev-parse', '--show-toplevel']);
      if (result.exitCode == 0) {
        final gitRoot = (result.stdout as String).trim();
        final pubspec = File('$gitRoot/pubspec.yaml');
        if (pubspec.existsSync()) {
          final c = pubspec.readAsStringSync();
          if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true)
              .hasMatch(c)) {
            return gitRoot;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  final root = resolve();
  if (root == null) {
    throw StateError(
      'Cannot determine zuraffa project root. '
      'CWD=${Directory.current.path}',
    );
  }
  _cachedProjectRoot = root;
  return root;
}
