/// Issue #1322 — phase-0 preflight: ensure the builder package is in the
/// dependency graph BEFORE the entity and build.yaml are written; the
/// #276 safety net names the missing package instead of blaming globs.
///
/// In a clean Dart package where `zorphy_annotation` is a direct
/// dependency but the `zorphy` builder package is NOT in the dependency
/// graph (not even transitively), `zfa tdd run` phase-0 used to scaffold
/// the entity + build.yaml, run the build, watch build_runner warn
/// `Ignoring options for unknown builder zorphy:zorphy`, silently
/// generate nothing — and then the zuraffa#276 safety net misdiagnosed
/// the 0-outputs state as a `generate_for` GLOB problem. One missing dev
/// dependency dead-ended the whole feature under three different outcome
/// labels (`runner-error`, `green-with-failed-build`,
/// `generation-error`), none naming the dependency.
///
/// This module is the shared remediation every call site routes through:
///
/// - [BuilderDependencyPreflight.missingBuilderPackages] is the ONE
///   classifier: the effective builder set (the project's `build.yaml`
///   UNION the canonical scaffold content) vs the dependency-graph truth
///   store (`.dart_tool/package_config.json`), corroborated by
///   build_runner's unknown-builder signal in the captured build output.
/// - [BuilderDependencyPreflight.ensureBuilderDependencies] is the AC-1
///   phase-0 preflight: auto `dart pub add --dev <pkg>` (Flutter
///   projects: `flutter pub add --dev <pkg>`), blocking when the add
///   fails. Process spawning is injectable (the doctor_checks.dart
///   `ZfaProcessRunner` / #1265 `PubspecProcessRunner` convention) so
///   tests stay hermetic — a separate spawner from
///   `PubspecAutoAdd.add`, because that module adds REGULAR dependencies
///   and builders must land in `dev_dependencies`.
/// - [BuilderDependencyPreflight.missingBuilderDependencyLines] renders
///   the missing-dependency message: names the package, quotes the
///   build_runner signal, prescribes the exact fix — never the glob
///   remedy.
///
/// Generic, never hardcoded zorphy: every builder registered in
/// build.yaml is checked the same way, and each missing package is named
/// with its own remedy. An ABSENT `.dart_tool/package_config.json` is an
/// UNVERIFIABLE state — the diagnosis never fires there (no false
/// positives on projects that simply have not run `pub get` yet;
/// build_runner's own "run pub get" error is accurate in that state).
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dependency_wirer.dart';
import 'pubspec_auto_add.dart' show PubspecProcessRunner;

/// One builder registration discovered in build.yaml: the build_runner
/// key (`zorphy:zorphy`, `some_pkg|its_builder`, or a bare
/// `json_serializable`) and the PACKAGE the key resolves to.
class RegisteredBuilder {
  const RegisteredBuilder({required this.package, required this.key});

  /// The package that must be resolvable for the builder to load.
  final String package;

  /// The build.yaml builder key verbatim.
  final String key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisteredBuilder &&
          other.package == package &&
          other.key == key;

  @override
  int get hashCode => Object.hash(package, key);

  @override
  String toString() => key;
}

/// Outcome of the [BuilderDependencyPreflight.ensureBuilderDependencies]
/// preflight (issue #1322 AC-1).
class BuilderPreflightResult {
  const BuilderPreflightResult({
    required this.missing,
    required this.added,
    required this.failed,
    this.dryRun = false,
    this.commandLine,
  });

  /// The builder registrations whose packages were missing from the
  /// dependency graph.
  final List<RegisteredBuilder> missing;

  /// Packages whose `pub add --dev` succeeded.
  final List<String> added;

  /// Packages whose `pub add --dev` did not succeed — the caller MUST
  /// refuse as a blocking step for these.
  final List<String> failed;

  /// True when the preflight only reported (no spawn, no writes).
  final bool dryRun;

  /// The exact command run (or would run), e.g.
  /// `dart pub add --dev zorphy`.
  final String? commandLine;

  /// Nothing was missing — a no-op preflight.
  bool get isNoOp => missing.isEmpty;

  /// At least one missing package could not be added automatically —
  /// a blocking failure.
  bool get blocked => failed.isNotEmpty;
}

/// The phase-0 builder-dependency preflight and the shared
/// missing-builder-dependency classifier (issue #1322).
class BuilderDependencyPreflight {
  /// The build_runner signal quoting a registered builder whose package
  /// is not loaded. Corroborating evidence for the static check — the
  /// same warning also fires for a builder-NAME typo inside a resolvable
  /// package, so it never fires the diagnosis alone.
  static const String unknownBuilderSignal =
      'Ignoring options for unknown builder';

