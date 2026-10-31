import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

// Regression guard for issue #2036.
//
// scripts/publish_fleet.sh kept its fleet INVENTORY as a hand-maintained
// heredoc. When the auth family grew a member (zuraffa_auth_firebase),
// nobody updated the publisher and the 7.3.2 mono release silently skipped
// it - discovered only by a manual pub.dev probe.
//
// The inventory must cover every publishable fleet pubspec that
// update_fleet.sh's discovery walk finds (root pubspec + packages/* +
// root-level zuraffa_* and zikzak_* dirs, publish_to: none excluded),
//
// Three complementary layers:
//  1. hermetic repo coverage - every fleet repository must appear in the
//     inventory's repo column (runs in CI with zero fleet checkouts);
//  2. package coverage - every publishable name discovered in the PRESENT
//     fleet checkouts must be inventoried; with ZURAFFA_REQUIRE_FLEET=1 an
//     absent checkout is a failure instead of a silent skip;
//  3. path-column validation - every inventory row for a present checkout
//     must point at an existing pubspec (the publish step cds into
//     dirname(path) and runs `dart pub publish` there; a wrong column
//     aborts the whole fleet run).

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

      // Layer 1: hermetic repo coverage. No fleet checkout needed, so CI
      // can never silently lose the whole coverage layer.
      final inventoriedRepos = _rows(
        inventoryBody,
      ).map((row) => row.repo).toSet();
      final missingRepos = _fleetRepos
          .where((r) => !inventoriedRepos.contains(r))
          .toList();
      expect(
        missingRepos,
        isEmpty,
        reason:
            'fleet repositories with no inventory row at all: MISSING_REPOS_EXPR. '
            'Add rows for them to the INVENTORY heredoc so the fleet release '
            'never skips a whole repository again.',
      );

      final devRoot = _devRoot(root);
      final absent = [
        for (final repo in _fleetRepos)
          if (!Directory('$devRoot/$repo').existsSync()) repo,
      ];
      if (absent.isNotEmpty) {
        final requireFleet =
            Platform.environment['ZURAFFA_REQUIRE_FLEET'] == '1';
        if (requireFleet) {
          fail(
            'fleet checkouts missing under $devRoot '
            '(ZURAFFA_REQUIRE_FLEET=1): ${absent.join(", ")}',
          );
        }
        // Coverage is partial, never silently: print what was skipped.
        // ignore: avoid_print
        print(
          'inventory coverage is PARTIAL - absent fleet checkouts under '
          '$devRoot: ${absent.join(", ")}',
        );
      }

      final missing = _discoveredButNotInventoried(devRoot, inventoryBody);
      expect(
        missing,
        isEmpty,
        reason:
            'publish_fleet.sh inventory is missing fleet members: $missing. '
            'Add them to the INVENTORY heredoc (mirroring update_fleet.sh '
            'discovery) so the fleet release never skips them again.',
      );
    },
  );

  test('every inventory pubspec path exists in its fleet checkout', () async {
    final root = await findProjectRoot();
    final content = File('$root/scripts/publish_fleet.sh').readAsStringSync();
    final devRoot = _devRoot(root);
    final broken = <String>[];
    for (final row in _rows(_inventoryBody(content))) {
      // A repo not cloned locally cannot validate its path column -
      // the same skip the coverage layer applies (printed there).
      if (!Directory('$devRoot/${row.repo}').existsSync()) continue;
      final spec = File('$devRoot/${row.repo}/${row.path}');
      if (!spec.existsSync()) {
        broken.add(
          '${row.name}: ${spec.path} - the publish step cds into '
          'dirname(path) and runs dart pub publish there, so this row '
          'would abort the fleet run.',
        );
      }
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });
}

/// One INVENTORY heredoc row: name|repo|pubspec-path.
typedef _InventoryRow = ({String name, String repo, String path});

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

/// Parses the heredoc body into structured rows, failing loudly on a
/// malformed row (each row must carry all three load-bearing columns).
List<_InventoryRow> _rows(String body) {
  final rows = <_InventoryRow>[];
  for (final line in body.split('\n')) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('|');
    expect(
      parts.length,
      3,
      reason: 'malformed INVENTORY row $line - expected name|repo|path',
    );
    rows.add((
      name: parts[0].trim(),
      repo: parts[1].trim(),
      path: parts[2].trim(),
    ));
  }
  return rows;
}

/// The fleet checkouts root, resolved the same way the publisher does it
/// (ZURAFFA_DEV_ROOT, defaulting to the sibling directory of this checkout).
String _devRoot(String projectRoot) =>
    Platform.environment['ZURAFFA_DEV_ROOT'] ??
    Directory(projectRoot).parent.path;

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

/// Replays the update_fleet.sh discovery walk against the fleet
/// checkouts under devRoot and returns every discovered publishable
/// package name that the inventory does not list.
Set<String> _discoveredButNotInventoried(String devRoot, String inventoryBody) {
  final discovered = <String>{};
  for (final repo in _fleetRepos) {
    final repoRoot = Directory('$devRoot/$repo');
    if (!repoRoot.existsSync()) continue;

    final specs = <String>[];
    // Root pubspec, guarded by the same name prefix the subdir loop
    // enforces - a workspace root like FFI_WS is not a fleet member.
    final rootSpec = File('${repoRoot.path}/pubspec.yaml');
    if (rootSpec.existsSync()) {
      final rootName = _pkgName(rootSpec.path);
      if (rootName != null &&
          (rootName.startsWith('zuraffa_') || rootName.startsWith('zikzak_'))) {
        specs.add(rootSpec.path);
      }
    }
    final packagesDir = Directory('${repoRoot.path}/packages');
    if (packagesDir.existsSync()) {
      for (final e in packagesDir.listSync().whereType<Directory>()) {
        final spec = File('${e.path}/pubspec.yaml');
        if (spec.existsSync()) specs.add(spec.path);
      }
    }
    for (final e in repoRoot.listSync().whereType<Directory>()) {
      final base = e.path.split('/').last;
      if (base.startsWith('zuraffa_') || base.startsWith('zikzak_')) {
        final spec = File('${e.path}/pubspec.yaml');
        if (spec.existsSync()) specs.add(spec.path);
      }
    }
    for (final spec in specs) {
      final name = _pkgName(spec);
      if (name == null || name.isEmpty) continue;
      // Only publish_to: none marks a package not publishable. A pubspec
      // naming another destination (a private publisher URL) is still a
      // fleet member the publisher must account for.
      final publishTo = File(spec)
          .readAsLinesSync()
          .where((l) => l.startsWith('publish_to:'))
          .map((l) => l.substring('publish_to:'.length).trim())
          .firstOrNull;
      if (publishTo != null && publishTo != 'none') continue;
      discovered.add(name);
    }
  }
  final inventoriedNames = _rows(inventoryBody).map((r) => r.name).toSet();
  return discovered.difference(inventoriedNames);
}

String? _pkgName(String spec) {
  final lines = File(spec).readAsLinesSync();
  final name = lines
      .where((l) => l.startsWith('name:'))
      .map((l) => l.substring(5).trim())
      .firstOrNull;
  return (name == null || name.isEmpty) ? null : name;
}
