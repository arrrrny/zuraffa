/// Cross-registry ownership lookup (bug #874).
///
/// After #827 the TDD artifacts are namespaced per feature and EVERY
/// feature carries its own registry (`specs/<feature>/tdd/artifacts.json`).
/// The recovery surfaces — `zfa tdd doctor`'s legacy-layout scan and
/// `zfa tdd gen`'s adopt fallback — must consult the SET of registries
/// before declaring a file "unowned": a path recorded by ANOTHER feature
/// is foreign-owned, and adopting it into a second registry would corrupt
/// ownership (two features owning one file — the exact trust violation
/// the ownership guardrails exist to prevent).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'artifact_registry.dart';

/// Normalizes a recorded artifact path to the absolute form used for
/// ownership comparisons. Registries may record absolute paths (gen's
/// default) or project-relative ones; both must resolve to the same
/// ownership answer.
String normalizeArtifactPath(String projectRoot, String recorded) =>
    p.isAbsolute(recorded)
    ? p.normalize(recorded)
    : p.normalize(p.join(projectRoot, recorded));

/// Maps every artifact path recorded across ALL feature registries
/// (`specs/<feature>/tdd/artifacts.json` under [projectRoot]) to the
/// feature that owns it.
///
/// The first feature (sorted by name) wins on a duplicate path — a
/// duplicate means the registries already disagree, and the deterministic
/// answer keeps the diagnosis reproducible.
Future<Map<String, String>> ownershipByPathAcrossFeatures(
  String projectRoot,
) async {
  final owners = <String, String>{};
  final specsDir = Directory(p.join(projectRoot, 'specs'));
  if (!specsDir.existsSync()) return owners;
  final features = specsDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  for (final featureDir in features) {
    final registry = ArtifactRegistry(featureDir: featureDir.path);
    for (final record in await registry.loadAll()) {
      for (final recorded in [record.testPath, record.subjectPath]) {
        owners.putIfAbsent(
          normalizeArtifactPath(projectRoot, recorded),
          () => p.basename(featureDir.path),
        );
      }
    }
  }
  return owners;
}

/// The feature that owns any of [paths] per a registry OTHER than
/// [excludeFeature], or `null` when no other feature records them (the
/// files are then either this feature's own or genuinely unowned).
Future<String?> foreignOwnerOf(
  String projectRoot,
  Iterable<String> paths, {
  required String excludeFeature,
}) async {
  final owners = await ownershipByPathAcrossFeatures(projectRoot);
  for (final path in paths) {
    final owner = owners[normalizeArtifactPath(projectRoot, path)];
    if (owner != null && owner != excludeFeature) return owner;
  }
  return null;
}