  /// The marker the #276 safety net prints when it fails the build for
  /// the missing-builder-dependency class (see
  /// [missingBuilderDependencyLines]). A child `zfa build` that failed
  /// through the safety net carries this marker in its captured output —
  /// the parent driver/make reads it as failure-linked evidence.
  static const String missingBuilderMarker = 'NOT in the dependency graph';

  // -------------------------------------------------------------------
  // Parsing
  // -------------------------------------------------------------------

  /// Parses the builder registrations from [contents] (build.yaml).
  ///
  /// YAML-parse first (the `yaml` package is a direct dependency) and
  /// walk every target's `builders:` map. A key containing `:` or `|`
  /// (`zorphy:zorphy`) resolves to `package:builder`; a bare key
  /// (`json_serializable`) is its own package. Falls back to a
  /// package-qualified-key regex when the content does not parse —
  /// fail-open: unparseable content yields an empty set, never a crash,
  /// and the #276 pre-flight guard still catches unregistered builders.
  static List<RegisteredBuilder> registeredBuilders(String contents) {
    if (contents.trim().isEmpty) return const [];
    final found = <RegisteredBuilder>{};
    try {
      final doc = loadYaml(contents);
      if (doc is YamlMap) {
        final targets = doc['targets'];
        if (targets is YamlMap) {
          for (final target in targets.values) {
            if (target is! YamlMap) continue;
            final builders = target['builders'];
            if (builders is! YamlMap) continue;
            for (final key in builders.keys) {
              final builder = _fromKey(key.toString());
              if (builder != null) found.add(builder);
            }
          }
        }
      }
    } catch (_) {
      found.clear();
      // Fallback: package-qualified keys at line starts
      // (`zorphy:zorphy:` / `some_pkg|its_builder:`).
      final re = RegExp(
        r'^\s*([A-Za-z_][A-Za-z0-9_]*)([:|])([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$',
        multiLine: true,
      );
      for (final match in re.allMatches(contents)) {
        found.add(
          RegisteredBuilder(
            package: match.group(1)!,
            key: '${match.group(1)}${match.group(2)}${match.group(3)}',
          ),
        );
      }
    }
    return found.toList();
  }

