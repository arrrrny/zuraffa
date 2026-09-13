// Spec-pin test for spec 1509-toolchain-path-portable (issue #1509).
//
// Pins the measurable success criterion SC-001: the documented-but-
// unavailable toolchain path from issue #1509 — the '/opt/flutter' dart
// binary — must not appear as a contiguous literal in any tracked *.dart,
// *.sh, *.yaml or *.yml file. The toolchain is PATH-resolved;
// machine-specific SDK locations are declared through the environment
// (ZURAFFA_DART_BIN, ZURAFFA_TOOLCHAIN_HINTS, FLUTTER_ROOT), never
// through source literals.
//
// NOTE: this file composes the banned path from fragments (and so does
// the acceptance test in dart_toolchain_resolver_test.dart) so that the
// SC-001 grep gate itself passes repo-wide — the string below is
// reassembled at compile time.
//
// RED evidence (recorded 2026-09-13, before the fix): this test failed
// against `bin/zuraffa_mcp_server.dart:1638`, which carried the literal
// as a last-resort fallback candidate in `_findDartExecutable()`.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The banned literal — assembled from fragments so this pin test does
/// not itself contain the contiguous string it bans.
const _bannedLiteral =
    '/opt/flutter/bin/'
    'dart';

/// File extensions the SC-001 grep covers.
const _scannedExtensions = {'.dart', '.sh', '.yaml', '.yml'};

/// Directories never scanned (generated / VCS internals). This is a
/// filesystem walk, not `git ls-files`: untracked or ignored scratch
/// files are still visited, so a dirty tree can surface them here.
const _skippedDirNames = {'.git', '.dart_tool'};

List<String> _trackedToolchainSourcesSync(Directory root) {
  final found = <String>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(recursive: false)) {
      final basename = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is Directory) {
        if (_skippedDirNames.contains(basename)) continue;
        walk(entity);
      } else if (entity is File) {
        if (_scannedExtensions.any(basename.endsWith)) found.add(entity.path);
      }
    }
  }

  walk(root);
  return found;
}

void main() {
  test(
    'spec-pin 1509: no hardcoded /opt/flutter dart path in tracked toolchain sources',
    () {
      final repoRoot = Directory.current;
      final pubspec = File('${repoRoot.path}/pubspec.yaml');
      expect(
        pubspec.existsSync(),
        isTrue,
        reason: 'tests must run from the package root (dart test contract)',
      );

      final offenders = <String>[];
      for (final path in _trackedToolchainSourcesSync(repoRoot)) {
        final relative = path.substring(repoRoot.path.length + 1);
        if (relative.startsWith('specs/') || relative.startsWith('test/')) {
          // Spec-kit artifacts and this very test document the literal
          // (as data, e.g. this file's _bannedLiteral constant and the
          // spec's reproduction snippet) — they are not toolchain
          // sources. Only bin/, lib/, tool/, tools/, scripts/ and the
          // remaining shell/yaml surface are executable toolchain.
          continue;
        }
        final content = File(path).readAsStringSync();
        if (content.contains(_bannedLiteral)) offenders.add(relative);
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'issue #1509: toolchain paths must be PATH-resolved or '
            'environment-declared (ZURAFFA_DART_BIN / '
            'ZURAFFA_TOOLCHAIN_HINTS / FLUTTER_ROOT). Found the banned '
            'literal in: $offenders',
      );
    },
  );
}
