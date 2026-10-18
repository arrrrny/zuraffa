import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../core/dependencies/dependency_wirer.dart';
import '../core/project/project_root.dart';

/// Outcome of inspecting a project's `build.yaml` from the build command.
enum BuildYamlStatus {
  /// No `build.yaml` exists at the project root. [BuildYamlGuard.scaffold]
  /// can create one that registers the zorphy builder.
  missing,

  /// A `build.yaml` exists but it does not register the `zorphy:zorphy`
  /// builder. build_runner will exit 0 having written 0 outputs, silently.
  /// The user must be told to add the zorphy builder registration.
  missingZorphyBuilder,

  /// A `build.yaml` exists, does not register the `zorphy:zorphy` builder,
  /// and the project provably does not use the zuraffa/zorphy
  /// code-generation pipeline — no `@Zorphy`-annotated source under `lib/`
  /// and no `zorphy` dependency declared in `pubspec.yaml`. There is nothing
  /// for the zorphy builder to generate, so the missing registration is not a
  /// misconfiguration and the build proceeds (issue #1709).
  notApplicable,

  /// A `build.yaml` exists and registers the `zorphy:zorphy` builder.
  ok,
}

/// Self-healing guard for `zfa build`.
///
/// Before delegating to `build_runner`, [BuildCommand] asks this guard whether
/// the project's `build.yaml` is in a state that will actually produce
/// `.zorphy.dart` / `.g.dart` outputs. When the file is missing, the build
/// command scaffolds it (reusing [DependencyWirer.buildYamlContent]); when the
/// file exists but omits the zorphy builder, the build command fails loudly
/// with an actionable error instead of silently reporting success with 0
/// outputs (zuraffa#276).
class BuildYamlGuard {
  /// The builder key that must appear in `build.yaml` for zorphy codegen to
  /// run. Matches `DependencyWirer.buildYamlContent`.
  static const String zorphyBuilderKey = 'zorphy:zorphy';

  /// Returns the current [BuildYamlStatus] for [projectRoot]
  /// (defaults to [Directory.current]).
  static BuildYamlStatus check({String? projectRoot}) {
    final root = projectRoot ?? ProjectRoot.safeCurrentPath();
    final file = File(p.join(root, 'build.yaml'));
    if (!file.existsSync()) {
      return BuildYamlStatus.missing;
    }
    final contents = file.readAsStringSync();
    if (_registersZorphyBuilder(contents)) {
      return BuildYamlStatus.ok;
    }
    // Issue #1709: a project that provably does not use the zuraffa/zorphy
    // code-generation pipeline has nothing for the zorphy builder to
    // generate, so a build.yaml for its OWN builders (slang, theme
    // extensions, …) is not a misconfiguration. A pubspec.yaml is required
    // for that proof — without a dependency graph we cannot establish that
    // zorphy is absent, so a bare build.yaml keeps the #276 fail-closed
    // behavior.
    if (_hasPubspec(root) && !usesZorphyCodegen(projectRoot: root)) {
      return BuildYamlStatus.notApplicable;
    }
    return BuildYamlStatus.missingZorphyBuilder;
  }

  /// True when the project at [projectRoot] carries any signal of the
  /// zuraffa/zorphy code-generation pipeline: at least one
  /// `@Zorphy`/`@ZorphyMixin`-annotated source under `lib/`, OR a `zorphy`
  /// dependency (the `zorphy` builder or `zorphy_annotation`) declared in any
  /// `pubspec.yaml` dependency section. Both signals are consulted so a
  /// project that annotated sources without (yet) declaring the dependency —
  /// or vice versa — still counts as using the pipeline (issue #1709).
  ///
  /// Deliberately conservative: any doubt resolves to `true`, which keeps the
  /// build.yaml guard applying exactly as it did before #1709.
  static bool usesZorphyCodegen({String? projectRoot}) {
    final root = projectRoot ?? ProjectRoot.safeCurrentPath();
    if (hasZorphyAnnotatedSources(projectRoot: root)) return true;
    return _pubspecDeclaresZorphy(root);
  }

