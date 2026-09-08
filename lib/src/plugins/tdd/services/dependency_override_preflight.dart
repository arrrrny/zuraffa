/// The dependency_overrides path preflight (issue #1303).
///
/// `tdd make` / `tdd run` spend minutes compiling before a stale
/// `dependency_overrides` path entry — `path: ../../zuraffa_flutter`
/// pointing at a directory without a `pubspec.yaml` — surfaces as a raw
/// exit-255 version-solving dump buried mid-log, and the "retry with
/// clean cache" fallback then burns a full rebuild on a resolution error
/// no cache clean can fix.
///
/// The preflight parses the project's `dependency_overrides` and, for
/// EVERY `path:` value, verifies that `<projectRoot>/<path>/pubspec.yaml`
/// exists. Each unresolvable path is one [OverridePathFinding]; the
/// caller refuses up front with the honest, machine-actionable verdict
/// (the `❌ preflight:` line + the `--> fix:` line, SPEC 917 drift class)
/// instead of letting the pipeline die mid-log.
///
/// Fail-open boundaries — the preflight's SINGLE contract is stale path
/// overrides; everything else fails honestly downstream:
///   - no pubspec.yaml at the project root, or an unparseable one →
///     vacuous pass (the pipeline's own pub get names the real problem
///     with the real message; this gate invents nothing);
///   - non-path overrides (version strings, `{sdk: flutter}` maps,
///     hosted/git source maps without a `path` key) → not this gate's
///     business, ignored.
///
/// Both pubspec shapes matter here: pub accepts a path override ONLY in
/// the map form (`pkg: {path: ../..}`) — a string override
/// (`analyzer: 14.1.0`) is a VERSION CONSTRAINT, never a path, so it is
/// not this gate's business. Validating the string form as a path would
/// false-positive every version pin and refuse healthy projects.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The machine-parseable remedy line (minus the command tail the caller
/// appends — `zfa tdd make` / `zfa tdd run`), shared by every command
/// that refuses on the preflight (issue #1303).
const String kOverrideFixLine =
    '--> fix: correct the override path or remove the entry from '
    'pubspec.yaml, then re-run';

/// One unresolvable `dependency_overrides` path entry.
class OverridePathFinding {
  /// The package name the override is declared for.
  final String package;

  /// The raw `path:` value exactly as written in pubspec.yaml.
  final String path;

  /// The absolute directory the path resolves to against the project
  /// root (normalized, `..` segments collapsed) — the location the gate
  /// actually checked.
  final String resolved;

  /// Why the path does not resolve to a package (the parenthetical of
  /// the rendered verdict line).
  final String detail;

  const OverridePathFinding({
    required this.package,
    required this.path,
    required this.resolved,
    required this.detail,
  });

  /// The honest single-line verdict (issue #1303 wording):
  /// `❌ preflight: dependency_overrides["p"] path "x" does not resolve
  /// to a package (no pubspec.yaml at /abs/target)`.
  String get line =>
      '❌ preflight: dependency_overrides["$package"] path "$path" '
      'does not resolve to a package ($detail)';
}

/// The gate verdict: `ok` when every declared path override resolves to
/// a package (or there are none to check — the vacuous pass).
class DependencyOverridePreflightReport {
  final bool ok;

  /// One finding per unresolvable path override, in declaration order.
  final List<OverridePathFinding> findings;

  /// How many path overrides were checked (the vacuous pass is 0).
  final int overridesChecked;

  const DependencyOverridePreflightReport({
    required this.ok,
    required this.findings,
    required this.overridesChecked,
  });
}

/// The preflight gate. Stateless per [projectRoot]; see the library doc
/// for the contract and the fail-open boundaries.
class DependencyOverridePreflight {
  DependencyOverridePreflight({required this.projectRoot});

  /// The project root whose `pubspec.yaml` is validated.
  final String projectRoot;

  /// The machine-parseable rendering of one finding for stdout.
  static String findingLine(OverridePathFinding finding) => finding.line;

  Future<DependencyOverridePreflightReport> check() async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      return const DependencyOverridePreflightReport(
        ok: true,
        findings: [],
        overridesChecked: 0,
      );
    }
    final YamlDocument document;
    try {
      document = loadYamlDocument(await pubspecFile.readAsString());
    } on YamlException {
      // Unparseable pubspec: not this gate's contract — pub get fails
      // with the authoritative message.
      return const DependencyOverridePreflightReport(
        ok: true,
        findings: [],
        overridesChecked: 0,
      );
    } on FileSystemException {
      // Unreadable pubspec (permission race between exists() and read):
      // fail open like the unparseable case — pub itself reports the
      // authoritative error.
      return const DependencyOverridePreflightReport(
        ok: true,
        findings: [],
        overridesChecked: 0,
      );
    }
    final pubspec = document.contents;
    if (pubspec is! YamlMap) {
      return const DependencyOverridePreflightReport(
        ok: true,
        findings: [],
        overridesChecked: 0,
      );
    }
    final overrides = pubspec['dependency_overrides'];
    if (overrides is! YamlMap || overrides.isEmpty) {
      return const DependencyOverridePreflightReport(
        ok: true,
        findings: [],
        overridesChecked: 0,
      );
    }

    final findings = <OverridePathFinding>[];
    var checked = 0;
    for (final entry in overrides.entries) {
      final package = entry.key;
      if (package is! String) continue; // not a decl this gate can name
      final pathValue = _pathValueOf(entry.value);
      if (pathValue == null) continue; // non-path override: ignored
      checked++;
      final resolvedDir = p.normalize(
        p.isAbsolute(pathValue) ? pathValue : p.join(projectRoot, pathValue),
      );
      final hasPubspec = File(p.join(resolvedDir, 'pubspec.yaml')).existsSync();
      if (!hasPubspec) {
        // One honest message for both failure shapes (the directory
        // itself missing, or a directory without a pubspec) — the issue
        // #1303 wording: the path does not resolve to a PACKAGE.
        findings.add(
          OverridePathFinding(
            package: package,
            path: pathValue,
            resolved: resolvedDir,
            detail: 'no pubspec.yaml at $resolvedDir',
          ),
        );
      }
    }
    return DependencyOverridePreflightReport(
      ok: findings.isEmpty,
      findings: findings,
      overridesChecked: checked,
    );
  }

  /// The `path:` value an override entry declares, or null when the
  /// entry declares no path. Pub's own grammar: a path override is the
  /// MAP form carrying a string `path` key. A plain STRING override is
  /// a version constraint (e.g. `analyzer: 14.1.0`) — never a path —
  /// and sdk/git/hosted maps carry no `path` key, so all of those are
  /// not this gate's business.
  String? _pathValueOf(Object? override) {
    if (override is YamlMap) {
      final path = override['path'];
      if (path is String) return path;
    }
    return null;
  }
}
