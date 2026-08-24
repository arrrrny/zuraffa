import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// `zfa package ...` — diagnose a Dart/Flutter package's Zuraffa
/// compatibility and emit actionable next-step guidance.
///
/// Issue #477 reports a misfire: an agent was told to "rewrite the
/// zikzak_inappwebview Flutter plugin using only `zfa`, no hand-written
/// code" and `zfa` silently misfired — there was no `zfa` command that
/// could diagnose "this is a non-Zuraffa Flutter plugin package; here
/// is what zfa can and cannot do with it". The agent had to discover
/// the limitation by running `zfa doctor` (which only says "Zuraffa
/// package not found in pubspec.yaml") and then guessing.
///
/// `zfa package analyze` closes that gap by:
///   1. Reading the package's `pubspec.yaml` (or reporting "no pubspec")
///   2. Detecting the package flavor
///      (Flutter app / Flutter plugin / pure-Dart package / non-Dart)
///   3. Detecting zuraffa + zorphy_annotation presence
///   4. Detecting the canonical Zuraffa lib/src/domain/entities layout
///   5. Emitting a structured verdict + concrete next-step commands
///
/// The command is **read-only** — it never writes files. To actually
/// wire Zuraffa into a compatible package, use `zfa initialize`
/// (in-place dep wiring) or `zfa setup <name>` (new app from scratch).
class PackageCommand extends Command<void> {
  @override
  String get name => 'package';

  @override
  String get description =>
      'Diagnose a Dart/Flutter package for Zuraffa compatibility and '
      'emit actionable next-step guidance. See `zfa package analyze`.';

  PackageCommand() {
    addSubcommand(_PackageAnalyzeCommand());
  }

  @override
  Future<void> run() async {
    print(usage);
    print('');
    print('Subcommands:');
    for (final sc in subcommands.values) {
      print('  ${sc.name.padRight(10)}  ${sc.description}');
    }
  }
}

class _PackageAnalyzeCommand extends Command<void> {
  @override
  String get name => 'analyze';

  @override
  String get description =>
      'Diagnose the current (or --root) Dart/Flutter package for Zuraffa '
      'compatibility and print actionable next steps. Read-only.';

  @override
  String get invocation => 'zfa package analyze [--root <path>] [--json]';

  _PackageAnalyzeCommand() {
    argParser.addOption(
      'root',
      valueHelp: '/path/to/pkg',
      help: 'Project root to analyze (default: current directory).',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Emit the report as a JSON object (for programmatic consumers).',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Verbose output (include all detected fields).',
    );
  }

  @override
  Future<void> run() async {
    final root = argResults?['root'] as String? ?? Directory.current.path;
    final asJson = argResults?['json'] == true;
    final verbose = argResults?['verbose'] == true;

    final report = PackageAnalysis.reportFor(root);
    if (asJson) {
      print(report.toJson(verbose: verbose));
    } else {
      print(report.toHumanReadable(verbose: verbose));
    }
  }
}

/// Result of analyzing a package for Zuraffa compatibility.
class PackageAnalysis {
  /// Absolute path that was analyzed.
  final String rootPath;

  /// `true` if a `pubspec.yaml` was found at the root.
  final bool hasPubspec;

  /// Parsed pubspec document (null when [hasPubspec] is false).
  final YamlMap? pubspec;

  /// Detected package flavor.
  final PackageFlavor flavor;

  /// `true` if `zuraffa:` appears as a direct dependency or dev_dependency.
  final bool hasZuraffa;

  /// `true` if `zorphy_annotation:` appears as a direct dependency.
  final bool hasZorphyAnnotation;

  /// `true` if `lib/src/domain/entities/` exists at the root.
  final bool hasZuraffaLayout;

  /// `true` if `.zfa.json` exists at the root.
  final bool hasZfaConfig;

  /// `true` if `lib/src/` exists (any Zuraffa-style src tree).
  final bool hasLibSrc;

  /// Detected package name (from pubspec `name:`), or `'<unknown>'`.
  final String packageName;

  /// Detected package version (from pubspec `version:`), or `'<unknown>'`.
  final String packageVersion;

  const PackageAnalysis({
    required this.rootPath,
    required this.hasPubspec,
    required this.pubspec,
    required this.flavor,
    required this.hasZuraffa,
    required this.hasZorphyAnnotation,
    required this.hasZuraffaLayout,
    required this.hasZfaConfig,
    required this.hasLibSrc,
    required this.packageName,
    required this.packageVersion,
  });

