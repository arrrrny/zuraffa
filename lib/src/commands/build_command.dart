import 'dart:io';
import 'package:args/command_runner.dart';

class BuildCommand extends Command {
  @override
  final String name = 'build';

  @override
  final String description =
      'Run zuraffa_build to generate code from annotations (calls build_runner)';

  @override
  Future<void> run() async {
    final entityCount = await _countEntities();
    final dartFileCount = await _countDartFiles();

    print('🔨 Running build_runner build...');
    print('   Entities: $entityCount, Dart files: $dartFileCount');

    final process = await Process.start('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ], mode: ProcessStartMode.inheritStdio);

    final exitCode = await process.exitCode;

    if (exitCode == 0) {
      print('\n✅ Build completed successfully');
    } else {
      print('\n❌ Build failed with exit code $exitCode');
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
