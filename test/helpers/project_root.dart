import 'dart:io';

/// Cached project root, resolved once and reused across all test files.
String? _cachedProjectRoot;

/// Last-resort error details collected during resolution.
String _diagnostics = '';

/// Returns the absolute path to the zuraffa project root.
///
/// Resolution strategies (tried in order):
/// 1. Return cached value if already resolved.
/// 2. [_ensureValidCwd] — recover CWD if deleted.
/// 3. Parse [Platform.script] URI by pure string ops (zero CWD/IO).
/// 4. [Platform.script.toFilePath()] + walk up.
/// 5. Walk up from [Directory.current] (skipped for temp paths).
/// 6. [git rev-parse --show-toplevel].
/// 7. Read `.dart_tool/package_config.json` relative to Platform.script.
///
/// Throws [StateError] if the root cannot be determined.
String findProjectRoot() {
  if (_cachedProjectRoot != null) return _cachedProjectRoot!;

  _diagnostics = '';
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
      'Cannot determine zuraffa project root. CWD=$cwdForError\n$_diagnostics',
    );
  }
  _cachedProjectRoot = root;
  return root;
}

// ----------------------------------------------------------------
// CWD recovery
// ----------------------------------------------------------------

/// Aggressively recover CWD to a known-valid directory.
void _ensureValidCwd() {
  try {
    final currentPath = Directory.current.path;
    if (Directory(currentPath).existsSync()) return;
  } catch (_) {
    _diag('_ensureValidCwd: Directory.current.path threw');
  }

  // CWD is invalid — try known-good paths.
  final candidates = <String>[
    Directory.systemTemp.path,
    '/tmp',
    Platform.environment['HOME'] ?? '',
  ];
  for (final c in candidates) {
    if (c.isEmpty) continue;
    try {
      if (Directory(c).existsSync()) {
        Directory.current = c;
        _diag('_ensureValidCwd: recovered to $c');
        return;
      }
    } catch (_) {}
  }
  _diag('_ensureValidCwd: FAILED to recover CWD');
}

// ----------------------------------------------------------------
// Resolution orchestrator
// ----------------------------------------------------------------

String? _resolveProjectRoot() {
  // Strategy 1: Pure string URI parsing (zero CWD / IO dependency).
  final s1 = _tryFromScriptString();
  if (s1 != null) return s1;

  // Strategy 2: Platform.script.toFilePath() + walk.
  final s2 = _tryFromScriptFilePath();
  if (s2 != null) return s2;

  // Strategy 3: Walk up from CWD (skip temp paths).
  if (!_isTempPath(Directory.current.path)) {
    final s3 = _walkToRoot(Directory.current.path);
    if (s3 != null) return s3;
  }

  // Strategy 4: git rev-parse.
  final s4 = _tryFromGit();
  if (s4 != null) return s4;

  // Strategy 5: .dart_tool/package_config.json.
  return _tryFromPackageConfig();
}

// ----------------------------------------------------------------
// Strategy 1 — Pure string URI parsing
// ----------------------------------------------------------------

/// Parse [Platform.script] as a string, extract the file path, and walk up.
/// This uses ZERO filesystem calls and ZERO CWD dependency.
String? _tryFromScriptString() {
  try {
    final uriStr = Platform.script.toString();
    if (!uriStr.startsWith('file://')) {
      _diag('S1: URI does not start with file:// ($uriStr)');
      return null;
    }
    var filePath = uriStr.substring(7); // strip "file://"
    filePath = Uri.decodeComponent(filePath);
    if (!filePath.startsWith('/')) {
      _diag('S1: decoded path not absolute ($filePath)');
      return null;
    }
    _diag('S1: script path from string = $filePath');
    return _walkToRoot(filePath);
  } catch (e) {
    _diag('S1: threw $e');
    return null;
  }
}

// ----------------------------------------------------------------
// Strategy 2 — Platform.script.toFilePath()
// ----------------------------------------------------------------

String? _tryFromScriptFilePath() {
  try {
    final scriptPath = Platform.script.toFilePath();
    if (scriptPath.startsWith('/')) {
      _diag('S2: toFilePath = $scriptPath');
      return _walkToRoot(scriptPath);
    }
    _diag('S2: path not absolute ($scriptPath)');
  } catch (e) {
    _diag('S2: threw $e');
  }
  // Fallback: raw .path property
  try {
    final raw = Platform.script.path;
    if (raw.startsWith('/')) {
      _diag('S2b: .path = $raw');
      return _walkToRoot(raw);
    }
  } catch (e) {
    _diag('S2b: threw $e');
  }
  return null;
}

// ----------------------------------------------------------------
// Tree walker
// ----------------------------------------------------------------

/// Walk up from [startPath] looking for pubspec.yaml with [name: zuraffa].
String? _walkToRoot(String startPath) {
  try {
    var dir = Directory(startPath).parent;
    for (var i = 0; i < 20; i++) {
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
    _diag('walkToRoot: exhausted from $startPath');
  } catch (e) {
    _diag('walkToRoot: threw $e');
  }
  return null;
}

// ----------------------------------------------------------------
// Strategy 4 — git rev-parse
// ----------------------------------------------------------------

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
  } catch (e) {
    _diag('S4 git: $e');
  }
  return null;
}

// ----------------------------------------------------------------
// Strategy 5 — .dart_tool/package_config.json
// ----------------------------------------------------------------

String? _tryFromPackageConfig() {
  try {
    // Get script path via pure string ops (same as S1)
    final uriStr = Platform.script.toString();
    if (!uriStr.startsWith('file://')) return null;
    var filePath = uriStr.substring(7);
    filePath = Uri.decodeComponent(filePath);

    // Walk up from script dir looking for .dart_tool/package_config.json
    var dir = Directory(filePath).parent;
    for (var i = 0; i < 20; i++) {
      final configFile =
          File('${dir.path}/.dart_tool/package_config.json');
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        // Find "zuraffa" package entry and extract its root path.
        final zuraffaMatch = RegExp(
          r'"name"\s*:\s*"zuraffa"[^}]*"rootUri"\s*:\s*"([^"]+)"',
        ).firstMatch(content);
        if (zuraffaMatch != null) {
          var rootUri = zuraffaMatch.group(1)!;
          // rootUri is usually like "../" or "file:///..." or a relative path
          if (rootUri.startsWith('file://')) {
            rootUri = rootUri.substring(7);
            rootUri = Uri.decodeComponent(rootUri);
          }
          // Resolve relative to the directory containing package_config.json
          if (!rootUri.startsWith('/')) {
            rootUri = '${dir.path}/$rootUri';
          }
          rootUri = Directory(rootUri).absolute.path;
          // Verify
          final pubspec = File('$rootUri/pubspec.yaml');
          if (pubspec.existsSync()) {
            _diag('S5: found zuraffa at $rootUri via package_config.json');
            return rootUri;
          }
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (e) {
    _diag('S5: $e');
  }
  return null;
}

// ----------------------------------------------------------------
// Utilities
// ----------------------------------------------------------------

bool _isTempPath(String p) {
  final lower = p.toLowerCase();
  final systemTempLower = Directory.systemTemp.path.toLowerCase();
  return lower == '/tmp' ||
      lower.startsWith('/tmp/') ||
      lower.contains('/tmp/') ||
      lower.contains('/var/folders/') ||
      lower.contains('/nosuchfile') ||
      lower == systemTempLower;
}

void _diag(String msg) {
  _diagnostics += '  $msg\n';
}
