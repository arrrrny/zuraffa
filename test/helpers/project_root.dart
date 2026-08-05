import 'dart:io';

/// Cached project root, resolved once and reused across all test files.
String? _cachedProjectRoot;

/// Returns the absolute path to the zuraffa project root.
///
/// Resolution order:
/// 1. Return cached value if already resolved.
/// 2. [_ensureValidCwd] — if CWD points to a deleted directory, recover
///    to systemTemp so that any CWD-dependent operation does not crash.
/// 3. Walk up from [Platform.script] (immune to CWD for absolute URIs).
/// 4. Walk up from [Directory.current] (skipped when CWD is a temp path).
/// 5. [git rev-parse --show-toplevel] (works from anywhere inside the repo).
///
/// Throws [StateError] if the root cannot be determined.
String findProjectRoot() {
  if (_cachedProjectRoot != null) return _cachedProjectRoot!;

  // Step 0: ensure CWD is valid BEFORE any filesystem operation.
  _ensureValidCwd();

  final root = _resolveProjectRoot();
  if (root == null) {
    String cwdForError;
    try {
      cwdForError = Directory.current.path;
    } catch (_) {
      cwdForError = '<unable to read CWD>';
    }
    throw StateError(
      'Cannot determine zuraffa project root. CWD=$cwdForError',
    );
  }
  _cachedProjectRoot = root;
  return root;
}

/// If CWD points to a deleted directory, recover to systemTemp.
void _ensureValidCwd() {
  try {
    if (!Directory(Directory.current.path).existsSync()) {
      Directory.current = Directory.systemTemp;
    }
  } catch (_) {
    try {
      Directory.current = Directory.systemTemp;
    } catch (_) {}
  }
}

/// Whether [p] looks like a temp directory that cannot contain the project.
bool _isTempPath(String p) {
  final lower = p.toLowerCase();
  final systemTempLower = Directory.systemTemp.path.toLowerCase();

  final isTmpSegment = lower == '/tmp' ||
      lower.startsWith('/tmp/') ||
      lower.contains('/tmp/');

  return isTmpSegment ||
      lower.contains('/var/folders/') ||
      lower.contains('/nosuchfile') ||
      lower == systemTempLower;
}

String? _resolveProjectRoot() {
  // Strategy 1: Walk up from Platform.script.
  final scriptResult = _tryFromScript();
  if (scriptResult != null) return scriptResult;

  // Strategy 2: Walk up from CWD (skip if it is a temp path).
  if (!_isTempPath(Directory.current.path)) {
    final cwdResult = _walkToRoot(Directory.current.path);
    if (cwdResult != null) return cwdResult;
  }

  // Strategy 3: git rev-parse --show-toplevel.
  return _tryFromGit();
}

String? _tryFromScript() {
  // Primary: Platform.script.toFilePath() — works for absolute URIs.
  try {
    final scriptPath = Platform.script.toFilePath();
    if (scriptPath.startsWith('/')) {
      return _walkToRoot(scriptPath);
    }
  } catch (_) {
    // toFilePath() may fail when CWD is deleted.
  }

  // Fallback: raw URI path component (truly CWD-independent).
  try {
    final raw = Platform.script.path;
    if (raw.startsWith('/')) {
      return _walkToRoot(raw);
    }
  } catch (_) {}

  return null;
}

/// Walk up from [startPath] looking for pubspec.yaml with name: zuraffa.
String? _walkToRoot(String startPath) {
  var dir = Directory(startPath).parent;
  for (var i = 0; i < 15; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true)
          .hasMatch(content)) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

String? _tryFromGit() {
  try {
    final result =
        Process.runSync('git', ['rev-parse', '--show-toplevel']);
    if (result.exitCode == 0) {
      final gitRoot = (result.stdout as String).trim();
      if (!_isTempPath(gitRoot)) {
        final pubspec = File('$gitRoot/pubspec.yaml');
        if (pubspec.existsSync()) {
          final content = pubspec.readAsStringSync();
          if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true)
              .hasMatch(content)) {
            return gitRoot;
          }
        }
      }
    }
  } catch (_) {}
  return null;
}
