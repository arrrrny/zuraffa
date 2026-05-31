import 'dart:io';

import 'package:path/path.dart' as path;

/// Resolves canonical `.zfa/` project memory locations.
class ProjectPaths {
  final String rootDirectory;

  const ProjectPaths(this.rootDirectory);

  String get zfaDirectory => path.join(rootDirectory, '.zfa');
  String get plansDirectory => path.join(zfaDirectory, 'plans');
  String get runsDirectory => path.join(zfaDirectory, 'runs');
  String get blueprintsDirectory => path.join(zfaDirectory, 'blueprints');
  String get decisionsDirectory => path.join(zfaDirectory, 'decisions');
  String get manifestsDirectory => path.join(zfaDirectory, 'manifests');
  String get contextFilePath => path.join(zfaDirectory, 'context.json');
  String get agentContractFilePath =>
      path.join(zfaDirectory, 'AGENT_CONTRACT.md');

  File planFile(String planId) =>
      File(path.join(plansDirectory, '$planId.json'));

  File legacyPlanFile(String planId) =>
      File(path.join(rootDirectory, '.zuraffa', 'plans', '$planId.json'));

  File runFile(String runId) => File(path.join(runsDirectory, '$runId.json'));

  File artifactFile(
    String directoryName,
    String artifactId, {
    String extension = 'json',
  }) => File(path.join(zfaDirectory, directoryName, '$artifactId.$extension'));
}
