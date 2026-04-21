import 'dart:io';
import 'package:args/command_runner.dart';

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
  }

  @override
  Future<void> run() async {
    final entityCount = await _countEntities();
    final dartFileCount = await _countDartFiles();
    final clean = argResults!['clean'] as bool;

    if (clean) {
      await _cleanBuildCache();
    }

    print('🔨 Running build_runner build...');
    print('   Entities: $entityCount, Dart files: $dartFileCount');

    final exitCode = await _runBuild();

    if (exitCode == 0) {
      print('\n✅ Build completed successfully');
    } else if (!clean) {
      print('\n⚠️  Build failed (exit $exitCode). Retrying with clean cache...');
      await _cleanBuildCache();
      final retryCode = await _runBuild();
      if (retryCode == 0) {
        print('\n✅ Build completed successfully after cache clean');
      } else {
        print('\n❌ Build failed with exit code $retryCode');
      }
    } else {
      print('\n❌ Build failed with exit code $exitCode');
    }
  }

  Future<int> _runBuild() async {
    final process = await Process.start('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ], mode: ProcessStartMode.inheritStdio);
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
