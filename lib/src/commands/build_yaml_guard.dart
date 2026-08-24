import 'dart:io';

import 'package:path/path.dart' as p;

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
    if (!_registersZorphyBuilder(contents)) {
      return BuildYamlStatus.missingZorphyBuilder;
    }
    return BuildYamlStatus.ok;
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
}
