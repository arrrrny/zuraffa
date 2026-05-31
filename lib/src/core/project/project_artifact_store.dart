import 'dart:convert';
import 'dart:io';

import 'project_paths.dart';

/// Minimal helper for `.zfa` JSON artifacts such as blueprints, decisions,
/// and manifests.
class ProjectArtifactStore {
  final String directoryName;
  final String? rootDirectory;

  ProjectArtifactStore.blueprints({this.rootDirectory})
    : directoryName = 'blueprints';

  ProjectArtifactStore.decisions({this.rootDirectory})
    : directoryName = 'decisions';

  ProjectArtifactStore.manifests({this.rootDirectory})
    : directoryName = 'manifests';

  ProjectPaths _paths(String? baseDir) =>
      ProjectPaths(baseDir ?? rootDirectory ?? Directory.current.path);

  Future<void> save(
    String artifactId,
    Map<String, dynamic> artifact, {
    String? baseDir,
  }) async {
    final file = _paths(baseDir).artifactFile(directoryName, artifactId);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(artifact),
    );
  }

  Future<Map<String, dynamic>?> load(
    String artifactId, {
    String? baseDir,
  }) async {
    final file = _paths(baseDir).artifactFile(directoryName, artifactId);
    if (!file.existsSync()) {
      return null;
    }

    final decoded = jsonDecode(await file.readAsString());
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<String>> list({String? baseDir}) async {
    final directory = Directory(
      _paths(baseDir).artifactFile(directoryName, '_').parent.path,
    );
    if (!directory.existsSync()) {
      return const [];
    }

    final artifactIds = <String>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      artifactIds.add(entity.uri.pathSegments.last.replaceFirst('.json', ''));
    }
    artifactIds.sort();
    return artifactIds;
  }
}
