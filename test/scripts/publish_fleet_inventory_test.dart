import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

// Regression guard for issue #2036.
//
// scripts/publish_fleet.sh kept its fleet INVENTORY as a hand-maintained
// heredoc. When the auth family grew a member (zuraffa_auth_firebase),
// nobody updated the publisher and the 7.3.2 mono release silently skipped
// it — discovered only by a manual pub.dev probe.
//
// The inventory must cover every publishable fleet pubspec that
// update_fleet.sh's discovery walk finds (root pubspec + packages/* +
// root-level zuraffa_* dirs, publish_to:none excluded), so a new federated
// member can never be silently left out of a release again.
void main() {
  test(
    'publish_fleet.sh inventory covers every fleet pubspec the discovery walk finds',
    () async {
      final root = await findProjectRoot();
      final script = File('$root/scripts/publish_fleet.sh');
      expect(
        script.existsSync(),
        isTrue,
        reason: 'scripts/publish_fleet.sh must exist at the repo root',
      );

      final content = script.readAsStringSync();

      // Standalone products must never enter the inventory.
      expect(
        content,
        isNot(contains('|zuraffa_browser|')),
        reason:
            'zuraffa_browser is a standalone product (publish_to: none), '
            'not a fleet package.',
      );

      final inventoryBody = _inventoryBody(content);

      final missing = _discoveredButNotInventoried(root, inventoryBody);
      expect(
        missing,
        isEmpty,
        reason:
            'publish_fleet.sh inventory is missing fleet members: $missing. '
            'Add them to the INVENTORY heredoc (mirroring update_fleet.sh '
            "discovery) so the fleet release never skips them again.",
      );
    },
  );
}

/// Extracts the INVENTORY heredoc body from the script text.
String _inventoryBody(String content) {
  const marker = "INVENTORY=\$(cat <<'EOF'";
  final start = content.indexOf(marker);
  expect(start, greaterThanOrEqualTo(0), reason: 'INVENTORY heredoc not found');
  final bodyStart = content.indexOf('\n', start) + 1;
  final end = content.indexOf('\nEOF', bodyStart);
  expect(end, greaterThan(bodyStart));
  return content.substring(bodyStart, end);
}

/// The fleet repos update_fleet.sh walks (FLEET_REPOS).
const _fleetRepos = [
  'zuraffa',
  'zuraffa_flutter',
  'zuraffa_ui',
  'zuraffa_agent',
  'zuraffa_code_editor',
  'zuraffa_ffi',
  'zuraffa_graphql',
  'zuraffa_observability',
  'zuraffa_storage',
  'zuraffa_session',
  'zuraffa_intents',
  'zuraffa_minio',
  'zuraffa_auth',
  'zuraffa_dashboard',
  'zuraffa_file_picker',
  'zuraffa_inappwebview',
  'zuraffa_ocr',
  'zuraffa_permissions',
  'zuraffa_purchase',
  'zuraffa_subscriptions',
  'zuraffa_notifications',
  'zuraffa_tui',
];

/// Replays the update_fleet.sh discovery walk against the sibling fleet
/// checkouts under the project root's parent directory (DEV_ROOT) and
/// returns every discovered publishable package name that [inventoryBody]
/// does not list.
Set<String> _discoveredButNotInventoried(
  String projectRoot,
  String inventoryBody,
) {
  final devRoot = Directory(projectRoot).parent.path;
  final discovered = <String>{};
  for (final repo in _fleetRepos) {
    final repoRoot = Directory('$devRoot/$repo');
    if (!repoRoot.existsSync()) continue;

    final specs = <String>[];
    final rootSpec = File('${repoRoot.path}/pubspec.yaml');
    if (rootSpec.existsSync()) specs.add(rootSpec.path);
    final packagesDir = Directory('${repoRoot.path}/packages');
    if (packagesDir.existsSync()) {
      for (final e in packagesDir.listSync().whereType<Directory>()) {
        final spec = File('${e.path}/pubspec.yaml');
        if (spec.existsSync()) specs.add(spec.path);
      }
    }
    for (final e in repoRoot.listSync().whereType<Directory>()) {
      final base = e.path.split('/').last;
      if (base.startsWith('zuraffa_')) {
        final spec = File('${e.path}/pubspec.yaml');
        if (spec.existsSync()) specs.add(spec.path);
      }
    }

    for (final spec in specs) {
      final lines = File(spec).readAsLinesSync();
      final name = lines
          .where((l) => l.startsWith('name:'))
          .map((l) => l.substring(5).trim())
          .firstOrNull;
      if (name == null || name.isEmpty) continue;
      final notPublishable = lines.any(
        (l) =>
            l.startsWith('publish_to:') &&
            !l.contains('none') &&
            l.trim() != 'publish_to:',
      );
      if (notPublishable) continue;
      discovered.add(name);
    }
  }

  final inventoried = inventoryBody
      .split('\n')
      .map((l) => l.split('|').first.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  return discovered.difference(inventoried);
}
