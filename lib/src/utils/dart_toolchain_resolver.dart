/// Dart toolchain resolution — PATH-first, environment-declared.
///
/// Spec 1509-toolchain-path-portable (issue #1509): toolchain commands
/// must use `dart` from `PATH` (or an environment-declared location)
/// rather than a hardcoded SDK install path — the documented
/// `/opt/flutter` toolchain layout — which does not exist in CI runners,
/// cloud agent sandboxes, or most local dev environments (exit 127 when
/// the binary is invoked at that literal location).
///
/// Environment contract (all optional):
/// - `ZURAFFA_DART_BIN` — absolute path to the dart executable; probed
///   before every other tier (operator pin).
/// - `ZURAFFA_TOOLCHAIN_HINTS` — platform-separated (`:` POSIX, `;`
///   Windows) list of SDK directories; each is probed as `<dir>/dart`
///   and `<dir>/bin/dart`. This is the portable replacement for any
///   hardcoded install location: an environment whose Flutter lives at
///   an unusual path declares it here (e.g. the documented environment
///   from issue #1509 works unchanged with
///   `ZURAFFA_TOOLCHAIN_HINTS=/opt/flutter`).
/// - `FLUTTER_ROOT` — exported by Flutter tooling; `$FLUTTER_ROOT/bin/dart`
///   is probed among the candidates.
///
/// Resolution order: pin → `PATH` (`which dart` / `where dart`) →
/// dart-next-to-`which flutter` (symlink-resolved sibling) →
/// candidate list. This mirrors the pre-1509 order; only the DERIVATION
/// of the candidates changed (environment-driven, never a literal
/// machine path).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves the `dart` executable without hardcoding any SDK location.
class DartToolchainResolver {
  /// Creates a resolver. Every dependency is injectable so each tier is
  /// testable without spawning processes; defaults wire the resolver to
  /// the real process environment and filesystem.
  DartToolchainResolver({
    Map<String, String>? environment,
    String? home,
    Future<List<String>> Function(String executable)? which,
    Future<bool> Function(String path)? fileExists,
    String Function(String path)? resolveSymlink,
  }) : _environment = environment ?? Platform.environment,
       _home = home ?? Platform.environment['HOME'],
       _which = which ?? _defaultWhich,
       _fileExists = fileExists ?? ((path) => File(path).exists()),
       _resolveSymlink =
           resolveSymlink ??
           ((path) {
             try {
               return File(path).resolveSymbolicLinksSync();
             } catch (_) {
               return path;
             }
           });

  final Map<String, String> _environment;
  final String? _home;
  final Future<List<String>> Function(String executable) _which;
  final Future<bool> Function(String path) _fileExists;
  final String Function(String path) _resolveSymlink;

  /// The environment-declared candidate directories, each probed as
  /// `<dir>/dart` and `<dir>/bin/dart`, in declared order.
  static List<String> _hintDirs(Map<String, String> environment) {
    final hints = environment['ZURAFFA_TOOLCHAIN_HINTS'];
    if (hints == null || hints.isEmpty) return const [];
    final separator = Platform.isWindows ? ';' : ':';
    return hints
        .split(separator)
        .map((dir) => dir.trim())
        .where((dir) => dir.isNotEmpty)
        .toList(growable: false);
  }

  /// The fallback candidate paths, in probe order, as a PURE function of
  /// the injected environment and home directory.
  ///
  /// Guarantees (FR-005 of spec 1509): no machine-specific absolute
  /// paths — every entry is either env-derived (`ZURAFFA_TOOLCHAIN_HINTS`,
  /// `FLUTTER_ROOT`, home-derived) or the neutral `/usr/local/flutter`
  /// generic hint. The banned literal from issue #1509 is never emitted.
  static List<String> candidatePaths({
    required Map<String, String> environment,
    required String? home,
  }) {
    final candidates = <String>[];
    for (final dir in _hintDirs(environment)) {
      candidates
        ..add(p.join(dir, 'dart'))
        ..add(p.join(dir, 'bin', 'dart'));
    }
    final flutterRoot = environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      candidates.add(p.join(flutterRoot, 'bin', 'dart'));
    }
    if (home != null && home.isNotEmpty) {
      candidates
        ..add(p.join(home, 'flutter', 'bin', 'dart'))
        ..add(p.join(home, 'development', 'flutter', 'bin', 'dart'));
    }
    // Neutral generic hint preserved from the pre-1509 candidate list
    // (not machine-specific, not user-derived).
    candidates.add('/usr/local/flutter/bin/dart');
    return candidates;
  }

  /// Resolves the dart executable, or `null` when every tier misses.
  ///
  /// Tiers: `ZURAFFA_DART_BIN` pin → `PATH` → flutter-adjacent sibling →
  /// [candidatePaths].
  Future<String?> resolve() async {
    // 0. Operator pin — declared executable wins over every tier.
    final pin = _environment['ZURAFFA_DART_BIN'];
    if (pin != null && pin.isNotEmpty && await _fileExists(pin)) return pin;

    // 1. dart on PATH (the portable default; issue #1509's environment
    //    class and the documented environment both satisfy this).
    final dartHits = await _which('dart');
    for (final hit in dartHits) {
      final trimmed = hit.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }

    // 2. dart next to the flutter binary (symlink-resolved sibling).
    final flutterHits = await _which('flutter');
    if (flutterHits.isNotEmpty) {
      final flutterPath = flutterHits.first.trim();
      if (flutterPath.isNotEmpty) {
        final resolved = _resolveSymlink(flutterPath);
        final dartPath = p.join(p.dirname(resolved), 'dart');
        if (await _fileExists(dartPath)) return dartPath;
      }
    }

    // 3. Environment-derived candidates (hints, FLUTTER_ROOT, HOME,
    //    generic) — probe in declared order, first existing wins.
    for (final candidate in candidatePaths(
      environment: _environment,
      home: _home,
    )) {
      if (await _fileExists(candidate)) return candidate;
    }

    return null;
  }

  /// The real PATH probe: `which` on POSIX, `where` on Windows, split
  /// into trimmed candidate paths (empty list = miss).
  static Future<List<String>> _defaultWhich(String executable) async {
    final probe = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(probe, [executable]);
      if (result.exitCode != 0) return const [];
      return result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
