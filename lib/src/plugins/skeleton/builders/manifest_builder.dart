/// Renders a [BoneManifest] as YAML.
library;

import '../models/bone.dart';

/// Renders [BoneManifest] instances to YAML strings matching
/// `contracts/bone-manifest.md`.
class ManifestBuilder {
  /// Renders [manifest] as a YAML string.
  String render(BoneManifest manifest) {
    final buf = StringBuffer();
    buf.writeln('version: ${manifest.version}');
    buf.writeln('feature: ${_yamlString(manifest.feature)}');
    buf.writeln('generated_at: ${_yamlString(manifest.generatedAt)}');
    buf.writeln('spec_version: ${manifest.specVersion}');

    buf.writeln('entities:');
    for (final entity in manifest.entities) {
      buf.writeln('  - $entity');
    }

    if (manifest.dependencies.isEmpty) {
      buf.writeln('dependencies: []');
    } else {
      buf.writeln('dependencies:');
      for (final dep in manifest.dependencies) {
        buf.writeln('  - bone: ${_yamlString(dep.bone)}');
        buf.writeln('    entities: [${dep.entities.join(', ')}]');
      }
    }

    buf.writeln('layers:');
    for (final layer in manifest.layers) {
      buf.writeln('  - $layer');
    }

    if (manifest.xray.isNotEmpty) {
      buf.writeln('xray:');
      for (final entry in manifest.xray.entries) {
        buf.writeln('  ${_yamlString(entry.key)}: ${_yamlString(entry.value)}');
      }
    }

    return buf.toString();
  }

  /// Wraps a string in YAML single quotes if it contains special characters.
  String _yamlString(String value) {
    // Simple heuristic: quote if contains colon, space, or starts with special.
    if (value.contains(':') ||
        value.contains(' ') ||
        value.startsWith('{') ||
        value.startsWith('[') ||
        value.startsWith('#') ||
        value.startsWith('&') ||
        value.startsWith('*') ||
        value.startsWith('!') ||
        value.startsWith('%') ||
        value.startsWith('@') ||
        value.startsWith('`')) {
      return "'${value.replaceAll("'", "''")}'";
    }
    return value;
  }
}
