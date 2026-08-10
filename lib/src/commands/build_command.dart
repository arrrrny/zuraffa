import 'dart:io';
import 'package:args/command_runner.dart';
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
    final entityCount = await _countEntities();
    final dartFileCount = await _countDartFiles();
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
      _reportBuildYamlDryRun();
      print('');
    } else {
      print('   Entities: $entityCount, Dart files: $dartFileCount');
      if (force) {
        print('   ⚠️  Force mode: regenerating from scratch');
      }
      final guardResult = await _ensureBuildYaml();
      if (!guardResult) {
        // _ensureBuildYaml already printed an actionable error.
        exit(1);
      }
      print('🔨 Running build_runner build...');
    }

    final exitCode = await _runBuild();

    if (exitCode == 0) {
      if (!dryRun) print('');
      print(dryRun ? '✅ Dry-run completed' : '✅ Build completed successfully');
      // Safety net: if build_runner wrote 0 outputs while @Zorphy sources
      // exist, warn loudly so silent regressions don't slip through.
      if (!dryRun) {
        _warnIfNoOutputsGenerated();
      }
    } else if (!clean) {
      print(
        '\n⚠️  Build failed (exit $exitCode). Retrying with clean cache...',
      );
      await _cleanBuildCache();
      final retryCode = await _runBuild();
      if (retryCode == 0) {
        print('\n✅ Build completed successfully after cache clean');
        _warnIfNoOutputsGenerated();
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
  Future<bool> _ensureBuildYaml() async {
    final status = BuildYamlGuard.check();
    switch (status) {
      case BuildYamlStatus.ok:
        return true;
      case BuildYamlStatus.missing:
        print(
          '🛠  No build.yaml found — scaffolding one that registers the zorphy builder.',
        );
        await BuildYamlGuard.scaffold();
        print('   Created: build.yaml');
        return true;
      case BuildYamlStatus.missingZorphyBuilder:
        print(BuildYamlGuard.missingZorphyBuilderMessage);
        return false;
    }
  }

  /// Dry-run counterpart of [_ensureBuildYaml]: reports what would happen
  /// without writing.
  void _reportBuildYamlDryRun() {
    final status = BuildYamlGuard.check();
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

  /// Warns (non-fatally) when build_runner exited 0 but produced no `.zorphy`
  /// / `.g.dart` outputs despite `@Zorphy`-annotated sources being present.
  /// Catches misconfigurations the pre-flight check can't detect statically.
  void _warnIfNoOutputsGenerated() {
    try {
      final hasZorphySources = _hasZorphyAnnotatedSources();
      final hasOutputs = _hasGeneratedOutputs();
      if (hasZorphySources && !hasOutputs) {
        print(
          '\n⚠️  build_runner wrote 0 outputs although @Zorphy sources exist.\n'
          '   Check build.yaml registers `zorphy:zorphy` for lib/src/** and\n'
          '   that the annotated files are under the configured generate_for\n'
          '   glob. Run `zfa setup` to regenerate a known-good build.yaml.',
        );
      }
    } catch (_) {
      // Best-effort safety net — never fail the build from this path.
    }
  }

  bool _hasGeneratedOutputs() {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) return false;
    bool found = false;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (name.endsWith('.zorphy.dart') || name.endsWith('.g.dart')) {
          found = true;
          break;
        }
      }
    }
    return found;
  }

  bool _hasZorphyAnnotatedSources() {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) return false;
    bool found = false;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Skip generated files themselves.
        final name = p.basename(entity.path);
        if (name.endsWith('.zorphy.dart') || name.endsWith('.g.dart')) continue;
        try {
          final src = entity.readAsStringSync();
          if (src.contains('@Zorphy') || src.contains('@ZorphyMixin')) {
            found = true;
            break;
          }
        } catch (_) {
          // Ignore unreadable files.
        }
      }
    }
    return found;
  }

  Future<int> _runBuild() async {
    // `--delete-conflicting-outputs` was removed in build_runner 2.16.0 and
    // emits a "These options have been removed" warning on every invocation.
    // build_runner now resolves conflicting outputs via the build cache, so
    // the flag is no longer needed.
    final args = <String>[
      'run',
      'build_runner',
      'build',
    ];

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

  Future<int> _countEntities() async {
    final entitiesDir = Directory('lib/src/domain/entities');
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

  Future<int> _countDartFiles() async {
    final libDir = Directory('lib');
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