  /// Run the analysis against [rootPath] and return the result.
  static PackageAnalysis reportFor(String rootPath) {
    final absRoot = Directory(rootPath).absolute.path;
    final pubspecFile = File(p.join(absRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return PackageAnalysis(
        rootPath: absRoot,
        hasPubspec: false,
        pubspec: null,
        flavor: PackageFlavor.nonDart,
        hasZuraffa: false,
        hasZorphyAnnotation: false,
        hasZuraffaLayout: false,
        hasZfaConfig: false,
        hasLibSrc: false,
        packageName: '<unknown>',
        packageVersion: '<unknown>',
      );
    }

    final YamlMap pubspec;
    try {
      final loaded = loadYaml(pubspecFile.readAsStringSync());
      pubspec = loaded is YamlMap ? loaded : YamlMap();
    } catch (_) {
      return PackageAnalysis(
        rootPath: absRoot,
        hasPubspec: true,
        pubspec: null,
        flavor: PackageFlavor.brokenPubspec,
        hasZuraffa: false,
        hasZorphyAnnotation: false,
        hasZuraffaLayout: false,
        hasZfaConfig: false,
        hasLibSrc: false,
        packageName: '<unknown>',
        packageVersion: '<unknown>',
      );
    }

    final name = pubspec['name']?.toString() ?? '<unknown>';
    final version = pubspec['version']?.toString() ?? '<unknown>';

    // Detect flavor: Flutter plugin > Flutter app/package > pure-Dart.
    final flutterSection = pubspec['flutter'];
    final isFlutter = flutterSection is YamlMap;
    final isFlutterPlugin = isFlutter &&
        flutterSection.containsKey('plugin') &&
        flutterSection['plugin'] is YamlMap;

    final flavor = !isFlutter
        ? PackageFlavor.pureDart
        : (isFlutterPlugin
            ? PackageFlavor.flutterPlugin
            : PackageFlavor.flutterApp);

    // Dependency scan. Pubspec can put them under `dependencies:` and/or
    // `dev_dependencies:`. We treat zuraffa as compat regardless of which
    // bucket; zorphy_annotation is normally a direct dep (runtime).
    bool depExists(String key) {
      for (final bucket in const ['dependencies', 'dev_dependencies']) {
        final v = pubspec[bucket];
        if (v is YamlMap && v.containsKey(key)) return true;
      }
      // Also check dependency_overrides (rare but possible).
      final overrides = pubspec['dependency_overrides'];
      if (overrides is YamlMap && overrides.containsKey(key)) return true;
      return false;
    }

    final hasZuraffa = depExists('zuraffa');
    final hasZorphyAnnotation = depExists('zorphy_annotation');

    final libSrc = Directory(p.join(absRoot, 'lib', 'src'));
    final entitiesDir =
        Directory(p.join(absRoot, 'lib', 'src', 'domain', 'entities'));
    final zfaConfig = File(p.join(absRoot, '.zfa.json'));

    return PackageAnalysis(
      rootPath: absRoot,
      hasPubspec: true,
      pubspec: pubspec,
      flavor: flavor,
      hasZuraffa: hasZuraffa,
      hasZorphyAnnotation: hasZorphyAnnotation,
      hasZuraffaLayout: entitiesDir.existsSync(),
      hasZfaConfig: zfaConfig.existsSync(),
      hasLibSrc: libSrc.existsSync(),
      packageName: name,
      packageVersion: version,
    );
  }

  /// Overall compatibility verdict.
  PackageVerdict get verdict {
    if (!hasPubspec) return PackageVerdict.noPubspec;
    if (flavor == PackageFlavor.brokenPubspec) {
      return PackageVerdict.brokenPubspec;
    }
    if (hasZuraffa && hasZorphyAnnotation && hasZuraffaLayout) {
      return PackageVerdict.zuraffaReady;
    }
    if (hasZuraffa || hasZorphyAnnotation || hasZuraffaLayout) {
      return PackageVerdict.partiallyZuraffa;
    }
    // Pure-Dart or Flutter package that has none of the markers.
    return PackageVerdict.notZuraffa;
  }

  /// Concrete next-step command lines an agent should run.
  List<String> get nextSteps {
    switch (verdict) {
      case PackageVerdict.noPubspec:
        return [
          'This directory has no pubspec.yaml. zfa cannot operate here.',
          'If you intend to start a new Zuraffa app, run:',
          '  zfa setup <name> --dart       # pure-Dart package',
          '  zfa setup <name>              # Flutter app (default)',
          'If you intended to operate on an existing package, cd into it first.',
        ];
      case PackageVerdict.brokenPubspec:
        return [
          'pubspec.yaml exists but could not be parsed as YAML. Fix the file first.',
          'Run: dart pub get    # to surface any errors from the Dart toolchain.',
        ];
      case PackageVerdict.zuraffaReady:
        return [
          'This package is already Zuraffa-ready. You can generate code:',
          '  zfa entity create -n <EntityName> --field "id:String"',
          '  zfa make --entity <EntityName> --preset full',
          '  zfa build    # run build_runner',
        ];
      case PackageVerdict.partiallyZuraffa:
        return [
          'This package is partially wired for Zuraffa. Complete the setup:',
          if (!hasZuraffa) ...[
            '  Wire the zuraffa dep:  zfa initialize --deps-only',
            '  (or manually: dart pub add zuraffa)',
          ],
          if (!hasZorphyAnnotation) ...[
            '  Add zorphy_annotation:  dart pub add zorphy_annotation',
          ],
          if (!hasZuraffaLayout) ...[
            '  Scaffold the domain layout:  zfa initialize (in-place)',
          ],
          'Then run:  zfa build   # build_runner',
        ];
      case PackageVerdict.notZuraffa:
        switch (flavor) {
          case PackageFlavor.flutterPlugin:
            return [
              'This is a Flutter plugin package, not a Zuraffa app.',
              'zfa is a clean-architecture generator for Zuraffa apps — '
              'it cannot rewrite an existing Flutter plugin.',
              'You have two reasonable paths:',
              '  A. Leave the plugin alone. If you need a Zuraffa app that '
              'uses this plugin, create one:',
              '     zfa setup <AppName>    # creates a new Zuraffa Flutter app',
              '     then add the plugin as a normal Flutter dep.',
              '  B. If you genuinely want to re-host the plugin under a '
              'Zuraffa structure (NOT a rewrite; only scaffolding alongside '
              'existing code):',
              '     zfa initialize --flutter --deps-only    # wire deps only',
              '     # then manually move your plugin code under lib/src/',
              'Do NOT expect zfa to refactor or rewrite the plugin sources.',
            ];
          case PackageFlavor.flutterApp:
            return [
              'This is a Flutter app that is not yet a Zuraffa app.',
              'To wire Zuraffa into this existing app (in-place):',
              '  zfa initialize --flutter      # wires zuraffa + zorphy_annotation',
              '  zfa build                     # build_runner',
              'To create a fresh Zuraffa Flutter app elsewhere:',
              '  zfa setup <NewAppName>',
            ];
          case PackageFlavor.pureDart:
            return [
              'This is a pure-Dart package that is not yet a Zuraffa package.',
              'To wire Zuraffa into this package (in-place, pure-Dart dep set):',
              '  zfa initialize --dart        # wires zuraffa (pure-Dart) + '
              'zorphy_annotation',
              '  zfa build                    # build_runner',
              'To scaffold a new Zuraffa pure-Dart package elsewhere:',
              '  zfa setup <NewPackageName> --dart',
              'Note: zfa cannot rewrite your existing Dart sources. It only '
              'adds the Zuraffa dependency set + scaffolds new entities/',
              'use cases/etc. alongside the existing code.',
            ];
          case PackageFlavor.nonDart:
            return [
              'This directory is not a Dart/Flutter package (no pubspec.yaml).',
              'To start a new Zuraffa app here:',
              '  zfa setup <name>             # Flutter app',
              '  zfa setup <name> --dart      # pure-Dart package',
            ];
          case PackageFlavor.brokenPubspec:
            return [
              'pubspec.yaml exists but could not be parsed as YAML.',
              'Fix the file, then re-run:  zfa package analyze',
            ];
        }
    }
  }

  String toHumanReadable({bool verbose = false}) {
    final b = StringBuffer();
    b.writeln('Zuraffa Package Analysis');
    b.writeln('  root:           $rootPath');
    if (!hasPubspec) {
      b.writeln('  pubspec:        not found');
      b.writeln('');
      b.writeln('Verdict: $verdictLabel');
      b.writeln('');
      for (final line in nextSteps) {
        b.writeln('  $line');
      }
      return b.toString().trimRight();
    }
    b.writeln('  pubspec:        found');
    b.writeln('  package:        $packageName ($packageVersion)');
    b.writeln('  flavor:         ${flavor.label}');
    b.writeln('  zuraffa dep:    ${hasZuraffa ? "yes" : "no"}');
    b.writeln('  zorphy_annot:   ${hasZorphyAnnotation ? "yes" : "no"}');
    b.writeln('  lib/src/:       ${hasLibSrc ? "yes" : "no"}');
    b.writeln('  lib/src/domain/');
    b.writeln('    entities/:    ${hasZuraffaLayout ? "yes" : "no"}');
    b.writeln('  .zfa.json:      ${hasZfaConfig ? "yes" : "no"}');
    if (verbose && pubspec != null) {
      final deps = pubspec!['dependencies'];
      if (deps is YamlMap) {
        b.writeln('  direct deps:');
        for (final entry in deps.entries) {
          b.writeln('    ${entry.key}: ${entry.value}');
        }
      }
    }
    b.writeln('');
    b.writeln('Verdict: $verdictLabel');
    b.writeln('');
    b.writeln('Next steps:');
    for (final line in nextSteps) {
      b.writeln('  $line');
    }
    return b.toString().trimRight();
  }

  String get verdictLabel {
    switch (verdict) {
      case PackageVerdict.noPubspec:
        return 'not a Dart/Flutter package (no pubspec.yaml)';
      case PackageVerdict.brokenPubspec:
        return 'pubspec.yaml is unreadable (broken YAML)';
      case PackageVerdict.zuraffaReady:
        return 'Zuraffa-ready (deps wired + layout present)';
      case PackageVerdict.partiallyZuraffa:
        return 'partially Zuraffa (some markers present, some missing)';
      case PackageVerdict.notZuraffa:
        return 'not a Zuraffa package';
    }
  }

  String toJson({bool verbose = false}) {
    final map = <String, dynamic>{
      'root': rootPath,
      'hasPubspec': hasPubspec,
      'package': packageName,
      'version': packageVersion,
      'flavor': flavor.name,
      'hasZuraffa': hasZuraffa,
      'hasZorphyAnnotation': hasZorphyAnnotation,
      'hasLibSrc': hasLibSrc,
      'hasZuraffaLayout': hasZuraffaLayout,
      'hasZfaConfig': hasZfaConfig,
      'verdict': verdict.name,
      'nextSteps': nextSteps,
    };
    if (verbose && pubspec != null) {
      map['pubspecDependencies'] = (pubspec!['dependencies'] is YamlMap
          ? (pubspec!['dependencies'] as YamlMap).keys.toList()
          : <String>[]);
    }
    // JSON via jsonEncode — but no JSON import in this file by design
    // (callers can use dart:convert on the returned string only when
    // they're prepared to handle the encoding themselves).
    return _encodeJson(map);
  }
}

/// High-level package flavor.
enum PackageFlavor {
  /// Pure-Dart package (no `flutter:` section in pubspec).
  pureDart('pure-Dart package'),

