import 'dart:io';

/// Manages build_runner execution for generating Morphy .g.dart files
///
/// Automatically runs build_runner when Morphy entities are generated
class BuildRunnerManager {
  final String projectPath;

  BuildRunnerManager(this.projectPath);

  /// Check if build_runner needs to be run
  /// Returns true if there are .dart files with @morphy that need .g.dart generation
  Future<bool> needsGeneration() async {
    final libDir = Directory('$projectPath/lib');
    if (!await libDir.exists()) return false;

    // Look for files with @morphy annotation
    final dartFiles = await libDir
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.dart'))
        .cast<File>()
        .toList();

    for (final file in dartFiles) {
      final content = await file.readAsString();
      if (content.contains('@morphy') || content.contains('@Morphy')) {
        // Check if corresponding .g.dart exists
        final generatedPath = file.path.replaceAll('.dart', '.g.dart');
        if (!await File(generatedPath).exists()) {
          return true; // Needs generation
        }
      }
    }

    return false;
  }

  /// Run build_runner build
  /// Returns BuildRunnerResult with success status and output
  Future<BuildRunnerResult> runBuild({
    bool deleteConflictingOutputs = false,
    void Function(String)? onProgress,
  }) async {
    final args = [
      'run',
      'build_runner',
      'build',
      if (deleteConflictingOutputs) '--delete-conflicting-outputs',
    ];

    onProgress?.call('🔨 Running build_runner...');

    final process = await Process.start(
      'dart',
      args,
      workingDirectory: projectPath,
      mode: ProcessStartMode.normal,
    );

    final stdout = <String>[];
    final stderr = <String>[];

    // Capture output
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      stdout.add(data);
      onProgress?.call(data.trim());
    });

    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      stderr.add(data);
      onProgress?.call('⚠️  $data'.trim());
    });

    final exitCode = await process.exitCode;

    return BuildRunnerResult(
      success: exitCode == 0,
      exitCode: exitCode,
      stdout: stdout.join('\n'),
      stderr: stderr.join('\n'),
      generatedFiles: await _findGeneratedFiles(),
    );
  }

  /// Find all .g.dart files that were generated
  Future<List<String>> _findGeneratedFiles() async {
    final libDir = Directory('$projectPath/lib');
    if (!await libDir.exists()) return [];

    final generatedFiles = await libDir
        .list(recursive: true)
        .where((entity) =>
            entity is File &&
            entity.path.endsWith('.g.dart') &&
            !entity.path.contains('/.dart_tool/'))
        .cast<File>()
        .map((file) => file.path.replaceAll('$projectPath/', ''))
        .toList();

    return generatedFiles;
  }

  /// Watch mode - run build_runner watch (for development)
  Future<Process> runWatch({
    bool deleteConflictingOutputs = false,
  }) async {
    final args = [
      'run',
      'build_runner',
      'watch',
      if (deleteConflictingOutputs) '--delete-conflicting-outputs',
    ];

    return await Process.start(
      'dart',
      args,
      workingDirectory: projectPath,
      mode: ProcessStartMode.detached,
    );
  }

  /// Clean generated files
  Future<BuildRunnerResult> clean() async {
    final process = await Process.start(
      'dart',
      ['run', 'build_runner', 'clean'],
      workingDirectory: projectPath,
    );

    final exitCode = await process.exitCode;

    return BuildRunnerResult(
      success: exitCode == 0,
      exitCode: exitCode,
      stdout: '',
      stderr: '',
      generatedFiles: [],
    );
  }
}

/// Result of build_runner execution
class BuildRunnerResult {
  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;
  final List<String> generatedFiles;

  BuildRunnerResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.generatedFiles,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Build Runner Result:');
    buffer.writeln('  Success: $success');
    buffer.writeln('  Exit Code: $exitCode');
    if (generatedFiles.isNotEmpty) {
      buffer.writeln('  Generated Files: ${generatedFiles.length}');
      for (final file in generatedFiles) {
        buffer.writeln('    - $file');
      }
    }
    if (stderr.isNotEmpty) {
      buffer.writeln('  Errors:');
      buffer.writeln('    $stderr');
    }
    return buffer.toString();
  }
}
