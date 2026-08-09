import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Kind of dependency entry in pubspec.yaml.
enum DependencyKind { regular, dev, override }

/// Describes a zuraffa dependency to be wired into a project's pubspec.yaml.
class DependencySpec {
  final String name;
  final DependencyKind kind;

  /// Git source (when the dependency is fetched from git rather than pub.dev).
  final String? gitUrl;
  final String? gitPath;
  final String? gitRef;

  /// Concrete version for [DependencyKind.override] entries
  /// (e.g. `14.1.0` for the analyzer override).
  final String? version;

  const DependencySpec({
    required this.name,
    required this.kind,
    this.gitUrl,
    this.gitPath,
    this.gitRef,
    this.version,
  });

  bool get isGit => gitUrl != null;
  bool get isOverride => kind == DependencyKind.override;

  @override
  String toString() {
    switch (kind) {
      case DependencyKind.regular:
        return isGit ? '$name (git)' : name;
      case DependencyKind.dev:
        return 'dev:$name';
      case DependencyKind.override:
        return 'override:$name=${version ?? "?"}';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencySpec &&
          name == other.name &&
          kind == other.kind &&
          gitUrl == other.gitUrl &&
          gitPath == other.gitPath &&
          gitRef == other.gitRef &&
          version == other.version;

  @override
  int get hashCode =>
      Object.hash(name, kind, gitUrl, gitPath, gitRef, version);
}

/// Result of wiring dependencies into a project.
class WireResult {
  /// Names of dependencies that were successfully added.
  final List<String> added;

  /// Names of dependencies that were already present (skipped).
  final List<String> skipped;

  /// Names of dependencies that could not be added.
  final List<String> failed;

  /// Whether this was a dry run (no writes).
  final bool dryRun;

  const WireResult({
    this.added = const [],
    this.skipped = const [],
    this.failed = const [],
    this.dryRun = false,
  });

  bool get isSuccess => failed.isEmpty;
  bool get didNothing => added.isEmpty && skipped.isNotEmpty;
}

/// Wires the standard zuraffa dependency set into a project's pubspec.yaml.
///
/// Used by both `zfa setup` (new app bootstrap) and `zfa init` (existing
/// project dependency wiring) so the two commands stay in sync.
class DependencyWirer {
  /// Git source for the zuraffa monorepo (contains both `zuraffa` at the root
  /// and `zuraffa_flutter` as a sub-package).
  static const zuraffaGitUrl = 'https://github.com/arrrrny/zuraffa';

  /// Git source for the zorphy monorepo (contains `zorphy` and
  /// `zorphy_annotation` sub-packages). Must match the exact URL string used
  /// by the zuraffa root pubspec (https://github.com/arrrrny/zorphy.git):
  /// pub treats git sources as identical only when the URL string matches
  /// verbatim, and a `.git`-vs-bare mismatch breaks version solving when
  /// `zuraffa_flutter` pulls `zuraffa` transitively.
  static const zorphyGitUrl = 'https://github.com/arrrrny/zorphy.git';

  /// Default git ref — tracks the development branch which is where active
  /// v6 work lands before merging to master.
  static const defaultGitRef = 'development';

  /// The analyzer version zuraffa pins in pure-Dart packages (see root
  /// pubspec.yaml). Overriding analyzer in downstream apps prevents
  /// version-conflict failures when `dart pub get` resolves the transitive
  /// graph.
  static const analyzerOverrideVersion = '14.1.0';

  /// Flutter apps cannot use the [analyzerOverrideVersion] override: the
  /// Flutter SDK pins `meta 1.18.0` while analyzer >=13.1.0 requires
  /// `meta ^1.18.3`, so version solving always fails. These match
  /// `zuraffa_flutter`'s own `dependency_overrides`
  /// (zuraffa_flutter/pubspec.yaml): analyzer is capped at ^13.1.0 and meta
  /// is overlaid with ^1.19.0 so the graph resolves under the Flutter SDK.
  static const flutterAnalyzerOverrideVersion = '^13.1.0';
  static const flutterMetaOverrideVersion = '^1.19.0';

  /// Returns the standard zuraffa dependency set for the given project type.
  ///
  /// [isFlutter] selects `zuraffa_flutter` + `flutter_lints` (Flutter apps)
  /// versus `zuraffa` (pure Dart packages), and picks the override set:
  /// Flutter apps get the analyzer + meta overrides that match
  /// `zuraffa_flutter`'s own pubspec, pure Dart packages pin analyzer
  /// directly. All other entries are shared.
  static List<DependencySpec> standardSet({required bool isFlutter}) {
    return [
      DependencySpec(
        name: isFlutter ? 'zuraffa_flutter' : 'zuraffa',
        kind: DependencyKind.regular,
        gitUrl: zuraffaGitUrl,
        gitPath: isFlutter ? 'zuraffa_flutter' : null,
        gitRef: defaultGitRef,
      ),
      DependencySpec(
        name: 'zorphy_annotation',
        kind: DependencyKind.regular,
        gitUrl: zorphyGitUrl,
        gitPath: 'zorphy_annotation',
        gitRef: defaultGitRef,
      ),
      const DependencySpec(name: 'build_runner', kind: DependencyKind.dev),
      const DependencySpec(name: 'mocktail', kind: DependencyKind.dev),
      if (isFlutter)
        const DependencySpec(name: 'flutter_lints', kind: DependencyKind.dev),
      if (isFlutter) ...[
        const DependencySpec(
          name: 'analyzer',
          kind: DependencyKind.override,
          version: flutterAnalyzerOverrideVersion,
        ),
        const DependencySpec(
          name: 'meta',
          kind: DependencyKind.override,
          version: flutterMetaOverrideVersion,
        ),
      ] else
        const DependencySpec(
          name: 'analyzer',
          kind: DependencyKind.override,
          version: analyzerOverrideVersion,
        ),
    ];
  }

  /// Finds which dependencies from [standardSet] are missing from the given
  /// pubspec.yaml content.
  ///
  /// Pure function — no I/O. Callers can unit-test this directly.
  static List<DependencySpec> findMissing(
    String pubspecContent, {
    required bool isFlutter,
  }) {
    final specs = standardSet(isFlutter: isFlutter);
    final YamlMap pubspec;
    try {
      pubspec = loadYaml(pubspecContent) as YamlMap;
    } catch (_) {
      // Unparseable pubspec → treat everything as missing so wire() reports it.
      return specs;
    }

    final deps = (pubspec['dependencies'] as YamlMap?) ?? YamlMap();
    final devDeps = (pubspec['dev_dependencies'] as YamlMap?) ?? YamlMap();
    final overrides =
        (pubspec['dependency_overrides'] as YamlMap?) ?? YamlMap();

    return specs.where((spec) {
      switch (spec.kind) {
        case DependencyKind.regular:
          return !deps.containsKey(spec.name);
        case DependencyKind.dev:
          return !devDeps.containsKey(spec.name);
        case DependencyKind.override:
          if (!overrides.containsKey(spec.name)) {
            return true; // missing entirely
          }
          // Key exists: check if the value matches the required version.
          final existing = overrides[spec.name];
          final existingStr = (existing is String ? existing : existing.toString()).trim();
          final requiredStr = (spec.version ?? '').trim();
          return existingStr != requiredStr; // stale if different
      }
    }).toList();
  }

  /// Detects whether the given pubspec.yaml content declares a Flutter
  /// dependency (`flutter: sdk: flutter`).
  static bool isFlutterProject(String pubspecContent) {
    try {
      final pubspec = loadYaml(pubspecContent) as YamlMap;
      final deps = (pubspec['dependencies'] as YamlMap?) ?? YamlMap();
      return deps.containsKey('flutter');
    } catch (_) {
      return false;
    }
  }

  /// Adds a `dependency_overrides` entry to pubspec.yaml content.
  ///
  /// - If the `dependency_overrides:` section does not exist, it is appended.
  /// - If it exists but [key] is absent, the entry is inserted under it.
  /// - If [key] already exists with the same [value], the content is returned
  ///   unchanged (idempotent). If the existing value differs, it is replaced
  ///   in place.
  ///
  /// Pure function — does not perform I/O.
  static String addOverrideToPubspec(
    String content,
    String key,
    String value,
  ) {
    final lines = content.split('\n');
    final overrideRegex = RegExp(r'^dependency_overrides:\s*$');
    final overrideIdx = lines.indexWhere((l) => overrideRegex.hasMatch(l));

    if (overrideIdx == -1) {
      // Append a new dependency_overrides section.
      var result = content;
      if (!result.endsWith('\n')) {
        result = '$result\n';
      }
      // Ensure a blank line separates the new section from the previous one.
      if (!result.endsWith('\n\n')) {
        result = '$result\n';
      }
      // Header is written at column zero; no leading-space workaround needed.
      return '${result}dependency_overrides:\n  $key: $value\n';
    }

    // Walk the existing section looking for the key.
    final keyPrefix = '  $key:';
    for (var i = overrideIdx + 1; i < lines.length; i++) {
      final line = lines[i];
      // A non-indented, non-empty line means we hit the next top-level key.
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        break;
      }
      if (line.startsWith(keyPrefix)) {
        // Key exists: check if the value matches.
        final existingValue = line.substring(keyPrefix.length).trim();
        if (existingValue == value) {
          return content; // already has the correct value
        }
        // Value differs: replace the line.
        lines[i] = '  $key: $value';
        return lines.join('\n');
      }
    }

    // Insert immediately after the `dependency_overrides:` header.
    lines.insert(overrideIdx + 1, '  $key: $value');
    return lines.join('\n');
  }

  /// Wires missing zuraffa dependencies into the pubspec.yaml at [projectRoot].
  ///
  /// Uses `dart pub add` for regular/dev dependencies (preserves pubspec
  /// formatting and runs `pub get` atomically) and direct YAML editing for
  /// `dependency_overrides` entries (which `dart pub add` does not support).
  ///
  /// When [dryRun] is true, reports what would be added without writing.
  static Future<WireResult> wire({
    required bool isFlutter,
    bool dryRun = false,
    String? projectRoot,
  }) async {
    final root = projectRoot ?? Directory.current.path;
    final pubspecFile = File(path.join(root, 'pubspec.yaml'));

    if (!pubspecFile.existsSync()) {
      print('❌ No pubspec.yaml found in $root');
      print(
        '   Run `zfa setup <name>` to create a new app, or cd to a project root.',
      );
      return const WireResult(failed: ['pubspec.yaml not found']);
    }

    final content = pubspecFile.readAsStringSync();
    final missing = findMissing(content, isFlutter: isFlutter);
    // Names already present before wiring — reported as skipped so
    // `WireResult.didNothing` is accurate when everything was already wired.
    final skippedNames = standardSet(
      isFlutter: isFlutter,
    ).where((s) => !missing.contains(s)).map((s) => s.name).toList();

    if (missing.isEmpty) {
      print('✅ All zuraffa dependencies are already present.');
      return WireResult(skipped: skippedNames);
    }

    print('🔧 Wiring ${missing.length} missing dependenc${missing.length == 1 ? 'y' : 'ies'}:');
    for (final spec in missing) {
      print('   • $spec');
    }

    if (dryRun) {
      print('\n🔍 Dry-run: no changes written. Re-run without --dry-run to apply.');
      return WireResult(
        added: missing.map((s) => s.name).toList(),
        dryRun: true,
      );
    }

    final added = <String>[];
    final failed = <String>[];

    // Split: pub-addable (regular + dev) vs override (direct edit).
    final pubAddSpecs = missing
        .where((s) => s.kind != DependencyKind.override)
        .toList();
    final overrideSpecs = missing
        .where((s) => s.kind == DependencyKind.override)
        .toList();

    // --- dependency_overrides via direct pubspec edit ---
    // Written BEFORE `pub add` so the version resolution that command
    // triggers already sees the overrides. In Flutter apps the analyzer +
    // meta overrides are what make the transitive graph resolvable in the
    // first place, so they must be in the pubspec before anything resolves.
    if (overrideSpecs.isNotEmpty) {
      var newContent = pubspecFile.readAsStringSync();
      for (final spec in overrideSpecs) {
        newContent = addOverrideToPubspec(
          newContent,
          spec.name,
          spec.version ?? '',
        );
        print('   ✅ Added override:${spec.name}=${spec.version}');
      }
      try {
        await pubspecFile.writeAsString(newContent);
        // Record overrides as added only after the write succeeds.
        added.addAll(overrideSpecs.map((s) => s.name));
      } catch (e) {
        print(
          '   ⚠️  Failed to write dependency_overrides to pubspec.yaml: $e',
        );
        failed.addAll(overrideSpecs.map((s) => s.name));
      }
    }

    // --- regular / dev deps via `pub add` ---
    // Flutter projects must use `flutter pub add`/`flutter pub get`: the
    // standalone `dart` executable cannot resolve `sdk: flutter` deps.
    final pubExecutable = isFlutter ? 'flutter' : 'dart';
    for (final spec in pubAddSpecs) {
      final args = _buildPubAddArgs(spec);
      try {
        final result = await Process.run(
          pubExecutable,
          ['pub', 'add', ...args],
          workingDirectory: root,
        );
        if (result.exitCode == 0) {
          added.add(spec.name);
          print('   ✅ Added $spec');
        } else {
          final err = result.stderr.toString().trim();
          final out = result.stdout.toString().trim();
          print('   ⚠️  Failed to add $spec: ${err.isNotEmpty ? err : out}');
          failed.add(spec.name);
        }
      } catch (e) {
        print('   ⚠️  Failed to add $spec: $e');
        failed.add(spec.name);
      }
    }

    // --- final re-resolve so the whole graph is consistent ---
    if (overrideSpecs.isNotEmpty) {
      try {
        final getResult = await Process.run(
          pubExecutable,
          ['pub', 'get'],
          workingDirectory: root,
        );
        if (getResult.exitCode != 0) {
          final err = getResult.stderr.toString().trim();
          if (err.isNotEmpty) {
            print(
              '   ⚠️  $pubExecutable pub get reported issues after wiring '
              'overrides ${overrideSpecs.map((s) => '${s.name}=${s.version}').join(', ')}:',
            );
            print('      ${err.split('\n').take(3).join('\n      ')}');
          }
        }
      } catch (e) {
        // Non-fatal: overrides are written; user can resolve later.
        print(
          '   ⚠️  Could not run $pubExecutable pub get after override edit: $e',
        );
      }
    }

    return WireResult(added: added, skipped: skippedNames, failed: failed);
  }

  /// Builds the argument list for `dart pub add` from a [DependencySpec].
  static List<String> _buildPubAddArgs(DependencySpec spec) {
    final args = <String>[];
    if (spec.kind == DependencyKind.dev) {
      args.add('dev:${spec.name}');
    } else {
      args.add(spec.name);
    }
    if (spec.isGit) {
      args.add('--git-url=${spec.gitUrl}');
      if (spec.gitPath != null) {
        args.add('--git-path=${spec.gitPath}');
      }
      if (spec.gitRef != null) {
        args.add('--git-ref=${spec.gitRef}');
      }
    }
    return args;
  }

  /// The `build.yaml` content that registers the zorphy + json_serializable
  /// builders for the project. Used by `zfa setup` and `zfa init` to ensure
  /// `zfa build` (build_runner) picks up `@Zorphy` annotations.
  static const buildYamlContent = '''
targets:
  \$default:
    builders:
      zorphy:zorphy:
        enabled: true
        generate_for:
          - lib/src/**
          - test/**
      json_serializable:
        enabled: true
        generate_for:
          - lib/src/**
          - test/**
        options:
          explicit_to_json: false
          include_if_null: false
          generic_argument_factories: true
      source_gen:combining_builder:
        enabled: true
''';

  /// Standard domain/data directory structure created by `zfa setup` and
  /// `zfa init` so the generated code has a home.
  static const standardDirs = <String>[
    'lib/src/domain/entities',
    'lib/src/domain/repositories',
    'lib/src/domain/usecases',
    'lib/src/data/datasources',
    'lib/src/data/repositories',
  ];

  /// Ensures `build.yaml` and the standard domain/data directories exist in
  /// [projectRoot]. Skips entries that already exist. When [dryRun] is true,
  /// reports what would be created without writing.
  static Future<void> ensureProjectStructure({
    String? projectRoot,
    bool dryRun = false,
  }) async {
    final root = projectRoot ?? Directory.current.path;

    // build.yaml
    final buildYaml = File(path.join(root, 'build.yaml'));
    if (!buildYaml.existsSync()) {
      if (dryRun) {
        print('   Would create: ${path.join(root, 'build.yaml')}');
      } else {
        await buildYaml.writeAsString(buildYamlContent);
        print('   Created: build.yaml');
      }
    }

    // Domain/data directories
    for (final dir in standardDirs) {
      final full = path.join(root, dir);
      if (!Directory(full).existsSync()) {
        if (dryRun) {
          print('   Would create: $full');
        } else {
          await Directory(full).create(recursive: true);
        }
      }
    }
  }
}