  /// True when at least one non-generated `.dart` source under `lib/` carries
  /// an `@Zorphy` / `@ZorphyMixin` annotation. `//` line comments are stripped
  /// before matching so a comment that merely mentions `@Zorphy` does not
  /// false-positive (important so the guard never breaks a correctly
  /// configured project — zuraffa#276).
  static bool hasZorphyAnnotatedSources({String? projectRoot}) {
    final libPath = projectRoot != null ? p.join(projectRoot, 'lib') : 'lib';
    final libDir = Directory(libPath);
    if (!libDir.existsSync()) return false;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final name = p.basename(entity.path);
        if (name.endsWith('.zorphy.dart') || name.endsWith('.g.dart')) {
          continue;
        }
        try {
          final src = entity.readAsStringSync();
          if (_containsZorphyAnnotation(src)) {
            return true;
          }
        } catch (_) {
          // Ignore unreadable files.
        }
      }
    }
    return false;
  }

  /// True when `pubspec.yaml` exists at [root] and declares a `zorphy` or
  /// `zorphy_annotation` dependency in its `dependencies`,
  /// `dev_dependencies`, or `dependency_overrides` section. An unparseable
  /// pubspec resolves to `false`: the annotation scan in [usesZorphyCodegen]
  /// is the other half of the proof, and a project with no zorphy
  /// annotations is not a zuraffa project whatever its pubspec says. A
  /// genuinely broken pubspec fails later, at build_runner, with its own
  /// accurate error.
  static bool _pubspecDeclaresZorphy(String root) {
    final file = File(p.join(root, 'pubspec.yaml'));
    if (!file.existsSync()) return false;
    final Object? doc;
    try {
      doc = loadYaml(file.readAsStringSync());
    } catch (_) {
      // Unparseable pubspec → no dependency proof here. The annotation scan
      // above already decided this is not a zorphy-annotated project.
      return false;
    }
    if (doc is! YamlMap) return false;
    for (final section in const [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final map = doc[section];
      if (map is! YamlMap) continue;
      for (final key in map.keys) {
        final name = key.toString();
        if (name == 'zorphy' || name == 'zorphy_annotation') return true;
      }
    }
    return false;
  }

  static bool _hasPubspec(String root) =>
      File(p.join(root, 'pubspec.yaml')).existsSync();

  /// Returns true when [source] contains an `@Zorphy` or `@ZorphyMixin`
  /// annotation outside of `//` line comments.
  static bool _containsZorphyAnnotation(String source) {
    final re = RegExp(r'@Zorphy(?:Mixin)?\b');
    for (final line in source.split('\n')) {
      if (re.hasMatch(_stripLineComment(line))) return true;
    }
    return false;
  }

  /// Strips a `//` line comment from [line], ignoring `//` that appears inside
  /// a single- or double-quoted string literal.
  static String _stripLineComment(String line) {
    var inSingle = false;
    var inDouble = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == "'" && !inDouble) {
        inSingle = !inSingle;
      } else if (ch == '"' && !inSingle) {
        inDouble = !inDouble;
      } else if (ch == '/' &&
          i + 1 < line.length &&
          line[i + 1] == '/' &&
          !inSingle &&
          !inDouble) {
        return line.substring(0, i);
      }
    }
    return line;
  }

  /// Scaffolds a `build.yaml` that registers the zorphy + json_serializable
  /// builders. Only call when [check] returned [BuildYamlStatus.missing] —
  /// never overwrite an existing `build.yaml`.
  static Future<void> scaffold({String? projectRoot}) async {
    final root = projectRoot ?? ProjectRoot.safeCurrentPath();
    final file = File(p.join(root, 'build.yaml'));
    await file.writeAsString(DependencyWirer.buildYamlContent);
  }

  /// True when [contents] enables the `zorphy:zorphy` builder.
  ///
  /// Accepts either the `builders:` mapping form or a bare `zorphy:zorphy`
  /// reference, and tolerates leading whitespace. This is intentionally a
  /// substring/regex check rather than a full YAML parse so the guard stays
  /// dependency-free and robust to hand-edited formatting.
  static bool _registersZorphyBuilder(String contents) {
    if (contents.isEmpty) return false;
    // Match `zorphy:zorphy` possibly followed by `:` (mapping) or whitespace,
    // at the start of a line (builder keys are map keys under `builders:`).
    final re = RegExp(r'^\s*zorphy:zorphy\s*:?', multiLine: true);
    return re.hasMatch(contents);
  }

  /// The actionable error message shown when `build.yaml` exists but does not
  /// register the zorphy builder. Kept here so tests can assert against it.
  static const String missingZorphyBuilderMessage = '''
❌ build.yaml exists but does not register the zorphy builder.

   build_runner ran successfully but wrote 0 outputs because no builder is
   configured to process @Zorphy annotations. Add the following under
   `targets:\$default.builders:` in build.yaml:

       builders:
         zorphy:zorphy:
           enabled: true
           generate_for:
             - lib/src/**
             - test/**

   Alternatively, run `zfa setup` to regenerate a correct build.yaml, or
   delete build.yaml and re-run `zfa build` to have it scaffolded for you.
''';

  /// Why an omitted zorphy-builder registration is not a misconfiguration for
  /// this project — the clause shared by [notApplicableNote] and
  /// [notApplicableDryRunNote]. Kept as one constant so the runtime note and
  /// its dry-run preview always carry the same finding and cannot drift apart
  /// (review note on #1748).
  static const String notApplicableReason =
      'this project has no @Zorphy sources and no zorphy dependency — the '
      'zuraffa code-generation pipeline is not in use';

  /// The informational line shown when [check] returned
  /// [BuildYamlStatus.notApplicable]: the project's `build.yaml` omits the
  /// zorphy builder, but nothing in the project uses zorphy, so the guard
  /// stands aside and the build proceeds with the project's own builders
  /// (issue #1709). Kept here so tests can assert against it.
  static const String notApplicableNote =
      'ℹ️  build.yaml does not register the zorphy builder, but '
      '$notApplicableReason, so the build continues with the project\'s own '
      'builders (issue #1709).';

  /// Dry-run counterpart of [notApplicableNote]: the same finding in future
  /// tense, so a preview never claims a build that did not happen. Composed
  /// from the same [notApplicableReason] clause so the two stay in step.
  static const String notApplicableDryRunNote =
      'ℹ️  build.yaml omits the zorphy builder, but $notApplicableReason, so '
      'the build would proceed with the project\'s own builders (issue #1709).';
}
