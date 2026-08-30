/// `TreeSnapshot` — content and shape snapshot for a project's source trees
/// (spec 048-tdd-refactor, T004; behaviors U6, U7).
///
/// Generalizes `verify_red_command.dart`'s private `_ReadOnlyTreeSnapshot`
/// into a shared service so the refactor command can use the same
/// path -> `file:<sha256>` / `directory` / `link:<target>` fingerprinting
/// and symmetric `changedPaths` diff for both:
///   - the `test/` immutability check (FR-004), and
///   - the `lib/` attribution check (FR-005).
///
/// `verify_red_command.dart` keeps its private copy unchanged; this is the
/// shared, generalizable form that other TDD-loop commands can adopt.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// A read-only content snapshot of one or more project trees.
///
/// [entries] maps project-relative paths to a fingerprint string:
///   - `file:<sha256>` for files (hex digest of file bytes)
///   - `directory` for directories (the path always ends with `/`)
///   - `link:<target>` for symlinks (the resolved link target)
class TreeSnapshot {
  const TreeSnapshot(this.entries);

  /// Path -> fingerprint map.
  final Map<String, String> entries;

  /// Capture the current state of one or more trees under [projectRoot].
  ///
  /// [trees] defaults to `['test', 'lib']` — the two trees the refactor
  /// command watches. Missing trees contribute no entries (no crash).
  static Future<TreeSnapshot> capture(
    String projectRoot, {
    List<String> trees = const ['test', 'lib'],
  }) async {
    final entries = <String, String>{};
    for (final treeName in trees) {
      final tree = Directory(p.join(projectRoot, treeName));
      if (!await tree.exists()) continue;
      entries['$treeName/'] = 'directory';
      await for (final entity in tree.list(
        recursive: true,
        followLinks: false,
      )) {
        final relative = p
            .normalize(p.relative(entity.path, from: projectRoot))
            .replaceAll(p.separator, '/');
        if (entity is File) {
          entries[relative] =
              'file:${sha256.convert(await entity.readAsBytes())}';
        } else if (entity is Directory) {
          entries['$relative/'] = 'directory';
        } else if (entity is Link) {
          entries[relative] = 'link:${await entity.target()}';
        }
      }
    }
    return TreeSnapshot(entries);
  }

  /// Symmetric diff of paths and fingerprints.
  ///
  /// Returns the sorted list of paths whose fingerprint differs between this
  /// snapshot and [other], plus paths present in one but not the other.
  /// The diff is symmetric: `a.changedPaths(b)` and `b.changedPaths(a)`
  /// produce the same set.
  List<String> changedPaths(TreeSnapshot other) {
    final paths = {...entries.keys, ...other.entries.keys}.toList()..sort();
    return paths.where((path) => entries[path] != other.entries[path]).toList();
  }
}
