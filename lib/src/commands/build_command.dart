import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'build_yaml_guard.dart';
import '../core/project/project_root.dart';
import '../dda/plugins/route/route_build_stage.dart';
import '../feature_flags/feature_flag_config.dart';
import '../feature_flags/registry_emitter.dart';

class BuildCommand extends Command {
  @override
  final String name = 'build';

  @override
  final String description =
      'Run zuraffa_build to generate code from annotations (calls build_runner)';

  BuildCommand() {
    argParser.addFlag(
      'clean',
      abbr: 'c',
      help: 'Delete the build cache before building (fixes stale cache errors)',
      negatable: false,
    );
    argParser.addOption(
      'flavor',
      help:
          'Build a named flavor (spec 030): resolves the features:/'
          'flavors: sections of .zfa.json into this build\'s feature-set — '
          'disabled features generate nothing and the generated '
          'FeatureFlags registry reflects the flavor.',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview what would change without writing files',
    );
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Bypass AST merge and regenerate all files from scratch',
    );
    argParser.addFlag(
      'analyze',
      abbr: 'a',
      help:
          'Run `dart analyze` after build and fail on errors '
          '(default: on; use --no-analyze to skip). Catches non-compiling '
          'generated code immediately (issue #395).',
      defaultsTo: true,
    );
    argParser.addFlag(
      'dda-routes',
      help:
          'Run the DDA @Route stage: scan @Route/@ZfaRoute annotations and '
          'compile lib/src/routing/zfa_router.g.dart (spec 033, issue #187). '
          'Validation errors fail the build.',
      defaultsTo: true,
    );
    argParser.addFlag(
      'dda-routes-only',
      negatable: false,
      help:
          'Run ONLY the DDA @Route stage — skip build_runner and the '
          'post-build verifiers entirely.',
    );
  }

  @override
  Future<void> run() async {
    final entityCount = await countEntities();
    final dartFileCount = await countDartFiles();
    final clean = argResults!['clean'] as bool;
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final analyze = argResults!['analyze'] as bool;
    final ddaRoutes = argResults!['dda-routes'] as bool;
    final ddaRoutesOnly = argResults!['dda-routes-only'] as bool;

    // ── Spec 030 (FR-003): per-flavor builds. Resolve + validate the
    // feature-set BEFORE any stage runs so a bad config fails fast.
    final flavor = argResults?['flavor'] as String?;
    final ResolvedFeatureSet? featureSet = await _resolveFeatureSet(flavor);
    if (flavor != null && featureSet == null) {
      // _resolveFeatureSet already printed the reason (unknown flavor,
      // no features section, or invalid config) and exited non-zero.
      return;
    }

    // ── DDA @Route stage (spec 033 / issue #187) ──
    // Runs FIRST so route misconfigurations fail fast, before any
    // expensive build_runner work.
    if (ddaRoutesOnly) {
      if (ddaRoutes) {
        final result = await runDdaRouteStage(
          dryRun: dryRun,
          featureSet: featureSet,
        );
        if (!result.success) {
          exit(1);
        }
        await emitFeatureFlagsRegistry(featureSet, flavorName: flavor);
        print('✅ DDA route stage completed');
      } else {
        print('⏭  DDA route stage disabled (--no-dda-routes) — nothing to do.');
      }
      return;
    }
    if (ddaRoutes) {
      final result = await runDdaRouteStage(
        dryRun: dryRun,
        featureSet: featureSet,
      );
      if (!result.success) {
        exit(1);
      }
      await emitFeatureFlagsRegistry(featureSet, flavorName: flavor);
    }

    if (clean) {
      await _cleanBuildCache();
    }

    // Self-healing pre-flight (zuraffa#276): ensure build.yaml registers the
    // zorphy builder, otherwise build_runner exits 0 having written 0 outputs
    // and we'd silently report success. Run BEFORE announcing the build so a
    // misconfigured project fails fast without invoking build_runner.
    if (dryRun) {
      print('🔍 Dry-run mode: previewing changes...');
      print('   Entities: $entityCount, Dart files: $dartFileCount');
      if (force) {
        print('   ⚠️  --force: will regenerate all files from scratch');
      } else {
        print(
          '   🧠 Smart merge: will preserve user code and @preserve blocks',
        );
      }
      reportBuildYamlDryRun();
      print('');
    } else {
      print('   Entities: $entityCount, Dart files: $dartFileCount');
      if (force) {
        print('   ⚠️  Force mode: regenerating from scratch');
      }
      final guardResult = await ensureBuildYaml();
      if (!guardResult) {
        // ensureBuildYaml already printed an actionable error.
        exit(1);
      }
      print('🔨 Running build_runner build...');
    }

    // Dry-run stops after the pre-flight preview — it must never invoke
    // build_runner (the preview above is the entire contract; a dry-run
    // that mutates the build cache or fails on a pubspec-less workspace
    // is not dry). Found by the spec-025 package-SDK e2e.
    if (dryRun) {
      print('✅ Dry-run completed');
      return;
    }

    final exitCode = await _runBuild();

    if (exitCode == 0) {
      print('');
      print('✅ Build completed successfully');
      // Safety net (zuraffa#276): if build_runner wrote 0 outputs while
      // @Zorphy sources exist, FAIL LOUDLY with an actionable error instead
      // of silently reporting success. The pre-flight check catches a missing
      // build.yaml / unregistered zorphy builder, but a build.yaml whose
      // `generate_for` glob doesn't match the annotated sources still
      // produces 0 outputs — this catches that residual class of misconfig.
      if (!dryRun) {
        if (!verifyOutputsOrFail() || !verifyDeclaredPartsOrFail()) {
          exit(1);
        }
        if (analyze && !await verifyAnalyzeOrFail()) {
          exit(1);
        }
      }
    } else if (!clean) {
      print(
        '\n⚠️  Build failed (exit $exitCode). Retrying with clean cache...',
      );
      await _cleanBuildCache();
      final retryCode = await _runBuild();
      if (retryCode == 0) {
        print('\n✅ Build completed successfully after cache clean');
        if (!verifyOutputsOrFail() || !verifyDeclaredPartsOrFail()) {
          exit(1);
        }
        if (analyze && !await verifyAnalyzeOrFail()) {
          exit(1);
        }
      } else {
        print('\n❌ Build failed with exit code $retryCode');
        // Fail loudly: a failed build must never exit 0 — the spec-025
        // package pipeline (and every CI format/test gate) trusts this
        // exit code as the build verdict.
        exit(1);
      }
    } else {
      print('\n❌ Build failed with exit code $exitCode');
      exit(1);
    }
  }

  /// Runs the DDA @Route stage (spec 033) against the current project root
  /// and prints a summary. Returns the stage result so tests can assert on
  /// it without process exits; [run] turns failures into exit code 1.
  @visibleForTesting
  Future<RouteBuildResult> runDdaRouteStage({
    String? projectRoot,
    bool dryRun = false,
    ResolvedFeatureSet? featureSet,
  }) async {
    final root = projectRoot ?? ProjectRoot.safeCurrentPath();
    final stage = RouteBuildStage(
      projectRoot: root,
      dryRun: dryRun,
      featureSet: featureSet,
    );
    final result = await stage.run();
    for (final file in result.generatedFiles) {
      print('   ✅ $file');
    }
    for (final file in result.deletedFiles) {
      print('   🧹 $file (removed — no @Route annotations remain)');
    }
    for (final warning in result.warnings) {
      print('   ⚠️  $warning');
    }
    if (!result.success) {
      print(
        '\n❌ @Route build-time validation failed '
        '(${result.errors.length} error(s)):',
      );
      for (final error in result.errors) {
        print('   - $error');
      }
      print(
        '\n   Fix the annotations listed above and re-run zfa build. See:\n'
        '   https://zuraffa.com/docs/routing (@Route decorator).',
      );
    }
    return result;
  }

  /// Spec 030 (FR-003, US1.AC4): resolves the effective feature-set for
  /// [flavor]. Returns null when no feature-flag config exists (build
  /// proceeds unchanged). An INVALID config or an unknown [flavor] is
  /// fatal: prints the reason naming the offender and exits non-zero —
  /// the build must never silently ignore a broken feature declaration.
  Future<ResolvedFeatureSet?> _resolveFeatureSet(String? flavor) async {
    final root = ProjectRoot.safeCurrentPath();
    final FeatureFlagConfig config;
    try {
      config = FeatureFlagConfig.load(projectRoot: root);
    } on FeatureConfigException catch (e) {
      print('❌ $e');
      exit(1);
    }
    if (config.isEmpty) {
      if (flavor != null) {
        print(
          '❌ --flavor "$flavor" requested but .zfa.json declares no '
          'features: section.',
        );
        exit(1);
      }
      return null;
    }
    try {
      final resolved = config.resolve(flavor: flavor);
      if (flavor != null) {
        print(
          '🏷  Flavor "$flavor": ${resolved.enabled.length} feature(s) '
          'enabled, ${resolved.disabled.length} disabled',
        );
      }
      return resolved;
    } on FeatureConfigException catch (e) {
      print('❌ $e');
      exit(1);
    }
  }

  /// Spec 030 (FR-005): emits the target app's feature_flags.g.dart from
  /// [featureSet]. Skipped when no feature flags are declared (build
  /// output identical to a no-features project — US2.AC4).
  Future<void> emitFeatureFlagsRegistry(
    ResolvedFeatureSet? featureSet, {
    String? projectRoot,
    String? flavorName,
  }) async {
    if (featureSet == null) return;
    final root = projectRoot ?? ProjectRoot.safeCurrentPath();
    final outDir = Directory(p.join(root, 'lib', 'src', 'core'));
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final outFile = File(p.join(outDir.path, 'feature_flags.g.dart'));
    final source = emitRegistry(
      className: 'FeatureFlags',
      resolved: featureSet,
      flavor: flavorName,
    );
    await outFile.writeAsString(source);
    print('   ✅ ${outFile.path} (FeatureFlags registry)');
  }

  /// Ensures `build.yaml` is in a state that lets build_runner produce zorphy
  /// outputs. Returns `true` when the build may proceed; `false` when the
  /// project has a `build.yaml` that omits the zorphy builder (the caller
  /// should abort — the user must fix their config).
  @visibleForTesting
  Future<bool> ensureBuildYaml({String? projectRoot}) async {
    final status = BuildYamlGuard.check(projectRoot: projectRoot);
    switch (status) {
      case BuildYamlStatus.ok:
        return true;
      case BuildYamlStatus.missing:
        print(
          '🛠  No build.yaml found — scaffolding one that registers the zorphy builder.',
        );
        await BuildYamlGuard.scaffold(projectRoot: projectRoot);
        print('   Created: build.yaml');
        return true;
      case BuildYamlStatus.missingZorphyBuilder:
        print(BuildYamlGuard.missingZorphyBuilderMessage);
        return false;
    }
  }

  /// Dry-run counterpart of [ensureBuildYaml]: reports what would happen
  /// without writing.
  @visibleForTesting
  void reportBuildYamlDryRun({String? projectRoot}) {
    final status = BuildYamlGuard.check(projectRoot: projectRoot);
    switch (status) {
      case BuildYamlStatus.ok:
        break;
      case BuildYamlStatus.missing:
        print('   Would scaffold: build.yaml (registers zorphy builder)');
        break;
      case BuildYamlStatus.missingZorphyBuilder:
        print(
          '   ⚠️  build.yaml exists but omits the zorphy builder — build would write 0 outputs.',
        );
        print('       Add `zorphy:zorphy` under targets.\$default.builders.');
        break;
    }
  }

  /// Returns `true` when the build produced the expected `.zorphy.dart` /
  /// `.g.dart` outputs (or when there are no `@Zorphy` sources to generate
  /// from). Returns `false` and prints an actionable error when build_runner
  /// exited 0 but wrote 0 outputs despite `@Zorphy`-annotated sources being
  /// present — the "silent success with 0 outputs" misconfiguration from
  /// zuraffa#276 that the static pre-flight cannot detect.
  @visibleForTesting
  bool verifyOutputsOrFail({String? projectRoot}) {
    try {
      final hasZorphySources = hasZorphyAnnotatedSources(
        projectRoot: projectRoot,
      );
      final hasOutputs = hasGeneratedOutputs(projectRoot: projectRoot);
      if (hasZorphySources && !hasOutputs) {
        print(
          '\n❌ build_runner wrote 0 outputs although @Zorphy sources exist.\n'
          '   This usually means build.yaml registers `zorphy:zorphy` but its\n'
          '   `generate_for` glob does not include the annotated files. Fix by\n'
          '   ensuring `generate_for` covers `lib/src/**` (and `test/**`):\n'
          '\n'
          '       builders:\n'
          '         zorphy:zorphy:\n'
          '           enabled: true\n'
          '           generate_for:\n'
          '             - lib/src/**\n'
          '             - test/**\n'
          '\n'
          '   Or run `zfa setup` to regenerate a known-good build.yaml, then\n'
          '   re-run `zfa build`.',
        );
        return false;
      }
    } catch (_) {
      // Best-effort safety net — never fail the build from an unexpected error
      // in the detection path itself.
    }
    return true;
  }

  /// Returns `true` when every generated part declared by a source file under
  /// `lib/`/`test/` (`.zorphy.dart` / `.g.dart`) actually exists on disk.
  ///
  /// This is the residual case zuraffa#379: build_runner (AOT) can exit 0 —
  /// or its clean-cache retry can — while a single generator (e.g.
  /// json_serializable failing on a `Function` field) leaves ONE entity's
  /// part file unwritten. `verifyOutputsOrFail` only catches the total-zero
  /// case; this catches the per-file partial case so the build fails loudly
  /// instead of leaving a broken package that references a missing part.
  ///
  /// Only sources that declare a `.zorphy.dart` / `.g.dart` part are checked,
  /// so hand-written multi-part libraries are not inspected.
  @visibleForTesting
  bool verifyDeclaredPartsOrFail({String? projectRoot}) {
    final missing = <String>[];
    for (final root in ['lib', 'test']) {
      final rootPath = projectRoot != null ? p.join(projectRoot, root) : root;
      final dir = Directory(rootPath);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.zorphy.dart') || name.endsWith('.g.dart')) {
          continue;
        }
        String src;
        try {
          src = entity.readAsStringSync();
        } catch (_) {
          // Ignore unreadable files.
          continue;
        }
        final partRe = RegExp(
          r"""^\s*part\s+['"]([^'"]+)['"]\s*;""",
          multiLine: true,
        );
        for (final m in partRe.allMatches(src)) {
          final partName = m.group(1)!;
          if (!partName.endsWith('.zorphy.dart') &&
              !partName.endsWith('.g.dart')) {
            continue;
          }
          final resolved = p.join(p.dirname(entity.path), partName);
          if (!File(resolved).existsSync()) {
            missing.add('${p.relative(entity.path)} -> $partName');
          }
        }
      }
    }
    if (missing.isNotEmpty) {
      print(
        '\n❌ Build exited 0 but ${missing.length} declared generated part(s) are '
        'missing — the build output is incomplete.\n'
        '   Missing:\n'
        '${missing.map((m) => '     - $m').join('\n')}\n'
        '   This usually means a generator (e.g. json_serializable) failed on one\n'
        '   source while the rest of the build succeeded. Fix the reported source\n'
        '   and re-run `zfa build`.',
      );
      return false;
    }
    return true;
  }

  /// True when at least one `.zorphy.dart` or `.g.dart` file exists under
  /// `lib/` or `test/` (the dirs covered by the canonical `generate_for`).
  @visibleForTesting
  bool hasGeneratedOutputs({String? projectRoot}) {
    const roots = <String>['lib', 'test'];
    for (final r in roots) {
      final dirPath = projectRoot != null ? p.join(projectRoot, r) : r;
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.endsWith('.zorphy.dart') || name.endsWith('.g.dart')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// True when at least one non-generated `.dart` source under `lib/` carries
  /// an `@Zorphy` / `@ZorphyMixin` annotation. `//` line comments are stripped
  /// before matching so a comment that merely mentions `@Zorphy` does not
  /// false-positive (important so the safety net never breaks a correctly
  /// configured project — zuraffa#276).
  @visibleForTesting
  bool hasZorphyAnnotatedSources({String? projectRoot}) {
    final libPath = projectRoot != null ? p.join(projectRoot, 'lib') : 'lib';
    final libDir = Directory(libPath);
    if (!libDir.existsSync()) return false;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final name = p.basename(entity.path);
        if (name.endsWith('.zorphy.dart') || name.endsWith('.g.dart')) continue;
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

  /// Post-build guard (issue #395): runs `dart analyze` and returns `false`
  /// when it reports any ERROR-severity issue. Only ERRORS fail the build;
  /// warnings and info-level lints are surfaced but do not cause a non-zero
  /// exit. Pass `--no-analyze` to skip this check entirely.
  ///
  /// This catches non-compiling generated code (e.g. missing imports, wrong
  /// relative import depth) immediately after `zfa build` instead of letting
  /// it surface downstream at `dart run` / CI time.
  @visibleForTesting
  Future<bool> verifyAnalyzeOrFail({String? projectRoot}) async {
    final root = projectRoot ?? ProjectRoot.safeCurrentPath();
    print('\n🔎 Running dart analyze on lib/...');
    final result = await Process.run('dart', [
      'analyze',
      'lib',
    ], workingDirectory: root);
    final stdout = result.stdout as String;
    final stderr = result.stderr as String;
    if (stdout.trim().isNotEmpty) {
      print(stdout.trim());
    }
    if (stderr.trim().isNotEmpty) {
      print(stderr.trim());
    }
    // `dart analyze` exit 0 = no issues; 1 = issues found; 2 = fatal error.
    // We only fail on actual errors (lines whose severity is "error").
    // Info-level lints are non-fatal by default (do NOT pass `--fatal-infos`,
    // which is a boolean flag that rejects a `=false` value and would make the
    // analyzer fail at flag-parse — see issue #415). We surface warnings/info
    // above but only flip the exit code on real "error" severity lines.
    final hasErrors = analyzeReportsError(stdout);
    if (hasErrors) {
      print(
        '\n❌ dart analyze reported errors — generated code does not compile.\n'
        '   Fix the generator or run with --no-analyze to skip this check.',
      );
      return false;
    }
    print('   ✅ dart analyze: no errors');
    return true;
  }

  /// Returns true when [analyzeOutput] contains at least one line whose
  /// severity marker is `error`. `dart analyze` formats lines as:
  ///   `   error - path:line:col - message - code`
  /// We look for ` - error - ` at the start of a line (after whitespace).
  /// Returns true when [analyzeOutput] contains at least one line whose
  /// severity marker is `error`. Exposed for unit testing so the parser can
  /// be verified without spawning `dart analyze` (which needs a full package).
  @visibleForTesting
  static bool analyzeReportsError(String analyzeOutput) {
    final errorLine = RegExp(r'^\s*error\s*-\s', multiLine: true);
    return errorLine.hasMatch(analyzeOutput);
  }

  Future<int> _runBuild() async {
    // `--delete-conflicting-outputs` was removed in build_runner 2.16.0 and
    // emits a "These options have been removed" warning on every invocation.
    // build_runner now resolves conflicting outputs via the build cache, so
    // the flag is no longer needed.
    final args = <String>['run', 'build_runner', 'build'];

    final process = await Process.start(
      'dart',
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  Future<void> _cleanBuildCache() async {
    print('🧹 Cleaning build cache...');
    final cacheDir = Directory('.dart_tool/build');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      print('   Deleted .dart_tool/build');
    }
  }

  /// Counts scaffolded entity directories under `lib/src/domain/entities`.
  @visibleForTesting
  Future<int> countEntities({String? projectRoot}) async {
    final entitiesPath = projectRoot != null
        ? p.join(projectRoot, 'lib/src/domain/entities')
        : 'lib/src/domain/entities';
    final entitiesDir = Directory(entitiesPath);
    if (!await entitiesDir.exists()) return 0;

    int count = 0;
    await for (final entity in entitiesDir.list()) {
      if (entity is Directory) {
        final entityName = entity.path.split('/').last;
        final dartFile = File('${entity.path}/$entityName.dart');
        if (await dartFile.exists()) {
          count++;
        }
      }
    }
    return count;
  }

  /// Counts `.dart` files under `lib/`.
  @visibleForTesting
  Future<int> countDartFiles({String? projectRoot}) async {
    final libPath = projectRoot != null ? p.join(projectRoot, 'lib') : 'lib';
    final libDir = Directory(libPath);
    if (!await libDir.exists()) return 0;

    int count = 0;
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        count++;
      }
    }
    return count;
  }
}
