import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../models/generated_file.dart';

/// Stores generation run artifacts in `.zfa/runs/`.
class RunStore {
  final String projectRoot;

  RunStore({required this.projectRoot});

  Directory get _runsDir => Directory(p.join(projectRoot, '.zfa', 'runs'));

  /// Saves a run artifact to `.zfa/runs/{timestamp}_{name}.json`.
  Future<void> save(RunArtifact artifact) async {
    if (!_runsDir.existsSync()) {
      await _runsDir.create(recursive: true);
    }

    final timestamp = artifact.timestamp.toIso8601String().replaceAll(':', '-');
    final fileName = '${timestamp}_${artifact.name}.json';
    final file = File(p.join(_runsDir.path, fileName));

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(artifact.toJson()));
  }

  /// Lists all run artifacts, sorted by timestamp descending.
  Future<List<RunArtifact>> list() async {
    if (!_runsDir.existsSync()) {
      return [];
    }

    final files = _runsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    final artifacts = <RunArtifact>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        artifacts.add(RunArtifact.fromJson(json));
      } catch (_) {
        // Skip corrupted files
      }
    }

    artifacts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return artifacts;
  }

  /// Loads the most recent run artifact for [name].
  Future<RunArtifact?> loadLatest(String name) async {
    final all = await list();
    return all.cast<RunArtifact?>().firstWhere(
      (a) => a!.name == name,
      orElse: () => null,
    );
  }
}

/// A record of a completed generation run.
class RunArtifact {
  final String name;
  final DateTime timestamp;
  final Duration duration;
  final bool success;
  final List<GeneratedFile> files;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> options;

  RunArtifact({
    required this.name,
    required this.timestamp,
    required this.duration,
    required this.success,
    required this.files,
    required this.errors,
    required this.warnings,
    required this.options,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'success': success,
    'files': files.map((f) => f.toJson()).toList(),
    'errors': errors,
    'warnings': warnings,
    'options': options,
  };

  factory RunArtifact.fromJson(Map<String, dynamic> json) {
    return RunArtifact(
      name: json['name'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: Duration(milliseconds: json['duration_ms'] as int),
      success: json['success'] as bool,
      files: (json['files'] as List)
          .map(
            (f) => GeneratedFile(
              path: f['path'] as String,
              type: f['type'] as String,
              action: f['action'] as String,
              content: f['content'] as String?,
            ),
          )
          .toList(),
      errors: List<String>.from(json['errors'] as List),
      warnings: List<String>.from(json['warnings'] as List),
      options: Map<String, dynamic>.from(json['options'] as Map),
    );
  }
}
