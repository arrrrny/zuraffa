import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'build_yaml_guard.dart';

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
  }

  @override
  Future<void> run() async {
    final entityCount = await countEntities();
    final dartFileCount = await countDartFiles();
    final clean = argResults!['clean'] as bool;
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;

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

    final exitCode = await _runBuild();

    if (exitCode == 0) {
      if (!dryRun) print('');
      print(dryRun ? '✅ Dry-run completed' : '✅ Build completed successfully');
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
      } else {
        print('\n❌ Build failed with exit code $retryCode');
      }
    } else {
      print('\n❌ Build failed with exit code $exitCode');
    }
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
        final partRe =
            RegExp(r"""^\s*part\s+['"]([^'"]+)['"]\s*;""", multiLine: true);
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