  /// Builds a [RegisteredBuilder] from one build.yaml builder key, or
  /// null when the key cannot name a package confidently (fail-open).
  static RegisteredBuilder? _fromKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    final sep = trimmed.indexOf(RegExp(r'[:|]'));
    if (sep > 0) {
      return RegisteredBuilder(
        package: trimmed.substring(0, sep),
        key: trimmed,
      );
    }
    // A bare key is its own package when identifier-shaped. Anything
    // else (a stray `$default`, a comment fragment) is skipped.
    if (RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(trimmed)) {
      return RegisteredBuilder(package: trimmed, key: trimmed);
    }
    return null;
  }

  /// Extracts the builder keys build_runner reported as unknown from
  /// [buildOutput] (`Ignoring options for unknown builder "zorphy:zorphy"`).
  /// Only package-qualified keys are extracted — a bare-word match could
  /// capture the next word of a sentence.
  static List<RegisteredBuilder> unknownBuildersFromOutput(String buildOutput) {
    if (buildOutput.isEmpty) return const [];
    final re = RegExp(
      r'Ignoring options for unknown builder\s+"?([A-Za-z_][A-Za-z0-9_]*)([:|])([A-Za-z_][A-Za-z0-9_]*)"?',
    );
    final found = <RegisteredBuilder>{};
    for (final match in re.allMatches(buildOutput)) {
      found.add(
        RegisteredBuilder(
          package: match.group(1)!,
          key: '${match.group(1)}${match.group(2)}${match.group(3)}',
        ),
      );
    }
    return found.toList();
  }

  // -------------------------------------------------------------------
  // The dependency-graph truth store
  // -------------------------------------------------------------------

  /// The package names resolvable in `<projectRoot>/.dart_tool/
  /// package_config.json`, or `null` when the file is ABSENT — the
  /// unverifiable state (the project has not been pub-resolved).
  static Set<String>? tryResolvablePackages(String projectRoot) {
    final file = File(p.join(projectRoot, '.dart_tool', 'package_config.json'));
    if (!file.existsSync()) return null;
    try {
      final doc = loadYaml(file.readAsStringSync());
      if (doc is! YamlMap) return const {};
      final packages = doc['packages'];
      if (packages is! YamlList) return const {};
      return {
        for (final entry in packages)
          if (entry is YamlMap && entry['name'] != null)
            entry['name'].toString(),
      };
    } catch (_) {
      // An unreadable/unparseable config is the unverifiable state too:
      // never diagnose from a store we could not read.
      return null;
    }
  }

  /// The effective builder set for [projectRoot]: the builders registered
  /// in the project's `build.yaml` when that file exists (the project's
  /// own registration governs its build), or — when the file is missing —
  /// the canonical builder set `DependencyWirer.buildYamlContent`
  /// scaffolds. Phase-0's `zfa build` step scaffolds exactly that file,
  /// so its builders must be ensured BEFORE the entity is written (AC-1).
  static List<RegisteredBuilder> effectiveBuilders(String projectRoot) {
    final file = File(p.join(projectRoot, 'build.yaml'));
    if (file.existsSync()) {
      try {
        return registeredBuilders(file.readAsStringSync());
      } catch (_) {
        // Unreadable build.yaml: fall through to the canonical set —
        // the same content `zfa build` would scaffold next run.
      }
    }
    return registeredBuilders(DependencyWirer.buildYamlContent);
  }

  // -------------------------------------------------------------------
  // The classifier (one implementation, every call site)
  // -------------------------------------------------------------------

  /// The missing-builder-dependency diagnosis (issue #1322): the
  /// effective builder set vs the dependency graph, corroborated by the
  /// build_runner unknown-builder signal in [buildOutput].
  ///
  /// Empty when nothing is missing — INCLUDING when
  /// `.dart_tool/package_config.json` is absent (unverifiable state:
  /// never a false diagnosis) and when the signal alone fires for a
  /// package that IS resolvable (the builder-name-typo class keeps the
  /// generic remedy).
  static List<RegisteredBuilder> missingBuilderPackages({
    String? projectRoot,
    String? buildOutput,
  }) {
    final root = projectRoot ?? Directory.current.path;
    final resolvable = tryResolvablePackages(root);
    if (resolvable == null) return const [];
    final missing = <RegisteredBuilder>{};
    for (final builder in effectiveBuilders(root)) {
      if (!resolvable.contains(builder.package)) missing.add(builder);
    }
    for (final builder in unknownBuildersFromOutput(buildOutput ?? '')) {
      if (!resolvable.contains(builder.package)) missing.add(builder);
    }
    final list = missing.toList();
    list.sort((a, b) => a.key.compareTo(b.key));
    return list;
  }

  /// The FAILED-BUILD classifier (issue #1322 AC-3): which builder
  /// packages a failed `zfa build` invocation can be attributed to.
  ///
  /// Unlike [missingBuilderPackages] (the safety-net diagnosis for the
  /// exited-0-but-wrote-0-outputs state, where the static check alone is
  /// authoritative), a NON-ZERO build exit can have many causes — a user
  /// compile error, an analyze failure. The failure is attributed to the
  /// missing dependency only when the captured output links the failure
  /// to the builder: build_runner's unknown-builder signal, or the #276
  /// safety-net marker (the child `zfa build` failing through
  /// [missingBuilderDependencyLines]). The static check still drives
  /// WHAT is named, so the typo class (builder name unknown inside a
  /// resolvable package) can never be diagnosed as a missing dependency.
  static List<RegisteredBuilder> missingBuildersForFailedBuild({
    String? projectRoot,
    String? buildOutput,
  }) {
    final output = buildOutput ?? '';
    if (output.isEmpty) return const [];
    final linksFailureToBuilder =
        unknownBuildersFromOutput(output).isNotEmpty ||
        output.contains(missingBuilderMarker);
    if (!linksFailureToBuilder) return const [];
    return missingBuilderPackages(
      projectRoot: projectRoot,
      buildOutput: output,
    );
  }

  // -------------------------------------------------------------------
  // The message contract (AC-2)
  // -------------------------------------------------------------------

  /// The missing-builder-dependency message lines: names the package,
  /// quotes the build_runner signal, prescribes the exact fix. The glob
  /// remedy is deliberately absent — this class is a missing DEPENDENCY,
  /// not a `generate_for` problem.
  static List<String> missingBuilderDependencyLines({
    required List<RegisteredBuilder> missing,
    String? buildOutput,
  }) {
    if (missing.isEmpty) return const [];
    final packages = missing.map((b) => b.package).toList()..sort();
    final keys = missing.map((b) => b.key).toList()..sort();
    final signal = unknownBuildersFromOutput(buildOutput ?? '');
    return [
      '❌ build_runner wrote 0 outputs although @Zorphy sources exist.',
      '',
      '   The builder package(s) ${packages.join(", ")} '
          '(registered in build.yaml as ${keys.join(", ")}) are NOT in the '
          'dependency graph — missing from .dart_tool/package_config.json — '
          'so build_runner ignored the builder and silently generated '
          'nothing. This is a MISSING DEPENDENCY, not a glob problem.',
      if (signal.isNotEmpty)
        '   build_runner signal: "$unknownBuilderSignal '
            '${signal.first.key}".',
      '',
      '   --> fix: `${pubAddDevCommand(packages)}` (then re-run `zfa build`)',
    ];
  }

  /// The exact fix command for [packages]:
  /// `dart pub add --dev zorphy` (space-joined for multiple packages).
  static String pubAddDevCommand(Iterable<String> packages) =>
      'dart pub add --dev ${packages.join(' ')}';

  /// The one-line stop message for the driver / make labeling (AC-3):
  /// names the missing package(s) and prescribes the exact fix.
  static String missingBuilderStopMessage({
    required List<RegisteredBuilder> missing,
    String context = '`zfa build`',
  }) {
    final packages = missing.map((b) => b.package).toList()..sort();
    return '$context failed because the builder package(s) '
        '${packages.join(", ")} are not in the dependency graph '
        '(.dart_tool/package_config.json) — fix: '
        '`dart pub add --dev ${packages.join(" ")}` (issue #1322).';
  }

  // -------------------------------------------------------------------
  // The AC-1 preflight (auto-add before the entity is written)
  // -------------------------------------------------------------------

  /// Ensures every builder package of the effective set is resolvable in
  /// [projectRoot] BEFORE the entity + build.yaml are written (issue
  /// #1322 AC-1). Missing packages are auto-added as dev dependencies
  /// with one `dart pub add --dev <pkgs>` spawn (`flutter pub add --dev`
  /// for Flutter projects — the standalone `dart` executable cannot
  /// resolve `sdk: flutter` graphs, the DependencyWirer convention).
  ///
  /// - No-op when nothing is missing (and when the project is not yet
  ///   pub-resolved — the unverifiable state never mutates anything).
  /// - [dryRun] reports the would-add without spawning or writing.
  /// - [runner] is the hermetic test seam; the default spawner captures
  ///   the pub output with the doctor-fix timeout convention.
  ///
  /// Failures are reported in [BuilderPreflightResult.failed] (blocking),
  /// never thrown.
  static Future<BuilderPreflightResult> ensureBuilderDependencies({
    String? projectRoot,
    bool dryRun = false,
    PubspecProcessRunner? runner,
  }) async {
    final root = projectRoot ?? Directory.current.path;
    final missing = missingBuilderPackages(projectRoot: root);
    if (missing.isEmpty) {
      return const BuilderPreflightResult(missing: [], added: [], failed: []);
    }
    final packages = missing.map((b) => b.package).toSet().toList()..sort();
    final executable = _isFlutterProject(root) ? 'flutter' : 'dart';
    final args = ['pub', 'add', '--dev', ...packages];
    final commandLine = '$executable ${args.join(' ')}';
    if (dryRun) {
      return BuilderPreflightResult(
        missing: missing,
        added: const [],
        failed: const [],
        dryRun: true,
        commandLine: commandLine,
      );
    }
    try {
      final result = await (runner ?? _defaultProcessRunner)(
        executable,
        args,
        root,
      );
      if (result.exitCode == 0) {
        return BuilderPreflightResult(
          missing: missing,
          added: packages,
          failed: const [],
          commandLine: commandLine,
        );
      }
    } catch (_) {
      // Missing executable / spawn failure — degrade to the blocking
      // prescription below.
    }
    return BuilderPreflightResult(
      missing: missing,
      added: const [],
      failed: packages,
      commandLine: commandLine,
    );
  }

  /// True when the project's pubspec declares a Flutter SDK dependency
  /// (`sdk: flutter`) — those graphs must be pub-resolved by the
  /// `flutter` executable.
  static bool _isFlutterProject(String projectRoot) {
    try {
      final file = File(p.join(projectRoot, 'pubspec.yaml'));
      if (!file.existsSync()) return false;
      return RegExp(r'sdk:\s*flutter\b').hasMatch(file.readAsStringSync());
    } catch (_) {
      return false;
    }
  }

  /// The default spawner with the same generous timeout convention as the
  /// doctor fixes (a network-resolving `pub add`).
  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
    );
    final stdout = process.stdout.transform(systemEncoding.decoder).join();
    final stderr = process.stderr.transform(systemEncoding.decoder).join();
    try {
      final completed = await Future.wait<Object>([
        process.exitCode,
        stdout,
        stderr,
      ]).timeout(const Duration(minutes: 10));
      return ProcessResult(
        process.pid,
        completed[0] as int,
        completed[1] as String,
        completed[2] as String,
      );
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      rethrow;
    }
  }
}