  /// Flutter app or Flutter package (has `flutter:` section, no plugin).
  flutterApp('Flutter app/package'),

  /// Flutter plugin (has `flutter.plugin` section).
  flutterPlugin('Flutter plugin'),

  /// No pubspec.yaml found — not a Dart package at all.
  nonDart('not a Dart/Flutter package'),

  /// pubspec.yaml exists but is not parseable YAML.
  brokenPubspec('broken pubspec.yaml');

  final String label;
  const PackageFlavor(this.label);
}

/// Overall verdict on the package's Zuraffa compatibility.
enum PackageVerdict {
  noPubspec,
  brokenPubspec,
  zuraffaReady,
  partiallyZuraffa,
  notZuraffa,
}

// Minimal hand-rolled JSON encoder to avoid pulling dart:convert into a
// file that doesn't otherwise need it. (Keeps the dependency surface of
// this command to just `package:yaml` which is already a project dep.)
String _encodeJson(Map<String, dynamic> map) {
  final pairs = <String>[];
  for (final entry in map.entries) {
    pairs.add('${_encodeJsonString(entry.key)}:'
        ' ${_encodeJsonValue(entry.value)}');
  }
  return '{${pairs.join(',')}}';
}

String _encodeJsonValue(dynamic v) {
  if (v == null) return 'null';
  if (v is bool) return v.toString();
  if (v is num) return v.toString();
  if (v is String) return _encodeJsonString(v);
  if (v is List) {
    return '[${v.map(_encodeJsonValue).join(',')}]';
  }
  if (v is Map<String, dynamic>) return _encodeJson(v);
  return _encodeJsonString(v.toString());
}

String _encodeJsonString(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}
